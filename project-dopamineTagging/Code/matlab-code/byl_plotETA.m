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
%    events         event timestamps (e.g. ripples.timestamps(:,1))
%	 data   	    timeseries data from which to pull windowed segments
%    timestamps
%    <options>      optional list of property-value pairs (see tables below)
%
%
%    =========================================================================
%     Properties    Values
%    -------------------------------------------------------------------------
%     'durations'   time window before and after event, in seconds
%                   (default = [-5 5]). 
%     'frequency'   sampling rate (in Hz) (default = 1250Hz)
%     'show'        plot results (default = 'off')
%     'plotType'   1=original version (several plots); 2=only raw lfp
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
% 2026-01-31 by Brian Y. Li


warning('this function is under development and may not work... yet')

% Check number of parameters
if nargin < 3
  error('Incorrect number of parameters.');
end


% Default values
p = inputParser;
addParameter(p,'durations',[-5 5],@isnumeric)
addParameter(p,'frequency',1250,@isnumeric)
addParameter(p,'show','off',@isstr)
addParameter(p,'plotType',2,@isnumeric)

% assign parameters (either defaults or given)
events = events;
xSeries = data;
tSeries = timestamps;
durations = p.Results.durations;
frequency = p.Results.frequency;
show = p.Results.show;
plotType = p.Results.plotType;

% Parameters
fs = frequency;           % LFP sampling rate (Hz)
pre  = durations(1);      % seconds before spike
post = durations(2);      % seconds after spike

% Define relative time axis (not samples)
tWind = pre : 1/fs : post;
winLength = numel(tWind);

etaMatrix = nan(numel(events), winLength);
tSampMatrix = nan(numel(events), winLength);
    
keepEvent = false(numel(eventTimes_hpc),1);
    for i = 1:numel(events)
        tSample = events(i) + tWind;
    
        if tSample(1) < timeseries(1) || tSample(end) > timeseries(end)
            continue
        end
    
        etaMatrix(i,:) = interp1(tSeries, xSeries, tSample, 'linear');
        tSampMatrix(i,:) = tSample;
        keepEvent(i) = true;
    end
    
etaMatrix = etaMatrix(keepEvent,:);
tSampMatrix = tSampMatrix(keepEvent,:);
  
% Event-triggered average
eta_avg = mean(etaMatrix, 1);
eta_std = std(etaMatrix, 0, 1);
eta_sem = eta_std / sqrt(size(etaMatrixHPC,1)-1);

eta = struct('avg',eta_avg, ...
             'std',eta_std, ...
             'sem',eta_sem, ...
             'windows',etaMatrix, ...
             'timestamps',tSampMatrix);
return

    
    
  