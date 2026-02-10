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
        regions = unique(extractBefore({syncPhotometryPaths.name}, '-'));
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

%% Initialize
sesh = 1;

cd(sessionPaths{sesh});
[~,name,~] = fileparts(sessionPaths{sesh});

% d = (dir(fullfile(sessionPaths{sesh},'N*.session.mat')));
% load(fullfile(d(1).folder, d(1).name))

% d = (dir(fullfile('N*.behavior.matrices.mat')));
% load(fullfile(d(1).folder, d(1).name))

d = (dir(fullfile('N*.TrialBehavior.mat')));
load(fullfile(d(1).folder, d(1).name))

d = (dir(fullfile('N*.Tracking.Behavior.mat')));
load(fullfile(d(1).folder, d(1).name))

d = (dir(fullfile('N*.ripples.events.mat')));
load(fullfile(d(1).folder, d(1).name))

d = (dir(fullfile('N*.ripples.stats.mat')));
load(fullfile(d(1).folder, d(1).name));

d = (dir(fullfile('N*.SleepState.states.mat')));
load(fullfile(d(1).folder, d(1).name))

if any(contains(fileTable(sesh,:).whichRegions{:},'HPC'))
    d = (dir(fullfile('N*.photometry.HPC.mat')));
    load(fullfile(d(1).folder, d(1).name))
    photom_hpc = concPhotom;
end

if any(contains(fileTable(sesh,:).whichRegions{:},'STR'))
d = (dir(fullfile('N*.photometry.STR.mat')));
load(fullfile(d(1).folder, d(1).name))
photom_str = concPhotom;
end


d = (dir(fullfile('N*.MergePoints.events.mat')));
load(fullfile(d(1).folder, d(1).name))

fprintf('%s - data loaded\n',name)
%% Events and Photometry
% events_possible = {'Ripples','Stims','Nosepoke','Rewarded Poke', 'Unrewarded Poke'};
% events_name = {'Ripples','Stims','Nosepoke','Rewarded Poke'};
% events_list = {ripples.timestamps(:,1), ripples.timestamps(:,1);...
%                photom_hpc.stimpulseOnOff(:,1)),...
%                     photom_str.stimpulseOnOff(:,1));...
%                behavTrials.timestamps, behavTrials.timestamps;...
%                behavTrials.timestamps(logical(behavTrials.reward_outcome)),behavTrials.timestamps(logical(behavTrials.reward_outcome))};
% 
% 
% for e = 1:size(events_list,1)
%     events_hpc = events_list{e,1};
%     events_str = events_list{e,2};
% 
%     F1 = figure(e); clf;
%     F1.Position = [300+(20*e) 300+(20*e) 1000 500];
%     subplot(2,1,1);  hold on;
%     plot(events_hpc, ones(size(events_hpc)),'|k','LineWidth',0.5,'MarkerSize',20)
%     plot(photom_hpc.timestamps,photom_hpc.grabDA_df)
%     YL = ylim;
%     epochs = photom_hpc.epochs;
%     x = [epochs(2,1) epochs(2,1) epochs(2,2) epochs(2,2)];
%     y = [YL flip(YL)];
%     patch(x, y, [0.7 0.7 0.7],'EdgeColor','none','FaceAlpha',0.5)
%     title(sprintf('%s and hippocampus dopamine over whole session',events_name{e}))
%     set(gca,'children',flipud(get(gca,'children')))
%     xlabel('Time (s)')
%     ylabel('z-score')
% 
%     subplot(2,1,2); hold on;
%     plot(events_str, ones(size(events_str)),'|k','LineWidth',0.5,'MarkerSize',20)
%     plot(photom_str.timestamps,photom_str.grabDA_df)
%     YL = ylim;
%     epochs = photom_str.epochs;
%     x = [epochs(2,1) epochs(2,1) epochs(2,2) epochs(2,2)];
%     y = [YL flip(YL)];
%     patch(x, y, [0.7 0.7 0.7],'EdgeColor','none','FaceAlpha',0.5)
%     title(sprintf('%s and striatum dopamine over whole session', events_name{e}))
%     set(gca,'children',flipud(get(gca,'children')))
%     xlabel('Time (s)')
%     ylabel('z-score')
% end

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

