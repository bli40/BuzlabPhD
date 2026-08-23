function blw = byl_DrawBaselines(events, data, timestamps, varargin)
%byl_DrawBaselines - Randomly sample n baseline windows that have variable
%overlap with event windows
%
% WARNING: THIS FUNCTION IS A WORK-IN-PROGRESS AND MAY NOT WORK (YET)
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
% 2026-08-22 by Brian Y. Li


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
end