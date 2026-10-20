function fig = quickTimeSeriesScroller(ts, Data, varargin)
%QUICKTIMESERIESSCROLLER Scroll one or more time series.
%
%   quickTimeSeriesScroller(Y)
%   quickTimeSeriesScroller(t, Y)
%   quickTimeSeriesScroller({t1,t2,...}, {y1,y2,...})
%
% Left/Right arrows or buttons pan in time.
% Up/Down arrows or buttons shift the y-window.
% Edit boxes set the time-window width and y-window height.

%% parse inputs
p = inputParser;
addRequired(p,'ts',@ismatrix)
addRequired(p,'Data',@ismatrix)
addParameter(p,'timeSeriesNames',{},@(x) isstring(x) || ischar(x) || iscellstr(x));
addParameter(p, 'secondAxisInds', [], @(x) isnumeric(x) || ismatrix(x))
addParameter(p,'events',{}, @(x) ismatrix(x) || iscell(x))
addParameter(p,'eventNames',{}, @(x) isstring(x) || ischar(x) || iscellstr(x));
addParameter(p,'eventColors',{'r','g','b','c','m','y','k'},@(x) isstring(x) || ischar(x) || iscellstr(x))
p.parse(ts,Data,varargin{:})

secondAxisInds = p.Results.secondAxisInds;
events = p.Results.events;
eventNames = p.Results.eventNames;
eventColors = p.Results.eventColors;
timeSeriesNames = p.Results.timeSeriesNames;


%%

if nargin == 1
    Data = ts;
    ts = [];
end

allT = ts;
allD = Data;

numDlines = size(allD,1);
numDsamps = size(allD,2);
if numDlines > numDsamps
    fprintf('Converting data inputs to row vectors.\n')
    allD = allD.';
    numDlines = size(allD, 1);
    numDsamps = size(allD, 2);
end

numTlines = size(allT,1);
numTsamps = size(allT,2);
if numTlines > numTsamps
    fprintf('Converting time inputs to row vectors.\n')
    allT = allT.';
    numTlines = size(allT, 1);
    numTsamps = size(allT, 2);
end

if numTlines == 1 && numTlines<numDlines
    allT = repmat(allT,numDlines,1);
    numTlines = size(allT,1);
elseif numTlines<numDlines && numTlines ~= 1
    error('Number of time vectors must equal number of data vectors or must be a shared time vector.\n');
end

nSeries = numDlines;
nEvents = numel(events);

if isempty(timeSeriesNames)
    timeSeriesNames = cell(nSeries,1);
    for i = 1:numel(timeSeriesNames)
        timeSeriesNames{i} = sprintf('Series %d', i);
    end
elseif ischar(timeSeriesNames) || isstring(timeSeriesNames)
    timeSeriesNames = cellstr(timeSeriesNames);
    if numel(timeSeriesNames) ~= nSeries
        error('Number of names provided does not match with number of timeseries.');
    end
end

if isempty(eventNames)
    eventNames = cell(nEvents,1);
    for i = 1:numel(timeSeriesNames)
        timeSeriesNames{i} = sprintf('Event %d', i);
    end
elseif ischar(eventNames) || isstring(eventNames)
    eventNames = cellstr(eventNames);
    if numel(eventNames) ~= nEvents
        error('Number of names provided does not match with number of timeseries.');
    end
end

