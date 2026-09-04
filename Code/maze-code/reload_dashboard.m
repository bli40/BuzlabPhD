%% Go to folder
clear all; close all;
cd('Z:\buzsakilab\Buzsakilabspace\LabShare\BrianLi\project-dopamine-tagging\');

% Codes:
%    000: system initiation settings log
%    001: trial offer
%    010: port poked
%    011: port rewarded
%    100: bonus status
%    101: trial overtime
%    110: trial initiation
%    111: trial end

%% Variables
sessionlog = "2026-07-21--12-28-36-M011.txt";
% sessionlog = "2026-07-19--18-06-54-M012.txt";
% sessionlog = "2026-08-05--19-07-09-M012.txt";
[~, session, ~] = fileparts(sessionlog);
numlines = length(readlines(sessionlog));
logStrings = cell(numlines,1);
timestamps = nan(numlines,1);
codelog = cell(numlines,1);
pokelog = nan(numlines,1);
displog = nan(numlines,1);
cued = [];
rewardRate = [];
trialRewardRate = [];
windowRewardRate = [];
trialRefErr = [];
trialWrkErr = [];

maxTimePlot = 200;
maxTrialPlot = 50;
ipi = 5000;

col = lines(7);

%% Initialize Plot

monitors = get(0, 'MonitorPositions');

% 2. Check if a second monitor exists
if size(monitors, 1) >= 2
    secMon = monitors(2, :);
    f = figure(1);
    f.Position = secMon;
    t = tiledlayout(2,3,"TileSpacing","tight");
    f.WindowState = 'maximized';

else
    disp('Second monitor not detected.');
    f = figure(1);
    t = tiledlayout(2,3,"TileSpacing","tight");
    f.WindowState = 'maximized';
end




%% diagram (1)
n1 = nexttile(1); hold on;
textITI = text(-11,3,0,'ITI:',"FontSize",15,"Color",col(2,:));
sessionDuration = text(-11,-3.5,0,sprintf('Session\nDuration:'),'FontSize',20,'Color',col(7,:));

diagram = gca;

angles = 22.5:45:360;
angles = circshift(angles,5);

[xa, ya, la] = getTiltRectangle(0,0,1,10,angles(1));
fill(xa, ya, 'w', 'EdgeColor', 'w'); % 'w' is white
a(1) = text(la(1,1), la(1,2), '1', ...
    'FontSize',16, ...
    'HorizontalAlignment','center');
a(5) = text(la(2,1), la(2,2), '5', ...
    'FontSize',16, ...
    'HorizontalAlignment','center');
A(1,:) = mean([xa(1:2), ya(1:2)]);
A(5,:) = mean([xa(3:4), ya(3:4)]);

[xa, ya, la] = getTiltRectangle(0,0,1,10,angles(2));
fill(xa, ya, 'w', 'EdgeColor', 'w'); % 'w' is white
a(2) = text(la(1,1), la(1,2), '2', ...
    'FontSize',16, ...
    'HorizontalAlignment','center');
a(6) = text(la(2,1), la(2,2), '6', ...
    'FontSize',16, ...
    'HorizontalAlignment','center');
A(2,:) = mean([xa(1:2), ya(1:2)]);
A(6,:) = mean([xa(3:4), ya(3:4)]);

[xa, ya, la] = getTiltRectangle(0,0,1,10,angles(3));
fill(xa, ya, 'w', 'EdgeColor', 'w'); % 'w' is white
a(3) = text(la(1,1), la(1,2), '3', ...
    'FontSize',16, ...
    'HorizontalAlignment','center');
a(7) = text(la(2,1), la(2,2), '7', ...
    'FontSize',16, ...
    'HorizontalAlignment','center');
A(3,:) = mean([xa(1:2), ya(1:2)]);
A(7,:) = mean([xa(3:4), ya(3:4)]);

[xa, ya, la] = getTiltRectangle(0,0,1,10,angles(4));
fill(xa, ya, 'w', 'EdgeColor', 'w'); % 'w' is white
a(4) = text(la(1,1), la(1,2), '4', ...
    'FontSize',16, ...
    'HorizontalAlignment','center');
a(8) = text(la(2,1), la(2,2), '8', ...
    'FontSize',16, ...
    'HorizontalAlignment','center');
A(4,:) = mean([xa(1:2), ya(1:2)]);
A(8,:) = mean([xa(3:4), ya(3:4)]);

for n = 1:length(A)
    tpos = a(n).Position;
    [xc, yc] = getCircle(tpos(1),tpos(2),0.5);
    circ(n) = fill(xc,yc, ...
        'w','EdgeColor','w', ...
        'LineWidth',2, ...
        'FaceAlpha',0);

    [xa, ya] = getTiltRectangle(A(n,1),A(n,2),1,1,angles(n));
    arm(n) = fill(xa, ya, 'w', 'EdgeColor', 'w'); hold on;
end

% define center circle
[xunit, yunit] = getCircle(0,0,1.5);
center = fill(xunit, yunit, 'w', 'EdgeColor', 'w'); % 'w' is white
center.LineWidth = 3;

% Trial Number In Center
trialnum = 0;
tt = text(0,0,0,sprintf("%.2i",trialnum), ...
    'FontSize',30, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','center', ...
    'VerticalAlignment','middle');

axis equal;
axis off;
grid on;
set(gca, 'Color', 'none');
 

%% total pokes (2)
n2 = nexttile(2); hold on;
h1 = histogram(pokelog,8,'FaceColor',col(4,:));
h1.BinEdges = [0.5:1:8.5];
xlabel('Arm Port');
ylabel('All Poke Count');
title('Total Pokes per Arm');

%% total attempts (3)
n3 = nexttile(3); hold on;
h2 = histogram(pokelog,8,'FaceColor',col(7,:));
h2.BinEdges = [0.5:1:8.5];
xlabel('Arm Port');
ylabel('Attempt Count');
title('Attempted Pokes per Arm');

%% reward rate (4)
n4 = nexttile(4); hold on; grid on;

r1 = plot(nan,nan,'-o', ...
    'LineWidth',2, ...
    'MarkerSize',15, ...
    'Color',col(7,:), ...
    'DisplayName','Overall');
r2 = plot(nan,nan,'-o', ...
    'LineWidth',2, ...
    'MarkerSize',10, ...
    'Color',col(5,:), ...
    'DisplayName','Last-5');
r3 = plot(nan,nan,'-o', ...
    'LineWidth',2, ...
    'MarkerSize',5, ...
    'Color',col(6,:), ...
    'DisplayName','Last-1');
legend();
ylim([0 1]);
xlim([0 maxTrialPlot]);
ylabel('Reward Rate');
xlabel('Trial Number');
title(sprintf('%s',session),'FontSize',20);
%% trial durations (5)
n5 = nexttile(5); hold on; grid on;
yyaxis left;
l1 = plot(nan,nan,'-s', ...
    'LineWidth',2, ...
    'MarkerSize',10, ...
    'Color',col(1,:));
ylim([0 maxTimePlot]);
ylabel('Trial Duration (s)');

yyaxis right;
l2 = plot(nan,nan,'-s', ...
    'LineWidth',2, ...
    'MarkerSize',10, ...
    'Color',col(2,:));
ylim([0 maxTimePlot]);
ylabel('ITI Duration (s)');

xlim([0 maxTrialPlot]);
xlabel('Trial Number');
title('Trial Duration');

%% time to reward (6);
n6 = nexttile(6); hold on; grid on;

p(1) = plot(0,0, ...
    '.-', ...
    'MarkerSize',15, ...
    'LineWidth',2);
p(2) = plot(0,0, ...
    '.-', ...
    'MarkerSize',15, ...
    'LineWidth',2);
p(3) = plot(0,0, ...
    '.-', ...
    'MarkerSize',15, ...
    'LineWidth',2);
p(4) = plot(0,0, ...
    '.-', ...
    'MarkerSize',15, ...
    'LineWidth',2);
legend();
xlabel('Trial Number');
ylabel('Time (s)');
xlim([0 maxTrialPlot]);
ylim([0 maxTimePlot]);

%% Read in session log
cued = [];

disp("Parsing " + sessionlog + " -- Press ctrl+C to stop.");
fid = fopen(sessionlog,'r');

if fid == -1
    error("Failed to open file. Double check that it exists.");
end

for i = 1:numlines
    tline = fgetl(fid);
    if tline == -1
        fprintf('Whole session parsed. Re-plotting dashboard.\n');
        break;
    end

    line = split(tline,' ');
    line = line{2};
    % fprintf("%s\n",line);
    lineElements = split(line,'//');

    if ~strcmp(lineElements{1},'000')
        timestamps(i) = str2double(lineElements{end});
        codelog{i} = lineElements{1};
    end

    if strcmp(lineElements{1},'000')
        if strcmp(lineElements{2},'CUED')
            cued = [cued, str2double(lineElements{3})];
        elseif strcmp(lineElements{2},'HOME')
            home = str2double(lineElements{3});
            p(4).DisplayName = string(home);
        end

        updateDiagram(lineElements, cued, arm, textITI);

        for c = 1:numel(cued)
            p(c).DisplayName = string(cued(c));
        end

        if strcmp(lineElements{2},'EMERGENCY-STOP')
            redbox.Visible = 'on';
        elseif strcmp(lineElements{2},'EMERGENCY-START')
            redbox.Visible = 'off';
        elseif strcmp(lineElements{2},'PAUSE')
            butt.Visible = 'on';
        end


    elseif strcmp(lineElements{1},'011')
        if ismember(str2double(lineElements{3}),cued)
            arm(str2double(lineElements{3})).FaceColor = col(5,:);
        elseif ismember(str2double(lineElements{3}),home)
            arm(str2double(lineElements{3})).FaceColor = col(3,:);
        end
        displog(i) = str2double(lineElements{3});
        [dp,tr,ts] = getRewards(timestamps,displog,codelog);
        starts = timestamps(strcmp(codelog,'110'));
        allport = [cued home];
        for c = 1:numel(allport)
            try
                p(c).YData = (ts(dp == allport(c)) - starts(tr(dp == allport(c))))/1000;
                p(c).XData = tr(dp == allport(c));
            end
        end

    
    elseif strcmp(lineElements{1},'010')
        pokelog(i) = str2double(lineElements{3});
        if ~ismember(str2double(lineElements{3}), [cued,home])
            arm(str2double(lineElements{3})).FaceColor = col(2,:);
        end
        h1.Data = pokelog;
        h1.Parent.YLim = [0 max(h1.BinCounts)+1];

        updateAttempts(h2,timestamps,pokelog,codelog, ipi);

        justPokes = pokelog(~isnan(pokelog));
        for i = 1:8
            circ(i).EdgeColor = 'w';
        end

        circ(justPokes(end)).EdgeColor = col(7,:);
        try 
            if numel(unique(justPokes)) >=3
                lastTwo = justPokes(find(justPokes ~= justPokes(end),2,'last'));
                circ(lastTwo(2)).EdgeColor = 'black';
                circ(lastTwo(1)).EdgeColor = col(1,:);
            else
                lastOne = justPokes(find(justPokes ~= justPokes(end),1,'last'));
                circ(lastOne(1)).EdgeColor = 'black';
            end
        end

    elseif strcmp(lineElements{1},'001')
        resetMaze(arm,center);
        center.EdgeColor = col(6,:);
        tt.String = sprintf("%.2i",str2double(lineElements{3}));

    elseif strcmp(lineElements{1},'110')
        center.EdgeColor = col(5,:);
        updateITIDuration(l2,timestamps,codelog)

    elseif strcmp(lineElements{1},'101')
        center.EdgeColor = col(7,:);

    elseif strcmp(lineElements{1},'111')
        updateTrialDuration(l1,timestamps,codelog);
        [pk,trA,tsA] = getAttempts(timestamps,pokelog,codelog,ipi);
        [dp,trR,tsR] = getRewards(timestamps,displog,codelog);

        totalRewardRate = numel(dp) / numel(pk);
        rewardRate = [rewardRate totalRewardRate];
        r1.XData = 1:numel(rewardRate);
        r1.YData = rewardRate;

        fiveRewardRate = sum(trR>(max(trR)-5) & trR<=max(trR)) / sum(sum(trA>(max(trA)-5) & trA<=max(trA)));
        windowRewardRate = [windowRewardRate fiveRewardRate];
        r2.XData = 1:numel(windowRewardRate);
        r2.YData = windowRewardRate;

        thisRewardRate = sum(trR == max(trR)) / sum(trA == max(trA));
        trialRewardRate = [trialRewardRate thisRewardRate];
        r3.XData = 1:numel(trialRewardRate);
        r3.YData = trialRewardRate;

        thisPokes = pk(trA == max(trA));
        thisPokes = thisPokes(1:end-1);
        thisRefErr = sum(~ismember(thisPokes,cued)) / numel(thisPokes);
        trialRefErr = [trialRefErr thisRefErr];
        thisWrkErr = sum(diff(sort(thisPokes)) == 0) / numel(thisPokes);
        trialWrkErr = [trialWrkErr thisWrkErr];
    
    end
end
fclose(fid);


%% Post-Hoc Analysis Sandbox
f2 = figure(2);
f2.Position = secMon;
f2.WindowState = 'maximized';

t1 = tiledlayout(1,2,'TileSpacing','compact','Padding','loose');
title(t1, sprintf("Performance Metrics: %s",session),'FontSize',40);

nexttile(1);
plot(trialRewardRate,'-o','LineWidth',3,'MarkerSize',12, ...
    'MarkerFaceColor',col(1,:),'Color',col(1,:));
grid on;
xlabel("Trial Number",'FontSize',20);
nt = gca;
title(nt,'Overall Reward Rate','FontSize',30);
nt.TitleHorizontalAlignment = 'left';
nt.XAxis.FontSize = 20;
nt.YAxis.FontSize = 20;
ylim([0 1])
yticks([0 0.25 0.5 0.75 1]);

nexttile(2); hold on;
plot(trialRefErr,'-v','LineWidth',3,'MarkerSize',12, ...
    'MarkerFaceColor',col(2,:), 'Color',col(2,:),'DisplayName','Reference Memory Errors');
plot(trialWrkErr,'-^','LineWidth',3,'MarkerSize',12, ...
    'MarkerFaceColor',col(3,:),'Color',col(3,:),'DisplayName','Working Memory Errors');
grid on;
lgd = legend();
lgd.FontSize = 30;
xlabel("Trial Number",'FontSize',20);
nt = gca;
title(nt,'Error Rate','FontSize',30);
nt.TitleHorizontalAlignment = 'left';
nt.XAxis.FontSize = 20;
nt.YAxis.FontSize = 20;
ylim([0 1])
yticks([0 0.25 0.5 0.75 1]);
%% Functions
function [xa, ya] = getCircle(x,y,r)
    th = 0:pi/50:2*pi;
    xa = r * cos(th) + x;
    ya = r * sin(th) + y;
end

function [xa, ya, la] = getTiltRectangle(x,y,w,l,t)
    % 1. Define Rectangle Parameters
    center = [x, y];    % [x, y] center
    width = w;          % x-direction
    length = l;         % y-direction
    angle = t;         % Angle in degrees (clockwise)
    
    % 2. Calculate Corners Relative to Center (unrotated)
    w2 = width / 2;
    l2 = length / 2;
    corners = [-w2, -l2;  % Bottom-left
                w2, -l2;  % Bottom-right
                w2,  l2;  % Top-right
               -w2,  l2]; % Top-left
    
    % 3. Create Rotation Matrix
    R = [cosd(angle), sind(angle); -sind(angle), cosd(angle)];
    
    % 4. Rotate and Translate Corners
    rotatedCorners = (R * corners')';
    xa = rotatedCorners(:,1) + center(1);
    ya = rotatedCorners(:,2) + center(2);

     % ---- LABEL POSITION ----
    % Direction toward rectangle "top"
    dir = R * [0; 1];

    % Offset distance beyond tip
    offset = 1;

    % Position just beyond top center
    la = [center - (l2 + offset) * dir';
          center + (l2 + offset) * dir'];
end

function updateDiagram(line, cued, arm, varText)
    col = lines(7);
    v2 = line{2};
    v3 = line{3};
    nexttile(1);
    if strcmp(v2,'mRAM')
        text(-11,7,0,upper(v3),'FontSize',30,'FontWeight','bold','VerticalAlignment','baseline');
    elseif strcmp(v2,'CUED')
        fmt = ['CUED: %i' repmat(', %i',1,numel(cued)-1)];
        text(-11,6,0,...
            sprintf(fmt,cued), "FontSize",20,"Color",col(1,:));
        for i = 1:numel(cued)
            arm(cued(i)).EdgeColor = col(1,:);
            arm(cued(i)).LineWidth = 2;
        end
    elseif strcmp(v2,'HOME')
        text(-11,5,0,...
            sprintf('HOME: %d',str2double(v3)),"FontSize",20,"Color",col(3,:));
        arm(str2double(v3)).EdgeColor = col(3,:);
        arm(str2double(v3)).LineWidth = 2;
    elseif strcmp(v2,'TOT')
        text(-11,4,0,...
            sprintf('TOT: %0.2fs',str2double(v3)),"FontSize",15,"Color",col(2,:));
    elseif strcmp(v2,'ITI')
        varText.String = sprintf('ITI: %0.2fs',str2double(v3));
        % text(-11,3,0,...
        %     sprintf('ITI: %0.2fs',str2double(v3)),"FontSize",15,"Color",col(2,:));
    elseif strcmp(v2,'DUR')
        text(-11,2,0,...
            sprintf('DUR: %0.2fms',str2double(v3)),"FontSize",15,"Color",col(2,:));
    
    end
end

function resetMaze(arm,center)
    for p = 1:numel(arm)
        arm(p).FaceColor = 'w';
    end
    center.EdgeColor = 'w';
end

function updateTrialDuration(fig, timestamps, codelog)
    trialStartIdx = find(strcmp(codelog,'110'));
    trialEndIdx = find(strcmp(codelog,'111'));
    trialEndIdx = trialEndIdx(2:end);
    trialDurations = (timestamps(trialEndIdx) - timestamps(trialStartIdx)) / 1000;
    % totalTrialDuration = sum(trialDurations);
    fig.XData = 1:numel(trialDurations);
    fig.YData = trialDurations;
end

function updateITIDuration(fig, timestamps, codelog)
    trialEndIdx = find(strcmp(codelog,'111'));
    trialStartIdx = find(strcmp(codelog,'110'));
    ITIDurations = (timestamps(trialStartIdx) - timestamps(trialEndIdx)) / 1000;
    fig.XData = 1:numel(ITIDurations);
    fig.YData = ITIDurations;
end

function [attemptPokes, attemptTrial, attemptTimes] = getAttempts(timestamps, pokelog, codelog, ipi)
    isTrial = strcmp(codelog,'110') - strcmp(codelog,'111');
    isTrial(find(isTrial==-1,1,'first')) = 0;
    isTrial = cumsum(isTrial);
    
    trialNum = strcmp(codelog,'110');
    trialNum = cumsum(trialNum);
    trialNum(~isTrial) = 0;

    justTS = timestamps(~isnan(pokelog));
    justPokes = pokelog(~isnan(pokelog));
    justTrial = trialNum(~isnan(pokelog));
    
    IPI = [0; diff(justTS)];
    relevantIdx = ((IPI > ipi) | logical([1; diff(justPokes)~=0])) & isTrial(~isnan(pokelog));
    
    attemptPokes = justPokes(relevantIdx);
    attemptTimes = justTS(relevantIdx);
    attemptTrial = justTrial(relevantIdx);
    
end

function [rewardPort, rewardTrial, rewardTimes] = getRewards(timestamps, displog, codelog, ipi)
    isDisp = ~isnan(displog);

    trialNum = strcmp(codelog,'110');
    trialNum = cumsum(trialNum);

    rewardPort = displog(isDisp);
    rewardTimes = timestamps(isDisp);
    rewardTrial = trialNum(isDisp);

end

function updateAttempts(fig, timestamps, pokelog, codelog, ipi)
    [pk, ~, ~] = getAttempts(timestamps, pokelog, codelog, ipi);

    fig.Data = pk;
    binTops = fig.BinCounts;
    % binCenters = fig.BinEdges(1:end-1) + diff(fig.BinEdges)/2;
    % text(binCenters, binTops, string(binTops), ...
    %     'VerticalAlignment','bottom', ...
    %     'HorizontalAlignment','center');
    fig.Parent.YLim = [0 max(binTops)+1];
end
