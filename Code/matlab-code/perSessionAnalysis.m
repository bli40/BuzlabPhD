%% Load Data Directory and filenames
clear all;
close all;
% clc;
% addpath('C:\Users\Gergely\Documents\Brian\BuzlabPhD\project-dopamineTagging\Code\matlab-code');
% directory = readtable('C:\Users\Gergely\Documents\Brian\Data\project-dopamineTagging-data\data-directory.xlsx');
% personal laptop / PC directory structure:
addpath("C:\Users\brian\BuzlabPhD\project-dopamineTagging\Code\matlab-code\");
directory = readtable("\\research-cifs.nyumc.org\research\buzsakilab\Buzsakilabspace\LabShare\BrianLi\project-dopamine-tagging\data-directories.xlsx");
sessions2analyze = logical(directory.Use);
animals2analyze = strcmp(directory.Mouse,'N17');
twoRegions = directory.HPC & directory.STR;
% sessionPaths = directory.Path(sessions2analyze & animals2analyze);
sessionPaths = directory.Path(sessions2analyze);
disp(sessionPaths);

[hasConc, hasSync, hasMat, numEpochs] = deal(zeros(size(directory,1),1));
whichRegions = cell(size(directory,1),1);
verbose = false;

for s = 1:numel(sessionPaths)
    preprocessedPaths = dir(fullfile(sessionPaths{s},'\*.photometry.*.mat'));
    [~,name,~] = fileparts(sessionPaths{s});
    fprintf('<strong>%d) %s </strong>\n',s,name)
    if numel(preprocessedPaths) ~= 0
        hasConc(s) = 1;
        for e = 1:numel(preprocessedPaths)
            sessionName = split(preprocessedPaths(e).name,'.');
            fprintf(2,'<strong>\t%s\n</strong>',preprocessedPaths(e).name);
        end
    end
    
    syncPhotometryPaths = dir(fullfile(sessionPaths{s},'*\*_new_photometry_sync.mat'));
    if numel(syncPhotometryPaths) ~= 0
        hasSync(s) = 1;
    end
    if numel(preprocessedPaths) == 0 || verbose
        regions = unique(extractBefore({syncPhotometryPaths.name}, '-'));
        for i = 1:numel(regions)
            fprintf('\t%s - %i files ready to <strong>concatenate</strong>.\n', regions{i}, sum(contains({syncPhotometryPaths.name},regions{i})));
            fprintf('\t\t%s\n',syncPhotometryPaths(contains({syncPhotometryPaths.name},regions{i})).name);
        end
    end

    photometryDataPaths = dir(fullfile(sessionPaths{s},'*\*_new_photometry.mat'));
    if numel(photometryDataPaths) ~= 0
        hasMat(s) = 1;
    end
    if numel(syncPhotometryPaths) == 0 || verbose
        regions = unique(extractBefore({photometryDataPaths.name}, '-'));
        for i = 1:numel(regions)
            fprintf('\t%s - %i files ready to <strong>synchronize</strong>.\n', regions{i}, sum(contains({photometryDataPaths.name},regions{i})));
            fprintf('\t\t%s\n',photometryDataPaths(contains({photometryDataPaths.name},regions{i})).name);
        end
    end

    epochsDataPaths = dir(fullfile(sessionPaths{s},'*\*.ppd'));
    regions = upper(unique(extractAfter(extractBefore({epochsDataPaths.name},'-'),'_')));
    regions = cellfun(@(x) x(1:3), regions, 'UniformOutput', false);
    whichRegions{s} = regions;
    numEpochs(s) = numel(unique({epochsDataPaths.folder}));
    if numel(photometryDataPaths) == 0 || verbose
        regions = unique(extractBefore({syncPhotometryPaths.name}, '-'));
        for i = 1:numel(regions)
            fprintf('\t%s - %i files ready to <strong>preprocess</strong>.\n', regions{i}, sum(contains({epochsDataPaths.name},regions{i})));
            fprintf('\t\t%s\n',epochsDataPaths(contains({epochsDataPaths.name},regions{i})).name);
        end
    end
end

fileTable = table(hasConc, hasSync, hasMat, whichRegions, numEpochs, ...
    'VariableNames',{'hasConc','hasSync','hasMat','whichRegions','numEpochs'});

%% Pick Session
% sesh = 29;
% cd(sessionPaths{sesh});
% [~,name,~] = fileparts(sessionPaths{sesh});
thisdir = dir('*.session.mat');
[~,name,~] = fileparts(thisdir.folder);
clearvars -except fileTable sessionPaths directory sesh name

%% Initialize
try
    d = (dir(fullfile(sessionPaths{sesh},'N*.session.mat')));
    load(fullfile(d(1).folder, d(1).name))
catch
    disp('No session.mat file');
end

try
    d = (dir(fullfile('N*.behavior.matrices.mat')));
    load(fullfile(d(1).folder, d(1).name))

    d = (dir(fullfile('N*.TrialBehavior.mat')));
    load(fullfile(d(1).folder, d(1).name))

    d = (dir(fullfile('N*.Tracking.Behavior.mat')));
    load(fullfile(d(1).folder, d(1).name))
catch
    disp('No behavioral data.');
end


try
    d = (dir(fullfile('N*.ripples.events.mat')));
    load(fullfile(d(1).folder, d(1).name))
    
    d = (dir(fullfile('N*.ripples.stats.mat')));
    load(fullfile(d(1).folder, d(1).name));
catch
    disp('No ripple detection.')
end

try
    d = (dir(fullfile('N*.SleepState.states.mat')));
    load(fullfile(d(1).folder, d(1).name))
catch
    disp('No sleep scoring.')
end

try
    d = dir(fullfile('N*.photometry.*.mat'));
    for re = 1:numel(d)
       photom{re} = load(fullfile(d(re).folder, d(re).name)); 
    end
    
    try
        photom_hpc = photom{contains({d(:).name},'HPC')}.concPhotom;
    catch
        disp('No HPC Data');
    end
    
    try
        photom_str = photom{contains({d(:).name},'STR')}.concPhotom;
    catch
        disp('No STR Data');
    end
    
    try
        photom_pfc = photom{contains({d(:).name},'PFC')}.concPhotom;
    catch
        disp('No PFC Data');
    end
catch
    disp('No photometry preprocessed.')
end

% d = (dir(fullfile('N*.MergePoints.events.mat')));
% load(fullfile(d(1).folder, d(1).name))

fprintf('%s - data loaded\n',name)

%% Find Ripples - Solos and Bursts
firstPass = ripples.timestamps;

% Merge ripples if inter-ripple period is too short <- from bz_FindRipples
disp(['Before ripple burst merge: ' num2str(length(firstPass)) ' events.'])
minInterRippleInterval = 0.150; %s;
secondPass = [];
id = [];
ripple = firstPass(1,:);
for i = 2:size(firstPass,1)
	if firstPass(i,1) - ripple(2) < minInterRippleInterval
		% Merge
		ripple = [ripple(1) firstPass(i,2)];    % prev ripple's endpoint is replaced by current ripple's endpoint. /kg
	    id = [id; 1];
    else
		secondPass = [secondPass; ripple];     % secondPass is updated each cycle and contains all previous ripples. /kg
		ripple = firstPass(i,:);                % ripple is updated each cycle and contains start and end indices. /kg
    end
end

secondPass = [secondPass ; ripple];
if isempty(secondPass)
	disp('Ripple burst merge failed');
	return
else
	disp(['After ripple burst merge: ' num2str(length(secondPass)) ' events.']);
end
solos = intersect(firstPass, secondPass, 'rows');
bursts = setdiff(secondPass, firstPass, 'rows');

%% Ripple Burst Index and Size
aa = ismember(ripples.timestamps, bursts);
bb = cumsum(aa);
cc = bb(:,1) > bb(:,2);
cc = cc + aa(:,2);
ripBurstNum = cumsum(aa(:,1));
ripBurstNum(~logical(cc)) = 0;
[ripBurstIdx, ripBurstRevIdx, ripBurstSize] = deal(cc);
for i = 1:max(unique(ripBurstNum))
    ripBurstIdx(ripBurstNum == i) = cumsum(cc(ripBurstNum == i));
    ripBurstRevIdx(ripBurstNum == i) = flip(cumsum(cc(ripBurstNum == i)));
    ripBurstSize(ripBurstNum == i) = sum(cc(ripBurstNum == i));
    burstRipNum(i,:) = ripBurstSize(find(ripBurstNum == i,1,'first'));
end

for r = 1:max(ripBurstIdx)
    burstPlace{r} = ripples.timestamps(ripBurstIdx == r,:);
    burstPlaceRev{r} = ripples.timestamps(ripBurstRevIdx == r,:);
    burstSize{r} = bursts(ismember(bursts(:,1), ripples.timestamps(ripBurstSize==r,1)),:);
end

% check
fprintf('%i/%i ripple bursts indexed\n',max(ripBurstNum),length(bursts));
if all(burstPlace{1}(:,1) == bursts(:,1))
    fprintf('Ripple placement is correct!\n')
end

%% Ripple Burst Index and Size -> structure!

rippleBurst = struct('solos', ripBurstIdx == 0,...
                     'bursts', ripBurstIdx ~= 0, ...
                     'duos', ripBurstSize == 2,...
                     'trios', ripBurstSize == 3, ...
                     'quartets', ripBurstSize == 4, ...
                     'quintets', ripBurstSize == 5, ...
                     'first', ripBurstIdx == 1, ...
                     'second', ripBurstIdx == 2, ...
                     'third', ripBurstIdx == 3, ...
                     'fourth', ripBurstIdx == 4, ...
                     'fifth', ripBurstIdx == 5, ...
                     'last', ripBurstRevIdx == 1, ...
                     'notLast', ripBurstRevIdx ~= 1 | 0, ...
                     'burstIndex', ripBurstNum, ...
                     'burstNum', burstRipNum, ...
                     'burstTimes', bursts, ...
                     'soloTimes', solos);
fprintf('rippleBurst structure complete.\n');

%% Mean Stimulation Time
stimOnOff = photom_hpc.stimpulseOnOff;
if ~isempty(stimOnOff)
    stimDur = stimOnOff(:,2) - stimOnOff(:,1);
else
    fprintf('%s - no stimulation\n',name)
end


%% Custom Color Map

ogCol = lines(7);
gradCol = cell(1,size(ogCol,1));
for c = 1:size(ogCol,1)
    gradCol{c} = customcolormap([0 0.5 1], [1 1 1; ogCol(c,:); 0 0 0],101);
    gradCol{c} = gradCol{c}([20 50 80],:);
end
blue = gradCol{1};
orange = gradCol{2};
yellow = gradCol{3};
purple = gradCol{4};
green = gradCol{5};
blue2 = gradCol{6};
red = gradCol{7};

fprintf('%i new colormaps added!\n',size(gradCol,2));


%% Quick Plot (upcoming: make pretty)
[~,name,~] = fileparts(sessionPaths{sesh});
% figure initiate
f1 = figure(1); clf; hold on;
f1.Units = 'normalized';
f1.Position = [0 0.05 1 0.865];
tiledlayout(3,6,'TileSpacing','tight','Padding','tight');
sgtitle(sprintf('%s',name),'Interpreter','none');

sessionEndTime = max(cellfun(@(x) x.concPhotom.timestamps(end), photom));
sessionStartTime = min(cellfun(@(x) x.concPhotom.timestamps(1), photom));

YL = [-10 10];
XL = [sessionStartTime - 100, sessionEndTime + 1500];

sleep1s = rippleBurst.soloTimes(:,1) < photom_hpc.epochs(2,1);
sleep1b = rippleBurst.burstTimes(:,1) < photom_hpc.epochs(2,1);

d = dir(fullfile('N*.photometry.*.mat'));
possibleRegions = {'HPC','STR','PFC'};

% --- SESSION METRICS
nexttile(1,[3,1]); cla; hold on;
title('SESSION METRICS','Color','blue','FontSize',12);
set(gca, 'Color', 'none'); % Axes background   
% axis off
secondsTotal = sessionEndTime - sessionStartTime;
h = floor(secondsTotal / 3600);
m = floor(mod(secondsTotal, 3600) / 60);
s = mod(secondsTotal, 60);
text(0.05, 1, sprintf('Duration: %ih %im %0.2fs',h,m,s),...
    'VerticalAlignment','top','FontSize',12);
text(0.1, 0.97, sprintf('-Epoch 1:\n-Epoch 2:\n'),'VerticalAlignment','top');

% --- FLUORESCENCE BY REGION
for r = 1:numel(possibleRegions)
    figLoc = (r-1)*6 + 2;
    nexttile(figLoc, [1 2]); hold on;
    region = contains(fileTable(sesh,:).whichRegions{:}, possibleRegions{r});
    if ~any(region)
        set(gca, 'Color', 'none'); % Axes background   
        axis off
        text(0.5,0.5, sprintf('NO %s PHOTOM DATA',possibleRegions{r}), ...
            'FontSize',12, ...
            'Color','r', ...
            'FontWeight','bold', ...
            'HorizontalAlignment','center');
    else
        photomIdx = photom{region}.concPhotom;
        
        plot(photomIdx.timestamps, photomIdx.grabDA_z, ...
            'color',[0.5 0.5 0.5],'LineWidth',0.5)
    
        for ep = 1:numel(photomIdx.epochNames)
            plot([photomIdx.epochs(ep,1) photomIdx.epochs(ep,1)],[-10 10], ...
                '--r')
            text(photomIdx.epochs(ep,1),YL(2)-1,photomIdx.epochNames{ep},'Color','r')
        end
        plot(solos(:,1),(-4.5)*ones(size(solos(:,1))),'|k','MarkerSize',7);
        plot(bursts(:,1),-6*ones(size(bursts(:,1))),'|b','MarkerSize',7);
        % plot(behavTrials.timestamps,(-7.5)*ones(size(behavTrials.timestamps)),'|r','MarkerSize',7)
        if ~isempty(stimOnOff)
            plot(photomIdx.stimpulseOnOff(:,1),(-9)*ones(size(photomIdx.stimpulseOnOff(:,1))), ...
                '|','Color',[0.3 0.3 0.3], 'MarkerSize',7)
        end
        text(sessionEndTime+50,-4.5,'solos','FontSize',10,'Color','k')
        text(sessionEndTime+50,-6,'bursts','FontSize',10,'Color','b')
        text(sessionEndTime+50,-7.5,'pokes','FontSize',10,'Color','r')
        text(sessionEndTime+50,-9,'stims','FontSize',10,'Color','[0.3 0.3 0.3]')
        
        xlim(XL); ylim(YL);
        xticklabels('')
        ylabel(sprintf('%s (z-score)',possibleRegions{r}))
        title(sprintf('%s Photometry Session',possibleRegions{r}));
    end

end


% --- RIPPLE TRIGGERED AVERAGES
events2plot = {'solos','duos','trios'};
events = {rippleBurst.soloTimes(sleep1s,1),...
          rippleBurst.burstTimes(rippleBurst.burstNum == 2 & sleep1b,1),...
          rippleBurst.burstTimes(rippleBurst.burstNum == 3 & sleep1b,1)};
durations = [-5 5];

for r = 1:numel(possibleRegions)
    figLoc = (r-1)*6 + 4;
    nexttile(figLoc); hold on;
    region = contains(fileTable(sesh,:).whichRegions{:}, possibleRegions{r});
    if ~any(region)
        set(gca, 'Color', 'none'); % Axes background   
        axis off
        text(0.5,0.5, sprintf('NO %s PHOTOM DATA',possibleRegions{r}), ...
            'FontSize',12, ...
            'Color','r', ...
            'FontWeight','bold', ...
            'HorizontalAlignment','center');
    else
       
        photomIdx = photom{region}.concPhotom;
        data = photomIdx.grabDA_z;
        timestamps = photomIdx.timestamps;

        for e = 1:numel(events)
            eta{r,e} = byl_getETA(events{e},data,timestamps, ...
                'frequency',130,'normalization','zscore','durations',durations);
            plot(eta{r,e}.window, eta{r,e}.avg, 'color', blue(e,:), 'LineWidth', 2,...
                'DisplayName',sprintf('%s (%i)',events2plot{e},numel(events{e})));
            x1 = [eta{r,e}.window, fliplr(eta{r,e}.window)];
            y = [eta{r,e}.avg + eta{r,e}.sem, fliplr(eta{r,e}.avg - eta{r,e}.sem)];
            patch(x1,y,blue(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');   
        end
        xlabel('Time from event (s)');
        ylabel('Fluorescence (z-score)');
        title(sprintf('Ripples'));
        grid on;
        legend('location','best','FontSize',6);
        set(gca,'children',flipud(get(gca,'children')))
        YLref = ylim;
    end
end

% --- NOSEPOKE TRIGGERED AVERAGES
events2plot = {'re','unre'};
try
    events = {behavTrials.timestamps(logical(behavTrials.reward_outcome)),...
              behavTrials.timestamps(~logical(behavTrials.reward_outcome))};
catch
    fprintf('no behavior\n')
    events = {};
end
durations = [-5 5];

for r = 1:numel(possibleRegions)
    figLoc = (r-1)*6 + 5;
    nexttile(figLoc); cla; hold on;
    region = contains(fileTable(sesh,:).whichRegions{:}, possibleRegions{r});

    if isempty(events)
        set(gca, 'Color', 'none'); % Axes background   
        axis off
        text(0.5,0.5,'NO BEHAVIOR', ...
            'FontSize',12, ...
            'Color','r', ...
            'FontWeight','bold', ...
            'HorizontalAlignment','center');
    elseif ~any(region)
        set(gca, 'Color', 'none'); % Axes background   
        axis off
        text(0.5,0.5, sprintf('NO %s PHOTOM DATA',possibleRegions{r}), ...
            'FontSize',12, ...
            'Color','r', ...
            'FontWeight','bold', ...
            'HorizontalAlignment','center');
    else
        
        photomIdx = photom{region}.concPhotom;
        data = photomIdx.grabDA_z;
        timestamps = photomIdx.timestamps;

        for e = 1:numel(events)
            eta{r,e} = byl_getETA(events{e},data,timestamps, ...
                'frequency',130,'normalization','zscore','durations',durations);
            plot(eta{r,e}.window, eta{r,e}.avg, 'color', yellow(e,:), 'LineWidth', 2,...
                'DisplayName',sprintf('%s (%i)',events2plot{e},numel(events{e})));
            x1 = [eta{r,e}.window, fliplr(eta{r,e}.window)];
            y = [eta{r,e}.avg + eta{r,e}.sem, fliplr(eta{r,e}.avg - eta{r,e}.sem)];
            patch(x1,y,yellow(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');   
        end
        xlabel('Time from event (s)');
        ylabel('Fluorescence (z-score)');
        title('Nosepokes');
        grid on;
        legend('location','best','FontSize',6);
        set(gca,'children',flipud(get(gca,'children')))
        YLref = ylim;
    end
end

% --- STIM TRIGGERED AVERAGES
events2plot = {'long','short'};
try
    events = {photom_hpc.stimpulseOnOff(stimDur > 1,1),...
              photom_hpc.stimpulseOnOff(stimDur < 1,1)};
catch
    fprintf('no stimulation\n')
    events = {};
end
durations = [-5 5];

for r = 1:numel(possibleRegions)
    figLoc = ((r-1)*6) + 6;
    nexttile(figLoc); cla; hold on;
    region = contains(fileTable(sesh,:).whichRegions{:}, possibleRegions{r});

    if isempty(events)
        set(gca, 'Color', 'none'); % Axes background   
        axis off
        text(0.5,0.5,'NO OPTOGENETICS', ...
            'FontSize',12, ...
            'Color','r', ...
            'FontWeight','bold', ...
            'HorizontalAlignment','center');
    elseif ~any(region)
        set(gca, 'Color', 'none'); % Axes background   
        axis off
        text(0.5,0.5, sprintf('NO %s PHOTOM DATA',possibleRegions{r}), ...
            'FontSize',12, ...
            'Color','r', ...
            'FontWeight','bold', ...
            'HorizontalAlignment','center');
    else

        photomIdx = photom{region}.concPhotom;
        data = photomIdx.grabDA_z;
        timestamps = photomIdx.timestamps;

        for e = 1:numel(events)
            eta{r,e} = byl_getETA(events{e},data,timestamps, ...
                'frequency',130,'normalization','zscore','durations',durations);
            plot(eta{r,e}.window, eta{r,e}.avg, 'color', red(e,:), 'LineWidth', 2,...
                'DisplayName',sprintf('%s (%i)',events2plot{e},numel(events{e})));
            x1 = [eta{r,e}.window, fliplr(eta{r,e}.window)];
            y = [eta{r,e}.avg + eta{r,e}.sem, fliplr(eta{r,e}.avg - eta{r,e}.sem)];
            patch(x1,y,red(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');   
        end
        xlabel('Time from event (s)');
        ylabel('Fluorescence (z-score)');
        title(sprintf('Stimulations'));
        grid on;
        legend('location','best','FontSize',6);
        set(gca,'children',flipud(get(gca,'children')))
        % YLref = ylim;
    end
end

%% Master Plot
[~,name,~] = fileparts(sessionPaths{sesh});
% figure initiate
f1 = figure(10); clf; hold on;
f1.Units = 'normalized';
f1.Position = [0 0.05 1 0.865];
tiledlayout(3,6,'TileSpacing','tight','Padding','tight');
sgtitle(sprintf('%s',name),'Interpreter','none');


%% >>> Inter-Ripple Interval
% >>> Histogram
f1 = figure(10);
nexttile(1, [1 2]); cla; hold on;
IRI1 = ripples.timestamps(2:end,1) - ripples.timestamps(1:end-1,2);
IRI1a = rmoutliers(IRI1);
histogram(IRI1a,50,'DisplayName','mine')

IRI2 = diff(ripples.timestamps(:,1));
IRI2a = rmoutliers(IRI2);
histogram(IRI2a,50,'DisplayName','lab')

xlabel('Inter-Ripple Interval (s)')
ylabel('SWR counts')
legend('location','northeast')

% >>> Semilog
f1 = figure(10);
nexttile(13, [1 2]); cla; hold on;
iri = IRI1a(IRI1a>0);   % ensure positive
nbins = 60;
edges = logspace(log10(min(iri)/10), log10(max(iri)*10), nbins+1);
[counts, edges] = histcounts(iri, edges);
binWidths = diff(edges);
pdf = counts ./ sum(counts) ./ binWidths;   % density normalization

binCenters = sqrt(edges(1:end-1).*edges(2:end));  % geometric mean

semilogx(binCenters, pdf, '-');
xlabel('Inter-ripple interval');
ylabel('Probability density');
title('IRI PDF (log-time)');
xscale('log')

%% >>> Ripple Stats
% >>> Ripple Amplitude
f1 = figure(10);
nexttile(3); cla; hold on;
solo = rippleStats.data.peakAmplitude(rippleBurst.solos);
duo = rippleStats.data.peakAmplitude(rippleBurst.duos);
trio = rippleStats.data.peakAmplitude(rippleBurst.trios);

plot(ones(size(solo)), solo, 'o','Color',[0.8 0.8 0.8],'HandleVisibility','off');
plot(1, mean(solo),'o','color',blue(1,:),'MarkerFaceColor',blue(1,:),'DisplayName','solos');
errorbar(1, mean(solo),std(solo),'color',blue(1,:))

plot(2*ones(size(duo)), duo, 'o','Color',[0.8 0.8 0.8],'HandleVisibility','off');
plot(2, mean(duo),'o','color',blue(2,:),'MarkerFaceColor',blue(2,:),'DisplayName','duos');
errorbar(2, mean(duo),std(duo),'color',blue(2,:))

plot(3*ones(size(trio)), trio, 'o','Color',[0.8 0.8 0.8],'HandleVisibility','off');
plot(3, mean(trio),'o','color',blue(3,:),'MarkerFaceColor',blue(3,:),'DisplayName','trios');
errorbar(3, mean(trio),std(trio),'color',blue(3,:))

xlim([0.5 3.5])

title('Ripple Peak Amplitude')
xticklabels({'solos','duos','trios'})

% >>> Ripple Duration
f1 = figure(10);
nexttile(4); cla; hold on;
solo = rippleStats.data.duration(rippleBurst.solos);
duo = rippleStats.data.duration(rippleBurst.duos);
trio = rippleStats.data.duration(rippleBurst.trios);

plot(ones(size(solo)), solo, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(1, mean(solo),'o','color',blue(1,:),'MarkerFaceColor',blue(1,:),'DisplayName','solos');
errorbar(1, mean(solo),std(solo),'color',blue(1,:))

plot(2*ones(size(duo)), duo, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(2, mean(duo),'o','color',blue(2,:),'MarkerFaceColor',blue(2,:),'DisplayName','duos');
errorbar(2, mean(duo),std(duo),'color',blue(2,:))

plot(3*ones(size(trio)), trio, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(3, mean(trio),'o','color',blue(3,:),'MarkerFaceColor',blue(3,:),'DisplayName','trios');
errorbar(3, mean(trio),std(trio),'color',blue(3,:))

xlim([0.5 3.5])
title('Ripple Duration')
xticklabels({'solos','duos','trios'})
ylabel('sec')

% >>> Ripple Frequency
f1 = figure(10);
nexttile(15); cla; hold on;
solo = rippleStats.data.peakFrequency(rippleBurst.solos);
duo = rippleStats.data.peakFrequency(rippleBurst.duos);
trio = rippleStats.data.peakFrequency(rippleBurst.trios);

plot(ones(size(solo)), solo, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(1, mean(solo),'o','color',blue(1,:),'MarkerFaceColor',blue(1,:),'DisplayName','solos');
errorbar(1, mean(solo),std(solo),'color',blue(1,:))

plot(2*ones(size(duo)), duo, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(2, mean(duo),'o','color',blue(2,:),'MarkerFaceColor',blue(2,:),'DisplayName','duos');
errorbar(2, mean(duo),std(duo),'color',blue(2,:))

plot(3*ones(size(trio)), trio, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(3, mean(trio),'o','color',blue(3,:),'MarkerFaceColor',blue(3,:),'DisplayName','trios');
errorbar(3, mean(trio),std(trio),'color',blue(3,:))

xlim([0.5 3.5])
title('Ripple Frequency')
xticklabels({'solos','duos','trios'})
ylabel('Hz')

% >>> Burst Duration
f1 = figure(10);
nexttile(16); cla; hold on;
solo = rippleStats.data.duration(rippleBurst.solos);
duo = rippleBurst.burstTimes(rippleBurst.burstNum == 2,2) - rippleBurst.burstTimes(rippleBurst.burstNum == 2,1);
trio = rippleBurst.burstTimes(rippleBurst.burstNum == 3,2) - rippleBurst.burstTimes(rippleBurst.burstNum == 3,1);

plot(ones(size(solo)), solo, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(1, mean(solo),'o','color',blue(1,:),'MarkerFaceColor',blue(1,:),'DisplayName','solos');
errorbar(1, mean(solo),std(solo),'color',blue(1,:))

plot(2*ones(size(duo)), duo, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(2, mean(duo),'o','color',blue(2,:),'MarkerFaceColor',blue(2,:),'DisplayName','duos');
errorbar(2, mean(duo),std(duo),'color',blue(2,:))

plot(3*ones(size(trio)), trio, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(3, mean(trio),'o','color',blue(3,:),'MarkerFaceColor',blue(3,:),'DisplayName','trios');
errorbar(3, mean(trio),std(trio),'color',blue(3,:))

xlim([0.5 3.5])
title('Burst Duration')
xticklabels({'solos','duos','trios'})
ylabel('sec')

% >>> Histogram Ripple Duration
f1 = figure(10);
nexttile(25, [1 2]); cla; hold on;
yyaxis left
histogram(rippleStats.data.duration(rippleBurst.solos),50,'DisplayName','solos');
yyaxis right
histogram(rippleStats.data.duration(rippleBurst.bursts),50,'DisplayName','bursts');
legend('Location','best')
ylabel('SWR Counts');
xlabel('Duration (ms)');
xticklabels(string(xticks*1000));
xscale linear

% >>> Histogram Ripple Amplitude
f1 = figure(10);
nexttile(27, [1 2]); cla; hold on;
yyaxis left
histogram(rippleStats.data.peakAmplitude(rippleBurst.solos),50,'DisplayName','solos');
yyaxis right
histogram(rippleStats.data.peakAmplitude(rippleBurst.bursts),50,'DisplayName','bursts');
legend('Location','best')
ylabel('SWR Counts');
xlabel('Amplitude');
xticklabels(string(xticks*1000));

%% >>> Time Series Across Session
% >>> Ripple Rate
f1 = figure(10);
nexttile(37,[1 4]); cla; hold on;
dt = 1/130;
time = 0:dt:photom_hpc.timestamps(end);
rips = histcounts(solos(:,1), [time time(end)+dt]) / dt;
burs = histcounts(bursts(:,1), [time time(end)+dt]) / dt;

sigma = 30; % seconds
g = fspecial('gaussian', [1 6*sigma/dt], sigma/dt);
rate_smooth_solos = conv(rips, g, 'same');
rate_smooth_bursts = conv(burs, g, 'same');
plot(time, rate_smooth_solos,'DisplayName','solos');
plot(time, rate_smooth_bursts,'DisplayName','bursts');
title(sprintf('%i-second kernel',sigma));
legend()
xticklabels('')
ylabel('Ripple rate (Hz)');

% >>> hippocampus fluorescence
f1 = figure(10);
nexttile(49,[1 4]); cla; hold on;
if any(contains(fileTable(sesh,:).whichRegions{:},'HPC'))
    plot(photom_hpc.timestamps, photom_hpc.grabDA_z, ...
        'color',[0.5 0.5 0.5],'LineWidth',0.5)
    YL = [-10 10];
    plot([photom_hpc.epochs(2,1) photom_hpc.epochs(2,1)],[-10 10], ...
        '--r')
    plot([photom_hpc.epochs(2,2) photom_hpc.epochs(2,2)],[-10 10], ...
        '--r')
    text(photom_hpc.epochs(1,1),YL(2)-1,photom_hpc.epochNames{1},'Color','r')
    text(photom_hpc.epochs(2,1),YL(2)-1,photom_hpc.epochNames{2},'Color','r')
    text(photom_hpc.epochs(3,1),YL(2)-1,photom_hpc.epochNames{3},'Color','r')
    plot(solos(:,1),(-4.5)*ones(size(solos(:,1))),'|k','MarkerSize',5);
    plot(bursts(:,1),-6*ones(size(bursts(:,1))),'|b','MarkerSize',5);
    plot(behavTrials.timestamps,(-7.5)*ones(size(behavTrials.timestamps)),'|r','MarkerSize',5)
    if ~isempty(stimOnOff)
        plot(photom_hpc.stimpulseOnOff(:,1),(-9)*ones(size(photom_hpc.stimpulseOnOff(:,1))), ...
            '|','Color',[0.3 0.3 0.3], 'MarkerSize',5)
    end
    text(photom_hpc.timestamps(end)+100,-4.5,'solos','FontSize',6,'Color','k')
    text(photom_hpc.timestamps(end)+100,-6,'bursts','FontSize',6,'Color','b')
    text(photom_hpc.timestamps(end)+100,-7.5,'nose pokes','FontSize',6,'Color','r')
    text(photom_hpc.timestamps(end)+100,-9,'stims','FontSize',6,'Color','[0.3 0.3 0.3]')
    
    xticklabels('')
    ylabel('Hipp. (z-score)')
else
    set(gca, 'Color', 'none'); % Axes background   
    axis off
    text(0.5,0.5, 'NO HPC PHOTOM DATA', ...
        'FontSize',12, ...
        'Color','r', ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center');
end


% >>> striatum fluorescence
f1 = figure(10);
nexttile(61,[1 4]); cla; hold on;
if any(contains(fileTable(sesh,:).whichRegions{:},'STR'))
    plot(photom_str.timestamps, photom_str.grabDA_z, ...
        'color',[0.5 0.5 0.5],'LineWidth',0.5)
    YL = [-10 10];
    plot([photom_str.epochs(2,1) photom_str.epochs(2,1)],[-10 10], ...
        '--r')
    plot([photom_str.epochs(2,2) photom_str.epochs(2,2)],[-10 10], ...
        '--r')
    text(photom_str.epochs(1,1),YL(2)-1,photom_str.epochNames{1},'Color','r')
    text(photom_str.epochs(2,1),YL(2)-1,photom_str.epochNames{2},'Color','r')
    text(photom_str.epochs(3,1),YL(2)-1,photom_str.epochNames{3},'Color','r')
    plot(solos(:,1),(-5+0.5)*ones(size(solos(:,1))),'|k','MarkerSize',5);
    plot(bursts(:,1),-6*ones(size(bursts(:,1))),'|b','MarkerSize',5);
    plot(behavTrials.timestamps,(-7-0.5)*ones(size(behavTrials.timestamps)),'|r','MarkerSize',5)
    if ~isempty(stimOnOff)
        plot(photom_str.stimpulseOnOff(:,1),(-9)*ones(size(photom_str.stimpulseOnOff(:,1))), ...
            '|','Color',[0.3 0.3 0.3], 'MarkerSize',5);
    end
    text(photom_str.timestamps(end)+100,-5+0.5,'solos','FontSize',6,'Color','k')
    text(photom_str.timestamps(end)+100,-6,'bursts','FontSize',6,'Color','b')
    text(photom_str.timestamps(end)+100,-7-0.5,'nose pokes','FontSize',6,'Color','r')
    text(photom_str.timestamps(end)+100,-9,'stims','FontSize',6,'Color','[0.3 0.3 0.3]')
    
    ylabel('Striat. (z-score)')
    xlabel('Time (s)')
else
    set(gca, 'Color', 'none'); % Axes background   
    axis off
    text(0.5,0.5, 'NO STR PHOTOM DATA', ...
        'FontSize',12, ...
        'Color','r', ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center');

end



%% >>> ETA: solos, duos, trios hippocampus (sleep) !!!!!!!
f1 = figure(10);
nexttile(5, [2 2]); delete(gca);
nexttile(5, [2 2]); cla; hold on;
if any(contains(fileTable(sesh,:).whichRegions{:},'HPC'))

    solo = rippleStats.data.duration(rippleBurst.solos);
    duo = rippleBurst.burstTimes(rippleBurst.burstNum == 2,2) - rippleBurst.burstTimes(rippleBurst.burstNum == 2,1);
    trio = rippleBurst.burstTimes(rippleBurst.burstNum == 3,2) - rippleBurst.burstTimes(rippleBurst.burstNum == 3,1);
    
    sleep = ripples.timestamps(:,1) < photom_hpc.epochs(2,1) | ...
            ripples.timestamps(:,1) > photom_hpc.epochs(2,2);
    events2plot = {'solo','duos','trios'};
    events = {ripples.timestamps(rippleBurst.solos & sleep,1),...
              ripples.timestamps(rippleBurst.duos & sleep,1),...
              ripples.timestamps(rippleBurst.trios & sleep,1)};
    data = photom_hpc.grabDA_z;
    timestamps = photom_hpc.timestamps;
    for e = 1:numel(events)  
        etaHPC = byl_getETA(events{e},data,timestamps,'frequency',130,'normalization','none');
    
        % Plot
        plot(etaHPC.window, etaHPC.avg, 'color', blue(e,:), 'LineWidth', 2,...
            'DisplayName',events2plot{e});
        x1 = [etaHPC.window, fliplr(etaHPC.window)];
        y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
        patch(x1,y,blue(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');    
    end
    patch([0 mean(solo) mean(solo) 0],...
          [-0.2 -0.2 -0.17 -0.17], ...
          blue(1,:),'EdgeColor','none','HandleVisibility','off');
    patch([0 mean(duo) mean(duo) 0],...
          [-0.17 -0.17 -0.14 -0.14], ...
          blue(2,:),'EdgeColor','none','HandleVisibility','off');
    patch([0 mean(trio) mean(trio) 0],...
          [-0.14 -0.14 -0.11 -0.11], ...
          blue(3,:),'EdgeColor','none','HandleVisibility','off');
    
    xlabel('Time from event (s)');
    ylabel('Fluorescence (z-score');
    title(sprintf('Ripple-Triggered Average\nHPC DA (sleep)'));
    grid on;
    legend('location','best');
    set(gca,'children',flipud(get(gca,'children')))
    yLimHPCsleep = ylim;
else
    set(gca, 'Color', 'none'); % Axes background   
    axis off
    text(0.5,0.5, 'NO HPC PHOTOM DATA', ...
        'FontSize',12, ...
        'Color','r', ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center');   
end
%% >>> ETA: solos, duos, trios hippocampus (behavior)
f1 = figure(10);
nexttile(7, [2 2]); cla; hold on;
if any(contains(fileTable(sesh,:).whichRegions{:},'HPC'))
    
    sleep = ripples.timestamps(:,1) < photom_hpc.epochs(2,1) | ...
            ripples.timestamps(:,1) > photom_hpc.epochs(2,2);
    events2plot = {'solo','duos','trios'};
    events = {ripples.timestamps(rippleBurst.solos & ~sleep,1),...
              ripples.timestamps(rippleBurst.duos & ~sleep,1),...
              ripples.timestamps(rippleBurst.trios & ~sleep,1)};
    data = photom_hpc.grabDA_z;
    timestamps = photom_hpc.timestamps;
    for e = 1:numel(events)  
        etaHPC = byl_getETA(events{e},data,timestamps,'frequency',130);
    
        % Plot
        plot(etaHPC.window, etaHPC.avg, 'color', blue(e,:), 'LineWidth', 2,...
            'DisplayName',events2plot{e});
        x1 = [etaHPC.window, fliplr(etaHPC.window)];
        y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
        patch(x1,y,blue(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
    end
    xlabel('Time from event (s)');
    ylabel('Fluorescence (z-score');
    title(sprintf('Ripple-Triggered Average\nHPC DA (behavior)'));
    grid on;
    legend('location','best');
    set(gca,'children',flipud(get(gca,'children')))
else
    set(gca, 'Color', 'none'); % Axes background   
    axis off
    text(0.5,0.5, 'NO HPC PHOTOM DATA', ...
        'FontSize',12, ...
        'Color','r', ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center');  
end
%% >>> long and short stims hippocampus
figure(10);
nexttile(9, [2 2]); cla; hold on;
if any(contains(fileTable(sesh,:).whichRegions{:},'HPC')) && ~isempty(stimOnOff)

    events2plot = {'short VTA stim','long VTA stim'};
    events = {photom_hpc.stimpulseOnOff(stimDur < 1,1),...
              photom_hpc.stimpulseOnOff(stimDur > 1,1)};
    data = photom_hpc.grabDA_z;
    timestamps = photom_hpc.timestamps;
    for e = 1:numel(events)  
        etaHPC = byl_getETA(events{e},data,timestamps,'frequency',130);
    
        % Plot
        plot(etaHPC.window, etaHPC.avg, 'color', purple(e,:), 'LineWidth', 2,...
            'DisplayName',events2plot{e});
        x1 = [etaHPC.window, fliplr(etaHPC.window)];
        y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
        patch(x1,y,purple(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
        
        
    end
    xlabel('Time from event (s)');
    ylabel('Fluorescence (z-score');
    title(sprintf('Poke/Stim-Triggered Average\nHPC DA (behavior)'));
    grid on;
    legend('location','best');
    set(gca,'children',flipud(get(gca,'children')))
elseif ~any(contains(fileTable(sesh,:).whichRegions{:},'HPC'))
    set(gca, 'Color', 'none'); % Axes background   
    axis off
    text(0.5,0.5, 'NO HPC PHOTOM DATA', ...
        'FontSize',12, ...
        'Color','r', ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center');  
elseif isempty(stimOnOff)
    set(gca, 'Color', 'none'); % Axes background   
    axis off
    text(0.5,0.5, 'NO STIMULATION', ...
        'FontSize',12, ...
        'Color','r', ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center'); 
end    
%% >>> ETA: rewarded, unrewarded hippocampus (behavior)
figure(10);
nexttile(11, [2 2]); cla; hold on;
if any(contains(fileTable(sesh,:).whichRegions{:},'HPC'))

    events2plot = {'unrewarded','rewarded'};
    events = {behavTrials.timestamps(~logical(behavTrials.reward_outcome)),...
              behavTrials.timestamps(logical(behavTrials.reward_outcome))};
    data = photom_hpc.grabDA_z;
    timestamps = photom_hpc.timestamps;
    for e = 1:numel(events)  
        etaHPC = byl_getETA(events{e},data,timestamps,'frequency',130);
    
        % Plot
        plot(etaHPC.window, etaHPC.avg, 'color', purple(e,:), 'LineWidth', 2,...
            'DisplayName',events2plot{e});
        x1 = [etaHPC.window, fliplr(etaHPC.window)];
        y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
        patch(x1,y,purple(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
        
        
    end
    xlabel('Time from event (s)');
    ylabel('Fluorescence (z-score');
    title(sprintf('Poke/Stim-Triggered Average\nHPC DA (behavior)'));
    grid on;
    legend('location','best');
    set(gca,'children',flipud(get(gca,'children')))
else
    set(gca, 'Color', 'none'); % Axes background   
    axis off
    text(0.5,0.5, 'NO HPC PHOTOM DATA', ...
        'FontSize',12, ...
        'Color','r', ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center');  
end
%% >>> ETA: solos, duos, trios striatum (sleep)
figure(10);
nexttile(29, [2 2]); cla; hold on;
if any(contains(fileTable(sesh,:).whichRegions{:},'STR'))

    sleep = ripples.timestamps(:,1) < photom_str.epochs(2,1) | ...
            ripples.timestamps(:,1) > photom_str.epochs(2,2);
    events2plot = {'solo','duos','trios'};
    events = {ripples.timestamps(rippleBurst.solos & sleep,1),...
              ripples.timestamps(rippleBurst.duos & sleep,1),...
              ripples.timestamps(rippleBurst.trios & sleep,1)};
    data = photom_str.grabDA_z;
    timestamps = photom_str.timestamps;
    for e = 1:numel(events)  
        etaHPC = byl_getETA(events{e},data,timestamps,'frequency',130);
    
        % Plot
        plot(etaHPC.window, etaHPC.avg, 'color', red(e,:), 'LineWidth', 2,...
            'DisplayName',events2plot{e});
        x1 = [etaHPC.window, fliplr(etaHPC.window)];
        y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
        patch(x1,y,red(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
        
    end
    xlabel('Time from event (s)');
    ylabel('Fluorescence (z-score');
    title(sprintf('Ripple-Triggered Average\nSTR DA (sleep)'));
    grid on;
    legend('location','best');
    set(gca,'children',flipud(get(gca,'children')))
else
    set(gca, 'Color', 'none'); % Axes background   
    axis off
    text(0.5,0.5, 'NO STR PHOTOM DATA', ...
        'FontSize',12, ...
        'Color','r', ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center');  
end
%% >>> ETA: solos, duos, trios striatum (behavior)
figure(10);
nexttile(31, [2 2]); cla; hold on;
if any(contains(fileTable(sesh,:).whichRegions{:},'STR'))
    
    sleep = ripples.timestamps(:,1) < photom_str.epochs(2,1) | ...
            ripples.timestamps(:,1) > photom_str.epochs(2,2);
    events2plot = {'solo','duos','trios'};
    events = {ripples.timestamps(rippleBurst.solos & ~sleep,1),...
              ripples.timestamps(rippleBurst.duos & ~sleep,1),...
              ripples.timestamps(rippleBurst.trios & ~sleep,1)};
    data = photom_str.grabDA_z;
    timestamps = photom_str.timestamps;
    for e = 1:numel(events)  
        etaHPC = byl_getETA(events{e},data,timestamps,'frequency',130);
    
        % Plot
        plot(etaHPC.window, etaHPC.avg, 'color', red(e,:), 'LineWidth', 2,...
            'DisplayName',events2plot{e});
        x1 = [etaHPC.window, fliplr(etaHPC.window)];
        y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
        patch(x1,y,red(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
    end
    xlabel('Time from event (s)');
    ylabel('Fluorescence (z-score');
    title(sprintf('Ripple-Triggered Average\nSTR DA (behavior)'));
    grid on;
    legend('location','best');
    set(gca,'children',flipud(get(gca,'children')))
else
    set(gca, 'Color', 'none'); % Axes background   
    axis off
    text(0.5,0.5, 'NO STR PHOTOM DATA', ...
        'FontSize',12, ...
        'Color','r', ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center');  
end
%% >>> ETA: long and short stims striatum
figure(10);
nexttile(33, [2 2]); cla; hold on;
if any(contains(fileTable(sesh,:).whichRegions{:},'STR')) && ~isempty(stimOnOff)

    events2plot = {'short stim','long stim'};
    events = {photom_str.stimpulseOnOff(stimDur < 1,1),...
              photom_str.stimpulseOnOff(stimDur > 1,1)};
    data = photom_str.grabDA_z;
    timestamps = photom_str.timestamps;
    for e = 1:numel(events)  
        etaSTR = byl_getETA(events{e},data,timestamps,'frequency',130);
    
        % Plot
        plot(etaSTR.window, etaSTR.avg, 'color', orange(e,:), 'LineWidth', 2,...
            'DisplayName',events2plot{e});
        x1 = [etaSTR.window, fliplr(etaSTR.window)];
        y = [etaSTR.avg + etaSTR.sem, fliplr(etaSTR.avg - etaSTR.sem)];
        patch(x1,y,orange(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
        
        
    end
    xlabel('Time from event (s)');
    ylabel('Fluorescence (z-score');
    title(sprintf('VTA Stim-Triggered Average\nSTR DA (behavior)'));
    grid on;
    legend('location','northwest');
    set(gca,'children',flipud(get(gca,'children')))
elseif ~any(contains(fileTable(sesh,:).whichRegions{:},'STR'))
    set(gca, 'Color', 'none'); % Axes background   
    axis off
    text(0.5,0.5, 'NO STR PHOTOM DATA', ...
        'FontSize',12, ...
        'Color','r', ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center');
elseif isempty(stimOnOff)
    set(gca, 'Color', 'none'); % Axes background   
    axis off
    text(0.5,0.5, 'NO STIMULATION', ...
        'FontSize',12, ...
        'Color','r', ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center');
end    

%% >>> ETA: rewarded, unrewarded striatum (behavior)
figure(10);
nexttile(35, [2 2]); cla; hold on;
if any(contains(fileTable(sesh,:).whichRegions{:},'STR')) 

    events2plot = {'unrewarded','rewarded'};
    events = {behavTrials.timestamps(~logical(behavTrials.reward_outcome)),...
              behavTrials.timestamps(logical(behavTrials.reward_outcome))};
    data = photom_str.grabDA_z;
    timestamps = photom_str.timestamps;
    for e = 1:numel(events)  
        etaHPC = byl_getETA(events{e},data,timestamps,'frequency',130);
    
        % Plot
        plot(etaHPC.window, etaHPC.avg, 'color', orange(e,:), 'LineWidth', 2,...
            'DisplayName',events2plot{e});
        x1 = [etaHPC.window, fliplr(etaHPC.window)];
        y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
        patch(x1,y,orange(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
        
        
    end
    xlabel('Time from event (s)');
    ylabel('Fluorescence (z-score');
    title(sprintf('Poke/Stim-Triggered Average\nSTR DA (behavior)'));
    grid on;
    legend('location','best');
    set(gca,'children',flipud(get(gca,'children')))
else
    set(gca, 'Color', 'none'); % Axes background   
    axis off
    text(0.5,0.5, 'NO STR PHOTOM DATA', ...
        'FontSize',12, ...
        'Color','r', ...
        'FontWeight','bold', ...
        'HorizontalAlignment','center');  
end

%% >>> Re-create Robinson et al. 2025 large vs. small ripple analysis
% Possible control analysis. Antonio's group showed that large vs small
% ripples had an effect on memory formation and PFC recruitment
meanRipDur = mean(rippleStats.data.duration);
meanRipAmp = mean(rippleStats.data.peakAmplitude);
meanRipFrq = mean(rippleStats.data.peakFrequency);
ripDurZ = zscore(rippleStats.data.duration);
ripAmpZ = zscore(rippleStats.data.peakAmplitude);
ripFrqZ = zscore(rippleStats.data.peakFrequency);
large = ripDurZ > 0 & ripAmpZ > 0;


nexttile(53); cla; hold on;
scatter(ripDurZ(~large), ripAmpZ(~large),'.k')
scatter(ripDurZ(large), ripAmpZ(large),'.b')
xlabel('Duration (z-score)')
ylabel('Amplitude (z-score')
xl = xlim;
yl = ylim;
plot(xl,[0 0],'-r','LineWidth',0.5);
plot([0 0],yl,'-r','LineWidth',0.5);

nexttile(54); cla; hold on;
scatter(ripDurZ(~large), ripFrqZ(~large),'.k')
scatter(ripDurZ(large), ripFrqZ(large),'.b')
xlabel('Duration (z-score)')
ylabel('Frequency (z-score')

nexttile(65); cla; hold on;
scatter(ripAmpZ(~large), ripFrqZ(~large),'.k')
scatter(ripAmpZ(large), ripFrqZ(large),'.b')
xlabel('Amplitude (z-score)')
ylabel('Frequency (z-score')

nexttile(66); cla; hold on;
meanSmall = mean(rippleStats.maps.ripples(~large,:),1);
stdSmall = std(rippleStats.maps.ripples(~large),0,1);
meanLarge = mean(rippleStats.maps.ripples(large,:),1);
stdLarge = std(rippleStats.maps.ripples(large),0,1);
t = 1:size(rippleStats.maps.ripples,2);

plot(t,meanLarge,'-b','DisplayName','large')
x1 = [t, fliplr(t)];
y = [meanLarge + stdLarge, fliplr(meanLarge - stdLarge)];
patch(x1,y,'b','FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');


plot(t+t(end),meanSmall,'-k','DisplayName','small')
x1 = [t+t(end), fliplr(t+t(end))];
y = [meanSmall + stdSmall, fliplr(meanSmall - stdSmall)];
patch(x1,y,'k','FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
xticks([94, 281])
xticklabels({'large','small'});
yticklabels('');

%% >>> hippocampus DA response vs ripple size
f1 = figure(10);
nexttile(55, [2 2]); delete(gca);
nexttile(55, [2 2]); cla; hold on;
large = ripDurZ > 0 & ripAmpZ > 0;

events2plot = {'small','large'};
events = {ripples.timestamps(~large,1),...
          ripples.timestamps(large,1)};
data = photom_hpc.grabDA_z;
timestamps = photom_hpc.timestamps;
for e = 1:numel(events)  
    etaHPC = byl_getETA(events{e},data,timestamps,'frequency',130);

    % Plot
    plot(etaHPC.window, etaHPC.avg, 'color', green(e,:), 'LineWidth', 2,...
        'DisplayName',events2plot{e});
    x1 = [etaHPC.window, fliplr(etaHPC.window)];
    y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
    patch(x1,y,green(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
end
smallStats = mean(rippleStats.data.duration(~large));
largeStats = mean(rippleStats.data.duration(large));
patch([0 smallStats smallStats 0],...
          [-0.2 -0.2 -0.17 -0.17], ...
          green(1,:),'EdgeColor','none','HandleVisibility','off');
patch([0 largeStats largeStats 0],...
      [-0.17 -0.17 -0.14 -0.14], ...
      green(2,:),'EdgeColor','none','HandleVisibility','off');


xlabel('Time from event (s)');
ylabel('Fluorescence (z-score)');
title(sprintf('Ripple-Triggered Average\nHPC DA (behavior)'));
grid on;
% ylim([-0.2 1])
legend('location','best');
set(gca,'children',flipud(get(gca,'children')))
ylim(yLimHPCsleep);


%% > SandBox: Control - Random Subsample of Solos
fprintf('Control Analyses\n')
f = figure(2); clf; hold on;
f.Units = 'normalized';
f.Position = [0 0.05 1 0.865];
tiledlayout(5,8,'TileSpacing','tight','Padding','tight');
sgtitle(sprintf('%s',name),'Interpreter','none');

% --- ORIGINAL TRACE
fprintf('Original trace\n')
nexttile(3, [2 2]); cla; hold on;
events2plot = {'solos','duos','trios'};
events = {rippleBurst.soloTimes(:,1),...
          rippleBurst.burstTimes(rippleBurst.burstNum == 2,1),...
          rippleBurst.burstTimes(rippleBurst.burstNum == 3,1)};
data = photom_hpc.grabDA_z;
timestamps = photom_hpc.timestamps;

durations = [-5 5];
eta{1} = byl_getETA(events{1},data,timestamps,'frequency',130,'normalization','zscore','durations',durations);
eta{2} = byl_getETA(events{2},data,timestamps,'frequency',130,'normalization','zscore','durations',durations);
eta{3} = byl_getETA(events{3},data,timestamps,'frequency',130,'normalization','zscore','durations',durations);
eta{4} = byl_getETA(ripples.timestamps(:,1),data,timestamps,'frequency',130,'normalization','zscore','durations',durations);


numelSolos = sum(rippleBurst.solos);
numelDuos = sum(rippleBurst.duos);
numelTrios = sum(rippleBurst.trios);

for e = 1:numel(events)  
    plot(eta{e}.window, eta{e}.avg, 'color', blue(e,:), 'LineWidth', 2,...
        'DisplayName',events2plot{e});
    x1 = [eta{e}.window, fliplr(eta{e}.window)];
    y = [eta{e}.avg + eta{e}.sem, fliplr(eta{e}.avg - eta{e}.sem)];
    patch(x1,y,blue(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');    
end

xlabel('Time from event (s)');
ylabel('Fluorescence (z-score)');
title(sprintf('Ripple-Triggered Average\nHPC DA (whole session)'));
grid on;
legend('location','northwest');
set(gca,'children',flipud(get(gca,'children')))
YLref = ylim;

% % --- BOOTSTRAP
% fprintf('Bootstrap\n')
% nexttile(5, [2 2]); cla; hold on;
% permNum = 100;
% subsampNum = 30;
% for e = 1:numel(events)
%     perm = nan(permNum,numel(eta{e}.window));
%     for i = 1:permNum
%         ripNum = randperm(size(eta{e}.chunks,1));
%         ripNum = ripNum(1:subsampNum);
%         perm(i,:) = mean(eta{e}.chunks(ripNum,:),1);
%     end
%     newAvg = mean(perm,1);
%     newSem = std(perm,0,1) / sqrt(permNum);
%     plot(eta{e}.window, newAvg, 'color', red(e,:), 'LineWidth', 2,...
%         'DisplayName',events2plot{e});
%     x = [eta{e}.window, fliplr(eta{e}.window)];
%     y = [newAvg + newSem, fliplr(newAvg - newSem)];
%     patch(x,y,red(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');  
% end
% xlabel('Time from event (s)');
% ylabel('Fluorescence (z-score');
% title(sprintf('bootstrap'));
% grid on;
% legend('location','northwest');
% set(gca,'children',flipud(get(gca,'children')))
% ylim(YLref);

% --- Z-SCORE BY RIPPLE
fprintf('Z-score\n')
nexttile(5, [2 2]); cla; hold on;
for e = 1:numel(events)  
    plot(eta{e}.window, eta{e}.normAvg, 'color', red(e,:), 'LineWidth', 2,...
        'DisplayName',events2plot{e});
    x1 = [eta{e}.window, fliplr(eta{e}.window)];
    y = [eta{e}.normAvg + eta{e}.normSem, fliplr(eta{e}.normAvg - eta{e}.normSem)];
    patch(x1,y,red(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');    
end
  
xlabel('Time from event (s)');
ylabel('Fluorescence (z-score)');
title(sprintf('z-score per event'));
grid on;
legend('location','northwest');
set(gca,'children',flipud(get(gca,'children')))

% --- RANDOM SUBSAMPLE
fprintf('Random subsample\n')
nexttile(7, [2 2]); hold on;
permNum = 100;
for e = 1:numel(events)
    perm = nan(permNum,numel(eta{e}.window));
    for i = 1:permNum
        ripNum = randperm(size(ripples.timestamps,1));
        ripNum = ripNum(1:size(eta{e}.chunks,1));
        perm(i,:) = mean(eta{4}.chunks(ripNum,:),1);
    end
    newAvg = mean(perm,1);
    newSem = std(perm,0,1) / sqrt(permNum);
    plot(eta{e}.window, newAvg, 'color', orange(e,:), 'LineWidth', 2,...
        'DisplayName',events2plot{e});
    x1 = [eta{e}.window, fliplr(eta{e}.window)];
    y = [newAvg + newSem, fliplr(newAvg - newSem)];
    patch(x1,y,orange(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');  
end
xlabel('Time from event (s)');
ylabel('Fluorescence (z-score)');
title(sprintf('random subsample'));
grid on;
legend('location','northwest');
set(gca,'children',flipud(get(gca,'children')))
ylim(YLref);


% --- CIRCULAR SHIFT 
fprintf('Circular shift\n   ')
nexttile(23, [2 2]); hold on;
permNum = 50;
zz = permNum * numel(events);
for e = 1:numel(events)
    perm = nan(permNum,numel(eta{e}.window));
    for i = 1:permNum
        etaCS = byl_getETA(events{e},circshift(data,randi(numel(data))), ...
            timestamps,'frequency',130,'normalization','zscore','durations',durations);
        perm(i,:) = etaCS.avg;

        if mod((((e-1)*permNum)+i),10)==0
            if (((e-1)*permNum)+i)~=10
                fprintf(repmat('\b',[1 length([num2str(round(100*(((e-1)*permNum)+i)/zz)), ' percent complete'])]))
            end
            fprintf('%d percent complete', round(100*(((e-1)*permNum)+i)/zz));
        end
    end
    newAvg = mean(perm,1);
    newSem = std(perm,0,1) / sqrt(permNum);
    plot(eta{e}.window, newAvg, 'color', yellow(e,:), 'LineWidth', 2,...
        'DisplayName',events2plot{e});
    x1 = [eta{e}.window, fliplr(eta{e}.window)];
    y = [newAvg + newSem, fliplr(newAvg - newSem)];
    patch(x1,y,yellow(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');  
end
xlabel('Time from event (s)');
ylabel('Fluorescence (z-score)');
title(sprintf('circular shift'));
grid on;
legend('location','northwest');
set(gca,'children',flipud(get(gca,'children')))
ylim(YLref);

% --- LARGE VS SMALL RIPPLES
meanRipDur = mean(rippleStats.data.duration);
meanRipAmp = mean(rippleStats.data.peakAmplitude);
meanRipFrq = mean(rippleStats.data.peakFrequency);
ripDurZ = zscore(rippleStats.data.duration);
ripAmpZ = zscore(rippleStats.data.peakAmplitude);
ripFrqZ = zscore(rippleStats.data.peakFrequency);
large = ripDurZ > 0 & ripAmpZ > 0;

nexttile(19, [2 2]); cla; hold on;
large = ripDurZ > 0 & ripAmpZ > 0;

events2plot = {'small','large'};
events = {ripples.timestamps(~large,1),...
          ripples.timestamps(large,1)};
data = photom_hpc.grabDA_z;
timestamps = photom_hpc.timestamps;
for e = 1:numel(events)  
    etaHPC = byl_getETA(events{e},data,timestamps,'frequency',130);

    % Plot
    plot(etaHPC.window, etaHPC.avg, 'color', green(e,:), 'LineWidth', 2,...
        'DisplayName',events2plot{e});
    x1 = [etaHPC.window, fliplr(etaHPC.window)];
    y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
    patch(x1,y,green(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
end
smallStats = mean(rippleStats.data.duration(~large));
largeStats = mean(rippleStats.data.duration(large));
patch([0 smallStats smallStats 0],...
          [-0.2 -0.2 -0.17 -0.17], ...
          green(1,:),'EdgeColor','none','HandleVisibility','off');
patch([0 largeStats largeStats 0],...
      [-0.17 -0.17 -0.14 -0.14], ...
      green(2,:),'EdgeColor','none','HandleVisibility','off');


xlabel('Time from event (s)');
ylabel('Fluorescence (z-score)');
title(sprintf('large vs. small ripples'));
grid on;
% ylim([-0.2 1])
legend('location','best');
set(gca,'children',flipud(get(gca,'children')))
ylim(YLref);

% --- QUINTILES BY RIPPLE DURATION
nexttile(21, [2 2]); cla; hold on;

gscol = gray(7);
gscol = gscol(1:5,:);

edges = quantile(ripDurZ,linspace(0,1,6));
for q = 1:numel(edges)-1
    Q{q} = ripDurZ >= edges(q) & ripDurZ < edges(q+1);
end

events2plot = {'Q1','Q2','Q3','Q4','Q5'};
data = photom_hpc.grabDA_z;
timestamps = photom_hpc.timestamps;

for e = 1:numel(events2plot)
    events = ripples.timestamps(Q{e},1);
    etaQ{e} = byl_getETA(events,data,timestamps,'frequency',130, ...
        'normalization','zscore','durations',durations);
    plot(etaQ{e}.window, etaQ{e}.avg, 'color', gscol(e,:), 'LineWidth', 2,...
        'DisplayName',events2plot{e});
    x1 = [etaQ{e}.window, fliplr(etaQ{e}.window)];
    y = [etaQ{e}.avg + etaQ{e}.sem, fliplr(etaQ{e}.avg - etaQ{e}.sem)];
    % patch(x1,y,gscol(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');    
end

xlabel('Time from event (s)');
ylabel('Fluorescence (z-score)');
title(sprintf('quintiles'));
grid on;
legend('location','northwest');
set(gca,'children',flipud(get(gca,'children')))
ylim(YLref);

% --- QUINTILES BY BURST DURATION
% nexttile(21, [2 2]); cla; hold on;
% 
% gscol = gray(7);
% gscol = gscol(1:5,:);
% 
% allSWR = sort(vertcat(rippleBurst.burstTimes, rippleBurst.soloTimes));
% allSWRDur = allSWR(:,2)-allSWR(:,1);
% 
% edges = quantile(allSWRDur,linspace(0,1,6));
% for q = 1:numel(edges)-1
%     Q{q} = allSWRDur >= edges(q) & allSWRDur < edges(q+1);
% end
% 
% events2plot = {'Q1','Q2','Q3','Q4','Q5'};
% data = photom_hpc.grabDA_z;
% timestamps = photom_hpc.timestamps;
% 
% for e = 1:numel(events2plot)
%     events = allSWR(Q{e},1);
%     etaQ{e} = byl_getETA(events,data,timestamps,'frequency',130, ...
%         'normalization','zscore','durations',durations);
%     plot(etaQ{e}.window, etaQ{e}.avg, 'color', gscol(e,:), 'LineWidth', 2,...
%         'DisplayName',events2plot{e});
%     x1 = [etaQ{e}.window, fliplr(etaQ{e}.window)];
%     y = [etaQ{e}.avg + etaQ{e}.sem, fliplr(etaQ{e}.avg - etaQ{e}.sem)];
%     patch(x1,y,gscol(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');    
% end
% 
% xlabel('Time from event (s)');
% ylabel('Fluorescence (z-score)');
% title(sprintf('quintiles'));
% grid on;
% legend('location','northwest');
% set(gca,'children',flipud(get(gca,'children')))
% ylim(YLref);

figure(2);

% >>> Ripple Amplitude
nexttile(1); cla; hold on;
solo = rippleStats.data.peakAmplitude(rippleBurst.solos);
duo = rippleStats.data.peakAmplitude(rippleBurst.duos);
trio = rippleStats.data.peakAmplitude(rippleBurst.trios);

plot(ones(size(solo)), solo, 'o','Color',[0.8 0.8 0.8],'HandleVisibility','off');
plot(1, mean(solo),'o','color',blue(1,:),'MarkerFaceColor',blue(1,:),'DisplayName','solos');
errorbar(1, mean(solo),std(solo),'color',blue(1,:))

plot(2*ones(size(duo)), duo, 'o','Color',[0.8 0.8 0.8],'HandleVisibility','off');
plot(2, mean(duo),'o','color',blue(2,:),'MarkerFaceColor',blue(2,:),'DisplayName','duos');
errorbar(2, mean(duo),std(duo),'color',blue(2,:))

plot(3*ones(size(trio)), trio, 'o','Color',[0.8 0.8 0.8],'HandleVisibility','off');
plot(3, mean(trio),'o','color',blue(3,:),'MarkerFaceColor',blue(3,:),'DisplayName','trios');
errorbar(3, mean(trio),std(trio),'color',blue(3,:))

xlim([0.5 3.5])

title('Ripple Peak Amplitude')
xticklabels({'solos','duos','trios'})

% >>> Ripple Duration
nexttile(2); cla; hold on;
solo = rippleStats.data.duration(rippleBurst.solos);
duo = rippleStats.data.duration(rippleBurst.duos);
trio = rippleStats.data.duration(rippleBurst.trios);

plot(ones(size(solo)), solo, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(1, mean(solo),'o','color',blue(1,:),'MarkerFaceColor',blue(1,:),'DisplayName','solos');
errorbar(1, mean(solo),std(solo),'color',blue(1,:))

plot(2*ones(size(duo)), duo, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(2, mean(duo),'o','color',blue(2,:),'MarkerFaceColor',blue(2,:),'DisplayName','duos');
errorbar(2, mean(duo),std(duo),'color',blue(2,:))

plot(3*ones(size(trio)), trio, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(3, mean(trio),'o','color',blue(3,:),'MarkerFaceColor',blue(3,:),'DisplayName','trios');
errorbar(3, mean(trio),std(trio),'color',blue(3,:))

xlim([0.5 3.5])
title('Ripple Duration')
xticklabels({'solos','duos','trios'})
ylabel('sec')

% >>> Ripple Frequency
nexttile(9); cla; hold on;
solo = rippleStats.data.peakFrequency(rippleBurst.solos);
duo = rippleStats.data.peakFrequency(rippleBurst.duos);
trio = rippleStats.data.peakFrequency(rippleBurst.trios);

plot(ones(size(solo)), solo, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(1, mean(solo),'o','color',blue(1,:),'MarkerFaceColor',blue(1,:),'DisplayName','solos');
errorbar(1, mean(solo),std(solo),'color',blue(1,:))

plot(2*ones(size(duo)), duo, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(2, mean(duo),'o','color',blue(2,:),'MarkerFaceColor',blue(2,:),'DisplayName','duos');
errorbar(2, mean(duo),std(duo),'color',blue(2,:))

plot(3*ones(size(trio)), trio, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(3, mean(trio),'o','color',blue(3,:),'MarkerFaceColor',blue(3,:),'DisplayName','trios');
errorbar(3, mean(trio),std(trio),'color',blue(3,:))

xlim([0.5 3.5])
title('Ripple Frequency')
xticklabels({'solos','duos','trios'})
ylabel('Hz')

% >>> Burst Duration
nexttile(10); cla; hold on;
solo = rippleStats.data.duration(rippleBurst.solos);
duo = rippleBurst.burstTimes(rippleBurst.burstNum == 2,2) - rippleBurst.burstTimes(rippleBurst.burstNum == 2,1);
trio = rippleBurst.burstTimes(rippleBurst.burstNum == 3,2) - rippleBurst.burstTimes(rippleBurst.burstNum == 3,1);

plot(ones(size(solo)), solo, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(1, mean(solo),'o','color',blue(1,:),'MarkerFaceColor',blue(1,:),'DisplayName','solos');
errorbar(1, mean(solo),std(solo),'color',blue(1,:))

plot(2*ones(size(duo)), duo, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(2, mean(duo),'o','color',blue(2,:),'MarkerFaceColor',blue(2,:),'DisplayName','duos');
errorbar(2, mean(duo),std(duo),'color',blue(2,:))

plot(3*ones(size(trio)), trio, 'o','Color',[0.7 0.7 0.7],'HandleVisibility','off');
plot(3, mean(trio),'o','color',blue(3,:),'MarkerFaceColor',blue(3,:),'DisplayName','trios');
errorbar(3, mean(trio),std(trio),'color',blue(3,:))

xlim([0.5 3.5])
title('Burst Duration')
xticklabels({'solos','duos','trios'})
ylabel('sec')

meanRipDur = mean(rippleStats.data.duration);
meanRipAmp = mean(rippleStats.data.peakAmplitude);
meanRipFrq = mean(rippleStats.data.peakFrequency);
ripDurZ = zscore(rippleStats.data.duration);
ripAmpZ = zscore(rippleStats.data.peakAmplitude);
ripFrqZ = zscore(rippleStats.data.peakFrequency);
large = ripDurZ > 0 & ripAmpZ > 0;

% --- DA before and after
nexttile(17); cla; hold on;
for e = 1:3
    before = zscore(mean(eta{e}.chunks(:,eta{e}.window < 0),2)); 
    after = (mean(eta{e}.chunks(:,eta{e}.window >= 0),2) - mean(before)) / std(before); 
    
    x1 = 2*(e-1)+1;
    y1 = x1 + 1;
    plot([x1,y1], [before after],'Color',[0.7 0.7 0.7],'LineWidth',0.5)
    plot(x1, mean(before), 'o', 'Color',purple(e,:), 'MarkerFaceColor',purple(e,:),'LineWidth',2);
    errorbar(x1, mean(before), std(before),'Color',purple(e,:),'LineWidth',2)
    plot(y1, mean(after), 'o', 'Color',purple(e,:), 'MarkerFaceColor',purple(e,:),'LineWidth',2);
    errorbar(y1, mean(after), std(after),'Color',purple(e,:),'LineWidth',2)
end
xlim([0 7])
title('change in average DA')
xticks(1:6)
xticklabels({'before','after','before','after','before','after'})
ylabel('z-score (rel. before)')


% --- DA 0 to max
nexttile(18); cla; hold on;
for e = 1:3
    change = max(eta{e}.chunks(:,eta{e}.window > 0),[],2) - eta{e}.chunks(:,eta{e}.window == 0);
    xi = e;
    x1 = e*ones(size(change));                 % all at x = 1
    jitterAmount = 0.15;                   % how wide to spread
    xJittered = x1 + (rand(size(x1)) - 0.5)*2*jitterAmount;
    scatter(xJittered, change, 5, [0.7 0.7 0.7], 'filled');
    plot(xi, mean(change), 'o', 'Color',purple(e,:), 'MarkerFaceColor',purple(e,:),'LineWidth',2);
    errorbar(xi, mean(change), std(change),'Color',purple(e,:),'LineWidth',2)
   
end
xlim([0 4])
title('change in average DA')
xticks(1:3)
xticklabels({'solos','duos','trios'})
ylabel('change in DA')


nexttile(37); cla; hold on;
scatter(ripDurZ(~large), ripAmpZ(~large),'.k')
scatter(ripDurZ(large), ripAmpZ(large),'.b')
xlabel('Duration (z-score)')
ylabel('Amplitude (z-score')
xl = xlim;
yl = ylim;
plot(xl,[0 0],'-r','LineWidth',0.5);
plot([0 0],yl,'-r','LineWidth',0.5);