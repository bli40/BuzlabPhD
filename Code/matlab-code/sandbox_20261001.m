%% Exploratory code for GRAB sensor analysis
clear all; close all;
basepath = pwd;
[~, basename, ~] = fileparts(basepath);

%% (2.5) process digitalin files
load([basename, '.session.mat']);
% digitalIn = bz_getDigitalIn(pwd,'fs',session.extracellular.sr);

%% (3) preprocess fiber photometry
byl_preprocessPhotometry(pwd,'show',true,'plottype',1,'saveMat',true,'sync',false);

%flip channels:
vidFrame = figure(42);
chi = vidFrame.Children.Children;
for c = 1:numel(chi)
    chi(c).Children = flipud(chi(c).Children);
end

%%
% Extract barcode data from Intan file
srIntan = session.extracellular.sr;
digitalIntan = 'digitalin.dat';
m = memmapfile(digitalIntan, 'Format', 'uint16', 'writable', false);
raw_digital = m.Data;
clear m

tester = zeros(length(raw_digital), 1);    
syncRandChan = 1;
barcodeIntan = double(bitget(raw_digital,syncRandChan));
tIntan = linspace(0,length(barcodeIntan)/srIntan,length(barcodeIntan));

% Extract barcode data from Doric file
digitalDoric = dir('*_0003.csv');
dio = readtable(string(digitalDoric.name));
srDoric = 1/mean(diff(dio.Time)); %Get samplingrate
barcodeDoric = dio.DigitalCh2; %High/low signal
tDoric = dio.Time;

%% Extract barcode data from video file
mazevid = dir('*.mp4');
v = VideoReader([mazevid.name]);
h = v.Height;
w = v.Width;
v.CurrentTime = 0;
srBlackfly = v.FrameRate;
nFramesEst = max(1, ceil(v.Duration * v.FrameRate));
barcodeBlackfly = nan(nFramesEst, 1, 'double');

% circle mask
mask = false(h,w);
cx = 460; cy = 120;        % center (use your center)
circleRadius = 5;                       % center circle radius
[xg,yg] = meshgrid(1:w,1:h);
maskCircle = (xg - cx).^2 + (yg - cy).^2 <= circleRadius^2;
mask = mask | maskCircle;

tic;
n=0;
while hasFrame(v)
    n=n+1;
    vidFrame = readFrame(v);
    if ndims(vidFrame) == 3
        vidFrame = vidFrame(:,:,1);
    end
    barcodeBlackfly(n) = sum(double(vidFrame(mask)),'all');
end
toc;
barcodeBlackfly = barcodeBlackfly(~isnan(barcodeBlackfly));
temp = barcodeBlackfly;

%%
barcodeBlackfly = temp;
cutoff = round(mean([min(barcodeBlackfly), max(barcodeBlackfly)]));
barcodeBlackfly = barcodeBlackfly > cutoff;
%% precompute bounding box of mask
% rows = any(maskCircle, 2);
% cols = any(maskCircle, 1);
% rowIdx = find(rows);
% colIdx = find(cols);
% rMin = rowIdx(1); rMax = rowIdx(end);
% cMin = colIdx(1); cMax = colIdx(end);
% maskCrop = maskCircle(rMin:rMax, cMin:cMax);  % small cropped mask
% 
% v.CurrentTime = 0;
% n = 0;
% tic
% while hasFrame(v)
%     n = n + 1;
%     vidFrame = readFrame(v);
%     patch = vidFrame(rMin:rMax, cMin:cMax, 1);  % crop first, then mask
%     barcodeBlackfly(n) = sum(double(patch(maskCrop)), 'all');
% end
% toc

%% Resample barcodeIntan to match barcodeDoric sampling rate
downsampleRate = srIntan / srDoric;
barcodeIntan_Downsampled = downsample(double(barcodeIntan), downsampleRate);
tIntan_Downsampled = linspace(0, length(barcodeIntan) / srIntan, length(barcodeIntan_Downsampled));
tDoric = linspace(0, length(barcodeDoric) / double(srDoric), length(barcodeDoric));

% Compute cross-correlation
[xcorrValues, lags] = xcorr(double(barcodeIntan_Downsampled), double(barcodeDoric));
[maxCorr, maxCorrIndex] = max(xcorrValues);
maxLag = lags(maxCorrIndex); % Lag in samples at 130 Hz

% Compute time shift
timeShift_Doric = maxLag / double(srDoric); % Convert lag to time (seconds)

