function fig = quickTimeSeriesScroller(t, Y)
%QUICKTIMESERIESSCROLLER Scroll one or more time series.
%
%   quickTimeSeriesScroller(Y)
%   quickTimeSeriesScroller(t, Y)
%   quickTimeSeriesScroller({t1,t2,...}, {y1,y2,...})
%
% Left/Right arrows or buttons pan in time.
% Up/Down arrows or buttons shift the y-window.
% Edit boxes set the time-window width and y-window height.

if nargin == 1
    Y = t;
    t = [];
end

[tCell, yCell] = normalizeInputs(t, Y);
nSeries = numel(yCell);

allT = vertcat(tCell{:});
allY = vertcat(yCell{:});

finiteY = allY(isfinite(allY));
if isempty(finiteY)
    error('Input data contains no finite values.');
end

tMin = min(allT);
tMax = max(allT);
tSpan = max(tMax - tMin, eps);

yMin = min(finiteY);
yMax = max(finiteY);
ySpan = max(yMax - yMin, eps);

state.xSpan = min(max(0.1 * tSpan, eps), tSpan);
state.ySpan = max(0.2 * ySpan, eps);
state.xStart = tMin;
state.yCenter = mean([yMin yMax]);
state.stepX = 0.1 * state.xSpan;
state.stepY = 0.1 * state.ySpan;
state.tMin = tMin;
state.tMax = tMax;
state.yMin = yMin;
state.yMax = yMax;

fig = figure( ...
    'Name', 'Time Series Scroller', ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'WindowKeyPressFcn', @keyPressFcn, ...
    'Units', 'normalized', ...
    'Position', [0.10 0.10 0.80 0.75]);

ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.08 0.22 0.90 0.73]);
hold(ax, 'on');

colors = lines(nSeries);
for i = 1:nSeries
    plot(ax, tCell{i}, yCell{i}, 'Color', colors(i, :), 'LineWidth', 1);
end

grid(ax, 'on');
xlabel(ax, 'Time');
ylabel(ax, 'Amplitude');

uicontrol(fig, 'Style', 'pushbutton', 'String', '◀', 'Units', 'normalized', ...
    'Position', [0.08 0.10 0.05 0.05], 'Callback', @(~,~) panX(-1));
uicontrol(fig, 'Style', 'pushbutton', 'String', '▶', 'Units', 'normalized', ...
    'Position', [0.14 0.10 0.05 0.05], 'Callback', @(~,~) panX(1));
uicontrol(fig, 'Style', 'pushbutton', 'String', '▼', 'Units', 'normalized', ...
    'Position', [0.20 0.10 0.05 0.05], 'Callback', @(~,~) panY(-1));
uicontrol(fig, 'Style', 'pushbutton', 'String', '▲', 'Units', 'normalized', ...
    'Position', [0.26 0.10 0.05 0.05], 'Callback', @(~,~) panY(1));

uicontrol(fig, 'Style', 'text', 'String', 'Time window', 'Units', 'normalized', ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left', 'Position', [0.36 0.11 0.10 0.03], ...
    'FontSize',20);
xEdit = uicontrol(fig, 'Style', 'edit', 'String', num2str(state.xSpan), 'Units', 'normalized', ...
    'Position', [0.46 0.10 0.08 0.05], 'Callback', @applySpans);

uicontrol(fig, 'Style', 'text', 'String', 'Window height', 'Units', 'normalized', ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left', 'Position', [0.58 0.11 0.10 0.03], ...
    'FontSize',20);
yEdit = uicontrol(fig, 'Style', 'edit', 'String', num2str(state.ySpan), 'Units', 'normalized', ...
    'Position', [0.69 0.10 0.08 0.05], 'Callback', @applySpans);

updateView();

    function keyPressFcn(~, event)
        switch lower(event.Key)
            case 'rightarrow'
                panX(1);
            case 'leftarrow'
                panX(-1);
            case 'uparrow'
                panY(1);
            case 'downarrow'
                panY(-1);
        end
    end

    function panX(direction)
        state.xStart = state.xStart + direction * state.stepX;
        updateView();
    end

    function panY(direction)
        state.yCenter = state.yCenter + direction * state.stepY;
        updateView();
    end

    function applySpans(~, ~)
        newXSpan = str2double(xEdit.String);
        newYSpan = str2double(yEdit.String);

        if isfinite(newXSpan) && newXSpan > 0
            state.xSpan = min(newXSpan, tSpan);
        end
        if isfinite(newYSpan) && newYSpan > 0
            state.ySpan = newYSpan;
        end

        state.stepX = 0.1 * state.xSpan;
        state.stepY = 0.1 * state.ySpan;

        xEdit.String = num2str(state.xSpan);
        yEdit.String = num2str(state.ySpan);

        updateView();
    end

    function updateView()
        x1 = max(state.tMin, min(state.xStart, state.tMax - state.xSpan));
        x2 = min(state.tMax, x1 + state.xSpan);
        if x2 <= x1
            x2 = x1 + eps;
        end

        y1 = state.yCenter - state.ySpan / 2;
        y2 = state.yCenter + state.ySpan / 2;

        if y1 < state.yMin
            y2 = y2 + (state.yMin - y1);
            y1 = state.yMin;
        end
        if y2 > state.yMax
            y1 = y1 - (y2 - state.yMax);
            y2 = state.yMax;
        end

        if y2 <= y1
            y1 = state.yMin;
            y2 = state.yMax;
        end

        xlim(ax, [x1 x2]);
        ylim(ax, [y1 y2]);
        state.xStart = x1;
        state.yCenter = mean([y1 y2]);
        drawnow;
    end
end

function [tCell, yCell] = normalizeInputs(t, Y)

if iscell(Y)
    yCell = cell(size(Y));
    for i = 1:numel(Y)
        yCell{i} = Y{i}(:);
    end

    if isempty(t)
        tCell = cell(size(Y));
        for i = 1:numel(Y)
            tCell{i} = (1:numel(yCell{i}))';
        end
    elseif iscell(t)
        if numel(t) ~= numel(Y)
            error('t and Y must have the same number of series.');
        end
        tCell = cell(size(t));
        for i = 1:numel(t)
            tCell{i} = t{i}(:);
            if numel(tCell{i}) ~= numel(yCell{i})
                error('Each time vector must match its data vector length.');
            end
        end
    elseif isnumeric(t) && isvector(t)
        t = t(:);
        tCell = cell(size(Y));
        for i = 1:numel(Y)
            if numel(t) ~= numel(yCell{i})
                error('Common time vector length must match every data vector.');
            end
            tCell{i} = t;
        end
    else
        error('Unsupported time input.');
    end

elseif isnumeric(Y)
    if isvector(Y)
        Y = Y(:);
    end

    if isempty(t)
        t = (1:size(Y, 1))';
    end

    if isnumeric(t) && isvector(t)
        t = t(:);
        if size(Y, 1) ~= numel(t)
            error('Length of t must match the number of rows in Y.');
        end
        tCell = repmat({t}, 1, size(Y, 2));
        yCell = cell(1, size(Y, 2));
        for i = 1:size(Y, 2)
            yCell{i} = Y(:, i);
        end
    elseif isnumeric(t) && isequal(size(t), size(Y))
        tCell = cell(1, size(Y, 2));
        yCell = cell(1, size(Y, 2));
        for i = 1:size(Y, 2)
            tCell{i} = t(:, i);
            yCell{i} = Y(:, i);
        end
    else
        error('t must be a vector, a matrix the same size as Y, or a cell array.');
    end
else
    error('Unsupported input type.');
end

end
