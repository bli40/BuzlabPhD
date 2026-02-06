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
sesh = 4;

[hasConc, hasSync, hasMat, numEpochs] = deal(zeros(size(directory,1),1));
whichRegions = cell(size(directory,1),1);
verbose = false;

for s = 1:numel(sessionPaths)
    preprocessedPaths = dir(fullfile(sessionPaths{s},'\*.photometry.*.sync.conc.mat'));
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
    regions = unique(extractBefore({syncPhotometryPaths.name}, '-'));
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
cd(sessionPaths{sesh});

fileTable = table(hasConc, hasSync, hasMat, whichRegions, numEpochs, ...
    'VariableNames',{'hasConc','hasSync','hasMat','whichRegions','numEpochs'});

%% Sync Pre-Processed Photometry Data

overwrite = false;
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
for sp = 15:numel(sessionPaths)
    photometryDataPaths = dir(fullfile(sessionPaths{sp},'*\*_new_photometry.mat'));
    syncPhotometryPaths = dir(fullfile(sessionPaths{sp},'*\*_new_photometry_sync.mat'));

    regions = fileTable.whichRegions{sp};
    numRegions = numel(regions);

    epochFolders = string({photometryDataPaths.folder});
    [~,epochFolders,~] = fileparts(epochFolders);
    [~,~,epochIdx] = unique(epochFolders, 'stable');
    
    [syncArray,unsyncArray] = deal(cell(numRegions, fileTable.numEpochs(sp)));

    for k = 1:numel(photometryDataPaths)
        fname = photometryDataPaths(k).name;
        reg = extractBefore(fname,'-');
        r = strcmp(regions, reg);
        c = epochIdx(k);
        unsyncArray{r,c} = load(fullfile(photometryDataPaths(k).folder,fname));
    end

    fprintf('Unsynced Data Loaded.\n')
    
    for k = 1:numel(syncPhotometryPaths)
        fname = syncPhotometryPaths(k).name;
        reg = extractBefore(fname,'-');
        r = strcmp(regions, reg);
        c = epochIdx(k);
        syncArray{r,c} = load(fullfile(syncPhotometryPaths(k).folder,fname));
    end
    fprintf('Synced Data Loaded.\n')
    
    F1 = figure(sp); clf; hold on;
    F1.Units = 'normalized';
    F1.Position = [0 0.05 1 0.865];
    
    TL = split(sessionPaths{sp},'\');
    TL = strrep(TL{end},'_',' ');
    
    sgtitle(sprintf('%s',TL));
    
    headings = {'HPC DA (unsynced)', 'HPC DA (synced)'; ...
                'STR DA (unsynced)', 'STR DA (synced)'};
    
    for re = 1:size(syncArray,1)
        
        subplot(size(syncArray,1),3,(1+(re-1)*size(syncArray,2)));  hold on;
        h1 = gobjects(size(syncArray,2),1);
        for ep = 1:size(syncArray,2)
            if numel(unsyncArray{re,ep}) == 0
                continue;
            else
                h1(ep) = plot(unsyncArray{re,ep}.photometryData.timestamps, ...
                              unsyncArray{re,ep}.photometryData.grabDA_z, ...
                              'DisplayName',sprintf('epoch %i',ep));
                            end
        end
        lgd = legend();
        lgd.ItemHitFcn = @(src,event) bringToFront(event, h1);    ylabel('DA (z-scored)')
        xlabel('time (s)')
        title(sprintf('%s DA (unsynced)',extractAfter(extractBefore(photometryDataPaths(re).name,'-'),'_')))
        
        subplot(size(syncArray,1),3,([2 3]+(re-1)*size(syncArray,2)));  hold on;
        h2 = gobjects(size(syncArray,2),1);
        for ep = 1:size(syncArray,2)
            if numel(syncArray{re,ep}) == 0
                continue;
            else
                h2(ep) = plot(syncArray{re,ep}.syncPhotometry.timestamps, ...
                              syncArray{re,ep}.syncPhotometry.grabDA_z, ...
                              'DisplayName',sprintf('epoch %i',ep));
            end
        end
        lgd = legend();
        lgd.ItemHitFcn = @(src,event) bringToFront(event, h2);    ylabel('DA (z-scored)')   
        xlabel('time (s)')
        title(sprintf('%s DA (synced)',extractAfter(extractBefore(syncPhotometryPaths(re).name,'-'),'_')))
    end
end

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
regions = [sleep1_hpc.timestamps(1), sleep1_hpc.timestamps(end); ...
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
                                    "epochs", regions, ...
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
regions = [sleep1_str.timestamps(1), sleep1_str.timestamps(end); ...
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
                                    "epochs", regions, ...
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
