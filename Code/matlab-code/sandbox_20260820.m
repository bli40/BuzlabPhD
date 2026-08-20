%% Initiate Sandbox
% Exploratory code for ripple induction analysis
clear all; close all; 
cd("C:\Users\brian\Documents\BYL\project-opto-ripples\M008\")
sessionDir = uigetdir;
cd(sessionDir);

%% Load data
sleepscorefiles = dir("*SleepScoreLFP*");
load(sleepscorefiles.name);

ripplefiles = dir("*ripples*");
for i = 1:numel(ripplefiles)
    load(ripplefiles(i).name);
end

optofile = dir("*optogenetics.events.mat*");
load(optofile.name);

sessioninfofile = dir("*sessionInfo.mat");
load(sessioninfofile.name);

sessionfile = dir("*session.mat");
load(sessionfile.name);
disp('session files, sleep scoring, ripple files, and opto files loaded.')
%% Load LFP and bandpass filter
[~,basename,~] = fileparts(pwd);
pyrCh = ripples.detectorinfo.detectionchannel;
pyrLFP = bz_GetLFP(pyrCh,'fromDat',true,'basename',basename);

fs = pyrLFP.samplingRate;
fr = [30 100];
[b,a] = butter(2,fr/(fs/2));
bpLFP = filtfilt(b,a,double(pyrLFP.data));
%% Induced Response
[wt,f] = cwt(double(pyrLFP.data), pyrLFP.samplingRate,'FrequencyLimits',[0.1 300]);
%% Evoked Response
numPulsesPer = 100;
time_window = [-.150 .150]; % seconds before and after event
sample_window = time_window * pyrLFP.samplingRate / 1000;

stimdurms = round(optogenetics.duration*1000); % milliseconds
durations = unique(stimdurms);
intensities = unique(optogenetics.intensity);

isi = diff(optogenetics.On);
lastStims = [0; find(isoutlier(isi)); numel(optogenetics.duration)];
numPulses = diff(lastStims);

stimGroup = cell(size(optogenetics.intensity));
for g = 1:numel(lastStims)-1
    stimGroup{g} = lastStims(g)+1:lastStims(g+1);

end

keep = cellfun(@numel,stimGroup) >= numPulsesPer;
stimGroup = stimGroup(keep);
stimGroup = reshape(stimGroup,3,3); % duration x intensity matrix

% --- event-triggered averages
data = bpLFP;
timestamps = pyrLFP.timestamps;
for d = 1:numel(durations)
    for i = 1:numel(intensities)
        eta{d,i} = byl_GetETA(optogenetics.timestamps(stimGroup{d,i},1), ...
                              data, ...
                              timestamps, ...
                              'durations',time_window, ...
                              'frequency',pyrLFP.samplingRate);
    end
end

% --- plot evoked response
f1 = figure(1); clf; hold on;
tile1 = tiledlayout(1,3,'TileSpacing','compact','Padding','compact');
title(tile1,sprintf('Evoked Reponse: Band-Pass %i - %i Hz',fr(1), fr(2)));
for i = 1:size(eta,2)
    n(i) = nexttile(i); hold on;
    title(sprintf("Intensity %i",intensities(i)));
    for d = 1:size(eta,1)
        plot(eta{d,i}.window, eta{d,i}.avg, ...
            'LineWidth',1.5, ...
            'DisplayName',sprintf("%i ms",durations(d)));
        YL = ylim;
        line([0 0],YL,'Color','r','HandleVisibility','off')
    end
    legend();
end
linkaxes(n,'xy')

figure(2); clf; hold on;
a = nebula(3);
b = copper(3);
c = summer(6);
col = [a;b;c(1:3,:)];
for i = 1:size(eta,2)
    for d = 1:size(eta,1)
        linInd = (i-1)*3 + d;
        plot(eta{d,i}.window, eta{d,i}.avg, ...
            'Color',b(i,:), ...
            'LineWidth',2, ...
            'DisplayName',sprintf("%i ms @ %i",durations(d),intensities(i)));
    end
    legend();
end

%% all evoked responses

allETA = byl_GetETA(optogenetics.timestamps(:,1), pyrLFP.data, pyrLFP.timestamps,'durations',time_window,'frequency',pyrLFP.samplingRate);

%% wavelets
close all;
for i = 1:size(eta,2)
    for d = 1:size(eta,1)
        for n = 1:size(eta{d,i}.chunks,1)
            [wt,f] = cwt(eta{d,i}.chunks(n,:),'Amor',pyrLFP.samplingRate,'FrequencyLimits',[50 250]);
            psd(n,:) = mean(abs(wt),2);
        end


        % [wt,f] = cwt(eta{d,i}.avg,"Amor",20000,'FrequencyLimits',[50  250]);
        % ax = axes(figure);
        % surf(ax,eta{d,i}.window,f,abs(wt),EdgeColor="none");
        % view(ax,[0,90])
        % pause
        % bz_eventWavelet(pyrLFP, optogenetics.timestamps(stimGroup{d,i},1),'tsmth',0);
    end
end

plot(f,mean(psd))
%% power spectrum 
figure(3); clf; hold on;
for i = 1:size(eta,2)
    for d = 1:size(eta,1)
        [p, f] = pspectrum(eta{d,i}.avg,pyrLFP.samplingRate);
        inducedResponse = mean(p,2);
        plot(f(f<=250),inducedResponse(f<=250));
    end
end