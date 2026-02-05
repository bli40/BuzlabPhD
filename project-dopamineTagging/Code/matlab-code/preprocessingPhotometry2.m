%% Load Data Directory and filenames
clear all;
close all;
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
sesh = 4;

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

%% Sync Pre-Processed Photometry Data

overwrite = true;
dryrun = false;
clc;
if dryrun
    fprintf('Starting DRY-RUN!\n');
else
    fprintf('Starting Synchronization!\n');
end

for sp = 1:numel(sessionPaths)
    [~,session,~] = fileparts(sessionPaths{sp});
    fprintf(2,'<strong>Syncing %s\n</strong>',session);
    photometryDataPaths = dir(fullfile(sessionPaths{sp},'*\*_new_photometry.mat'));
    if numel(photometryDataPaths) == 0
        fprintf('There are no photometry.mat files to process.\nPlease run preprocessingPhotometry1.py first!\n')
        return;
    end
    intanDataPaths = fullfile(sessionPaths{sp},'digitalin.dat');
    for e = 1:numel(photometryDataPaths)
        fprintf('\t<strong>Epoch</strong> - %s\n',photometryDataPaths(e).name);
        filename = fullfile(photometryDataPaths(e).folder,photometryDataPaths(e).name);
        [filepath,name,ext] = fileparts(filename);
        savefile = join([filepath,'\',name,'_sync',ext]);
        shortname = split(savefile,'\');
        shortname = join(['*\',fullfile(shortname{end-2:end})]);
        if isfile(savefile) 
            fprintf('\tAlready exists!\n\t%s\n',shortname')
            if overwrite
                fprintf('\t-> Overwriting...\n');
            else
                fprintf('\t-> Skipping...\n');
                continue;
            end
        else
            fprintf('\tSaving to: %s\n',shortname)
        end
        
        if dryrun == false
            load(filename);
            syncPhotometry = byl_getSyncPhotometry(photometryData, intanDataPaths);
            save(savefile,"syncPhotometry");
        end
        fprintf("\t\tfile %d/%d done.\n",e,numel(photometryDataPaths));
    end

end
if dryrun
    fprintf('DRY-RUN complete!\n');
else
    fprintf('Synchronization complete!\n');
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
F1.Units = 'normalized';
F1.Position = [0 0.05 1 0.865];

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
plot(sleep1_hpc_sync.timestamps(sleep1_hpc_sync.syncpulseOnOff(:,1)), ...
    zeros(numel(sleep1_hpc_sync.syncpulseOnOff(:,1),1)), ...
    'k|','HandleVisibility','off');
plot(behav1_hpc_sync.timestamps(behav1_hpc_sync.syncpulseOnOff(:,1)), ...
    zeros(numel(behav1_hpc_sync.syncpulseOnOff(:,1),1)), ...
    'k|','HandleVisibility','off');
plot(sleep2_hpc_sync.timestamps(sleep2_hpc_sync.syncpulseOnOff(:,1)), ...
    zeros(numel(sleep2_hpc_sync.syncpulseOnOff(:,1),1)), ...
    'k|','HandleVisibility','off');
legend()
xlabel('time (s)')
title('HPC DA (synced)')

subplot(2,3,[5 6]);  hold on;
plot(sleep1_str_sync.timestamps, sleep1_str_sync.grabDA_z,'DisplayName','sleep1')
plot(behav1_str_sync.timestamps, behav1_str_sync.grabDA_z,'DisplayName','behav1')
plot(sleep2_str_sync.timestamps, sleep2_str_sync.grabDA_z,'DisplayName','sleep2')
plot(sleep1_str_sync.timestamps(sleep1_str_sync.syncpulseOnOff(:,1)), ...
    zeros(numel(sleep1_str_sync.syncpulseOnOff(:,1),1)), ...
    'k|','HandleVisibility','off');
plot(behav1_str_sync.timestamps(behav1_str_sync.syncpulseOnOff(:,1)), ...
    zeros(numel(behav1_str_sync.syncpulseOnOff(:,1),1)), ...
    'k|','HandleVisibility','off');
plot(sleep2_str_sync.timestamps(sleep2_str_sync.syncpulseOnOff(:,1)), ...
    zeros(numel(sleep2_str_sync.syncpulseOnOff(:,1),1)), ...
    'k|','HandleVisibility','off');
legend()
ylabel('DA (z-scored)')
xlabel('time (s)')
title('STR DA (synced)')


%% Load Data for Concatenation
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
disp('Ready to concatenate.')
%% Concatenate Photometry files
disp('Concatenating hippocampal data ...')

% >>>>>>> hippocampus data <<<<<<<
sampling_rate = 130;

% >>>>>>>
stimpulseOnOff = [sleep1_hpc.stimulusOnOff,...
              behav1_hpc.stimulusOnOff + numel(sleep1_hpc.timestamps),...
              sleep2_hpc.stimulusOnOff + numel(sleep1_hpc.timestamps) + numel(behav1_hpc.timestamps)]';

% >>>>>>>
syncpulseOnOff = [sleep1_hpc.syncpulseOnOff;...
                 behav1_hpc.syncpulseOnOff + numel(sleep1_hpc.timestamps);...
                 sleep2_hpc.syncpulseOnOff + numel(sleep1_hpc.timestamps) + numel(behav1_hpc.timestamps)];

% >>>>>>>
highLowStim = [sleep1_hpc.highLowStim, ...
           behav1_hpc.highLowStim, ...
           sleep2_hpc.highLowStim]';

% >>>>>>>
highLowSync = [sleep1_hpc.highLowSync, ...
           behav1_hpc.highLowSync, ...
           sleep2_hpc.highLowSync]';

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
                                    "stimpulseOnOff", stimpulseOnOff, ...
                                    "syncpulseOnOff", syncpulseOnOff, ...
                                    "highLowStim", highLowStim, ...
                                    "highLowSync", highLowSync, ...
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
    disp("saved and done.")
end

disp('Concatenating striatal data ...')

% >>>>>>> striatum data <<<<<<<
sampling_rate = 130;

% >>>>>>>
stimpulseOnOff = [sleep1_str.stimpulseOnOff,...
              behav1_str.stimpulseOnOff + numel(sleep1_str.timestamps),...
              sleep2_str.stimpulseOnOff + numel(sleep1_str.timestamps) + numel(behav1_str.timestamps)]';

% >>>>>>>
syncpulseOnOff = [sleep1_str.syncpulseOnOff;...
                 behav1_str.syncpulseOnOff + numel(sleep1_str.timestamps);...
                 sleep2_str.syncpulseOnOff + numel(sleep1_str.timestamps) + numel(behav1_str.timestamps)];

% >>>>>>>
highLowStim = [sleep1_str.highLow, ...
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
                                    "stimpulseOnOff", stimpulseOnOff, ...
                                    "syncpulseOnOff", syncpulseOnOff, ...
                                    "highLowStim", highLowStim, ...
                                    "highLowSync", highLowSync, ...
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
    disp("saved and done.")
end
cd(sessionPaths{sesh});
