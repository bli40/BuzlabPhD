%% Load Data Directory and Check Preprocessing Progress
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
verbose = true;

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
        regName = unique(extractBefore({epochsDataPaths.name}, '-'));
        for i = 1:numel(regions)
            fprintf('\t%s - %i files ready to <strong>preprocess</strong>.\n', regName{i}, sum(contains(upper({epochsDataPaths.name}),regions{i})));
            fprintf('\t\t%s\n',epochsDataPaths(contains(upper({epochsDataPaths.name}),regions{i})).name);
        end
    end
end

fileTable = table(hasConc, hasSync, hasMat, whichRegions, numEpochs, ...
    'VariableNames',{'hasConc','hasSync','hasMat','whichRegions','numEpochs'});

%% Sync Pre-Processed Photometry Data
sesh = 26;
cd(sessionPaths{sesh});

overwrite = false;
dryrun = false;
clc;
if dryrun
    fprintf('Starting DRY-RUN!\n');
else
    fprintf('Starting Synchronization!\n');
end
tic;
for sp = 27:28%1:numel(sessionPaths)
    [~,session,~] = fileparts(sessionPaths{sp});
    fprintf(2,'<strong>Syncing %s\n</strong>',session);
    photometryDataPaths = dir(fullfile(sessionPaths{sp},'*\*_new_photometry.mat'));
    if numel(photometryDataPaths) == 0
        fprintf('There are no photometry.mat files to process.\nPlease run preprocessingPhotometry1.py first!\n')
        return;
    end
    intanDataPaths = fullfile(sessionPaths{sp},'digitalin.dat');
    if ~isfile(intanDataPaths)
        intanDataPaths = dir(fullfile(sessionPaths{sp},'*\digitalin.dat'));
        intanDataPaths = fullfile(intanDataPaths.folder, intanDataPaths.name);
        if ~isfile(intanDataPaths)
            fprintf(2,'No digitalin.dat file found!!');
        end
    end
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
                fprintf('\t--> Overwriting...\n');
            else
                fprintf('\t--> Skipping...\n');
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
toc;
%% Check Synchronization
%{
parpool(8);

parfor sp = 1:numel(sessionPaths)
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
%}

%% Concatenate
overwrite = true;

disp('Loading data for concatenation...')
epochNames = {'sleep_1','behav_1','sleep_2'};
for sp = 25:28%1:numel(sessionPaths)
    preprocessedPaths = dir(fullfile(sessionPaths{sp},'\*.photometry.*.mat'));
    if ~isempty(preprocessedPaths) && overwrite
        fprintf('%d) Full photometry file exists. Overwriting.\n',sp);
    elseif ~isempty(preprocessedPaths) && ~ overwrite
        fprintf('%d) Full photometry file exists. Skipping.\n',sp);
        continue;
    end

    syncPhotometryPaths = dir(fullfile(sessionPaths{sp},'*\*_new_photometry_sync.mat'));

    regions = fileTable.whichRegions{sp};
    numRegions = numel(regions);

    epochFolders = string({syncPhotometryPaths.folder});
    [~,epochFolders,~] = fileparts(epochFolders);
    [~,~,epochIdx] = unique(epochFolders, 'stable');
    numEpochs = numel(epochIdx);

    syncArray = cell(numRegions, fileTable.numEpochs(sp));
  
    for k = 1:numel(syncPhotometryPaths)
        fname = syncPhotometryPaths(k).name;
        [~,fdir,~] = fileparts(syncPhotometryPaths(k).folder);
        reg = upper(extractAfter(extractBefore(fname,'-'),'_'));
        reg = reg(1:3);
        r = contains(regions, reg);
        c = epochIdx(k);
        syncArray{r,c} = load(fullfile(syncPhotometryPaths(k).folder,fname));
    end
    fprintf('\tSynchronized Data Loaded.\n')

    clear syncPhotometry
    fprintf('\tReady to concatenate.\n')

    whichFiles = ~cellfun(@isempty, syncArray);
    fields = fieldnames(syncArray{find(whichFiles,1,'first')}.syncPhotometry);

    for re = 1:numRegions
        cells = syncArray(re,:);
        cells = cells(~cellfun(@isempty, cells));
        structs = [cells{:}];
        structs = [structs.syncPhotometry];

        for f = 1:numel(fields)
            fn = fields{f};
            try
                concPhotom.(fn) = vertcat(structs.(fn));
            catch
                concPhotom.(fn) = horzcat(structs.(fn));
            end
        end
        % --- interpolate to regularize timestamps
        concPhotom.sampling_rate = double(unique(concPhotom.sampling_rate));
        ts = concPhotom.timestamps(1) : 1/concPhotom.sampling_rate : concPhotom.timestamps(end);
        concPhotom.grabDA_df  = interp1(concPhotom.timestamps, concPhotom.grabDA_df, ts);
        concPhotom.grabDA_z   = interp1(concPhotom.timestamps, concPhotom.grabDA_z,  ts);
        concPhotom.grabDA_raw = interp1(concPhotom.timestamps, concPhotom.grabDA_raw,ts);
        concPhotom.timestamps = ts;
        % --- generate epoch names and timestamps
        epochs = cellfun(@(x) [x.syncPhotometry.timestamps(1), x.syncPhotometry.timestamps(end)], ...
            cells, 'UniformOutput', false);
        epochs = vertcat(epochs{:});
        concPhotom.epochs = epochs;
        concPhotom.epochNames = epochNames(whichFiles(re,:));
        % --- replace inter-epoch interpolated values with NaNs
        for ep = 1:size(epochs,1)-1
            toReplace = (ts > epochs(ep,2) & ts < epochs(ep+1,1));
            concPhotom.grabDA_df(toReplace) = nan;
            concPhotom.grabDA_z(toReplace) = nan;
            concPhotom.grabDA_raw(toReplace) = nan;
        end

        [~,name,~] = fileparts(sessionPaths{sp});
        fprintf('\t<strong>%i) %s</strong> - %s concatenated.\n',sp,name,regions{re})
        savepath = fullfile(sessionPaths{sp},join({name,'photometry',regions{re},'mat'},'.'));
        save(savepath{:}, "concPhotom");
        fprintf(2,'\t\tSaved!\n');
    end
end
%% delete old files
%{
clc
for s = 1:numel(sessionPaths)
    preprocessedPaths = dir(fullfile(sessionPaths{s},'\*.photometry.*.sync.conc.mat'));
    for e = 1:numel(preprocessedPaths)
        fprintf('<strong>%d) %s </strong>\n',s,preprocessedPaths(e).name);
        delete(fullfile(preprocessedPaths(e).folder,preprocessedPaths(e).name));
    end
end
%}
