function byl_concatPhotomData(sessionPath,varargin)
%byl_syncPhotomData - Synchronize photometry data in each session using the
%session's concatenated digitalin.dat file.
%
% USAGE
%    concPhotom = byl_concatPhotomData(sessionPath,<options>)
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
%     'rename'      true if you want to be prompted rename epochs to be 
%                   more descriptive (default = true) [e.g. epoch_1 ->
%                   sleep_1]
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
addParameter(p,'rename',true,@islogical)
parse(p,varargin{:})

% --- assign parameters (either defaults or given) ---
sessdir = sessionPath;
overwrite = p.Results.overwrite;
verbose = p.Results.verbose;
dryrun = p.Results.dryrun;
rename = p.Results.rename;

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

% --- concatenate photometry data.
preprocessedPaths = dir(fullfile(sessdir,'\*.photometry.*.mat'));
if ~isempty(preprocessedPaths) && overwrite
    fprintf('%d) Full photometry file exists. Overwriting.\n',sp);
elseif ~isempty(preprocessedPaths) && ~ overwrite
    fprintf('%d) Full photometry file exists. Skipping.\n',sp);
    return;
end

% --- get number of regions and number of epochs
syncPhotometryPaths = dir(fullfile(sessdir,'*\*_new_photometry_sync.mat'));

regions = unique(extractBetween({syncPhotometryPaths.name},'_','-'));
numRegions = numel(regions);

epochFolders = string({syncPhotometryPaths.folder});
[epochFolders,epochNum,epochIdx] = unique(epochFolders, 'stable');
numEpochs = numel(epochFolders);
epochNames = "epoch_" + string(1:numEpochs);

% --- (optional) rename epochs
if rename
    agreement = input(sprintf('Choose new names for %i epochs? [y/n]:', numEpochs),"s");
    while ~strcmpi(agreement,'y') && ~strcmpi(agreement,'n')
        disp('Please type "y" or "n"')
        agreement = input(sprintf('Choose new names for %i epochs? [y/n]:', numEpochs),"s");
    end
    if strcmpi(agreement,'y')
        for e = 1:numEpochs
            prompt = sprintf('%s -> ',epochNames(e));
            epochNames(e) = input(prompt,"s");
        end
    elseif strcmpi(agreement,'n')
        fprintf(strcat('Epoch names will remain:\n\t',repmat('%s, ',1,numEpochs),'\n'),epochNames);
    end

end

syncArray = cell(numRegions, numEpochs);

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

    [~,name,~] = fileparts(sessdir);
    fprintf('\t<strong>%s</strong> - %s concatenated.\n',name,regions{re})
    savepath = fullfile(sessdir,join({name,'photometry',regions{re},'mat'},'.'));
    if ~dryrun
        save(savepath{:}, "concPhotom");
        fprintf(2,'\t\tSaved!\n');
    end
end

end