%% List Files
clear all; close all;
% --- list files to be looked at
sessdir = pwd;
preprocessedPaths = dir(fullfile(sessdir,'\*.photometry.*.mat'));
[~,name,~] = fileparts(sessdir);
fprintf('<strong>%s</strong>\n',name)
if numel(preprocessedPaths) ~= 0
    for e = 1:numel(preprocessedPaths)
        sessionName = split(preprocessedPaths(e).name,'.');
        fprintf(2,'<strong>\t%s\n</strong>',preprocessedPaths(e).name);
    end
end

% --- load files
try
    d = (dir(fullfile(sessdir,'N*.session.mat')));
    load(fullfile(d(1).folder, d(1).name))
catch
    disp('No session.mat file');
end

try
    d = (dir(fullfile('N*.behavior.matrices.mat')));
    load(fullfile(d(1).folder, d(1).name))

    d = (dir(fullfile('N*.TrialBehavior.mat')));
    load(fullfile(d(1).folder, d(1).name))

    d = (dir(fullfile('N*.Tracking.Behavior.mat')));
    load(fullfile(d(1).folder, d(1).name))
catch
    disp('No behavioral data.');
end

try
    d = (dir(fullfile('N*.ripples.events.mat')));
    load(fullfile(d(1).folder, d(1).name))
    
    d = (dir(fullfile('N*.ripples.stats.mat')));
    load(fullfile(d(1).folder, d(1).name));

    d = (dir(fullfile('N*.ripples.bursts.mat')));
    load(fullfile(d(1).folder, d(1).name))
catch
    disp('No ripple detection.')
end

try
    d = (dir(fullfile('N*.SleepState.states.mat')));
    load(fullfile(d(1).folder, d(1).name))
catch
    disp('No sleep scoring.')
end

try
    d = dir(fullfile('N*.photometry.*.mat'));
    for re = 1:numel(d)
       photom{re} = load(fullfile(d(re).folder, d(re).name)); 
    end
    
    try
        photom_hpc = photom{contains({d(:).name},'HPC')}.concPhotom;
    catch
        disp('No HPC Data');
    end
    
    try
        photom_str = photom{contains({d(:).name},'STR')}.concPhotom;
    catch
        disp('No STR Data');
    end
    
    try
        photom_pfc = photom{contains({d(:).name},'PFC')}.concPhotom;
    catch
        disp('No PFC Data');
    end
catch
    disp('No photometry preprocessed.')
end

try
    d = (dir(fullfile('N*.MergePoints.events.mat')));
    load(fullfile(d(1).folder, d(1).name))
catch
    disp('No MergePoints')
end

fprintf('%s - data loaded\n',name)

%% Mean Stimulation Time
stimOnOff = photom_hpc.stimpulseOnOff;
if ~isempty(stimOnOff)
    stimDur = stimOnOff(:,2) - stimOnOff(:,1);
else
    fprintf('%s - no stimulation\n',name)
end


%% Custom Color Map

ogCol = lines(7);
gradCol = cell(1,size(ogCol,1));
for c = 1:size(ogCol,1)
    gradCol{c} = customcolormap([0 0.5 1], [1 1 1; ogCol(c,:); 0 0 0],101);
    gradCol{c} = gradCol{c}([20 50 80],:);
end
blue = gradCol{1};
orange = gradCol{2};
yellow = gradCol{3};
purple = gradCol{4};
green = gradCol{5};
blue2 = gradCol{6};
red = gradCol{7};

fprintf('%i new colormaps added!\n',size(gradCol,2));


%% Quick Plot (upcoming: make pretty)
[~,name,~] = fileparts(sessdir);

% figure initiate
f1 = figure(1); clf; hold on;
f1.Units = 'normalized';
f1.Position = [0 0.05 1 0.865];
tiledlayout(3,6,'TileSpacing','tight','Padding','tight');
sgtitle(sprintf('%s',name),'Interpreter','none');

sessionEndTime = max(cellfun(@(x) x.concPhotom.timestamps(end), photom));
sessionStartTime = min(cellfun(@(x) x.concPhotom.timestamps(1), photom));

YL = [-10 10];
XL = [sessionStartTime - 100, sessionEndTime + 1500];


d = dir(fullfile('N*.photometry.*.mat'));
possibleRegions = {'HPC','STR','PFC'};
whichRegions = extractBetween({d.name},'photometry.','.mat');



% --- SESSION METRICS
nexttile(1,[3,1]); cla; hold on;
title('SESSION METRICS','Color','black','FontSize',12);
set(gca, 'Color', 'none'); % Axes background   
axis off