%% Event Triggered Averages
% build a -5 to +5 time window around each ripple event, evenly sampled at
% 130 Hz (photometry sampling rate), and interpolate at the windowed
% samples from the PHOTOM DATA to build the event-triggered average DA
% trace.

%{
% Choose Events
N = split(num2str(1:numel(burstPlace)));
% events2plot = {'bursts', 'solos'}; 
events2plot = {'solos','duos','trios'};
% events2plot = {'solos','1','2','3'};
% events2plot = {'solos','1','last'};
% events2plot = {'long stim','short stim'};
% events2plot = {'stims','nosepokes'};
% events2plot = {'rewarded pokes', 'unrewarded pokes'};
% events2plot = {'gibberish'};
traces2pull = {'z-score'};      % z-score, dF/F

% stack plots or not
stack = true;

% create color scheme
str_col = customcolormap([0 0.75 1],[1 0.9 0.9; 0.5 0 0; 0.1 0 0],101);
str_col = str_col([20 50 80],:);
hpc_col = customcolormap([0 0.75 1],[0.9 0.9 1; 0 0 0.5; 0 0 0.1],101);
hpc_col = hpc_col([20 50 80],:);

% str_col = autumn(4);
% hpc_col = winter(4);

for e = 1:numel(events2plot)
    % for a = 1:numel(traces2pull)
    event = events2plot{e};
    trace = traces2pull{1};
    % rename event times variables
    switch lower(event)
        case "ripples"
            eventTimes_hpc = ripples.timestamps(:,1);
            eventTimes_str = ripples.timestamps(:,1);
        case "stims"
            eventTimes_hpc = photom_hpc.stimpulseOnOff(:,1));
            eventTimes_str = photom_str.stimpulseOnOff(:,1));
        case "long stim"
            eventTimes_hpc = photom_hpc.stimpulseOnOff(stimDur > 1,1));
            eventTimes_str = photom_str.stimpulseOnOff(stimDur > 1,1));
        case "short stim"
            eventTimes_hpc = photom_hpc.stimpulseOnOff(stimDur < 1,1));
            eventTimes_str = photom_str.stimpulseOnOff(stimDur < 1,1));
        case "nosepokes"
            eventTimes_hpc = behavTrials.timestamps;
            eventTimes_str = behavTrials.timestamps;
        case "rewarded pokes"
            eventTimes_hpc = behavTrials.timestamps(logical(behavTrials.reward_outcome));
            eventTimes_str = behavTrials.timestamps(logical(behavTrials.reward_outcome));
        case "unrewarded pokes"
            eventTimes_hpc = behavTrials.timestamps(~logical(behavTrials.reward_outcome));
            eventTimes_str = behavTrials.timestamps(~logical(behavTrials.reward_outcome));
        case "first in duos"
            idx = rippleBurst.first & rippleBurst.duos;
            eventTimes_hpc = ripples.timestamps(idx,1);
            eventTimes_str = ripples.timestamps(idx,1);
        case "second in duos"
            idx = rippleBurst.second & rippleBurst.duos;
            eventTimes_hpc = ripples.timestamps(idx,1);
            eventTimes_str = ripples.timestamps(idx,1);
        case "first in trios"
            idx = rippleBurst.first & rippleBurst.trios;
            eventTimes_hpc = ripples.timestamps(idx,1);
            eventTimes_str = ripples.timestamps(idx,1);
        case "second in trios"
            idx = rippleBurst.second & rippleBurst.trios;
            eventTimes_hpc = ripples.timestamps(idx,1);
            eventTimes_str = ripples.timestamps(idx,1);
        case "third in trios"
            idx = rippleBurst.third & rippleBurst.trios;
            eventTimes_hpc = ripples.timestamps(idx,1);
            eventTimes_str = ripples.timestamps(idx,1);
        otherwise
            if isfield(rippleBurst, event)
                eventTimes_hpc = ripples.timestamps(rippleBurst.(event),1);
                eventTimes_str = ripples.timestamps(rippleBurst.(event),1);
            else
                fprintf('%s is not a registered event type. Halting.\n',event);
                break;
            end
    end
    
    disp('Extracting event windows...')

    etaHPC = byl_getETA(eventTimes_hpc, ...
        photom_hpc.grabDA_z, ...
        photom_hpc.timestamps, ...
        'frequency',130);
    etaSTR = byl_getETA(eventTimes_str, ...
        photom_str.grabDA_z, ...
        photom_str.timestamps, ...
        'frequency',130);
    % Plot
    [~,name,~] = fileparts(sessionPaths{sesh});


    if stack == true && e == 1
        f = figure(e); clf; hold on;
        disp('Waiting for next plots...')
    elseif stack == true && e ~= 1
        f = gcf; hold on;
        disp('Waiting for next plots...')
    else 
        f = figure(e); clf;
        tiledlayout(1,2,"TileSpacing",'tight')
    end
    f.Position = [100 200 1300 500];
    sgtitle(sprintf('%s',name),'Interpreter','none');

    nexttile(1); hold on;
    plot(etaHPC.window, etaHPC.avg, 'color', hpc_col(e,:), 'LineWidth', 2,...
        'DisplayName',events2plot{e});
    x = [etaHPC.window, fliplr(etaHPC.window)];
    y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
    patch(x,y,hpc_col(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
    YL1 = ylim;
    plot([0 0], YL1,'-k','LineWidth',0.5,'HandleVisibility','off');
    xlabel('Time from event (s)');
    ylabel(ylab);
    title(sprintf('Event-Triggered Average\nHPC DA'));
    grid on;
    legend();
    
    nexttile(2); hold on;
    plot(etaSTR.window, etaSTR.avg, 'color', str_col(e,:), 'LineWidth', 2,...
        'DisplayName',events2plot{e});
    x = [etaSTR.window, fliplr(etaSTR.window)];
    y = [etaSTR.avg + etaSTR.sem, fliplr(etaSTR.avg - etaSTR.sem)];
    patch(x,y,str_col(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
    YL2 = ylim;
    plot([0 0], YL2,'-k','LineWidth',0.5,'HandleVisibility','off');
    xlabel('Time from event (s)');
    ylabel(ylab);
    title(sprintf('Event-Triggered Average\nSTR DA'));
    grid on;
    legend();
    % YL = [min([YL1,YL2]), max([YL1,YL2])];
    % ax = findall(f,'type','axes');
    % ylim(ax, YL)
    
end
disp('done!')
%}

%% Custom Color Map
red = customcolormap([0 0.5 1],[1 1 1; 0.5 0 0; 0 0 0],101);
red = red([20 50 80],:);
orange = customcolormap([0 0.65 1],[1 1 1; 0.9 0.4 0; 0 0 0],101);
orange = orange([20 50 80],:);
green = customcolormap([0 0.5 1],[1 1 1; 0 0.6 0.3; 0 0 0],101);
green = green([20 50 80],:);
blue = customcolormap([0 0.75 1],[1 1 1; 0 0 0.5; 0 0 0],101);
blue = blue([20 50 80],:);
purple = customcolormap([0 0.5 1],[1 1 1; 0.5 0 0.5; 0 0 0],101);
purple = purple([20 50 80],:);


% figure(69); colorbar; colormap(orange);
%% Master Plot
[~,name,~] = fileparts(sessionPaths{sesh});
% figure initiate
f1 = figure(10); clf; hold on;
f1.Units = 'normalized';
f1.Position = [0 0.05 1 0.865];
tiledlayout(6,12,'TileSpacing','tight','Padding','tight');
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



%% >>> ETA: solos, duos, trios hippocampus (sleep)
% create color scheme
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
        x = [etaHPC.window, fliplr(etaHPC.window)];
        y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
        patch(x,y,blue(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');    
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
        x = [etaHPC.window, fliplr(etaHPC.window)];
        y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
        patch(x,y,blue(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
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

    events2plot = {'long VTA stim','short VTA stim'};
    events = {photom_hpc.stimpulseOnOff(stimDur > 1,1),...
              photom_hpc.stimpulseOnOff(stimDur < 1,1)};
    data = photom_hpc.grabDA_z;
    timestamps = photom_hpc.timestamps;
    for e = 1:numel(events)  
        etaHPC = byl_getETA(events{e},data,timestamps,'frequency',130);
    
        % Plot
        plot(etaHPC.window, etaHPC.avg, 'color', purple(e,:), 'LineWidth', 2,...
            'DisplayName',events2plot{e});
        x = [etaHPC.window, fliplr(etaHPC.window)];
        y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
        patch(x,y,purple(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
        
        
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

    events2plot = {'rewarded','unrewarded'};
    events = {behavTrials.timestamps(logical(behavTrials.reward_outcome)),...
              behavTrials.timestamps(~logical(behavTrials.reward_outcome))};
    data = photom_hpc.grabDA_z;
    timestamps = photom_hpc.timestamps;
    for e = 1:numel(events)  
        etaHPC = byl_getETA(events{e},data,timestamps,'frequency',130);
    
        % Plot
        plot(etaHPC.window, etaHPC.avg, 'color', purple(e,:), 'LineWidth', 2,...
            'DisplayName',events2plot{e});
        x = [etaHPC.window, fliplr(etaHPC.window)];
        y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
        patch(x,y,purple(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
        
        
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
        x = [etaHPC.window, fliplr(etaHPC.window)];
        y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
        patch(x,y,red(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
        
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
        x = [etaHPC.window, fliplr(etaHPC.window)];
        y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
        patch(x,y,red(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
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

    events2plot = {'long VTA stim','short VTA stim'};
    events = {photom_str.stimpulseOnOff(stimDur < 1,1),...
              photom_str.stimpulseOnOff(stimDur > 1,1)};
    data = photom_str.grabDA_z;
    timestamps = photom_str.timestamps;
    for e = 1:numel(events)  
        etaSTR = byl_getETA(events{e},data,timestamps,'frequency',130);
    
        % Plot
        plot(etaSTR.window, etaSTR.avg, 'color', orange(e,:), 'LineWidth', 2,...
            'DisplayName',events2plot{e});
        x = [etaSTR.window, fliplr(etaSTR.window)];
        y = [etaSTR.avg + etaSTR.sem, fliplr(etaSTR.avg - etaSTR.sem)];
        patch(x,y,orange(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
        
        
    end
    xlabel('Time from event (s)');
    ylabel('Fluorescence (z-score');
    title(sprintf('Poke/Stim-Triggered Average\nSTR DA (behavior)'));
    grid on;
    legend('location','best');
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

    events2plot = {'rewarded','unrewarded'};
    events = {behavTrials.timestamps(logical(behavTrials.reward_outcome)),...
              behavTrials.timestamps(~logical(behavTrials.reward_outcome))};
    data = photom_str.grabDA_z;
    timestamps = photom_str.timestamps;
    for e = 1:numel(events)  
        etaHPC = byl_getETA(events{e},data,timestamps,'frequency',130);
    
        % Plot
        plot(etaHPC.window, etaHPC.avg, 'color', orange(e,:), 'LineWidth', 2,...
            'DisplayName',events2plot{e});
        x = [etaHPC.window, fliplr(etaHPC.window)];
        y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
        patch(x,y,orange(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
        
        
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
x = [t, fliplr(t)];
y = [meanLarge + stdLarge, fliplr(meanLarge - stdLarge)];
patch(x,y,'b','FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');


plot(t+t(end),meanSmall,'-k','DisplayName','small')
x = [t+t(end), fliplr(t+t(end))];
y = [meanSmall + stdSmall, fliplr(meanSmall - stdSmall)];
patch(x,y,'k','FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
xticks([94, 281])
xticklabels({'large','small'});
yticklabels('');

%% >>> hippocampus DA response vs ripple size
f1 = figure(10);
nexttile(55, [2 2]); delete(gca);
nexttile(55, [2 2]); cla; hold on;
large = ripDurZ > 0 & ripAmpZ > 0;

events2plot = {'large','small'};
events = {ripples.timestamps(large,1),...
          ripples.timestamps(~large,1)};
data = photom_hpc.grabDA_z;
timestamps = photom_hpc.timestamps;
for e = 1:numel(events)  
    etaHPC = byl_getETA(events{e},data,timestamps,'frequency',130);

    % Plot
    plot(etaHPC.window, etaHPC.avg, 'color', green(e,:), 'LineWidth', 2,...
        'DisplayName',events2plot{e});
    x = [etaHPC.window, fliplr(etaHPC.window)];
    y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
    patch(x,y,green(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
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














