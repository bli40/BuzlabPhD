function [outputArg1,outputArg2] = byl_getDataLags(inputArg1,inputArg2)
%byl_getDataLags - Function to get lags in order to synchronize multiple possible data types.
%
% USAGE
%    synclags = byl_getDataLags(file1,file2,...,fileN)
%
% INPUTS - note these are NOT name-value pairs... just raw values
%    sessionPath    path to session directory ('*sess*')
%    <options>      optional list of property-value pairs (see tables below)
%
%
%   =========================================================================
%     Properties    Values
%   -------------------------------------------------------------------------
%     'overwrite'   true if overwrite existing synced files. (default =
%                   false)
%     'verbose'     true if want to see all the files in the session.
%                   (default = false)
%     'dryrun'      true if you don't want to save data (default = false)
%   =========================================================================
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
% 2026-10-06 by Brian Y. Li




%Inputs:
%   - file1, file2, etc. to synchronize. Lags are relative to file1.     
%   
%Returns:
%   - [basename].synclags.mat file 

% Extract barcode data from Intan file
srIntan = session.extracellular.sr;
digitalIntan = 'digitalin.dat';
m = memmapfile(digitalIntan, 'Format', 'uint16', 'writable', false);
raw_digital = m.Data;
clear m

tester = zeros(length(raw_digital), 1);    
syncRandChan = 1;
barcodeIntan = double(bitget(raw_digital,syncRandChan));
tIntan = linspace(0,length(barcodeIntan)/srIntan,length(barcodeIntan));

% Extract barcode data from Doric file
digitalDoric = dir('*_0003.csv');
dio = readtable(string(digitalDoric.name));
srDoric = 1/mean(diff(dio.Time)); %Get samplingrate
barcodeDoric = dio.DigitalCh2; %High/low signal
tDoric = dio.Time;

% Extract barcode data from video file
mazevid = dir('*.mp4');
v = VideoReader([mazevid.name]);
h = v.Height;
w = v.Width;
v.CurrentTime = 0;
srBlackfly = v.FrameRate;
nFramesEst = max(1, ceil(v.Duration * v.FrameRate));
barcodeBlackfly = nan(nFramesEst, 1, 'double');

% circle mask
mask = false(h,w);
cx = 460; cy = 120;        % center (use your center)
circleRadius = 5;                       % center circle radius
[xg,yg] = meshgrid(1:w,1:h);
maskCircle = (xg - cx).^2 + (yg - cy).^2 <= circleRadius^2;
mask = mask | maskCircle;

tic;
n=0;
while hasFrame(v)
    n=n+1;
    vidFrame = readFrame(v);
    if ndims(vidFrame) == 3
        vidFrame = vidFrame(:,:,1);
    end
    barcodeBlackfly(n) = sum(double(vidFrame(mask)),'all');
end
toc;
barcodeBlackfly = barcodeBlackfly(~isnan(barcodeBlackfly));
temp = barcodeBlackfly;

%%
barcodeBlackfly = temp;
cutoff = round(mean([min(barcodeBlackfly), max(barcodeBlackfly)]));
barcodeBlackfly = barcodeBlackfly > cutoff;

% Resample barcodeIntan to match barcodeDoric sampling rate
downsampleRate = srIntan / srDoric;
barcodeIntan_Downsampled = downsample(double(barcodeIntan), downsampleRate);
tIntan_Downsampled = linspace(0, length(barcodeIntan) / srIntan, length(barcodeIntan_Downsampled));
tDoric = linspace(0, length(barcodeDoric) / double(srDoric), length(barcodeDoric));

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