% Add to tDoric
tDoric_shifted = tDoric + timeShift_Doric;
disp(timeShift_Doric);

%% Resample barcodeIntan to match barcodeBlackfly sampling rate
downsampleRate = srIntan / srBlackfly;
try
    barcodeIntan_Downsampled = downsample(double(barcodeIntan), downsampleRate);
catch
    barcodeIntan_Downsampled = resample(double(barcodeIntan), srBlackfly, srIntan);
end
tIntan_Downsampled = linspace(0, length(barcodeIntan) / srIntan, length(barcodeIntan_Downsampled));
tBlackfly = linspace(0, length(barcodeBlackfly) / double(srBlackfly), length(barcodeBlackfly));

% Compute cross-correlation
[xcorrValues, lags] = xcorr(double(barcodeIntan_Downsampled), double(barcodeBlackfly));
[maxCorr, maxCorrIndex] = max(xcorrValues);
maxLag = lags(maxCorrIndex); % Lag in samples at 130 Hz

% Compute time shift
timeShift_Blackfly = maxLag / double(srBlackfly); % Convert lag to time (seconds)

% Add to tBlackfly
tBlackfly_shifted = tBlackfly + timeShift_Blackfly;
disp(timeShift_Blackfly);

%%
T = {tIntan(:), tDoric_shifted(:), tBlackfly_shifted(:)};
D = {barcodeIntan(:)+2, barcodeDoric(:)+1, barcodeBlackfly(:)};
quickTimeSeriesScroller(T,D)

%%
T = {tIntan(:), tDoric_shifted(:)};
D = {barcodeIntan(:)+2, barcodeDoric(:)+1};
quickTimeSeriesScroller(T,D)

%%
synclags.timeShift_Intan = 0;
synclags.timeShift_Doric = timeShift_Doric;
synclags.timeShift_Blackfly = timeShift_Blackfly;
save([basepath, filesep, basename, '.synclags.mat'], 'synclags');



%% get behavioral performance
clear all; close all;
basename = bz_BasenameFromBasepath(pwd);
load([basename, '.session.mat']);
load([basename, '.photometry.mat']);
srIntan = session.extracellular.sr;
digitalIntan = 'digitalin.dat';
m = memmapfile(digitalIntan, 'Format', 'uint16', 'writable', false);
raw_digital = m.Data;
clear m

npChan = 4;
rwChan = 12;
trChan = 13;

channels2Extract = [npChan, rwChan, trChan];

for i = 1:numel(channels2Extract)
    digiIntan{channels2Extract(i)} = double(bitget(raw_digital,channels2Extract(i)));
end
timeIntan = linspace(0,length(digiIntan{trChan})/srIntan,length(digiIntan{trChan}));

%% perform second regression to remove ACh signal from DA signal
g1refit = fitlm(photometry.ROI1.red.dff, photometry.ROI1.green.dff);
g1est = predict(g1refit,photometry.ROI1.red.dff);
photometry.ROI1.green.dff = photometry.ROI1.green.dff - g1est;

g2refit = fitlm(photometry.ROI2.red.dff, photometry.ROI2.green.dff);
g2est = predict(g2refit,photometry.ROI2.red.dff);
photometry.ROI2.green.dff = photometry.ROI2.green.dff - g2est;

g3refit = fitlm(photometry.ROI3.red.dff, photometry.ROI3.green.dff);
g3est = predict(g3refit,photometry.ROI3.red.dff);
photometry.ROI3.green.dff = photometry.ROI3.green.dff - g3est;
disp('2nd regression done.')
%%
% Detect behavioral event onsets from the extracted digital channels
npOnsets = find(diff(digiIntan{npChan}) > 0) + 1;
rwOnsets = find(diff(digiIntan{rwChan}) > 0) + 1;
trOnsets = find(diff(digiIntan{trChan}) > 0) + 1;
omOnsets = find(diff(digiIntan{npChan} & ~digiIntan{rwChan}) > 0) + 1;
% Detect behavioral event offsets from the extracted digital channels
npOffsets = find(diff(digiIntan{npChan}) < 0) + 1;
rwOffsets = find(diff(digiIntan{rwChan}) < 0) + 1;
trOffsets = find(diff(digiIntan{trChan}) < 0) + 1;
omOffsets = find(diff(digiIntan{npChan} & ~digiIntan{rwChan}) < 0) + 1;

trialStarts = timeIntan(trOnsets);
pumpstarts = timeIntan(rwOnsets);
npWindows = timeIntan([npOnsets npOffsets]);