% durations
secondsTotal = sessionEndTime - sessionStartTime;
h = floor(secondsTotal / 3600);
m = floor(mod(secondsTotal, 3600) / 60);
s = mod(secondsTotal, 60);
text(0, 1, sprintf('Duration: %ih %im %0.2fs',h,m,s),...
    'VerticalAlignment','top','FontSize',12);
numEpochs = numel(photom_hpc.epochNames);
for e = 1:numEpochs
    epochEndTime = max(cellfun(@(x) x.concPhotom.epochs(e,2), photom));
    epochStartTime = min(cellfun(@(x) x.concPhotom.epochs(e,1), photom));
    secondsTotal = epochEndTime - epochStartTime;
    h = floor(secondsTotal / 3600);
    m = floor(mod(secondsTotal, 3600) / 60);
    s = mod(secondsTotal, 60);
    text(0.6, 1-(e*0.02), sprintf('%s:  %ih %im %0.2fs',photom_hpc.epochNames{e},h,m,s), ...
        'VerticalAlignment','top','HorizontalAlignment','right','color','red','Interpreter','none');
end


% ripples
for e = 1:numEpochs
    epIdx{e} = rippleBurst.ripburst(:,1) >= photom_hpc.epochs(e,1) & rippleBurst.ripburst(:,1) <= photom_hpc.epochs(e,2);
    countByEp(1,e) = [sum(rippleBurst.ripburstsize == 1 & epIdx{e})];
    countByEp(2,e) = [sum(rippleBurst.ripburstsize == 2 & epIdx{e})];
    countByEp(3,e) = [sum(rippleBurst.ripburstsize == 3 & epIdx{e})];
    countByEp(4,e) = [sum(rippleBurst.ripburstsize >= 4 & epIdx{e})];
end
text(0, 0.88, sprintf('Ripples: %i',numel(ripples.peaks)),...
    'VerticalAlignment','top','FontSize',12);
                  
text(0.1, 0.86, sprintf(['1s: %i ',repmat('(%i) ',1,numEpochs)],sum(rippleBurst.ripburstsize == 1),countByEp(1,:)), ...
        'VerticalAlignment','top','HorizontalAlignment','left','color',blue(:,1),'Interpreter','none');
text(0.1, 0.84, sprintf(['2s: %i ',repmat('(%i) ',1,numEpochs)],sum(rippleBurst.ripburstsize == 2),countByEp(2,:)), ...
        'VerticalAlignment','top','HorizontalAlignment','left','color',blue(:,2),'Interpreter','none');
text(0.1, 0.82, sprintf(['3s: %i ',repmat('(%i) ',1,numEpochs)],sum(rippleBurst.ripburstsize == 3),countByEp(3,:)), ...
        'VerticalAlignment','top','HorizontalAlignment','left','color',blue(:,3),'Interpreter','none');
text(0.1, 0.80, sprintf(['4+: %i ',repmat('(%i) ',1,numEpochs)],sum(rippleBurst.ripburstsize >= 4),countByEp(4,:)), ...
        'VerticalAlignment','top','HorizontalAlignment','left','color','k','Interpreter','none');

text(0.1, 0.86, sprintf('1s: %i',sum(rippleBurst.ripburstsize == 1)), ...
        'VerticalAlignment','top','HorizontalAlignment','left','color',blue(:,1),'Interpreter','none');

% choose epochs to highlight
ui = [5];

