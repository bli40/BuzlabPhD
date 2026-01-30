%% Load Data and Check if Preprocessing is Complete
clear all;
close all;
% addpath('C:\Users\Gergely\Documents\Brian\BuzlabPhD\project-dopamineTagging\Code\matlab-code');
% directory = readtable('C:\Users\Gergely\Documents\Brian\Data\project-dopamineTagging-data\data-directory.xlsx');
addpath("C:\Users\brian\BuzlabPhD\project-dopamineTagging\Code\matlab-code\");
directory = readtable("\\research-cifs.nyumc.org\research\buzsakilab\Buzsakilabspace\LabShare\BrianLi\project-dopamine-tagging\data-directories.xlsx");
sessions2analyze = logical(directory.Use);
animals2analyze = strcmp(directory.Mouse,'N17');
twoRegions = directory.HPC & directory.STR;
% sessionPaths = directory.Path(sessions2analyze & animals2analyze);
sessionPaths = directory.Path(animals2analyze & twoRegions);
disp(sessionPaths);
sesh = 2;

for s = 1:numel(sessionPaths)
    preprocessedPaths = dir(fullfile(sessionPaths{s},'\*.photometry.*.sync.conc.mat'));
    [~,name,~] = fileparts(sessionPaths{s});
    fprintf('<strong>%d) %s has %d</strong> synchronized and concatenated photometry files:\n',s,name,numel(preprocessedPaths))
    for e = 1:numel(preprocessedPaths)
        sessionName = split(preprocessedPaths(e).name,'.');
        fprintf(2,'<strong>\t%s\n</strong>',sessionName{3})
    end
    if numel(preprocessedPaths) == 0
        syncPhotometryPaths = dir(fullfile(sessionPaths{s},'*\*_new_photometry_sync.mat'));
        if numel(syncPhotometryPaths) ~= 0
            epochs = split({syncPhotometryPaths.name},'-');
            epochs = unique(epochs(:,:,1));
            for i = 1:numel(epochs)
                fprintf('\t%s - %i files ready to <strong>concatenate</strong>.\n', epochs{i}, sum(contains({syncPhotometryPaths.name},epochs{i})));
            end
        else
            photometryDataPaths = dir(fullfile(sessionPaths{s},'*\*_new_photometry.mat'));
            if numel(photometryDataPaths) ~= 0
                epochs = split({photometryDataPaths.name},'-');
                epochs = unique(epochs(:,:,1));
                for i = 1:numel(epochs)
                    fprintf('\t%s - %i files ready to <strong>synchronize</strong>.\n', epochs{i}, sum(contains({photometryDataPaths.name},epochs{i})));
                end
            else
                epochsDataPaths = dir(fullfile(sessionPaths{s},'*\*.ppd'));
                epochs = split({epochsDataPaths.name},'-');
                epochs = unique(epochs(:,:,1));
                for i = 1:numel(epochs)
                    fprintf('\t%s - %i files ready to <strong>preprocess</strong>.\n', epochs{i}, sum(contains({epochsDataPaths.name},epochs{i})));
                end
            end
        end
    end
end
cd(sessionPaths{sesh});

%% Initialize
sesh = 1;

cd(sessionPaths{sesh});
d = (dir(fullfile(sessionPaths{sesh},'N*.session.mat')));
load(fullfile(d(1).folder, d(1).name))

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

d = (dir(fullfile('N*.photometry.HPC.sync.conc.mat')));
load(fullfile(d(1).folder, d(1).name))

d = (dir(fullfile('N*.photometry.STR.sync.conc.mat')));
load(fullfile(d(1).folder, d(1).name))

d = (dir(fullfile('N*.MergePoints.events.mat')));
load(fullfile(d(1).folder, d(1).name))


%% Events and Photometry
events_possible = {'Ripples','Stims','Nosepoke','Rewarded Poke', 'Unrewarded Poke'};
events_name = {'Ripples','Stims','Nosepoke','Rewarded Poke'};
events_list = {ripples.timestamps(:,1), ripples.timestamps(:,1);...
               photometry_HPC_sync_concat.timestamps(photometry_HPC_sync_concat.barcodesOn),...
                    photometry_STR_sync_concat.timestamps(photometry_STR_sync_concat.barcodesOn);...
               behavTrials.timestamps, behavTrials.timestamps;...
               behavTrials.timestamps(logical(behavTrials.reward_outcome)),behavTrials.timestamps(logical(behavTrials.reward_outcome))};


for e = 1:size(events_list,1)
    events_hpc = events_list{e,1};
    events_str = events_list{e,2};

    F1 = figure(e); clf;
    F1.Position = [300+(20*e) 300+(20*e) 1000 500];
    subplot(2,1,1);  hold on;
    plot(events_hpc, ones(size(events_hpc)),'|k','LineWidth',0.5,'MarkerSize',20)
    plot(photometry_HPC_sync_concat.timestamps,photometry_HPC_sync_concat.grabDA_df)
    YL = ylim;
    epochs = photometry_HPC_sync_concat.epochs;
    x = [epochs(2,1) epochs(2,1) epochs(2,2) epochs(2,2)];
    y = [YL flip(YL)];
    patch(x, y, [0.7 0.7 0.7],'EdgeColor','none','FaceAlpha',0.5)
    title(sprintf('%s and hippocampus dopamine over whole session',events_name{e}))
    set(gca,'children',flipud(get(gca,'children')))
    xlabel('Time (s)')
    ylabel('z-score')
    
    subplot(2,1,2); hold on;
    plot(events_str, ones(size(events_str)),'|k','LineWidth',0.5,'MarkerSize',20)
    plot(photometry_STR_sync_concat.timestamps,photometry_STR_sync_concat.grabDA_df)
    YL = ylim;
    epochs = photometry_STR_sync_concat.epochs;
    x = [epochs(2,1) epochs(2,1) epochs(2,2) epochs(2,2)];
    y = [YL flip(YL)];
    patch(x, y, [0.7 0.7 0.7],'EdgeColor','none','FaceAlpha',0.5)
    title(sprintf('%s and striatum dopamine over whole session', events_name{e}))
    set(gca,'children',flipud(get(gca,'children')))
    xlabel('Time (s)')
    ylabel('z-score')
end

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
		secondPass = [secondPass ; ripple];     % secondPass is updated each cycle and contains all previous ripples. /kg
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
                     'notLast', ripBurstRevIdx ~= 1 | 0);