attempts = [];
for i = 1:numel(trialStarts)
    if i < numel(trialStarts)
        trialpokes = npWindows(npWindows(:,1) >= trialStarts(i) & npWindows(:,1) < trialStarts(i+1),:);
    else
        trialpokes = npWindows(npWindows(:,1) >= trialStarts(i),:);
    end

    if ~isempty(trialpokes)
        attempts = [attempts; byl_mergeEvents(trialpokes,2)];
    end
end
attempts = attempts(:,1);

% attempts = attempts(attempts <= photometry.ROI1.iso.ts(photometry.epochs.photom(2)));
% trialStarts = trialStarts(trialStarts <= photometry.ROI1.iso.ts(photometry.epochs.photom(2)));
% pumpstarts = pumpstarts(pumpstarts <= photometry.ROI1.iso.ts(photometry.epochs.photom(2)));



% create a set of vectors that can be used to index to particular pokes or
% trials
[attempt_trial_num, attempt_poke_order, attempt_outcome] = deal(zeros(size(attempts)));

for i = 1:numel(trialStarts)
    if i < numel(trialStarts)
        idx = attempts >= trialStarts(i) & attempts < trialStarts(i+1);
    elseif i == numel(trialStarts)
        idx = attempts >= trialStarts(i);
    end
    attempt_trial_num(idx) = i;
    pokeorder = cumsum(idx);
    attempt_poke_order(idx) = pokeorder(idx);
end

for i = 1:numel(attempts)
    idx = find(pumpstarts>=attempts(i),1,'first');
    if pumpstarts(idx)-attempts(i) <= 0.1
        attempt_outcome(i) = 1;
    end

end

rewarded = attempts(logical(attempt_outcome));
omitted = attempts(~(attempt_outcome) & attempt_poke_order == 1);
later = attempts(~(attempt_outcome) & attempt_poke_order ~= 1);
unrewarded = attempts(~attempt_outcome);

figure(1); clf; hold on;
fig = gcf;
fig.Units = 'pixels';
fig.Position = [100 500 2300 600];
axs = findall(gcf, 'Type', 'axes');
for k = 1:numel(axs)
    axs(k).LooseInset = axs(k).TightInset;
end

xline(trialStarts,'-','Color',repmat(0.5,1,3));
plot(rewarded,0.1*ones(size(rewarded)),'g|','MarkerSize',20,'LineWidth',1.5)
plot(omitted,0.1*ones(size(omitted)),'r|','MarkerSize',15,'LineWidth',1.5)
plot(later,0.1*ones(size(later)),'k|','MarkerSize',10,'LineWidth',1.5)

plot(pumpstarts,0.2*ones(size(pumpstarts)),'b|','MarkerSize',20,'LineWidth',2)
ylim([0 0.3])

%% rewarded vs. unrewarded
rw_DA_NAc = byl_getETA(rewarded, photometry.ROI1.green.dff, photometry.ROI1.green.ts, 'duration',[-3 3], 'sampleRate',10000);
rw_DA_CA1 = byl_getETA(rewarded, photometry.ROI2.green.dff, photometry.ROI2.green.ts, 'duration',[-3 3], 'sampleRate',10000);
rw_DA_CA3 = byl_getETA(rewarded, photometry.ROI3.green.dff, photometry.ROI3.green.ts, 'duration',[-3 3], 'sampleRate',10000);

om_DA_NAc = byl_getETA(unrewarded, photometry.ROI1.green.dff, photometry.ROI1.green.ts, 'duration',[-3 3], 'sampleRate',10000);
om_DA_CA1 = byl_getETA(unrewarded, photometry.ROI2.green.dff, photometry.ROI2.green.ts, 'duration',[-3 3], 'sampleRate',10000);
om_DA_CA3 = byl_getETA(unrewarded, photometry.ROI3.green.dff, photometry.ROI3.green.ts, 'duration',[-3 3], 'sampleRate',10000);

rw_ACh_NAc = byl_getETA(rewarded, photometry.ROI1.red.dff, photometry.ROI1.red.ts, 'duration',[-3 3], 'sampleRate',10000);
rw_ACh_CA1 = byl_getETA(rewarded, photometry.ROI2.red.dff, photometry.ROI2.red.ts, 'duration',[-3 3], 'sampleRate',10000);
rw_ACh_CA3 = byl_getETA(rewarded, photometry.ROI3.red.dff, photometry.ROI3.red.ts, 'duration',[-3 3], 'sampleRate',10000);