% --- FLUORESCENCE BY REGION
for r = 1:numel(possibleRegions)   
    figLoc = (r-1)*6 + 2;
    nexttile(figLoc, [1 2]); hold on;
    region = contains(whichRegions, possibleRegions{r});
    if ~any(region)
        set(gca, 'Color', 'none'); % Axes background   
        axis off
        text(0.5,0.5, sprintf('NO %s PHOTOM DATA',possibleRegions{r}), ...
            'FontSize',12, ...
            'Color','r', ...
            'FontWeight','bold', ...
            'HorizontalAlignment','center');
    else
        photomIdx = photom{region}.concPhotom;
            
        for ep = 1:numel(photomIdx.epochNames)
            if ismember(ep, ui)
                patch([photomIdx.epochs(ep,1) photomIdx.epochs(ep,2) ...
                    photomIdx.epochs(ep,2) photomIdx.epochs(ep,1)], ...
                    [YL(1) YL(1) YL(2) YL(2)], ...
                    [1 0 0], 'FaceAlpha',0.1,'EdgeColor','none');
            end
            plot([photomIdx.epochs(ep,1) photomIdx.epochs(ep,1)],[-10 10], ...
                '--r')
            text(photomIdx.epochs(ep,1),YL(2)-1,photomIdx.epochNames{ep},'Color','r')
        end
        plot(photomIdx.timestamps, photomIdx.grabDA_z, ...
            'color',[0.5 0.5 0.5],'LineWidth',0.5)

        plot(rippleBurst.solos(:,1),(-4.5)*ones(size(rippleBurst.solos(:,1))),'|k','MarkerSize',7);
        plot(rippleBurst.bursts(:,1),-6*ones(size(rippleBurst.bursts(:,1))),'|b','MarkerSize',7);
        % plot(behavTrials.timestamps,(-7.5)*ones(size(behavTrials.timestamps)),'|r','MarkerSize',7)
        if ~isempty(stimOnOff)
            plot(photomIdx.stimpulseOnOff(:,1),(-9)*ones(size(photomIdx.stimpulseOnOff(:,1))), ...
                '|','Color',[0.3 0.3 0.3], 'MarkerSize',7)
        end
        text(sessionEndTime+50,-4.5,'solos','FontSize',10,'Color','k')
        text(sessionEndTime+50,-6,'bursts','FontSize',10,'Color','b')
        text(sessionEndTime+50,-7.5,'pokes','FontSize',10,'Color','r')
        text(sessionEndTime+50,-9,'stims','FontSize',10,'Color','[0.3 0.3 0.3]')
        
        xlim(XL); ylim(YL);
        xticklabels('')
        ylabel(sprintf('%s (z-score)',possibleRegions{r}))
        title(sprintf('%s Photometry Session',possibleRegions{r}));
    end

end


% --- RIPPLE TRIGGERED AVERAGES
events2plot = {'solos','duos','trios'};
durations = [-5 5];

