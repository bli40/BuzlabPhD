% ThePipeline
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
%      10) extract ripples, ripple stats, and cluster metrics
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
clear all; close all;
% --- cd to local animal directory
cd('C:\Users\brian\Documents\BYL\project-dopamine-tagging\M012\');
% cd('C:\Users\brian\Documents\BYL\project-opto-ripples\M008\')
% --- global variables
overwrite = false;
forcesort = false;

%% (0) basename and basepath
basepath = pwd;
[~,basename,~] = fileparts(basepath);

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
        % disp(ii);
        cd(allpath{ii});
        xmlFile = dir('*.xml');
        ii = ii + 1;
    end
    if isempty(xmlFile)    
        [file, path] = uigetfile('*.xml','Select global xml file');
        if file==0 && path==0
            answer = questdlg("No global.xml selected or found. Skip this step and continue? (Do this if you are grouping non-ephys recordings)", ...
                'Continue?','Yes','No','');
            commandwindow;
            switch answer
                case 'Yes'
                    % Continue: do nothing (or place skipped-step code here)
                case {'No', ''} % '' covers window-close / Esc
                    fprintf('User chose to stop. Exiting.\n');
                    return; % stop running the rest of the script
            end
            
        else
            copyfile(strcat(path,file),'global.xml');
        end
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
aaa = dir('M*');
bbb = dir('*sess*');

namesA = {aaa.name};
namesB = {bbb.name};
[diffNames,ia] = setdiff(namesA, namesB);
diffFiles = aaa(ia);

% --- select files to group
if isstring(diffNames)
    diffNames = cellstr(diffNames); 
end

if ~isempty(diffNames)
    disp('Select epoch files to group together...')
    [indx, tf] = listdlg('ListString', diffNames, ...
                         'PromptString', 'Select epoch files to concatenate:', ...
                         'SelectionMode', 'multiple', ...
                         'ListSize',[300 300]);
    commandwindow;
    if ~tf
        error('No file(s) selected.');
    else
        newEpochs = diffFiles(indx);
    end
end

% --- check most recent session is populated. If not, then populate.
existingSessions = cellfun(@(x) str2double(extractAfter(x,'_sess')), {bbb.name});
if isempty(existingSessions)
    startSess = 0;
else
    startSess = max(existingSessions);
    lastSessIdx = contains({bbb.name},join(['sess',string(startSess)],''));
    if numel(dir(fullfile(bbb(lastSessIdx).folder,bbb(lastSessIdx).name))) <=2
        startSess = startSess-1;
    end
end

% newRecordingDates = cellfun(@(x) extractBetween(x, '_','_'), {newEpochs.name});
newRecordingDates = cellfun(@(s) regexp(s,'_(.*?)_','tokens','once'), {newEpochs.name});
uniqueRecordingDates = unique(newRecordingDates);
animal = unique(cellfun(@(x) extractBefore(x, '_'), {newEpochs.name}, 'UniformOutput', false));


if numel(existingSessions) ~= max(existingSessions)
    missingSessions = setdiff(existingSessions, 1:max(existingSessions));
    for n = 1:numel(missingSessions)
        fprintf('\tSession %i is missing.\n', missingSessions(n));
    end
else
    fprintf('\t%i sessions exist. Merging %i epochs into %i session.\n', ...
        numel(existingSessions),numel(newEpochs),numel(uniqueRecordingDates));
end

if isempty(newEpochs)
    fprintf(2,'\t<strong><<< No new epochs recorded! Stopping The Pipeline. >>></strong>\n')
    return;
else
    for rd = 1:numel(uniqueRecordingDates)
        specificEpochs = dir(join(['*',uniqueRecordingDates{rd},'*']));
        sessName = join([animal,uniqueRecordingDates{rd},sprintf('sess%i',startSess+rd)],'_');
        sessName = sessName{1};
        newDir = fullfile(animalDir,sessName);
        theseEpochs = newEpochs(cellfun(@(x) contains(x,uniqueRecordingDates{rd}), {newEpochs.name}));

        fprintf('\t%s\n',newDir);        
        if isempty(dir(newDir))
            mkdir(newDir);
        end
        for ep = 1:numel(theseEpochs)
            thisEpoch = fullfile(theseEpochs(ep).folder, theseEpochs(ep).name);
            movefile(thisEpoch,newDir)
            fprintf(2,'\t\t%s\n',theseEpochs(ep).name);
        end
    end
end

%% (2) Concatenate -dat files
basepath = pwd;
[~,basename,~] = fileparts(basepath);
subSess = dir('M*');

if ~isempty(dir('*sess*'))
    if ~isempty(dir('*.dat'))
        fprintf(2,'Data already concatenated! Stopping concatenation.\n');
    else
        fprintf(2,'You are in the animal directory, not the session directory! Stopping concatenation.\n');
    end
    return;
end

if size(subSess,1)>=1
    if size(subSess,1)==1
        fprintf(2,'No sub-sessions for today! Copying -dat and -xml files parent directory and renaming to match.\n');
    end
    if ~exist(strcat(basename,'.xml'),'file')
        delete(strcat(basename,'.xml'));% bring xml file
        copyfile(strcat(animalDir,'\global.xml'),strcat(basename,'.xml'),'f');
    end
    % --- Concatenate sessions       
    bz_ConcatenateDats(pwd,0,1);

    % --- Loading metadata
    try
        session = sessionTemplate(pwd,'showGUI',false); % 
        session.channels = 1:session.extracellular.nChannels;    
        save([session.general.name,'.session.mat'],'session','-v7.3');
    catch
        warning('it seems that CellExplorer is not on your path');
    end
end    

%% (2.5) process digitalin files

digitalIn = bz_getDigitalIn(pwd,'fs',session.extracellular.sr);

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

%% (3) preprocess fiber photometry
byl_preprocessPhotometry(pwd,'show',true,'plottype',2,'saveMat',true);

%% (4) Spike sorting (matlab: kilosort3 | python: kilosort 4) --> WIP
subSess = dir();
if size(subSess,1)>=5
    if forcesort || isempty(dir('*Kilosort*')) % if not kilosorted yet
        fprintf(' ** Kilosorting session %3.i of %3.i... \n',ii, size(allSess,1));   
        KiloSortWrapper;
        kilosortFolder = dir('*Kilosort_*');
        try
            PhyAutoClustering(strcat(kilosortFolder.folder,'\',kilosortFolder.name)); % auto-clustering
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
byl_concatPhotomData(pwd);
% --- to-do: pass string list to rename epochs

%% (6) extract behavioral data and tracking
getPatchTracking('basePath',pwd)

%% (7) extract LFP
if isempty(dir('*.lfp'))
    try 
        bz_LFPfromDat(pwd,'outFs',1250); % generating lfp
    catch
        disp('Problems with bz_LFPfromDat, resampling...');
        ResampleBinary(strcat(sessionInfo.session.name,'.dat'),strcat(sessionInfo.session.name,'.lfp'),...
            sessionInfo.nChannels,1,sessionInfo.rates.wideband/sessionInfo.rates.lfp);
    end
end
%% (7.5) session lfp power spectrum
figure(1); clf; hold on;
load([basename,'.MergePoints.events.mat']);
pyrLFP = bz_GetLFP(66,'fromDat',false,'basename',basename);
for e = 1:size(MergePoints.timestamps_samples,1)
    mp1 = find(pyrLFP.timestamps >= MergePoints.timestamps(e,1),1,"first");
    mp2 = find(pyrLFP.timestamps <= MergePoints.timestamps(e,2),1,"last");
    [pxx,f] = pspectrum(double(pyrLFP.data(mp1:mp2)),pyrLFP.samplingRate,'FrequencyLimits',[0 625]);
    plot(f, pow2db(pxx));
end
params.Fs = 1250;
params.fpass = [0 500];
f0 = [60,120,180,240,300,360,420];
data = double(pyrLFP.data);
rmlnLFP = rmlinesc(data,params,[],[],f0);
[pxx,f] = pspectrum(rmlnLFP,pyrLFP.samplingRate,'FrequencyLimits',[0 625]);
plot(f, pow2db(pxx));
%% (8) extract Sleep State Scoring
% badChannels = [24:38 48:63]; %N7
% badChannels = [0:3 15:18 21:30 43 50 95 97]; %N9
% badChannels = [20:38]; %N11   
% badChannels = [74]; %N14
% badChannels = [0:3 15:18 21:30 41 43 46 47 50 52 95 97]; %N15
% badChannels = [42 48 56:59 61 70 72]; %N17
% badChannels = [1,2,4:14,74,82,83,91,92,112:118,120:126]; %N18
% badChannels = [1,2,3,4,5,6,8,9,10,11,12,13,...
%     14,31,32,33,34,35,36,37,38,39,40,41,42,...
%     43,44,45,46,47,74,80,81,82,83,84,85,86,...
%     87,88,89,90,91,92,93,94,95,96,97,99,100,...q21
%     112,113,114,115,116,117,118,120,121,122,123,...
%     124,125,126,127]; % M008
% badChannels = [26,27,37,38,39,40,44,45,46,47,48,49, ...
%                50,52,53,54,55,56,57,58,59,60,61,62, ...
%                63,64,65,77,78,79,80,82,83,84,85,86, ...
%                87,88,89,91,93,94,95,96,97,98,99,100, ...
%                101,102,103,104,105,106,107,108,110,111]; % M012

load([basename, '.session.mat']);
badChannels = session.channelTags.Bad.channels;
SleepScoreMaster(pwd,'rejectChannels',badChannels);%,'ThetaChannels',[1 31],'SWChannels',[5 8]);

%% (9) extract ripples
% Dictionary 
%   - N11 : 
%   - N17 :     pyrCh 121   noiseCh 111
%   - N18 :     pyrCh 56   noiseCh 64
%   - N19 :     
%   - M012  :   pyrCh = 92; noiseCh = 15;
%   - M008  :   pyrCh = 64; noiseCh = 71;    
pyrCh = 51; noiseCh = 15;
% pyrCh = ripples.detectorinfo.detectionchannel;  %75 for n11 115 67 for n11
% noiseCh = ripples.detectorinfo.noisechannel;
SleepStateFile = dir("*SleepState.states.mat");
load(SleepStateFile.name);
[ripples] = bz_FindRipples(pwd,pyrCh,'noise',noiseCh, ...
                                     'savemat',true, ...
                                     'durations',[30 200], ...
                                     'passband',[100 250], ...
                                     'thresholds',[2 5], ...
                                     'restrict',SleepState.ints.NREMstate, ...
                                     'EMGThresh',0.95);

%% (10) extract session info
[sessionInfo] = bz_getSessionInfo(pwd, 'noPrompts', true); 
sessionInfo.rates.lfp = 1250;  
save(strcat(sessionInfo.session.name,'.sessionInfo.mat'),'sessionInfo');

session = sessionTemplate(pwd,'showGUI',false); % 
session.channels = 1:session.extracellular.nChannels;    
save([session.general.name,'.session.mat'],'session','-v7.3');


%% (11) ripple stats and cluster metrics
rippleFile = dir("*ripples.events.mat");
load(rippleFile.name);
% --- get ripple stats                                     
pyrCh = bz_GetLFP(ripples.detectorinfo.detectionchannel);
ripLFP = bz_Filter(pyrCh.data,'passband',ripples.detectorinfo.detectionparms.passband);
[maps,data,stats] = bz_RippleStats(ripLFP, pyrCh.timestamps,ripples);
rippleStats = struct('maps',maps,'data',data','stats',stats);
d = dir('*ripples.events.mat');
[~,name,~] = fileparts(d.folder);
save(join([name,'.ripples.stats.mat']),"rippleStats");

% --- find ripples - solos and clusters
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
		secondPass = [secondPass; ripple];     % secondPass is updated each cycle and contains all previous ripples. /kg
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
clusters = setdiff(secondPass, firstPass, 'rows');
ripclust = secondPass;

% --- Ripple cluster Index and Size
aa = ismember(ripples.timestamps, clusters);
bb = cumsum(aa);
cc = bb(:,1) > bb(:,2);
cc = cc + aa(:,2);
ripClustNum = cumsum(aa(:,1));
ripClustNum(~logical(cc)) = 0;
[ripClustIdx, ripClustRevIdx, ripSizeAll] = deal(cc);
for i = 1:max(unique(ripClustNum))
    ripClustIdx(ripClustNum == i) = cumsum(cc(ripClustNum == i));
    ripClustRevIdx(ripClustNum == i) = flip(cumsum(cc(ripClustNum == i)));
    ripSizeAll(ripClustNum == i) = sum(cc(ripClustNum == i));
    clustsize(i,:) = ripSizeAll(find(ripClustNum == i,1,'first'));
end
ripSizeAll(ripSizeAll == 0) = 1;

ripClustSize = nan(size(ripclust(:,1)));
[~,~,isolo] = intersect(solos(:,1), ripclust(:,1));
ripClustSize(isolo) = 1;
[~,ia,iclust] = intersect(clusters(:,1), ripclust(:,1));
ripclustSize(iclust) = clustsize(ia);

% check
fprintf('%i/%i ripple clusters indexed\n',max(ripClustNum),length(clusters));


% --- Ripple Clust Index and Size -> structure!
rippleClust = struct('ripclust',ripclust, ...
                     'ripclustsize',ripclustSize, ...
                     'solos',solos, ...
                     'clusters',clusters, ...
                     'clustersize',clustsize, ...
                     'ripsizeall',ripSizeAll, ...
                     'ripclustidx',ripClustIdx, ...
                     'reverseidx',ripClustRevIdx);

% rippleBurst = struct('solos', ripBurstIdx == 0,...
%                      'bursts', ripBurstIdx ~= 0, ...
%                      'duos', ripBurstSize == 2,...
%                      'trios', ripBurstSize == 3, ...
%                      'quartets', ripBurstSize == 4, ...
%                      'quintets', ripBurstSize == 5, ...
%                      'first', ripBurstIdx == 1, ...
%                      'second', ripBurstIdx == 2, ...
%                      'third', ripBurstIdx == 3, ...
%                      'fourth', ripBurstIdx == 4, ...
%                      'fifth', ripBurstIdx == 5, ...
%                      'last', ripBurstRevIdx == 1, ...
%                      'notLast', ripBurstRevIdx ~= 1 | 0, ...
%                      'burstIndex', ripBurstNum, ...
%                      'burstNum', burstSize, ...
%                      'burstTimes', bursts, ...
%                      'soloTimes', solos);
fprintf('rippleClust structure complete.\n');
d = dir('*.ripples.events.mat');
[~,name,~] = fileparts(d.folder);
save(join([name,'.ripples.clusters.mat']),"rippleClust");