firstAxisInds = 1:nSeries;
secondAxisInds = unique(secondAxisInds(:).');

if ~isempty(secondAxisInds)
    firstAxisInds = firstAxisInds(~ismember(firstAxisInds, secondAxisInds));

    leftData = allD(firstAxisInds, :);
    rightData = allD(secondAxisInds, :);

    leftFinite = leftData(isfinite(leftData));
    rightFinite = rightData(isfinite(rightData));

    state.leftYMin = min(leftFinite);
    state.leftYMax = max(leftFinite);
    state.rightYMin = min(rightFinite);
    state.rightYMax = max(rightFinite);

    state.leftYCenter = mean([state.leftYMin state.leftYMax]);
    state.rightYCenter = mean([state.rightYMin state.rightYMax]);

    state.leftYSpan = max(1.1 * (state.leftYMax - state.leftYMin), eps);
    state.rightYSpan = max(1.1 * (state.rightYMax - state.rightYMin), eps);
else
    finiteY = allD(isfinite(allD));
    state.leftYMin = min(finiteY);
    state.leftYMax = max(finiteY);
    state.leftYCenter = mean([state.leftYMin state.leftYMax]);
    state.leftYSpan = max(1.1 * (state.leftYMax - state.leftYMin), eps);
end


tMin = min(allT,[],'all');
tMax = max(allT,[],'all');
tSpan = max(tMax - tMin, eps);

% state.xSpan = min(max(0.1 * tSpan, eps), tSpan);
state.xSpan = min(60, tSpan);
state.xStart = tMin;
state.stepX = 0.1 * state.xSpan;
state.stepYL = 0.1 * state.leftYSpan;
if ~isempty(secondAxisInds)
    state.stepYR = 0.1 * state.rightYSpan;
else
    state.stepYR = state.stepYL;
end
state.tMin = tMin;
state.tMax = tMax;

fig = figure( ...
    'Name', 'Time Series Scroller', ...
    'NumberTitle', 'off', ...
    'Color', 'w', ...
    'WindowKeyPressFcn', @keyPressFcn, ...
    'Units', 'normalized', ...
    'Position', [0.05 0.05 .9 .9]);

ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.05 0.05 0.90 0.90]);
hold(ax, 'on');

fprintf('Plotting %i timeseries.\n', nSeries);
colors = lines(nSeries);

yyaxis(ax, 'left');
for i = 1:numel(firstAxisInds)
    idx = firstAxisInds(i);
    plot(ax, allT(idx, :), allD(idx, :), '-', ...
        'Color', colors(idx, :), 'LineWidth', 1, 'DisplayName',timeSeriesNames{idx});
end

if ~isempty(secondAxisInds)
    yyaxis(ax, 'right');
    for i = 1:numel(secondAxisInds)
        idx = secondAxisInds(i);
        plot(ax, allT(idx, :), allD(idx, :), '-', ...
            'Color', colors(idx, :), 'LineWidth', 1, 'DisplayName',timeSeriesNames{idx});
    end
end


if ~isempty(events)
    if ~iscell(events)
        events = {events};
    end
    for e = 1:numel(events)
        plot(ax,nan,nan,'-','Color',eventColors{e},'DisplayName',eventNames{e});
        xline(ax,events{e},'LineWidth',1,'Color',eventColors{e},'HandleVisibility','off');
    end
end

legend(ax,'location','best','FontSize',15);
grid(ax, 'on');
title('Quick Timeseries Scroller','FontSize',20);
xlabel(ax, 'Time (s)','FontSize',15);
yyaxis(ax, 'left')
ylabel(ax, 'Amplitude','FontSize',15);
yyaxis(ax, 'right')
ylabel(ax, 'Amplitude','FontSize',15);

% uicontrol(fig, 'Style', 'pushbutton', 'String', '◀', 'Units', 'normalized', ...
%     'Position', [0.08 0.10 0.05 0.05], 'Callback', @(~,~) panX(-1));
% uicontrol(fig, 'Style', 'pushbutton', 'String', '▶', 'Units', 'normalized', ...
%     'Position', [0.14 0.10 0.05 0.05], 'Callback', @(~,~) panX(1));
% uicontrol(fig, 'Style', 'pushbutton', 'String', '▼', 'Units', 'normalized', ...
%     'Position', [0.20 0.10 0.05 0.05], 'Callback', @(~,~) panY(-1));
% uicontrol(fig, 'Style', 'pushbutton', 'String', '▲', 'Units', 'normalized', ...
%     'Position', [0.26 0.10 0.05 0.05], 'Callback', @(~,~) panY(1));
% 
% uicontrol(fig, 'Style', 'text', 'String', 'Time window', 'Units', 'normalized', ...
%     'BackgroundColor', 'w', 'HorizontalAlignment', 'left', 'Position', [0.36 0.11 0.10 0.03], ...
%     'FontSize',20);
% xEdit = uicontrol(fig, 'Style', 'edit', 'String', num2str(state.xSpan), 'Units', 'normalized', ...
%     'Position', [0.46 0.10 0.08 0.05], 'Callback', @applySpans);
% 
% uicontrol(fig, 'Style', 'text', 'String', 'Window height', 'Units', 'normalized', ...
%     'BackgroundColor', 'w', 'HorizontalAlignment', 'left', 'Position', [0.58 0.11 0.10 0.03], ...
%     'FontSize',20);
% yEdit = uicontrol(fig, 'Style', 'edit', 'String', num2str(state.ySpan), 'Units', 'normalized', ...
%     'Position', [0.69 0.10 0.08 0.05], 'Callback', @applySpans);

