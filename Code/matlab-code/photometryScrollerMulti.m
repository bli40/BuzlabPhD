% Multi-Trace, Multi-Event Photometry Scroller GUI
% ------------------------------------------------
% Scroll through t-second chunks of photometry data with multiple traces
% and multiple event types overlaid on the same timestamps.
%
% REQUIRED INPUTS:
%   data        - [N x M] matrix (M traces, N samples)
%   fs          - sampling rate (Hz)
%   events      - struct array with fields:
%                   .times  -> vector of event timestamps (seconds)
%                   .label  -> string (e.g., 'Ripple', 'Reward')
%                   .color  -> RGB or char (optional)
%   winSec      - window size in seconds (e.g., 10)
%
% Example:
%   events(1).times = rippleTimes;
%   events(1).label = 'Ripple';
%   events(1).color = 'r';
%   events(2).times = rewardTimes;
%   events(2).label = 'Reward';
%   events(2).color = 'b';
%   photometryScrollerMulti(X, 130, events, 10)
%
% Controls:
%   ← →   scroll
%   ↑ ↓   zoom y
%
% Brian-style minimal, fast, no toolboxes.

function photometryScrollerMulti(data, fs, events, winSec)

if isvector(data)
    data = data(:);
end

[N, M] = size(data);
T = N/fs;
winSamples = round(winSec*fs);
idx = 1;
yScale = 1;

fig = figure('Name','Photometry Multi-Trace Event Scroller',...
    'NumberTitle','off','KeyPressFcn',@keyPress);

ax = axes(fig); hold on;

% Plot handles for traces
hTr = gobjects(M,1);
colors = lines(M);
for k = 1:M
    hTr(k) = plot(ax, nan, nan, 'LineWidth', 1.5, 'Color', colors(k,:));
end

% Plot handles for events
nE = numel(events);
hEv = gobjects(nE,1);
for e = 1:nE
    if ~isfield(events(e),'color') || isempty(events(e).color)
        events(e).color = 'k';
    end
    hEv(e) = plot(ax, nan, nan, '|', 'MarkerSize', 14, ...
        'LineWidth', 2, 'Color', events(e).color);
end

xlabel('Time (s)'); ylabel('Signal');
legend([hTr; hEv], [arrayfun(@(k)sprintf('Trace %d',k),1:M,'uni',0), ...
    {events.label}], 'Location','best');

title('← → scroll   ↑ ↓ zoom y');

updatePlot();

    function updatePlot()
        i1 = idx;
        i2 = min(idx + winSamples - 1, N);
        t = (i1:i2)/fs;

        % Stack traces vertically
        yWin = data(i1:i2,:);
        offsets = (0:M-1)*max(range(yWin))*1.3;

        for k = 1:M
            set(hTr(k), 'XData', t, 'YData', yWin(:,k) + offsets(k));
        end

        % Plot events
        for e = 1:nE
            mask = events(e).times >= t(1) & events(e).times <= t(end);
            evT = events(e).times(mask);
            evY = interp1(t, yWin(:,1), evT, 'linear', 'extrap');
            set(hEv(e), 'XData', evT, 'YData', evY + offsets(1));
        end

        % ylim([min(offsets)-range(yWin(:))*0.5, max(offsets)+range(yWin(:))*1.5]*yScale);
        xlim([t(1) t(end)]);
        title(sprintf('%.2f – %.2f s', t(1), t(end)));
        drawnow;
    end

    function keyPress(~, event)
        switch event.Key
            case 'rightarrow'
                idx = min(idx + winSamples/2, N-winSamples+1);
            case 'leftarrow'
                idx = max(idx - winSamples/2, 1);
            case 'uparrow'
                yScale = yScale * 0.8;
            case 'downarrow'
                yScale = yScale * 1.25;
        end
        updatePlot();
    end

end
