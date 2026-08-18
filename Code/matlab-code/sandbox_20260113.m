%% Load Data and Check if Preprocessing is Complete
clear all;
close all;
directory = readtable('C:\Users\Gergely\Documents\Brian\DA-Tagging-Project\Data\data-directory.xlsx');
sessions2analyze = logical(directory.Use);
animals2analyze = strcmp(directory.Mouse,'N17');
sessionPaths = directory.Path(sessions2analyze & animals2analyze);
disp(sessionPaths);
sesh = 1;

for s = 1:numel(sessionPaths)
    preprocessedPaths = dir(fullfile(sessionPaths{s},'\*.photometry.*.sync.conc.mat'));
    [~,name,~] = fileparts(sessionPaths{s});
    fprintf('<strong>%d) %s has %d</strong> synchronized and concatenated photometry files:\n',s,name,numel(preprocessedPaths))
    for e = 1:numel(preprocessedPaths)
        sessionName = split(preprocessedPaths(e).name,'.');
        fprintf(2,'<strong>\t%s\n</strong>',sessionName{3})
    end
end

%% Sync Pre-Processed Photometry Data
addpath('C:\Users\Gergely\Documents\Brian\DA-Tagging-Project\Code\');
photometryDataPaths = dir(fullfile(sessionPaths{sesh},'*\*_new_photometry.mat'));
intanDataPaths = fullfile(sessionPaths{sesh},'digitalin.dat');
for e = 1:numel(photometryDataPaths)
    filename = fullfile(photometryDataPaths(e).folder,photometryDataPaths(e).name);
    [filepath,name,ext] = fileparts(filename);
    savefile = join([filepath,'\',name,'_sync',ext]);
    if isfile(savefile)
        fprintf('Already exists! \n\tSkipping %s .\n',savefile)
        continue;
    else
        fprintf('Saving to: %s\n',savefile)
    end

    load(filename);
    syncPhotometry = getSyncPhotometry(photometryData, intanDataPaths);
    save(savefile,"syncPhotometry");
    fprintf("file %d/%d done...\n",e,numel(photometryDataPaths));
end

%% Check Synchronization
photometryDataPaths = dir(fullfile(sessionPaths{sesh},'*\*_new_photometry.mat'));
for e = 1:size(photometryDataPaths,1)
    filenames_unsync{e,1} = fullfile([photometryDataPaths(e).folder],[photometryDataPaths(e).name]);
end   

% unsync
load(filenames_unsync{1});
sleep1_hpc_unsync = photometryData;
load(filenames_unsync{2});
sleep1_str_unsync = photometryData;
load(filenames_unsync{3});
behav1_hpc_unsync = photometryData;
load(filenames_unsync{4});
behav1_str_unsync = photometryData;
load(filenames_unsync{5});
sleep2_hpc_unsync = photometryData;
load(filenames_unsync{6});
sleep2_str_unsync = photometryData;

syncPhotometryPaths = dir(fullfile(sessionPaths{sesh},'*\*_new_photometry_sync.mat'));
for e = 1:size(syncPhotometryPaths,1)
    filenames_sync{e,1} = fullfile([syncPhotometryPaths(e).folder],[syncPhotometryPaths(e).name]);
end

% sync
load(filenames_sync{1});
sleep1_hpc_sync = syncPhotometry;
load(filenames_sync{2});
sleep1_str_sync = syncPhotometry;
load(filenames_sync{3});
behav1_hpc_sync = syncPhotometry;
load(filenames_sync{4});
behav1_str_sync = syncPhotometry;
load(filenames_sync{5});
sleep2_hpc_sync = syncPhotometry;
load(filenames_sync{6});
sleep2_str_sync = syncPhotometry;


F1 = figure(10); clf; hold on;
F1.Position = [100 100 1500 800];

TL = split(sessionPaths{sesh},'\');
TL = strrep(TL{end},'_',' ');

sgtitle(sprintf('%s',TL));

subplot(2,3,1);  hold on;
h1 = gobjects(3,1);
h1(1) = plot(sleep1_hpc_unsync.timestamps, sleep1_hpc_unsync.grabDA_z,'DisplayName','sleep1');
h1(2) = plot(behav1_hpc_unsync.timestamps, behav1_hpc_unsync.grabDA_z,'DisplayName','behav1');
h1(3) = plot(sleep2_hpc_unsync.timestamps, sleep2_hpc_unsync.grabDA_z,'DisplayName','sleep2');
lgd = legend(h1);
lgd.ItemHitFcn = @(src,event) bringToFront(event, h1);    ylabel('DA (z-scored)')
xlabel('time (s)')
title('HPC DA (unsynced)')

subplot(2,3,4);  hold on;
h2 = gobjects(3,1);
h2(1) = plot(sleep1_str_unsync.timestamps, sleep1_str_unsync.grabDA_z,'DisplayName','sleep1');
h2(2) = plot(behav1_str_unsync.timestamps, behav1_str_unsync.grabDA_z,'DisplayName','behav1');
h2(3) = plot(sleep2_str_unsync.timestamps, sleep2_str_unsync.grabDA_z,'DisplayName','sleep2');
lgd = legend(h2);
lgd.ItemHitFcn = @(src,event) bringToFront(event, h2);    ylabel('DA (z-scored)')   
xlabel('time (s)')
title('STR DA (unsynced)')

subplot(2,3,[2 3]);  hold on;
plot(sleep1_hpc_sync.timestamps, sleep1_hpc_sync.grabDA_z,'DisplayName','sleep1')
plot(behav1_hpc_sync.timestamps, behav1_hpc_sync.grabDA_z,'DisplayName','behav1')
plot(sleep2_hpc_sync.timestamps, sleep2_hpc_sync.grabDA_z,'DisplayName','sleep2')
legend()
xlabel('time (s)')
title('HPC DA (synced)')

subplot(2,3,[5 6]);  hold on;
plot(sleep1_str_sync.timestamps, sleep1_str_sync.grabDA_z,'DisplayName','sleep1')
plot(behav1_str_sync.timestamps, behav1_str_sync.grabDA_z,'DisplayName','behav1')
plot(sleep2_str_sync.timestamps, sleep2_str_sync.grabDA_z,'DisplayName','sleep2')
legend()
ylabel('DA (z-scored)')
xlabel('time (s)')
title('STR DA (synced)')


%% Load Data for Concatenation
close all; 
clearvars -except sessionPaths sesh;
cd Z:\\Buzsakilabspace\LabShare\ZutshiI\patchTask\N17\N17_250511_sess17\

disp('Loading data for concatenation...')

syncPhotometryPaths = dir(fullfile(sessionPaths{sesh},'*\*_new_photometry_sync.mat'));
for e = 1:size(syncPhotometryPaths,1)
    filenames_sync{e,1} = fullfile([syncPhotometryPaths(e).folder],[syncPhotometryPaths(e).name]);
end

% sync
load(filenames_sync{1});
sleep1_hpc = syncPhotometry;
load(filenames_sync{2});
sleep1_str = syncPhotometry;
load(filenames_sync{3});
behav1_hpc = syncPhotometry;
load(filenames_sync{4});
behav1_str = syncPhotometry;
load(filenames_sync{5});
sleep2_hpc = syncPhotometry;
load(filenames_sync{6});
sleep2_str = syncPhotometry;

clear syncPhotometry

%% Concatenate Photometry files
disp('Concatenating hippocampal data ...')

% >>>>>>> hippocampus data <<<<<<<
sampling_rate = 130;

% >>>>>>>
barcodesOn = [sleep1_hpc.barcodesOn,...
              behav1_hpc.barcodesOn + numel(sleep1_hpc.timestamps),...
              sleep2_hpc.barcodesOn + numel(sleep1_hpc.timestamps) + numel(behav1_hpc.timestamps)]';

% >>>>>>>
barcodesOnOff = [sleep1_hpc.barcodesOnOff;...
                 behav1_hpc.barcodesOnOff + numel(sleep1_hpc.timestamps);...
                 sleep2_hpc.barcodesOnOff + numel(sleep1_hpc.timestamps) + numel(behav1_hpc.timestamps)];

% >>>>>>>
highLow = [sleep1_hpc.highLow, ...
           behav1_hpc.highLow, ...
           sleep2_hpc.highLow]';

% >>>>>>>
timestamps = [sleep1_hpc.timestamps;...
              behav1_hpc.timestamps;...
              sleep2_hpc.timestamps];

% >>>>>>>
grabDA_z = [sleep1_hpc.grabDA_z;...
            behav1_hpc.grabDA_z;...
            sleep2_hpc.grabDA_z];

% >>>>>>>
grabDA_df = [sleep1_hpc.grabDA_df;...
             behav1_hpc.grabDA_df;...
             sleep2_hpc.grabDA_df];

% >>>>>>>
grabDA_raw = [sleep1_hpc.grabDA_raw;...
              behav1_hpc.grabDA_raw;...
              sleep2_hpc.grabDA_raw];

% >>>>>>>
epochs = [sleep1_hpc.timestamps(1), sleep1_hpc.timestamps(end); ...
    behav1_hpc.timestamps(1), behav1_hpc.timestamps(end); ...
    sleep2_hpc.timestamps(1) sleep2_hpc.timestamps(end)];

% >>>>>>>
epochNames = ["sleep_1"; "behav_1"; "sleep_2"];

photometry_HPC_sync_concat = struct("sampling_rate", sampling_rate, ...
                                    "barcodesOn", barcodesOn, ...
                                    "barcodesOnOff", barcodesOnOff, ...
                                    "highLow", highLow, ...
                                    "timestamps", timestamps, ...
                                    "grabDA_z", grabDA_z, ...
                                    "grabDA_df", grabDA_df, ...
                                    "grabDA_raw", grabDA_raw, ...
                                    "epochs", epochs, ...
                                    "epochNames", epochNames);
[~,name,~] = fileparts(sessionPaths{sesh});
savepath = fullfile(sessionPaths{sesh},join([name, '.photometry.HPC.sync.conc.mat'],''));
if isfile(savepath)
    fprintf('Already exists! \n\t Skipping %s\n',savepath);
else
    save(savepath, "photometry_HPC_sync_concat");
    disp("...saved and done")
end

disp('Concatenating striatal data ...')

% >>>>>>> striatum data <<<<<<<
sampling_rate = 130;

% >>>>>>>
barcodesOn = [sleep1_str.barcodesOn,...
              behav1_str.barcodesOn + numel(sleep1_str.timestamps),...
              sleep2_str.barcodesOn + numel(sleep1_str.timestamps) + numel(behav1_str.timestamps)]';

% >>>>>>>
barcodesOnOff = [sleep1_str.barcodesOnOff;...
                 behav1_str.barcodesOnOff + numel(sleep1_str.timestamps);...
                 sleep2_str.barcodesOnOff + numel(sleep1_str.timestamps) + numel(behav1_str.timestamps)];

% >>>>>>>
highLow = [sleep1_str.highLow, ...
           behav1_str.highLow, ...
           sleep2_str.highLow]';

% >>>>>>>
timestamps = [sleep1_str.timestamps;...
              behav1_str.timestamps;...
              sleep2_str.timestamps];

% >>>>>>>
grabDA_z = [sleep1_str.grabDA_z;...
            behav1_str.grabDA_z;...
            sleep2_str.grabDA_z];

% >>>>>>>
grabDA_df = [sleep1_str.grabDA_df;...
             behav1_str.grabDA_df;...
             sleep2_str.grabDA_df];

% >>>>>>>
grabDA_raw = [sleep1_str.grabDA_raw;...
              behav1_str.grabDA_raw;...
              sleep2_str.grabDA_raw];

% >>>>>>>
epochs = [sleep1_str.timestamps(1), sleep1_str.timestamps(end); ...
    behav1_str.timestamps(1), behav1_str.timestamps(end); ...
    sleep2_str.timestamps(1) sleep2_str.timestamps(end)];

% >>>>>>>
epochNames = ["sleep_1"; "behav_1"; "sleep_2"];

photometry_STR_sync_concat = struct("sampling_rate", sampling_rate, ...
                                    "barcodesOn", barcodesOn, ...
                                    "barcodesOnOff", barcodesOnOff, ...
                                    "highLow", highLow, ...
                                    "timestamps", timestamps, ...
                                    "grabDA_z", grabDA_z, ...
                                    "grabDA_df", grabDA_df, ...
                                    "grabDA_raw", grabDA_raw, ...
                                    "epochs", epochs, ...
                                    "epochNames", epochNames);
[~,name,~] = fileparts(sessionPaths{sesh});
savepath = fullfile(sessionPaths{sesh},join([name, '.photometry.STR.sync.conc.mat'],''));
if isfile(savepath)
    fprintf('Already exists! \n\t Skipping %s\n',savepath);
else
    save(savepath, "photometry_STR_sync_concat");
    disp("...saved and done")
end
cd(sessionPaths{sesh});

%% Initialize
close all;
clearvars -except sessionPaths sesh
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

d = (dir(fullfile('N*.SleepState.states.mat')));
load(fullfile(d(1).folder, d(1).name))

d = (dir(fullfile('N*.photometry.HPC.sync.conc.mat')));
load(fullfile(d(1).folder, d(1).name))

d = (dir(fullfile('N*.photometry.STR.sync.conc.mat')));
load(fullfile(d(1).folder, d(1).name))

d = (dir(fullfile('N*.MergePoints.events.mat')));
load(fullfile(d(1).folder, d(1).name))

%% Find Ripples - Solos and Bursts
firstPass = ripples.timestamps;

% Merge ripples if inter-ripple period is too short <- from bz_FindRipples
disp(['Before ripple cluster merge: ' num2str(length(firstPass)) ' events.'])
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
	disp('Ripple cluster merge failed');
	return
else
	disp(['After ripple cluster merge: ' num2str(length(secondPass)) ' events.']);
end
solos = intersect(firstPass, secondPass, 'rows');
bursts = setdiff(secondPass, firstPass, 'rows');

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

%% Test Against Lucy's Synced Behavior
% This is now fixed. My sync initially did two things wrong. (1) I was using the per-session
% digitalin.mat rather than the whole day's digitalin.mat (in the parent
% directory. (2) I had ported the sync pulse to the 'syncpulseOnOff' field
% while Lucy had it in the "barcodesOnOff" field. I am now using that field
% for the stimulation times. Will consider renaming it...

% clear all; close all;

% unsync
load N17_250511_141119\N17_HPC-2025-05-11-141123_photometry.mat
behav1_hpc_u = photometryData;
load N17_250511_141119\N17_striatum-2025-05-11-141123_photometry.mat
behav1_striatum_u = photometryData;
clear photometryData

% my sync
load N17_250511_141119\N17_HPC-2025-05-11-141123_photometry_sync.mat
behav1_hpc = syncPhotometry;
load N17_250511_141119\N17_striatum-2025-05-11-141123_photometry_sync.mat
behav1_str = syncPhotometry;
clear syncPhotometry

% Lucy's Sync
load N17_250511_sess17.PhotometryBehavStriatum.mat
load N17_250511_sess17.PhotometryBehavHPC.mat
% photometry_STR_sync_concat = photometry_striatum;
% Photometry_HPC_sync_concat = photometry_hpc;

F1 = figure(10); clf; hold on;
F1.Position = [500 500 1000 800];
subplot(2,1,1);  hold on;
plot(behav1_hpc_u.timestamps, behav1_hpc_u.grabDA_df,'DisplayName','unsynced')
plot(behav1_hpc.timestamps, behav1_hpc.grabDA_df,'DisplayName','my sync')
plot(photometry_hpc.timestamps, photometry_hpc.grabDA_df,'DisplayName','Lucy sync')
legend()

subplot(2,1,2);  hold on;
plot(behav1_striatum_u.timestamps, behav1_striatum_u.grabDA_df,'DisplayName','unsynced')
plot(behav1_str.timestamps, behav1_str.grabDA_df,'DisplayName','my sync')
plot(photometry_striatum.timestamps, photometry_striatum.grabDA_df,'DisplayName','Lucy sync')
legend()





%% Event-Triggered Averages of DA Traces in HPC and Striatum
% This is not as good as using time-space (this is in index-space) since
% the concatenation still results in jumps in timestamp between the epochs.
% interpolating the data with a pre-defined window at a particular sample
% rate around each event handles this without needing the pad/insert nans
% into the data.

% Parameters
fs = 130;           % LFP sampling rate (Hz)
pre  = 1;           % seconds before spike
post = 1;           % seconds after spike
event = 'stim';     % ripple, nosepoke, rewarded poke, unrewarded poke

% Convert window to samples
preSamp  = round(pre  * fs);
postSamp = round(post * fs);

winLength = preSamp + postSamp + 1;

% Convert event times to sample indices
switch lower(event)
    case "ripple"
        eventSamples_hpc = round(ripples.timestamps(:,1) * fs);
        eventSamples_str = round(ripples.timestamps(:,1) * fs);
    case "stim"
        eventSamples_hpc = round(photometry_HPC_sync_concat.timestamps(photometry_HPC_sync_concat.barcodesOn) * fs);
        eventSamples_str = round(photometry_STR_sync_concat.timestamps(photometry_STR_sync_concat.barcodesOn) * fs);
    case "nosepoke"
        eventSamples_hpc = round(behavTrials.timestamps * fs);
        eventSamples_str = round(behavTrials.timestamps * fs);
    case "rewarded poke"
        eventSamples_hpc = round(behavTrials.timestamps(logical(behavTrials.reward_outcome)) * fs);
        eventSamples_str = round(behavTrials.timestamps(logical(behavTrials.reward_outcome)) * fs);
    case "unrewarded poke"
        eventSamples_hpc = round(behavTrials.timestamps(~logical(behavTrials.reward_outcome)) * fs);
        eventSamples_str = round(behavTrials.timestamps(~logical(behavTrials.reward_outcome)) * fs);
end
% Remove spikes too close to edges
validEvents_hpc = eventSamples_hpc(eventSamples_hpc > preSamp & ...
                           eventSamples_hpc <= length(photometry_HPC_sync_concat.grabDA_df) - postSamp);
validEvents_str = eventSamples_str(eventSamples_str > preSamp & ...
                           eventSamples_str <= length(photometry_STR_sync_concat.grabDA_df) - postSamp);

% Preallocate
etaMatrixHPC = zeros(length(validEvents_hpc), winLength);
etaMatrixSTR = zeros(length(validEvents_str), winLength);

% Extract grabDA dF/F snippets
for i = 1:length(validEvents_hpc)
    idx = validEvents_hpc(i);
    etaMatrixHPC(i,:) = photometry_HPC_sync_concat.grabDA_df(idx - preSamp : idx + postSamp);

end
for i = 1:length(validEvents_str)
    idx = validEvents_str(i);
    etaMatrixSTR(i,:) = photometry_STR_sync_concat.grabDA_df(idx - preSamp : idx + postSamp);

end

% Event-triggered average
etaHPC = mean(etaMatrixHPC, 1);
etaHPC_sem = std(etaMatrixHPC, 0, 1);
etaSTR = mean(etaMatrixSTR, 1);
etaSTR_sem = std(etaMatrixSTR, 0, 1);



% Time axis
t = (-preSamp:postSamp) / fs;

% Plot
figure(100); clf; 
subplot(1,2,1); hold on;
x = [t, fliplr(t)];
y = [etaHPC + etaHPC_sem, fliplr(etaHPC - etaHPC_sem)];

plot(t, etaHPC, 'r', 'LineWidth', 2);
xlabel('Time (s)');
ylabel('dF / F');
title(sprintf('%s-Triggered Average\nHPC DA', event));
grid on;

subplot(1,2,2); hold on;
x = [t, fliplr(t)];
y = [etaSTR + etaSTR_sem, fliplr(etaSTR - etaSTR_sem)];

plot(t, etaSTR, 'b', 'LineWidth', 2)
xlabel('Time (s)');
ylabel('dF / F');
title(sprintf('%s-Triggered Average\nSTR DA', event));
grid on;

%% ETA but in time not index space

% Lucy's Sync
% load N17_250511_sess17.PhotometryBehavStriatum.mat
% load N17_250511_sess17.PhotometryBehavHPC.mat
% photometry_STR_sync_concat = photometry_striatum;
% Photometry_HPC_sync_concat = photometry_hpc;

% Parameters
fs = 130;           % LFP sampling rate (Hz)
pre  = 5;           % seconds before spike
post = 5;           % seconds after spike
events2plot = {'bursts', 'solos'};     
% events2plot = {'stims','nosepokes'};
% events2plot = {'unrewarded pokes', 'rewarded pokes'};
traces2pull = {'z-score'};      % z-score, dF/F

% Define relative time axis (not samples)
tWind = -pre : 1/fs : post;
winLength = numel(tWind);

% stack plots or not
stack = true;

% create color scheme
red = autumn(3);
blue = winter(3);

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
        case "nosepokes"
            eventTimes_hpc = behavTrials.timestamps;
            eventTimes_str = behavTrials.timestamps;
        case "rewarded pokes"
            eventTimes_hpc = behavTrials.timestamps(logical(behavTrials.reward_outcome));
            eventTimes_str = behavTrials.timestamps(logical(behavTrials.reward_outcome));
        case "unrewarded pokes"
            eventTimes_hpc = behavTrials.timestamps(~logical(behavTrials.reward_outcome));
            eventTimes_str = behavTrials.timestamps(~logical(behavTrials.reward_outcome));
        case "solos"
            eventTimes_hpc = solos(:,1);
            eventTimes_str = solos(:,1);
        case "bursts"
            eventTimes_hpc = bursts(:,1);
            eventTimes_str = bursts(:,1);
        otherwise
            fprintf('%s is not a registered event type. Halting.\n',event);
            break;
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
    
    nexttile(1); hold on;
    plot(tWind, etaHPC, 'color', blue(e,:), 'LineWidth', 2,...
        'DisplayName',events2plot{e});
    x = [tWind, fliplr(tWind)];
    y = [etaHPC + etaHPC_sem, fliplr(etaHPC - etaHPC_sem)];
    patch(x,y,blue(e,:),'FaceAlpha', 0.5,'EdgeColor','none','DisplayName','SEM');
    YL1 = ylim;
    % plot([0 0], YL1,'-k','LineWidth',0.5);
    xlabel('Time from event (s)');
    ylabel(ylab);
    title(sprintf('Event-Triggered Average\nHPC DA'));
    grid on;
    legend();
    
    nexttile(2); hold on;
    plot(tWind, etaSTR, 'color', red(e,:), 'LineWidth', 2,...
        'DisplayName',events2plot{e});
    x = [tWind, fliplr(tWind)];
    y = [etaSTR + etaSTR_sem, fliplr(etaSTR - etaSTR_sem)];
    patch(x,y,red(e,:),'FaceAlpha', 0.5,'EdgeColor','none','DisplayName','SEM');
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


%% Time series analysis

fs = 130;
ts = photometry_HPC_sync_concat.timestamps;
x = photometry_HPC_sync_concat.grabDA_z;
wavelet = 'amor';
lof = 0.1;
hif = 15;
[c,f] = cwt(x,wavelet,fs,FrequencyLimits=[lof hif]);
imagesc(t,f,abs(c))

% [s,f,t] = stft(x,fs, Window=window, OverlapLength=noverlap, FFTLength=nfft);


%% >>> 
solo = rippleBurst.soloTimes(:,2) - rippleBurst.soloTimes(:,1);
duo = rippleBurst.burstTimes(rippleBurst.burstNum == 2,2) - rippleBurst.burstTimes(rippleBurst.burstNum == 2,1);
trio = rippleBurst.burstTimes(rippleBurst.burstNum == 3,2) - rippleBurst.burstTimes(rippleBurst.burstNum == 3,1);

data = photometry_HPC_sync_concat.grabDA_z;
times = photometry_HPC_sync_concat.timestamps;

etaSolo = byl_GetETA(rippleBurst.soloTimes(:,1),data,times,'frequency',130,'normalization','zscore');
etaDuo = byl_GetETA(rippleBurst.burstTimes(rippleBurst.burstNum == 2,1),data,times,'frequency',130,'normalization','zscore');
etaTrio = byl_GetETA(rippleBurst.burstTimes(rippleBurst.burstNum == 3,1),data,times,'frequency',130,'normalization','zscore');


%%
figure(1); clf; hold on;
plot(etaSolo.window, etaSolo.normAvg, 'Color',blue(1,:), 'LineWidth',2)
plot(etaDuo.window, etaDuo.normAvg, 'Color',blue(2,:), 'LineWidth',2)
plot(etaTrio.window, etaTrio.normAvg, 'Color',blue(3,:), 'LineWidth',2)

plot(etaSolo.window, etaSolo.avg, 'Color',red(1,:));
plot(etaDuo.window, etaDuo.avg, 'Color',red(2,:));
plot(etaTrio.window, etaTrio.avg, 'Color',red(3,:));

%%
perSolo = mean(etaSolo.chunks(:,etaSolo.window >= 1 & etaSolo.window <= 2),2);
perDuo = mean(etaDuo.chunks(:,etaDuo.window >= 1 & etaDuo.window <= 2),2);
perTrio = mean(etaTrio.chunks(:,etaTrio.window >= 1 & etaTrio.window <= 2),2);

figure(1); clf; hold on;
scatter(solo, perSolo, '.','color', blue(1,:))
scatter(duo, perDuo, '.','color', blue(2,:))
scatter(trio, perTrio, '.','color', blue(3,:))

%%

for r = 1:size(etaDuo.chunks,1)
    figure(2); clf; hold on;
    plot(etaDuo.window, etaDuo.chunks(r,:),'b')
    plot(etaDuo.window, etaDuo.normChunks(r,:),'r');
    pause;
end

%%
data = photometry_HPC_sync_concat.grabDA_z;
events = struct();
fs = 130;
events(1).times = ripples.timestamps(rippleBurst.solos,1);
events(1).label = 'solos';
events(1).color = blue(1,:);

events(2).times = ripples.timestamps(rippleBurst.duos,1);
events(2).label = 'duos';
events(2).color = blue(2,:);

events(3).times = ripples.timestamps(rippleBurst.trios,1);
events(3).label = 'trios';
events(3).color = blue(3,:);

photometryScrollerMulti(data, fs, events, 30)

%% >> ripple rate around nosepokes
% f1 = figure(10);
% nexttile(59,[2 2]); cla; hold on;
% dt = 1/130;
% time = photometry_HPC_sync_concat.timestamps;
% rips = histcounts(ripples.timestamps(:,1), [time; time(end)+dt]) / dt;
% 
% sigma = 1; % seconds
% tk = -4*sigma:dt:4*sigma;
% g = exp(-tk.^2/(2*sigma^2));
% g = g / sum(g*dt); 
% rate_smooth = conv(rips, g, 'same');
% 
% events2plot = {'rewarded','unrewarded'};
% events = {behavTrials.timestamps(logical(behavTrials.reward_outcome)),...
%           behavTrials.timestamps(~logical(behavTrials.reward_outcome))};
% data = rate_smooth;
% timestamps = photometry_HPC_sync_concat.timestamps;
% for e = 1:numel(events)  
%     etaHPC = byl_GetETA(events{e},data,timestamps,'frequency',130);
% 
%     % Plot
%     plot(etaHPC.window, etaHPC.avg, 'color', purple(e,:), 'LineWidth', 2,...
%         'DisplayName',events2plot{e});
%     x = [etaHPC.window, fliplr(etaHPC.window)];
%     y = [etaHPC.avg + etaHPC.sem, fliplr(etaHPC.avg - etaHPC.sem)];
%     patch(x,y,purple(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');
% 
% 
% end
% xlabel('Time from event (s)');
% ylabel('Fluorescence (z-score');
% title(sprintf('Poke/Stim-Triggered Average\nHPC DA (behavior)'));
% grid on;
% legend('location','best');
% set(gca,'children',flipud(get(gca,'children')))