om_ACh_NAc = byl_getETA(unrewarded, photometry.ROI1.red.dff, photometry.ROI1.red.ts, 'duration',[-3 3], 'sampleRate',10000);
om_ACh_CA1 = byl_getETA(unrewarded, photometry.ROI2.red.dff, photometry.ROI2.red.ts, 'duration',[-3 3], 'sampleRate',10000);
om_ACh_CA3 = byl_getETA(unrewarded, photometry.ROI3.red.dff, photometry.ROI3.red.ts, 'duration',[-3 3], 'sampleRate',10000);

%% first poke vs later pokes
rw_DA_NAc = byl_getETA(attempts(attempt_poke_order == 1), photometry.ROI1.green.dff, photometry.ROI1.green.ts, 'duration',[-3 3], 'sampleRate',10000);
rw_DA_CA1 = byl_getETA(attempts(attempt_poke_order == 1), photometry.ROI2.green.dff, photometry.ROI2.green.ts, 'duration',[-3 3], 'sampleRate',10000);
rw_DA_CA3 = byl_getETA(attempts(attempt_poke_order == 1), photometry.ROI3.green.dff, photometry.ROI3.green.ts, 'duration',[-3 3], 'sampleRate',10000);

om_DA_NAc = byl_getETA(attempts(attempt_poke_order ~= 1), photometry.ROI1.green.dff, photometry.ROI1.green.ts, 'duration',[-3 3], 'sampleRate',10000);
om_DA_CA1 = byl_getETA(attempts(attempt_poke_order ~= 1), photometry.ROI2.green.dff, photometry.ROI2.green.ts, 'duration',[-3 3], 'sampleRate',10000);
om_DA_CA3 = byl_getETA(attempts(attempt_poke_order ~= 1), photometry.ROI3.green.dff, photometry.ROI3.green.ts, 'duration',[-3 3], 'sampleRate',10000);

rw_ACh_NAc = byl_getETA(attempts(attempt_poke_order == 1), photometry.ROI1.red.dff, photometry.ROI1.red.ts, 'duration',[-3 3], 'sampleRate',10000);
rw_ACh_CA1 = byl_getETA(attempts(attempt_poke_order == 1), photometry.ROI2.red.dff, photometry.ROI2.red.ts, 'duration',[-3 3], 'sampleRate',10000);
rw_ACh_CA3 = byl_getETA(attempts(attempt_poke_order == 1), photometry.ROI3.red.dff, photometry.ROI3.red.ts, 'duration',[-3 3], 'sampleRate',10000);

om_ACh_NAc = byl_getETA(attempts(attempt_poke_order ~= 1), photometry.ROI1.red.dff, photometry.ROI1.red.ts, 'duration',[-3 3], 'sampleRate',10000);
om_ACh_CA1 = byl_getETA(attempts(attempt_poke_order ~= 1), photometry.ROI2.red.dff, photometry.ROI2.red.ts, 'duration',[-3 3], 'sampleRate',10000);
om_ACh_CA3 = byl_getETA(attempts(attempt_poke_order ~= 1), photometry.ROI3.red.dff, photometry.ROI3.red.ts, 'duration',[-3 3], 'sampleRate',10000);

%% dopamine
figure(88); clf; hold on;

subplot(1,2,1); cla; hold on;
cola = lines(4);
e = 1;
plot(rw_DA_NAc.window, rw_DA_NAc.avg, 'color', cola(e,:), 'LineWidth', 2,...
    'DisplayName','NAc Dopamine');
