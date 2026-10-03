%% Exploratory code for GRAB sensor analysis
clear all; close all;
basepath = pwd;
[~, basename, ~] = fileparts(basepath);

%% (2.5) process digitalin files
load([basename, '.session.mat']);
% digitalIn = bz_getDigitalIn(pwd,'fs',session.extracellular.sr);

%% (3) preprocess fiber photometry
byl_preprocessPhotometry(pwd,'show',true,'plottype',1,'saveMat',true,'sync',false);

%flip channels:
vidFrame = figure(42);
chi = vidFrame.Children.Children;
for c = 1:numel(chi)
    chi(c).Children = flipud(chi(c).Children);
end

%%
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

%% Extract barcode data from video file
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
%% precompute bounding box of mask
% rows = any(maskCircle, 2);
% cols = any(maskCircle, 1);
% rowIdx = find(rows);
% colIdx = find(cols);
% rMin = rowIdx(1); rMax = rowIdx(end);
% cMin = colIdx(1); cMax = colIdx(end);
% maskCrop = maskCircle(rMin:rMax, cMin:cMax);  % small cropped mask
% 
% v.CurrentTime = 0;
% n = 0;
% tic
% while hasFrame(v)
%     n = n + 1;
%     vidFrame = readFrame(v);
%     patch = vidFrame(rMin:rMax, cMin:cMax, 1);  % crop first, then mask
%     barcodeBlackfly(n) = sum(double(patch(maskCrop)), 'all');
% end
% toc

%% Resample barcodeIntan to match barcodeDoric sampling rate
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

%% Resample barcodeIntan to match barcodeBlackfly sampling rate
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

%%

T = {tIntan(:), tDoric_shifted(:), tBlackfly_shifted(:)};
D = {barcodeIntan(:)+2, barcodeDoric(:)+1, barcodeBlackfly(:)};
quickTimeSeriesScroller(T,D)

%%
T = {tIntan(:), tDoric_shifted(:)};
D = {barcodeIntan(:)+2, barcodeDoric(:)+1};
quickTimeSeriesScroller(T,D)