updateView();

    function keyPressFcn(~, event)
        isCtrl = ismember('control', event.Modifier);
        isShift = ismember('shift', event.Modifier);

        switch lower(event.Key)
            case 'rightarrow'
                if isCtrl
                    changeXSpan(1);
                else
                    panX(1);
                end
            case 'leftarrow'
                if isCtrl
                    changeXSpan(-1);
                else
                    panX(-1);
                end
            case 'uparrow'
                if isCtrl && isShift && ~isempty(secondAxisInds)
                    changeYSpan(-1, 'right');
                elseif isCtrl
                    changeYSpan(-1, 'left');
                elseif isShift && ~isempty(secondAxisInds)
                    panY(-1, 'right');
                else
                    panY(-1, 'left');
                end
            case 'downarrow'
                if isCtrl && isShift && ~isempty(secondAxisInds)
                    changeYSpan(1, 'right');
                elseif isCtrl
                    changeYSpan(1, 'left');
                elseif isShift && ~isempty(secondAxisInds)
                    panY(1,'right');
                else
                    panY(1, 'left');
                end
        end
    end

    function panX(direction)
        state.xStart = state.xStart + direction * state.stepX;
        updateView();
    end

    function panY(direction, whichAxis)
        if strcmp(whichAxis, 'right')
            state.rightYCenter = state.rightYCenter + direction * state.stepYR;
        elseif strcmp(whichAxis,'left')
            state.leftYCenter = state.leftYCenter + direction * state.stepYL;
        end
        updateView();
    end

    function changeXSpan(direction)
        xCenter = state.xStart + state.xSpan / 2;
        scale = 1 + 0.1 * direction;
        state.xSpan = max(eps, min(tSpan, state.xSpan * scale));
        state.xStart = xCenter - state.xSpan / 2;
        state.stepX = 0.1 * state.xSpan;
        xEdit.String = num2str(state.xSpan);
        updateView();
    end

    function changeYSpan(direction, whichAxis)
        scale = 1 + 0.1 * direction;

        if strcmp(whichAxis, 'right')
            state.rightYSpan = max(eps, state.rightYSpan * scale);
            state.stepYR = 0.1 * state.rightYSpan;
        elseif strcmp(whichAxis,'left')
            state.leftYSpan = max(eps, state.leftYSpan * scale);
            state.stepYL = 0.1 * state.leftYSpan;
        end

        updateView();
    end

    function applySpans(~, ~)
        newXSpan = str2double(xEdit.String);
        newYSpan = str2double(yEdit.String);

        if isfinite(newXSpan) && newXSpan > 0
            state.xSpan = min(newXSpan, tSpan);
        end
        if isfinite(newYSpan) && newYSpan > 0
            state.leftYSpan = newYSpan;
        end

        state.stepX = 0.1 * state.xSpan;
        state.stepYL = 0.1 * state.leftYSpan;

        xEdit.String = num2str(state.xSpan);
        yEdit.String = num2str(state.leftYSpan);

        updateView();
    end

    function updateView()
        x1 = max(state.tMin, min(state.xStart, state.tMax - state.xSpan));
        x2 = min(state.tMax, x1 + state.xSpan);
        if x2 <= x1
            x2 = x1 + eps;
        end
    
        xlim(ax, [x1 x2]);
    
        yyaxis(ax, 'left');
        ylim(ax, [state.leftYCenter - state.leftYSpan/2, state.leftYCenter + state.leftYSpan/2]);
    
        if isfield(state, 'rightYCenter')
            yyaxis(ax, 'right');
            ylim(ax, [state.rightYCenter - state.rightYSpan/2, state.rightYCenter + state.rightYSpan/2]);
        end
    
        yyaxis(ax, 'left');
        state.xStart = x1;
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