for r = 1:numel(possibleRegions)
    figLoc = (r-1)*6 + 4;
    nexttile(figLoc); hold on;
    region = contains(whichRegions, possibleRegions{r});
    if ~any(region)
        set(gca, 'Color', 'none'); % Axes background   
        axis off
        text(0.5,0.5, sprintf('NO %s PHOTOM DATA',possibleRegions{r}), ...
            'FontSize',12, ...
            'Color','r', ...
            'FontWeight','bold', ...
            'HorizontalAlignment','center');
    else
        % --- logical indices for each epoch
        photomIdx = photom{region}.concPhotom;
        for e = 1:numel(photomIdx.epochNames)
            epIdx{e} = rippleBurst.ripburst(:,1) >= photomIdx.epochs(e,1) & rippleBurst.ripburst(:,1) <= photomIdx.epochs(e,2);
        end
        if isempty(ui)
            chosenEpochs = true(size(rippleBurst.ripburst(:,1)));
        else
            chosenEpochs = false(size(rippleBurst.ripburst(:,1)));
            for k = ui
                chosenEpochs = chosenEpochs | epIdx{k};
            end
        end
        events = {rippleBurst.ripburst(rippleBurst.ripburstsize == 1 & chosenEpochs,1),...
                  rippleBurst.ripburst(rippleBurst.ripburstsize == 2 & chosenEpochs,1),...
                  rippleBurst.ripburst(rippleBurst.ripburstsize == 3 & chosenEpochs,1)};
        data = photomIdx.grabDA_z;
        timestamps = photomIdx.timestamps;

        for e = 1:numel(events2plot)
            eta{r,e} = byl_getETA(events{e},data,timestamps, ...
                'frequency',130,'normalization','zscore','durations',durations);
            plot(eta{r,e}.window, eta{r,e}.avg, 'color', blue(e,:), 'LineWidth', 2,...
                'DisplayName',sprintf('%s (%i)',events2plot{e},numel(events{e})));
            x1 = [eta{r,e}.window, fliplr(eta{r,e}.window)];
            y = [eta{r,e}.avg + eta{r,e}.sem, fliplr(eta{r,e}.avg - eta{r,e}.sem)];
            patch(x1,y,blue(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');   
        end
        xlabel('Time from event (s)');
        ylabel('Fluorescence (z-score)');
        title(sprintf('Ripples'));
        grid on;
        legend('location','best','FontSize',6);
        set(gca,'children',flipud(get(gca,'children')))
        YLref = ylim;
    end
end

% --- NOSEPOKE TRIGGERED AVERAGES
events2plot = {'re','unre'};
try
    events = {behavTrials.timestamps(logical(behavTrials.reward_outcome)),...
              behavTrials.timestamps(~logical(behavTrials.reward_outcome))};
catch
    fprintf('no behavior\n')
    events = {};
end
durations = [-5 5];

for r = 1:numel(possibleRegions)
    figLoc = (r-1)*6 + 5;
    nexttile(figLoc); cla; hold on;
    region = contains(whichRegions, possibleRegions{r});

    if isempty(events)
        set(gca, 'Color', 'none'); % Axes background   
        axis off
        text(0.5,0.5,'NO BEHAVIOR', ...
            'FontSize',12, ...
            'Color','r', ...
            'FontWeight','bold', ...
            'HorizontalAlignment','center');
    elseif ~any(region)
        set(gca, 'Color', 'none'); % Axes background   
        axis off
        text(0.5,0.5, sprintf('NO %s PHOTOM DATA',possibleRegions{r}), ...
            'FontSize',12, ...
            'Color','r', ...
            'FontWeight','bold', ...
            'HorizontalAlignment','center');
    else
        
        photomIdx = photom{region}.concPhotom;
        data = photomIdx.grabDA_z;
        timestamps = photomIdx.timestamps;

        for e = 1:numel(events)
            eta{r,e} = byl_getETA(events{e},data,timestamps, ...
                'frequency',130,'normalization','zscore','durations',durations);
            plot(eta{r,e}.window, eta{r,e}.avg, 'color', yellow(e,:), 'LineWidth', 2,...
                'DisplayName',sprintf('%s (%i)',events2plot{e},numel(events{e})));
            x1 = [eta{r,e}.window, fliplr(eta{r,e}.window)];
            y = [eta{r,e}.avg + eta{r,e}.sem, fliplr(eta{r,e}.avg - eta{r,e}.sem)];
            patch(x1,y,yellow(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');   
        end
        xlabel('Time from event (s)');
        ylabel('Fluorescence (z-score)');
        title('Nosepokes');
        grid on;
        legend('location','best','FontSize',6);
        set(gca,'children',flipud(get(gca,'children')))
        YLref = ylim;
    end
end

% --- STIM TRIGGERED AVERAGES
events2plot = {'long','short'};
try
    events = {photom_hpc.stimpulseOnOff(stimDur > 1,1),...
              photom_hpc.stimpulseOnOff(stimDur < 1,1)};
catch
    fprintf('no stimulation\n')
    events = {};
end
durations = [-5 5];

for r = 1:numel(possibleRegions)
    figLoc = ((r-1)*6) + 6;
    nexttile(figLoc); cla; hold on;
    region = contains(whichRegions, possibleRegions{r});

    if isempty(events)
        set(gca, 'Color', 'none'); % Axes background   
        axis off
        text(0.5,0.5,'NO OPTOGENETICS', ...
            'FontSize',12, ...
            'Color','r', ...
            'FontWeight','bold', ...
            'HorizontalAlignment','center');
    elseif ~any(region)
        set(gca, 'Color', 'none'); % Axes background   
        axis off
        text(0.5,0.5, sprintf('NO %s PHOTOM DATA',possibleRegions{r}), ...
            'FontSize',12, ...
            'Color','r', ...
            'FontWeight','bold', ...
            'HorizontalAlignment','center');
    else

        photomIdx = photom{region}.concPhotom;
        data = photomIdx.grabDA_z;
        timestamps = photomIdx.timestamps;

        for e = 1:numel(events)
            eta{r,e} = byl_getETA(events{e},data,timestamps, ...
                'frequency',130,'normalization','zscore','durations',durations);
            plot(eta{r,e}.window, eta{r,e}.avg, 'color', red(e,:), 'LineWidth', 2,...
                'DisplayName',sprintf('%s (%i)',events2plot{e},numel(events{e})));
            x1 = [eta{r,e}.window, fliplr(eta{r,e}.window)];
            y = [eta{r,e}.avg + eta{r,e}.sem, fliplr(eta{r,e}.avg - eta{r,e}.sem)];
            patch(x1,y,red(e,:),'FaceAlpha', 0.5,'EdgeColor','none','HandleVisibility','off');   
        end
        xlabel('Time from event (s)');
        ylabel('Fluorescence (z-score)');
        title(sprintf('Stimulations'));
        grid on;
        legend('location','best','FontSize',6);
        set(gca,'children',flipud(get(gca,'children')))
        % YLref = ylim;
    end
end
