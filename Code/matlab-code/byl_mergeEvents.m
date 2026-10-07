function mergedEvents = byl_mergeEvents(eventWindows, threshold)
%byl_mergeEvents -  Function to merge events whose inter-event intervals
%                   fall below a threshold. Based on the ripple merging
%                   algorithm in bz_FindRipples.
%
% USAGE
%   mergedEvents = byl_mergeEvents(eventWindows, threshold)
%
% INPUTS - note these are NOT name-value pairs... just raw values
%   eventWindows    Nx2 matrix of [onset offset] for every detected event
%   threshold       IEI cutoff to consider as the same or separate events
%                   (units in seconds)
%
% OUTPUT
%   mergedEvents    Mx2 matrix of [onset offset] pairs for the now-merged events
%
% SEE ALSO
%
%       bz_FindRipples
%
% 2026-10-07 by Brian Y. Li


arguments (Input)
    eventWindows (:,2) {mustBeNumeric, mustBeFinite}
    threshold (1,1) {mustBeNumeric, mustBeFinite}
end

mergedEvents = [];
query = eventWindows(1,:);
for i = 2:size(eventWindows,1)
    if eventWindows(i,1) - query(2) <= threshold
        start = query(1);
        stop = max([query(2) eventWindows(i,2)]);
        query = [start stop];
    else
        mergedEvents = [mergedEvents; query];
        query = eventWindows(i,:);
    end
end
mergedEvents = [mergedEvents; query];

end