x = [rw_DA_NAc.window, fliplr(rw_DA_NAc.window)];
y = [rw_DA_NAc.avg + rw_DA_NAc.sem, fliplr(rw_DA_NAc.avg - rw_DA_NAc.sem)];
patch(x,y,cola(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

e = 2;
plot(rw_DA_CA1.window, rw_DA_CA1.avg, 'color', cola(e,:), 'LineWidth', 2,...
    'DisplayName','CA1 Dopamine');
x = [rw_DA_CA1.window, fliplr(rw_DA_CA1.window)];
y = [rw_DA_CA1.avg + rw_DA_CA1.sem, fliplr(rw_DA_CA1.avg - rw_DA_CA1.sem)];
patch(x,y,cola(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

e = 3;
plot(rw_DA_CA3.window, rw_DA_CA3.avg, 'color', cola(e,:), 'LineWidth', 2,...
    'DisplayName','CA3 Dopamine');
x = [rw_DA_CA3.window, fliplr(rw_DA_CA3.window)];
y = [rw_DA_CA3.avg + rw_DA_CA3.sem, fliplr(rw_DA_CA3.avg - rw_DA_CA3.sem)];
patch(x,y,cola(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

legend('FontSize',12,'Location','northwest');
xlabel('time relative to poke (s)','FontSize',20);
ylabel('dF / F', 'FontSize',20);
title('Dopaminergic Response to Rewarded Poke', 'FontSize',16);
set(gca,'TitleHorizontalAlignment','left');
xline(0, '--r', 'HandleVisibility', 'off');

subplot(1,2,2); cla; hold on;
colb = lines(4);
e = 1;
plot(om_DA_NAc.window, om_DA_NAc.avg, 'color', colb(e,:), 'LineWidth', 2,...
    'DisplayName','NAc Dopamine');
x = [om_DA_NAc.window, fliplr(om_DA_NAc.window)];
y = [om_DA_NAc.avg + om_DA_NAc.sem, fliplr(om_DA_NAc.avg - om_DA_NAc.sem)];
patch(x,y,colb(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

e = 2;
plot(om_DA_CA1.window, om_DA_CA1.avg, 'color', colb(e,:), 'LineWidth', 2,...
    'DisplayName','CA1 Dopamine');
x = [om_DA_CA1.window, fliplr(om_DA_CA1.window)];
y = [om_DA_CA1.avg + om_DA_CA1.sem, fliplr(om_DA_CA1.avg - om_DA_CA1.sem)];
patch(x,y,colb(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

e = 3;
plot(om_DA_CA3.window, om_DA_CA3.avg, 'color', colb(e,:), 'LineWidth', 2,...
    'DisplayName','CA3 Dopamine');
x = [om_DA_CA3.window, fliplr(om_DA_CA3.window)];
y = [om_DA_CA3.avg + om_DA_CA3.sem, fliplr(om_DA_CA3.avg - om_DA_CA3.sem)];
patch(x,y,colb(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

legend('FontSize',12,'Location','northwest');
xlabel('time relative to poke (s)','FontSize',20);
ylabel('dF / F', 'FontSize',20);
title('Dopaminergic Response to Unrewarded Poke', 'FontSize',16);
set(gca,'TitleHorizontalAlignment','left');
xline(0, '--r', 'HandleVisibility', 'off');

linkaxes()
%% acetylcholine responses
figure(89); clf; hold on;

subplot(1,2,1); cla; hold on;
cola = lines(4);
e = 1;
plot(rw_ACh_NAc.window, rw_ACh_NAc.avg, 'color', cola(e,:), 'LineWidth', 2,...
    'DisplayName','NAc Acetylcholine');
x = [rw_ACh_NAc.window, fliplr(rw_ACh_NAc.window)];
y = [rw_ACh_NAc.avg + rw_ACh_NAc.sem, fliplr(rw_ACh_NAc.avg - rw_ACh_NAc.sem)];
patch(x,y,cola(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

e = 2;
plot(rw_ACh_CA1.window, rw_ACh_CA1.avg, 'color', cola(e,:), 'LineWidth', 2,...
    'DisplayName','CA1 Acetylcholine');
x = [rw_ACh_CA1.window, fliplr(rw_ACh_CA1.window)];
y = [rw_ACh_CA1.avg + rw_ACh_CA1.sem, fliplr(rw_ACh_CA1.avg - rw_ACh_CA1.sem)];
patch(x,y,cola(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

e = 3;
plot(rw_ACh_CA3.window, rw_ACh_CA3.avg, 'color', cola(e,:), 'LineWidth', 2,...
    'DisplayName','CA3 Acetylcholine');
x = [rw_ACh_CA3.window, fliplr(rw_ACh_CA3.window)];
y = [rw_ACh_CA3.avg + rw_ACh_CA3.sem, fliplr(rw_ACh_CA3.avg - rw_ACh_CA3.sem)];
patch(x,y,cola(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

legend('FontSize',12,'Location','northwest');
xlabel('time relative to poke (s)','FontSize',20);
ylabel('dF / F', 'FontSize',20);
title('Cholinergic Response to Rewarded Poke', 'FontSize',16);
set(gca,'TitleHorizontalAlignment','left');
xline(0, '--r', 'HandleVisibility', 'off');

subplot(1,2,2); cla; hold on;
colb = lines(4);
e = 1;
plot(om_ACh_NAc.window, om_ACh_NAc.avg, 'color', colb(e,:), 'LineWidth', 2,...
    'DisplayName','NAc Acetylcholine');
x = [om_ACh_NAc.window, fliplr(om_ACh_NAc.window)];
y = [om_ACh_NAc.avg + om_ACh_NAc.sem, fliplr(om_ACh_NAc.avg - om_ACh_NAc.sem)];
patch(x,y,colb(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

e = 2;
plot(om_ACh_CA1.window, om_ACh_CA1.avg, 'color', colb(e,:), 'LineWidth', 2,...
    'DisplayName','CA1 Acetylcholine');
x = [om_ACh_CA1.window, fliplr(om_ACh_CA1.window)];
y = [om_ACh_CA1.avg + om_ACh_CA1.sem, fliplr(om_ACh_CA1.avg - om_ACh_CA1.sem)];
patch(x,y,colb(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

e = 3;
plot(om_ACh_CA3.window, om_ACh_CA3.avg, 'color', colb(e,:), 'LineWidth', 2,...
    'DisplayName','CA3 Acetylcholine');
x = [om_ACh_CA3.window, fliplr(om_ACh_CA3.window)];
y = [om_ACh_CA3.avg + om_ACh_CA3.sem, fliplr(om_ACh_CA3.avg - om_ACh_CA3.sem)];
patch(x,y,colb(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

legend('FontSize',12,'Location','northwest');
xlabel('time relative to poke (s)','FontSize',20);
ylabel('dF / F', 'FontSize',20);
title('Cholinergic Response to Unrewarded Poke', 'FontSize',16);
set(gca,'TitleHorizontalAlignment','left');
xline(0, '--r', 'HandleVisibility', 'off');

linkaxes()

%% edits to preprocess photometry
numExcite = 3;
datafiles = dir("*\*_*_*.csv");
epochs = unique({datafiles.folder});
channels = unique(split({datafiles.name},'_'));
channels = channels(contains(channels, '.csv'));

numEpochs = numel(epochs);
numChannels = numel(channels);

fprintf("Found %i putative RBFMC data files.\n",numel(datafiles));
fprintf('\t  <strong>Epochs:</strong> %i\n\t<strong>Channels:</strong> %i\n',numEpochs,numChannels);
fprintf('Building session cell structure...\n')
sessioncell = cell(numEpochs, numChannels);

for e = 1:numEpochs
    epoch_datafiles = datafiles(cellfun(@(x) strcmp(x,epochs{e}), {datafiles.folder}));
    for c = 1:numChannels
        if contains(epoch_datafiles(c).name, channels)
            filestr = [epoch_datafiles(c).folder filesep epoch_datafiles(c).name];
            sessioncell{e,c} = readtable(filestr);
        else
            fprintf(2,'\tEpoch %i does not have channel %s\n',e,extractBefore(channels{c},'.'));
        end
    end
    % --- make all lengths the same for just the light channels
    chanLength = cellfun(@(x) size(x,1),sessioncell(e,1:numExcite));
    if max(abs(diff(chanLength))) > 0
        fprintf(2,'\tChannel sample numbers unequal. Removing %i extra samples.\n', max(abs(diff(chanLength))))
        minLength = min(chanLength(1,:));
        for c = 1:numExcite
            sessioncell{e,c} = sessioncell{e,c}(1:minLength,:);
        end
    end
end


%%

%% Photometry Scroller
livePlot = true;
basename = bz_BasenameFromBasepath(pwd);
load([basename, '.photometry.mat']);
YData = [photometry.ROI1.green.dff photometry.ROI2.green.dff photometry.ROI3.green.dff];
XData = [photometry.ROI1.green.ts photometry.ROI2.green.ts photometry.ROI3.green.ts];

quickTimeSeriesScroller(XData, YData, ...
    'secondAxisInds',1, ...
    'timeSeriesNames',{'NAc','R-CA1','L-CA3'}, ...
    'events',{unrewarded,pumpstarts}, ...
    'eventColors',{'r','b'}, ...
    'eventNames',{'unrewarded','pumpstarts'});

%% PSD of fiber
[pxx,f] = pspectrum(photometry.ROI1, pyrLFP.samplingRate,'FrequencyLimits',[0 625]);
plot(f, pow2db(pxx),'-k','LineWidth',1.5,'DisplayName',sprintf('full sess'));
legend('FontSize',15);
title(sprintf('%s - epoch PSD',basename),'Interpreter','none','FontSize',15);
xlabel('frequency (Hz)','FontSize',15);
ylabel('power (dB)','FontSize',15);