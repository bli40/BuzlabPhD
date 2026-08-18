function byl_syncPhotomData(sessionPath,varargin)
%byl_syncPhotomData - Synchronize photometry data in each session using the
%session's concatenated digitalin.dat file.
%
% USAGE
%    syncPhotom = byl_syncPhotomData(sessionPath,<options>)
%
% INPUTS - note these are NOT name-value pairs... just raw values
%    sessionPath    path to session directory ('*sess*')
%    <options>      optional list of property-value pairs (see tables below)
%
%
%   =========================================================================
%     Properties    Values
%    -------------------------------------------------------------------------
%     'overwrite'   true if overwrite existing synced files. (default =
%                   false)
%     'verbose'     true if want to see all the files in the session.
%                   (default = false)
%     'dryrun'      true if you don't want to save data (default = false)
%    =========================================================================
%
% OUTPUT
%
%    ripples        buzcode format .event. struct with the following fields
%                   .timestamps        Nx2 matrix of start/stop times for
%                                      each ripple
%                   .detectorName      string ID for detector function used
%                   .peaks             Nx1 matrix of peak power timestamps 
%                   .stdev             standard dev used as threshold
%                   .noise             candidate ripples that were
%                                      identified as noise and removed
%                   .peakNormedPower   Nx1 matrix of peak power values
%                   .detectorParams    struct with input parameters given
%                                      to the detector
% SEE ALSO
%
%       ...
%
% 2026-02-22 by Brian Y. Li


% --- Check number of parameters ---
if nargin < 1
  error('Incorrect number of parameters.');
end

% --- Default values ---
p = inputParser;
addParameter(p,'overwrite',false,@islogical)
addParameter(p,'verbose',false,@islogical)
addParameter(p,'dryrun',false,@islogical)
parse(p,varargin{:})

% --- assign parameters (either defaults or given) ---
sessdir = sessionPath;
overwrite = p.Results.overwrite;
verbose = p.Results.verbose;
dryrun = p.Results.dryrun;

% --- list files to be looked at
preprocessedPaths = dir(fullfile(sessdir,'\*.photometry.*.mat'));
[~,name,~] = fileparts(sessdir);
fprintf('<strong>%s</strong>\n',name)
if numel(preprocessedPaths) ~= 0
    for e = 1:numel(preprocessedPaths)
        sessionName = split(preprocessedPaths(e).name,'.');
        fprintf(2,'<strong>\t%s\n</strong>',preprocessedPaths(e).name);
    end
end

syncPhotometryPaths = dir(fullfile(sessdir,'*\*_new_photometry_sync.mat'));
if numel(preprocessedPaths) == 0 || verbose
    regions = unique(extractBefore({syncPhotometryPaths.name}, '-'));
    for i = 1:numel(regions)
        fprintf('\t%s - %i files ready to <strong>concatenate</strong>.\n', regions{i}, sum(contains({syncPhotometryPaths.name},regions{i})));
        fprintf('\t\t%s\n',syncPhotometryPaths(contains({syncPhotometryPaths.name},regions{i})).name);
    end
end

photometryDataPaths = dir(fullfile(sessdir,'*\*_new_photometry.mat'));

if numel(syncPhotometryPaths) == 0 || verbose
    regions = unique(extractBefore({photometryDataPaths.name}, '-'));
    for i = 1:numel(regions)
        fprintf('\t%s - %i files ready to <strong>synchronize</strong>.\n', regions{i}, sum(contains({photometryDataPaths.name},regions{i})));
        fprintf('\t\t%s\n',photometryDataPaths(contains({photometryDataPaths.name},regions{i})).name);
    end
end

epochsDataPaths = dir(fullfile(sessdir,'*\*.ppd'));
regions = upper(unique(extractAfter(extractBefore({epochsDataPaths.name},'-'),'_')));
regions = cellfun(@(x) x(1:3), regions, 'UniformOutput', false);
numEpochs = numel(unique({epochsDataPaths.folder}));
if numel(photometryDataPaths) == 0 || verbose
    regName = unique(extractBefore({epochsDataPaths.name}, '-'));
    for i = 1:numel(regions)
        fprintf('\t%s - %i files ready to <strong>preprocess</strong>.\n', regName{i}, sum(contains(upper({epochsDataPaths.name}),regions{i})));
        fprintf('\t\t%s\n',epochsDataPaths(contains(upper({epochsDataPaths.name}),regions{i})).name);
    end
end

% --- synchronize photometry data with digital TTL pulse.
[~,session,~] = fileparts(sessdir);
fprintf(2,'<strong>Syncing %s\n</strong>',session);
photometryDataPaths = dir(fullfile(sessdir,'*\*_new_photometry.mat'));
if numel(photometryDataPaths) == 0
    fprintf('There are no photometry.mat files to process.\nPlease extract -ppd -> -mat first!\n')
    return;
end
intanDataPaths = fullfile(sessdir,'digitalin.dat');
if ~isfile(intanDataPaths)
    intanDataPaths = dir(fullfile(sessdir,'*\digitalin.dat'));
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