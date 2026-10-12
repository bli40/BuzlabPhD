function synclags = byl_getDataLags(basepath,varargin)
%byl_getDataLags - Function to get lags in order to synchronize multiple
%                  possible data types to concatenated main Intan
%                  digitalin.dat
%
% USAGE
%   synclags = byl_getDataLags(file1,file2,...,fileN)
%
% INPUTS - note these are NOT name-value pairs... just raw values
%   basepath        basepath to Intan digital file (digitalin.dat)
%   varargin        other file to synchronize
%   <options>       optional list of property-value pairs (see tables below)
%
%
%   =========================================================================
%     Properties    Values
%   -------------------------------------------------------------------------
%     'intanChan'   channel of random sync pulse on intan (default = 1)
%     'otherChan'   channel of random sync pulse on other data type
%                   (default = 1)
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
p.addParameter('intanChan', 1, @(x) validateattributes(x, {'numeric'}, {'scalar','integer','positive'}));
p.addParameter('otherChan', 1, @(x) validateattributes(x, {'numeric'}, {'scalar','integer','positive'}));
p.parse(intanDigitalFile, varargin{:});
options = p.Results;


%% Extract barcode data from Intan file
session = load([basepath '.session.mat']);
srIntan = session.extracellular.sr;
digitalIntan = [basepath filesep 'digitalin.dat'];
m = memmapfile(digitalIntan, 'Format', 'uint16', 'writable', false);
raw_digital = m.Data;
clear m

syncRandChan = 1;
barcodeIntan = double(bitget(raw_digital,syncRandChan));
tIntan = linspace(0,length(barcodeIntan)/srIntan,length(barcodeIntan));

% Extract barcode data from other input files
digitalDoric = dir('*_0003.csv');
dio = readtable(string(digitalDoric.name));
srDoric = 1/mean(diff(dio.Time)); %Get samplingrate
barcodeDoric = dio.DigitalCh2; %High/low signal
tDoric = dio.Time;



%%
barcodeBlackfly = temp;
cutoff = round(mean([min(barcodeBlackfly), max(barcodeBlackfly)]));
barcodeBlackfly = barcodeBlackfly > cutoff;

% Resample barcodeIntan to match barcodeDoric sampling rate
downsampleRate = srIntan / srDoric;
barcodeDoric = interp1(tDoric, barcodeDoric, tIntan);

% Compute cross-correlation
[xcorrValues, lags] = xcorr(double(barcodeIntan_Downsampled), double(barcodeDoric));
[maxCorr, maxCorrIndex] = max(xcorrValues);
maxLag = lags(maxCorrIndex); % Lag in samples at 130 Hz

% Compute time shift
timeShift_Doric = maxLag / double(srDoric); % Convert lag to time (seconds)

% Add to tDoric
tDoric_shifted = tDoric + timeShift_Doric;
disp(timeShift_Doric);

% Resample barcodeIntan to match barcodeBlackfly sampling rate
downsampleRate = srIntan / srBlackfly;
try
    barcodeIntan_Downsampled = downsample(double(barcodeIntan), downsampleRate);
catch
    barcodeIntan_Downsampled = resample(double(barcodeIntan), srBlackfly, srIntan);
end
tIntan_Downsampled = linspace(0, length(barcodeIntan) / srIntan, length(barcodeIntan_Downsampled));
tBlackfly = linspace(0, length(barcodeBlackfly) / double(srBlackfly), length(barcodeBlackfly));

% Compute cross-correlation
[xcorrValues, lags] = xcorr(double(barcodeIntan_Downsampled), double(barcodeBlackfly));
[maxCorr, maxCorrIndex] = max(xcorrValues);
maxLag = lags(maxCorrIndex); % Lag in samples at 130 Hz

% Compute time shift
timeShift_Blackfly = maxLag / double(srBlackfly); % Convert lag to time (seconds)

% Add to tBlackfly
tBlackfly_shifted = tBlackfly + timeShift_Blackfly;
disp(timeShift_Blackfly);



% Save synclags
synclags.timeShift_Intan = 0;
synclags.timeShift_Doric = timeShift_Doric;
synclags.timeShift_Blackfly = timeShift_Blackfly;
save([basepath, filesep, basename, '.synclags.mat'], 'synclags');
end