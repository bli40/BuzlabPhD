function eta = byl_GetETA(events, data, timestamps, varargin)
%byl_GetETA - Plot event-triggered averages for any waveform
%
%
% USAGE
%    [fig, eta] = byl_GetETA(events,data,timestamps,<options>)
%
%    Event times are used to generate a Nx1 time window at the sampling
%    frequency. These will be used as query points for interpolating the
%    timeseries data provided. The matrix will then be averaged to produce
%    a single Nx1 vector of the event-triggered average. Optionally, can
%    plot the ETA in a new figure or a passed handle.
%
% INPUTS - note these are NOT name-value pairs... just raw values
%    events          event timestamps (e.g. ripples.timestamps(:,1))
%    data            timeseries data from which to pull windowed segments
%    timestamps      timestamps of time series data
%    <options>       optional list of property-value pairs (see tables below)
%
%
%    =========================================================================
%     Properties    Values
%    -------------------------------------------------------------------------
%     'durations'   time window before and after event, in seconds
%                   (default = [-5 5]). 
%     'samplerate'   sampling rate (in Hz) (default = 1250Hz)
%     'show'        plot results (default = 'off')
%     'plotType'   1=original version (several plots); 2=only raw lfp
%    =========================================================================
%
% OUTPUT
%
% SEE ALSO
%
%       ...
%
% 2026-01-31 by Brian Y. Li


% --- Check number of parameters ---
if nargin < 3
  error('Incorrect number of parameters.');
end

% --- Default values ---
p = inputParser;
addParameter(p,'durations',[-5 5],@isnumeric)
addParameter(p,'samplerate',1250,@isnumeric)
addParameter(p,'show','off',@isstr)
addParameter(p,'normalization','none',@isstr)
parse(p,varargin{:})

% --- assign parameters (either defaults or given) ---
events = events;
xSeries = data;
tSeries = timestamps;
durations = p.Results.durations;
sr = p.Results.samplerate;
show = p.Results.show;
norm = p.Results.normalization;

% --- Parameters ---
fs = sr;           % LFP sampling rate (Hz)
pre  = durations(1);      % seconds before spike
post = durations(2);      % seconds after spike

% --- Define sample indices ---
tWind = pre : 1/fs : post;
winLength = numel(tWind);
winSamples = round(tWind * fs);

% --- Convert events to sample indices ---
t0 = timestamps(1);
eventIdx = round((events - t0) * fs) + 1;
nData = numel(data);

% --- Preallocate ---
etaMatrix = nan(numel(events), winLength);
tSampMatrix = nan(numel(events), winLength);
keepEvent = false(numel(events),1);
for i = 1:numel(events)
    idx = eventIdx(i) + winSamples;

    if idx(1) < 1 || idx(end) > nData
        continue
    end

    etaMatrix(i,:) = data(idx);
    tSampMatrix(i,:) = timestamps(idx);
    keepEvent(i) = true;
end
    
etaMatrix = etaMatrix(keepEvent,:);
tSampMatrix = tSampMatrix(keepEvent,:);



% --- Compute Statistics ---
eta_avg = mean(etaMatrix, 1,'omitnan');
eta_std = std(etaMatrix, 0, 1,'omitnan');
eta_sem = eta_std / sqrt(size(etaMatrix,1));
eta = struct('avg',eta_avg, ...
             'std',eta_std, ...
             'sem',eta_sem, ...
             'window',tWind, ...
             'chunks',etaMatrix, ...
             'timestamps',tSampMatrix);
% --- Optional normalization ---
if ~strcmp(norm, 'none')
    normedMat = normalize(etaMatrix,2,norm);
    normedAvg = mean(normedMat,1,'omitnan');
    normedSem = std(normedMat,0,1,'omitnan') / sqrt(size(normedMat,1));
    eta.normChunks = normedMat;
    eta.normAvg = normedAvg;
    eta.normSem = normedSem;
end
return

    
    
  