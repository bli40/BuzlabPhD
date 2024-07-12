function [events] = FindStatePatch(trace, period, varargin)
% This needs to be cleaned up and fixed. Will need different parameters for
% ripples, IEDs, Dentate Spikes, theta/delta ratio, etc. 
    maxDur = inf;
    minDur = 0;
    lowThresholdFactor = 2;
    highThresholdFactor = 0;
    minIterSamples = 1;
    stateFilt = 1;
    state = ones(size(trace));
    
    % p = inputParser;
    % addRequired(p,'trace',@(x)validateattributes(x,{'numeric'},{'nonempty'}));
    % addRequired(p,'period',@(x)validateattributes(x,{'numeric'},{'nonempty'}));
    % addOptional(p,'state',@(x)validateattributes(x,{'numeric'},{'nonempty'}));
    % addOptional(p,'stateFilt',@(x)validateattributes(x,{'numeric'},{'nonempty'}));
    % addParameter(p,'maxDur',@(x)validateattributes(x,{'numeric'},{'nonempty'}));
    % addParameter(p,'minDur',@(x)validateattributes(x,{'numeric'},{'nonempty'}));
    % addParameter(p,'lowThresholdFactor',@(x)validateattributes(x,{'numeric'},{'nonempty'}));
    % addParameter(p,'highThresholdFactor',@(x)validateattributes(x,{'numeric'},{'nonempty'}));
    % parse(p,varargin);
    
    % disp(lowThresholdFactor)
    
    idx = find(state ~= stateFilt);
    %%
    trace(idx) = 0;
    times = (0:length(trace)-1)*period;
    
    
    %% first Low Thresholding
    signal = trace';
    
    % Square and normalize signal
    % normalizedSquaredSignal = signal.^2;
    normalizedSquaredSignal = signal;
    
    
    % Detect ripple periods by thresholding normalized squared signal
    thresholded = normalizedSquaredSignal > lowThresholdFactor;
    start = find(diff(thresholded)==1);
    stop = find(diff(thresholded)==-1)+1;
    
    % Exclude last ripple if it is incomplete
    if start(end) > stop(end)
        start(end) = [];
    end
    
    % Exclude first ripple if it is incomplete
    if start(1) > stop(1)
        stop(1) = [];
    end
    
    firstPass = [start,stop];
    if isempty(firstPass)
        disp('Detection by thresholding failed');
        return
    else
        disp(['After detection by thresholding: ' num2str(length(firstPass)) ' events.']);
    end
    
    %% Merge ripples if inter-ripple period is too short
    secondPass = [];
    ripple = firstPass(1,:);
    for i = 2:size(firstPass,1)
        if firstPass(i,1) - ripple(2) < minIterSamples
            % Merge
            ripple = [ripple(1) firstPass(i,2)];
        else
            secondPass = [secondPass; ripple];
            ripple = firstPass(i,:);
        end
    end
    secondPass = [secondPass; ripple];
    if isempty(secondPass)
        disp('Ripple merge failed');
        return
    else
        disp(['After ripple merge: ' num2str(length(secondPass)) ' events.']);
    end
    
    %% Discard ripples with a peak power < highThresholdFactor
    thirdPass = [];
    peakNormalizedPower = [];
    for i = 1:size(secondPass,1)
        [maxValue,maxIndex] = max(normalizedSquaredSignal(secondPass(i,1):secondPass(i,2)));
        if maxValue > highThresholdFactor
            thirdPass = [thirdPass ; secondPass(i,:)];
            peakNormalizedPower = [peakNormalizedPower ; maxValue];
        end
    end
    if isempty(thirdPass)
        disp('Peak thresholding failed.');
        return
    else
        disp(['After peak thresholding: ' num2str(length(thirdPass)) ' events.']);
    end

    %% Detect peak position for each ripple
    
    peakPosition = zeros(size(thirdPass,1),1);
    for i=1:size(thirdPass,1)
        [maxValue,maxIndex] = max(signal(thirdPass(i,1):thirdPass(i,2)));
        peakPosition(i) = maxIndex + thirdPass(i,1) -1;
    end
    
    % Discard ripples that are way too long
    events = [times(thirdPass(:,1));
              times(peakPosition); 
              times(thirdPass(:,2)); 
              peakNormalizedPower']';
    duration = events(:,3)-events(:,1);
    events(duration>maxDur,:) = NaN;
    %disp(['After duration test: ' num2str(size(ripples,1)) ' events.']);
    
    % Discard ripples that are too short
    events(duration<minDur,:) = NaN;
    events = events((all((~isnan(events)),2)),:);
    
    disp(['After duration test: ' num2str(size(events,1)) ' events.']);
    
    
    %%
    evs = events; clear events
    
    events.timestamps = evs(:,[1 3]);
    events.peaks = evs(:,2);            %peaktimes? could also do these as timestamps and then ripples.ints for start/stops?
    events.peakNormedPower = evs(:,4);  %amplitudes?
    events.times = times;
    events.trace = trace;
    
    
end