%% Mean Stimulation Time
stimOnOff = photometry_HPC_sync_concat.timestamps(photometry_HPC_sync_concat.barcodesOnOff);
stimDur = stimOnOff(:,2) - stimOnOff(:,1);

%% Event Triggered Averages
% build a -5 to +5 time window around each ripple event, evenly sampled at
% 130 Hz (photometry sampling rate), and interpolate at the windowed
% samples from the photometry data to build the event-triggered average DA
% trace.

% Parameters
fs = 130;           % LFP sampling rate (Hz)
pre  = 5;           % seconds before spike
post = 5;           % seconds after spike

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

% Define relative time axis (not samples)
tWind = -pre : 1/fs : post;
winLength = numel(tWind);

% stack plots or not
stack = true;

% create color scheme
str_col = autumn(5);
hpc_col = winter(5);

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
            eventTimes_hpc = photometry_HPC_sync_concat.timestamps(photometry_HPC_sync_concat.barcodesOn);
            eventTimes_str = photometry_STR_sync_concat.timestamps(photometry_STR_sync_concat.barcodesOn);
        case "long stim"
            eventTimes_hpc = photometry_HPC_sync_concat.timestamps(photometry_HPC_sync_concat.barcodesOn(stimDur == 3));
            eventTimes_str = photometry_STR_sync_concat.timestamps(photometry_STR_sync_concat.barcodesOn(stimDur == 3));
        case "short stim"
            eventTimes_hpc = photometry_HPC_sync_concat.timestamps(photometry_HPC_sync_concat.barcodesOn(stimDur == 0.5));
            eventTimes_str = photometry_STR_sync_concat.timestamps(photometry_STR_sync_concat.barcodesOn(stimDur == 0.5));
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
    % Preallocate
    etaMatrixHPC = nan(numel(eventTimes_hpc), winLength);
    etaMatrixSTR = nan(numel(eventTimes_str), winLength);
    
    % Interpolate DA traces in time space
    tHPC = photometry_HPC_sync_concat.timestamps;
    tSTR = photometry_STR_sync_concat.timestamps;
    
    switch trace
        case 'z-score'
            xHPC = photometry_HPC_sync_concat.grabDA_z;
            xSTR = photometry_STR_sync_concat.grabDA_z;
            ylab = 'mean DA (z-score)';
        case 'dF/F'
            xHPC = photometry_HPC_sync_concat.grabDA_df;
            xSTR = photometry_STR_sync_concat.grabDA_df;
            ylab = 'mean DA (dF/F)';
        otherwise
            fprintf('%s is not a registered event type. Halting.\n',event);
            break;
    end

    % --- HPC ---
    keepHPC = false(numel(eventTimes_hpc),1);
    
    for i = 1:numel(eventTimes_hpc)
        tSample = eventTimes_hpc(i) + tWind;
    
        if tSample(1) < tHPC(1) || tSample(end) > tHPC(end)
            continue
        end
    
        etaMatrixHPC(i,:) = interp1(tHPC, xHPC, tSample, 'linear');
        keepHPC(i) = true;
    end
    
    etaMatrixHPC = etaMatrixHPC(keepHPC,:);
    
    % --- STR ---
    keepSTR = false(numel(eventTimes_str),1);
    
    for i = 1:numel(eventTimes_str)
        tSample = eventTimes_str(i) + tWind;
    
        if tSample(1) < tSTR(1) || tSample(end) > tSTR(end)
            continue
        end
    
        etaMatrixSTR(i,:) = interp1(tSTR, xSTR, tSample, 'linear');
        keepSTR(i) = true;
    end
    
    etaMatrixSTR = etaMatrixSTR(keepSTR,:);
    
    
    % Event-triggered average
    etaHPC = mean(etaMatrixHPC, 1);
    etaHPC_sem = std(etaMatrixHPC, 0, 1) / sqrt(size(etaMatrixHPC,1)-1);
    etaSTR = mean(etaMatrixSTR, 1);
    etaSTR_sem = std(etaMatrixSTR, 0, 1) / sqrt(size(etaMatrixSTR,1)-1);
    
    
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
    plot(tWind, etaHPC, 'color', hpc_col(e,:), 'LineWidth', 2,...
        'DisplayName',events2plot{e});
    x = [tWind, fliplr(tWind)];
    y = [etaHPC + etaHPC_sem, fliplr(etaHPC - etaHPC_sem)];
    patch(x,y,hpc_col(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
    YL1 = ylim;
    % plot([0 0], YL1,'-k','LineWidth',0.5);
    xlabel('Time from event (s)');
    ylabel(ylab);
    title(sprintf('Event-Triggered Average\nHPC DA'));
    grid on;
    legend();
    
    nexttile(2); hold on;
    plot(tWind, etaSTR, 'color', str_col(e,:), 'LineWidth', 2,...
        'DisplayName',events2plot{e});
    x = [tWind, fliplr(tWind)];
    y = [etaSTR + etaSTR_sem, fliplr(etaSTR - etaSTR_sem)];
    patch(x,y,str_col(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
    YL2 = ylim;
    % plot([0 0], YL2,'-k','LineWidth',0.5);
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

%% Ripple Stats
pyrCh = bz_GetLFP(ripples.detectorinfo.detectionchannel);
ripLFP = bz_Filter(pyrCh.data,'passband',ripples.detectorinfo.detectionparms.passband);
[maps,data,stats] = bz_RippleStats(ripLFP, pyrCh.timestamps,ripples);
rippleStats = struct('maps',maps,'data',data','stats',stats);
[~,name,~] = fileparts(sessionPaths{sesh});
save(join([name,'.ripples.stats.mat']),"rippleStats");
%%
% ripple peaks
f1 = figure(10); clf; hold on;
f1.Units = 'normalized';
f1.Position = [0 0.05 1 0.865];
tiledlayout(5,12,'TileSpacing','tight','Padding','compact');
sgtitle(sprintf('%s',name),'Interpreter','none');

% >>>
nexttile(1, [1 2]); hold on;
IRI1 = ripples.timestamps(2:end,1) - ripples.timestamps(1:end-1,2);
IRI1a = rmoutliers(IRI1);
histogram(IRI1a,50,'DisplayName','mine')

IRI2 = diff(ripples.timestamps(:,1));
IRI2a = rmoutliers(IRI2);
histogram(IRI2a,50,'DisplayName','lab')

xlabel('Inter-Ripple Interval (s)')
ylabel('SWR counts')
legend('location','northeast')

% >>>
nexttile(13, [1 2]); hold on;
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


peakAmp_avg = [mean(data.peakAmplitude(rippleBurst.solos)),...
                mean(data.peakAmplitude(rippleBurst.duos)),...
                mean(data.peakAmplitude(rippleBurst.trios));...
            mean(data.peakAmplitude(rippleBurst.first & rippleBurst.duos)),...
                mean(data.peakAmplitude(rippleBurst.second & rippleBurst.duos)),...
                nan;...
            mean(data.peakAmplitude(rippleBurst.first & rippleBurst.trios)),...
                mean(data.peakAmplitude(rippleBurst.second & rippleBurst.trios)),...
                mean(data.peakAmplitude(rippleBurst.third & rippleBurst.trios))];

peak_sem = [std(ripples.peaks(rippleBurst.solos)) / sqrt(sum(rippleBurst.solos)),...
            std(ripples.peaks(rippleBurst.duos)) / sqrt(sum(rippleBurst.duos)),...
            std(ripples.peaks(rippleBurst.trios)) / sqrt(sum(rippleBurst.trios))];
% labels = {'solos','duos','trios','first in duos','second in duos'};
% bar(labels,peakAmp_avg);













