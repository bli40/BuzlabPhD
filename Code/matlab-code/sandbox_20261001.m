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

%% apply lags
load([basename, '.photometry.mat']);
load([basename, '.synclags.mat']);
photometry.EI_time = photometry.EI_time + synclags.timeShift_Doric;
photometry.E1_time = photometry.E1_time + synclags.timeShift_Doric;
photometry.E2_time = photometry.E2_time + synclags.timeShift_Doric;
photometry.synced = true;
save([basename, '.photometry.mat'],'photometry');

%% get behavioral performance
load([basename, '.session.mat']);
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
npWindows = timeIntan([npOnsets npOffsets]);
attempts = byl_mergeEvents(npWindows, 2);
rewards = timeIntan(rwOnsets)';
omissions = nan(length(attempts),1);
for i = 1:size(attempts,1)
    if sum((rewards > attempts(i,1) & rewards < attempts(i,1)+3)) == 0
        omissions(i) = attempts(i,1);
    end
end
omissions = omissions(~isnan(omissions));
%% 
rw_DA_NAc = byl_getETA(rewards, photometry.ROI1.E1dff, photometry.E1_time, 'duration',[-3 3], 'sampleRate',10000);
rw_DA_CA1 = byl_getETA(rewards, photometry.ROI2.E1dff, photometry.E1_time, 'duration',[-3 3], 'sampleRate',10000);
rw_DA_CA3 = byl_getETA(rewards, photometry.ROI3.E1dff, photometry.E1_time, 'duration',[-3 3], 'sampleRate',10000);

om_DA_NAc = byl_getETA(omissions, photometry.ROI1.E1dff, photometry.E1_time, 'duration',[-3 3], 'sampleRate',10000);
om_DA_CA1 = byl_getETA(omissions, photometry.ROI2.E1dff, photometry.E1_time, 'duration',[-3 3], 'sampleRate',10000);
om_DA_CA3 = byl_getETA(omissions, photometry.ROI3.E1dff, photometry.E1_time, 'duration',[-3 3], 'sampleRate',10000);



rw_ACh_NAc = byl_getETA(rewards, photometry.ROI1.E2dff, photometry.E2_time, 'duration',[-3 3], 'sampleRate',10000);
rw_ACh_CA1 = byl_getETA(rewards, photometry.ROI2.E2dff, photometry.E2_time, 'duration',[-3 3], 'sampleRate',10000);
rw_ACh_CA3 = byl_getETA(rewards, photometry.ROI3.E2dff, photometry.E2_time, 'duration',[-3 3], 'sampleRate',10000);

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
xlabel('time relative to reward (s)','FontSize',20);
ylabel('dF / F', 'FontSize',20);
title('Dopaminergic Response to Reward', 'FontSize',16);
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
xlabel('time relative to omission (s)','FontSize',20);
ylabel('dF / F', 'FontSize',20);
title('Dopaminergic Response to Omission', 'FontSize',16);
set(gca,'TitleHorizontalAlignment','left');
xline(0, '--r', 'HandleVisibility', 'off');

linkaxes()
%% acetylcholine responses
subplot(1,2,2); cla; hold on;
colb = copper(3);
e = 1;
plot(rw_ACh_NAc.window, rw_ACh_NAc.avg, 'color', colb(e,:), 'LineWidth', 2,...
    'DisplayName','NAc Dopamine');
x = [rw_ACh_NAc.window, fliplr(rw_ACh_NAc.window)];
y = [rw_ACh_NAc.avg + rw_ACh_NAc.sem, fliplr(rw_ACh_NAc.avg - rw_ACh_NAc.sem)];
patch(x,y,colb(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

e = 2;
plot(rw_ACh_CA1.window, rw_ACh_CA1.avg, 'color', colb(e,:), 'LineWidth', 2,...
    'DisplayName','CA1 Dopamine');
x = [rw_ACh_CA1.window, fliplr(rw_ACh_CA1.window)];
y = [rw_ACh_CA1.avg + rw_ACh_CA1.sem, fliplr(rw_ACh_CA1.avg - rw_ACh_CA1.sem)];
patch(x,y,colb(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

e = 3;
plot(rw_ACh_CA3.window, rw_ACh_CA3.avg, 'color', colb(e,:), 'LineWidth', 2,...
    'DisplayName','CA3 Dopamine');
x = [rw_ACh_CA3.window, fliplr(rw_ACh_CA3.window)];
y = [rw_ACh_CA3.avg + rw_ACh_CA3.sem, fliplr(rw_ACh_CA3.avg - rw_ACh_CA3.sem)];
patch(x,y,colb(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');

legend();
xlabel('time relative to reward (s)','FontSize',20);
ylabel('dF / F', 'FontSize',20);
title('Dopaminergic Response to Reward', 'FontSize',16);
xline(0, '--r', 'HandleVisibility', 'off');

linkaxes()