function synclags = byl_getDataLags(basepath,intanChan,otherfiles,otherChan,varargin)
%byl_getDataLags - Function to get lags in order to synchronize multiple
%                  possible data types to concatenated main Intan
%                  digitalin.dat
%
% USAGE
%   synclags = byl_getDataLags(file1,file2,...,fileN)
%
% INPUTS - note these are NOT name-value pairs... just raw values
%   basepath        basepath to Intan digital file (digitalin.dat)
%   varargin        other file(s) to synchronize. Assumes -csv file with
%                   data field and time field (Doric).
%   <options>       optional list of property-value pairs (see tables below)
%
%
%   =========================================================================
%     Properties    Values
%   -------------------------------------------------------------------------
%     'intanChan'   channel of random sync pulse on intan (default = 1)
%     'otherChan'   channel of random sync pulse on other data type
%                   (default = 1)
%     'plotbool'        bool for showing alignment plots (default = true)
%   =========================================================================
%
% OUTPUT
%
%    synclags       custom format struct with lags for each of the input
%                   files
%
% SEE ALSO
%
%       ...
%
% 2026-10-06 by Brian Y. Li
%% Parse inputs
p = inputParser;
p.addRequired('basepath', @(x) ischar(x) || isstring(x));
p.addRequired('intanChan', @(x) validateattributes(x, {'numeric'}, {'scalar','integer','positive'}));
p.addRequired('otherFiles', @(x) ischar(x) || isstring(x) || iscellstr(x));
p.addRequired('otherChan', @(x) validateattributes(x, {'numeric'}, {'scalar','integer','positive'}));
p.addParameter('plotbool', true, @islogical);
p.addParameter('method','crosscorr',@(x) ischar(x) || isstring(x));
p.parse(basepath, intanChan, otherfiles, otherChan, varargin{:});

otherfiles = string(p.Results.otherFiles);
intanChan = p.Results.intanChan;
otherChan = p.Results.otherChan;
plotbool = p.Results.plotbool;
method = p.Results.method;

basepath = p.Results.basepath;
basename = bz_BasenameFromBasepath(basepath);

[~, names, exts] = cellfun(@fileparts, otherfiles, 'UniformOutput', false);
filenames = strcat(names, exts);

fprintf('Syncing %i files with Intan digitalin.dat.\n', numel(otherfiles));
fprintf(2,'\t%s\n',filenames{:});

%% If session didn't have proper random sync pulse
switch method
    case 'crosscorr'
        fprintf('Synchronizing using cross-correlogram peak in random sync pulses.\n');
    case 'framegrab'
        fprintf('Synchronizing using timing of first frame grab.\n');
        load([basepath filesep basename '.session.mat']);
        srIntan = session.extracellular.sr;
        digitalIntan = [basepath filesep 'digitalin.dat'];
        m = memmapfile(digitalIntan, 'Format', 'uint16', 'writable', false);
        raw_digital = m.Data;
        clear m

        barcodeIntan = double(bitget(raw_digital,intanChan));
        tIntan = linspace(0,length(barcodeIntan)/srIntan,length(barcodeIntan));
        
        frameGrabTimes = tIntan(logical([diff(barcodeIntan) == 1; 0]));
        framePeriod = mean(diff(frameGrabTimes));

        if frameGrabTimes(1) > framePeriod
            synclags = frameGrabTimes(1);
            fprintf('Lag %i\n',synclags);
            return

        elseif frameGrabTimes <= framePeriod
            fprintf(2,'\tCannot determine when first frame is grabbed. Synchronization impossible.\n');
            return
        end
    otherwise
        error('Unknown synchronization method: %s', method);
end

%% Extract barcode data from Intan file
load([basepath filesep basename '.session.mat']);
srIntan = session.extracellular.sr;
digitalIntan = [basepath filesep 'digitalin.dat'];
m = memmapfile(digitalIntan, 'Format', 'uint16', 'writable', false);
raw_digital = m.Data;
clear m

barcodeIntan = double(bitget(raw_digital,intanChan));
tIntan = linspace(0,length(barcodeIntan)/srIntan,length(barcodeIntan));

%% Extract barcode data from other input files

timeshift = nan(numel(otherfiles),1);
[barcodeOther, srOther] = deal(cell(numel(otherfiles),1));
for i = 1:numel(otherfiles)
    dio = readtable(otherfiles{i});
    srOther{i} = 1/mean(diff(dio.Time)); %Get samplingrate
    barcodeOther{i} = dio.(otherChan); %High/low signal
    
    % either downsample or resample barcodeIntan to match srOther
    downsampleRate = srIntan / srOther{i};
    try
        barcodeIntanDS = downsample(double(barcodeIntan), downsampleRate);
    catch
        warning('ratio between sampling rates is not an integer. Resampling instead of downsampling.');
        barcodeIntanDS = resample(double(barcodeIntan), srBlackfly, srIntan);
    end

    % Compute cross-correlation
    [xcorrValues, lags] = xcorr(barcodeIntanDS, barcodeOther{i});
    [maxCorr, maxCorrIndex] = max(xcorrValues);
    maxLag = lags(maxCorrIndex);

    % Compute time shift
    timeshift(i) = maxLag / srOther{i}; % Convert lag to time (seconds)

    fprintf('Lag %i: %f (corr = %f)\n',i,timeshift(i),maxCorr);
   
end
synclags = timeshift;

if plotbool
    risingEdgeIntan = find(diff(barcodeIntan) == 1);
    figure('Name', sprintf('Synchronization: %s', filenames{i}));
    plot(risingEdgeIntan / srIntan, 0.5*ones(size(risingEdgeIntan)), 'k|','MarkerSize',20);
    hold on;
    for i = 1:numel(otherfiles) 
        risingEdgeOther = find(diff(barcodeOther{i}) == 1);
        plot((risingEdgeOther / srOther{i}) + timeshift(i), (0.55) * ones(size(risingEdgeOther)), '|','MarkerSize',20);
        xlabel('Time (s)');
        ylim([0 1])
        yticks([0.5 0.55])
        yticklabels({'Intan', 'Other'});
        title(sprintf('Lag = %.6f s', timeshift(i)));
        % legend('Intan', 'Other','FontSize',20);
        grid on;
    end
end


return 
end