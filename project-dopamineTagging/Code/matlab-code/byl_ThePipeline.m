%% ThePipeline
% This is the skeleton code for running the preprocessing and essential
% data analysis steps for the DA-tagging project. There are 4 data types:
% (1) ephys, (2) fiber-photometry, (3) behavioral tracking, and (4)
% behavioral performance. Not all sessions will have all data types, and
% there may be variable numbers of daily epochs.
%
%       1) Organize files into daily sessions
%       2) concatenate -dat files.
%       3) (python) extract -ppd files
%       4) (python) spike sorting (kilosort4)
%       5) synchronize and concatenate -ppd files
%       6) extract session info
%       7) extract behavioral data and tracking
%       8) extract LFP
%       9) extract Sleep State Scoring
%      10) extract ripples, ripple stats, and burst metrics
%
% For now, this will be a script that needs to be run on each session. You
% must be within the animal's main directory. Future progress will include
% running this in batch from directories specified in an spreadsheet,
% making this a function that can be called from the command line, etc.
% Many functions derived from IZ and HJ.
%
% Missing Functionality (to-do):
% - Separating epochs by recording date automatically (and reflecting this 
%   in command line ouputs
% - 
%
%
%
%
% created by Brian Y. Li - 2026/02/20

%% (0) Global Settings Variables + Initiation
% clear all; close all;
% --- cd to local animal directory
cd('B:\Brian\N18\');

% --- global variables
overwrite = false;
forcesort = false;

%% (1) Organize to standard directory structure

% --- choose animal directory
if ~exist('animalDir') || isempty(animalDir)
    animalDir = uigetdir; % select folder
    cd(animalDir);
end
disp(pwd);

allpath = strsplit(genpath(animalDir),';'); % all folders
cd(allpath{1});

% --- find the first global.xml or prompt user
disp('Check xml...');
if isempty(dir('global.xml')) 
    disp('No xml global file! Looking for it...');
    xmlFile = []; ii = 2;
    while isempty(xmlFile) && ii < size(allpath,2)
        disp(ii);
        cd(allpath{ii});
        xmlFile = dir('*.xml');
        ii = ii + 1;
    end
    if isempty(xmlFile)    
        [file, path] = uigetfile('*.xml','Select global xml file');
        copyfile(strcat(path,file),'global.xml');
    else
        copyfile(strcat(xmlFile(1).folder,filesep,xmlFile(1).name),strcat(allpath{1},filesep,'global.xml'));
    end
    cd(allpath{1});
else
    disp('global.xml exists.')
end

% --- build session format
fprintf('\nBuilding session folders (all epochs recorded on same day)\n');
allSess = dir(pwd);

% --- Find max session number already
aaa = dir('N*');
bbb = dir('*sess*');

namesA = {aaa.name};
namesB = {bbb.name};
diffNames = setdiff(namesA, namesB);

[~,idx] = ismember(diffNames, namesA);
newEpochs = aaa(idx);

% --- check most recent session is populated. If not, then populate.
existingSessions = cellfun(@(x) str2double(extractAfter(x,'_sess')), {bbb.name});
startSess = max(existingSessions);
lastSessIdx = contains({bbb.name},join(['sess',string(startSess)],''));
if numel(dir(fullfile(bbb(lastSessIdx).folder,bbb(lastSessIdx).name))) <=2
    startSess = startSess-1;
end

newRecordingDates = unique(cellfun(@(x) extractBetween(x, '_','_'), {newEpochs.name}));
animal = unique(cellfun(@(x) extractBefore(x, '_'), {newEpochs.name}, 'UniformOutput', false));


if numel(existingSessions) ~= max(existingSessions)
    missingSessions = setdiff(existingSessions, 1:max(existingSessions));
    for n = 1:numel(missingSessions)
        fprintf('\tSession %i is missing.\n', missingSessions(n));
    end
else
    fprintf('\t%i sessions exist. Merging %i epochs into %i session(s).\n', ...
        numel(existingSessions),numel(newEpochs),numel(newRecordingDates));
end

if isempty(newEpochs)
    fprintf(2,'\t<strong><<< No new epochs recorded! Stopping The Pipeline. >>></strong>\n')
    return;
else
    for rd = 1:numel(newRecordingDates)
        specificEpochs = dir(join(['*',newRecordingDates{rd},'*']));
        sessName = join([animal,newRecordingDates,sprintf('sess%i',startSess+rd)],'_');
        sessName = sessName{1};
        newDir = fullfile(animalDir,sessName);

        fprintf('\t%s\n',newDir);        
        if isempty(dir(newDir))
            mkdir(newDir);
        end
        for ep = 1:numel(newEpochs)
            thisEpoch = fullfile(newEpochs(ep).folder, newEpochs(ep).name);
            movefile(thisEpoch,newDir)
            fprintf(2,'\t\t%s\n',newEpochs(ep).name);
        end
    end
end

%% (2) Concatenate -dat files
newDir = pwd;
cd(newDir)
subSess = dir('N*');
[~,name,~] = fileparts(newDir);

% --- WIP
% if ~isempty(dir('*sess*'))
%    fprintf(2,'You are in the animal directory, not the session directory! Stopping concatenation.\n');
%    return;
% end

if size(subSess,1)>=1
    if ~exist(strcat(name,'.xml'))
        delete(strcat(name,'.xml'));% bring xml file
        copyfile(strcat(animalDir,'\global.xml'),strcat(name,'.xml'),'f');
    end
    % --- Concatenate sessions       
    bz_ConcatenateDats(pwd,0,1);

    % --- Loading metadata
    try
        session = sessionTemplate(pwd,'showGUI',false); % 
        session.channels = 1:session.extracellular.nChannels;    
        %session.channelTags.Bad.channels = [24:38 48:63];
        save([session.general.name,'.session.mat'],'session','-v7.3');
    catch
        warning('it seems that CellExplorer is not on your path');
    end
end    

%% (3) Extract -ppd files (python) --> WIP
haveSessions = dir('*sess*');
haveSessions = any(isfolder({haveSessions.name}));

haveEpochs = dir('N*_*_*');
haveEpochs = any(~contains({haveEpochs.name},'sess') & isfolder({haveEpochs.name}));

if haveSessions
    fprintf(2,'\tYou are in the animal directory! Please choose a session directory.\n')
elseif ~haveSessions && ~haveEpochs
    fprintf(2,'\tYou are in the epoch directory! Please choose a session directory.\n')
end

thisPyEnv = pyenv;
if thisPyEnv.Status == "Loaded"
    terminate(pyenv)
end
thisPyEnv = pyenv('Version','C:\Users\Gergely\anaconda3\envs\matpy\python.exe',ExecutionMode='OutOfProcess');
py.sys.path().append('C:\Users\Gergely\Documents\Brian\BuzlabPhD\project-dopamineTagging\Code\python-code\pyPhotometry')
pyscript = 'C:\Users\Gergely\Documents\Brian\BuzlabPhD\project-dopamineTagging\Code\python-code\byl_extractppd.py';
if count(py.sys.path, fileparts(pyscript)) == 0
    py.sys.path().append(fileparts(pyscript))
end

pyrunfile(pyscript,'inputFromMatlab',pwd);

%% (4) Spike sorting (matlab: kilosort3 | python: kilosort 4) --> WIP
subSess = dir();
if size(subSess,1)>=5
    if forcesort || isempty(dir('*Kilosort*')) % if not kilosorted yet
        fprintf(' ** Kilosorting session %3.i of %3.i... \n',ii, size(allSess,1));   
        KiloSortWrapper;
        kilosortFolder = dir('*Kilosort_*');
        try
            PhyAutoClustering(strcat(kilosortFolder.folder,'\',kilosortFolder.name)); % autoclustering
        catch err
            disp(err.message)
            warning('PhyAutoClustering not possible!!');
        end
        if exist('phyLink') && ~isempty(phyLink) % move phy link to
            kilosort_path = dir('*Kilosort*');
            try copyfile(phyLink, strcat(kilosort_path.name,filesep,'LaunchPhy')); % copy pulTime to kilosort folder
            end
        end
    end
end

%% (5) Synchronize and concatenate -ppd files
byl_syncPhotomData(pwd);




%% (6) extract session info
%% (7) extract behavioral data and tracking
%% (8) extract LFP
%% (9) extract Sleep State Scoring
%% (10) extract ripples, ripple stats, and burst metrics