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
pyrLFP = bz_GetLFP(pyrCh,'fromDat',false,'basename',basename);

disp('filtering...')
fs = pyrLFP.samplingRate;
fr = [100 250];
[b,a] = butter(2,fr/(fs/2));
bpLFP = filtfilt(b,a,double(pyrLFP.data));
disp('done.')

%% Event-Triggered Responses
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
data = pyrLFP.data;
timestamps = pyrLFP.timestamps;
for d = 1:numel(durations)
    for i = 1:numel(intensities)
        eta{d,i} = byl_GetETA(optogenetics.timestamps(stimGroup{d,i},1), ...
                              data, ...
                              timestamps, ...
                              'durations',time_window, ...
                              'samplerate',pyrLFP.samplingRate);
        baselines{d,i} = byl_GetETA(optogenetics.timestamps(stimGroup{d,i},1), ...
                              data, ...
                              timestamps, ...
                              'durations',[-.5 -.2], ...
                              'samplerate',pyrLFP.samplingRate);
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


%% wavelets optostims
close all;
fr = [1 300];
clear tp bslpwr bslmean dbcorr_tp ip dbcorr_ip dbcorr_ep phang_tp
for i = 1:size(eta,2)
    for d = 1:size(eta,1)
        wt = cwt(eta{d,i}.avg,'amor',pyrLFP.samplingRate,'FrequencyLimits',fr);
        bl = cwt(baselines{d,i}.avg,'amor',pyrLFP.samplingRate,'FrequencyLimits',fr);
        blp = mean(abs(bl).^2,2);
        wtp = abs(wt).^2;
        erpp = 10*log10(wtp./blp);

        for n = 1:size(eta{d,i}.chunks,1)
            % --- total baseline power
            [bwt,f] = cwt(baselines{d,i}.chunks(n,:),'amor',pyrLFP.samplingRate,'FrequencyLimits',fr);
            bslpwr(:,:,n) = abs(bwt).^2;
            bslmean(:,n) = mean(bslpwr(:,:,n),2);

            % --- total power
            [wt,f] = cwt(eta{d,i}.chunks(n,:),'amor',pyrLFP.samplingRate,'FrequencyLimits',fr);
            tp(:,:,n) = abs(wt).^2;
            dbcorr_tp(:,:,n) = 10*log10(tp(:,:,n)./bslmean(:,n));

            % --- non-phase locked (induced) power
            npwf = eta{d,i}.chunks(n,:) - eta{d,i}.avg;
            [iwt, f] = cwt(baselines{d,i}.chunks(n,:),'amor',pyrLFP.samplingRate,'FrequencyLimits',fr);
            ip(:,:,n) = abs(iwt).^2;
            dbcorr_ip(:,:,n) = 10*log10(ip(:,:,n)./bslmean(:,n));

            % --- phase locked (evoked) power
            dbcorr_ep(:,:,n) = dbcorr_tp(:,:,n) - dbcorr_ip(:,:,n);

            % --- phase angles
            phang_tp(:,:,n) = angle(wt);
            phang_bl(:,:,n) = angle(bwt);
        end

        figure(3*(i-1)+d);
        tt = tiledlayout(3,5,'TileSpacing','compact','Padding','compact');
        title(tt,sprintf('%i ms pulse @ %i',durations(d),intensities(i)), ...
            'Color','b','FontSize',20,'FontWeight','bold');
        colormap(turbo)

        % --- total power
        nt1 = nexttile(1);
        pcolor(1000*eta{d,i}.window,f,mean(tp,3),EdgeColor="none");
        colorbar();
        title(nt1,'total power','FontSize',14)
        nt1.TitleHorizontalAlignment = 'left';
        ylabel('frequency (Hz)');
        xlabel('time (ms)')

        % --- total power dB corrected
        nt2 = nexttile(2);
        pcolor(1000*eta{d,i}.window,f,mean(dbcorr_tp,3),EdgeColor="none");
        colorbar();
        title(nt2,'total power (dB corrected)','FontSize',14)
        nt2.TitleHorizontalAlignment = 'left';
        ylabel('frequency (Hz)');
        xlabel('time (ms)')
        s = gca;
        % clim([0-(diff(round(s.CLim))/2) 0+(diff(round(s.CLim))/2)]);

        % --- baseline power
        nt3 = nexttile(11);
        title(nt3,'baseline','FontSize',14)
        nt3.TitleHorizontalAlignment = 'left';
        yyaxis left;
        ylabel(nt3,'frequency (Hz)');
        xlabel('time (ms)')
        pcolor(1000*baselines{d,i}.window,f,mean(bslpwr,3),EdgeColor="none");
        colorbar();
        hold on; yyaxis right;
        plot(1000*baselines{d,i}.window, baselines{d,i}.avg, ...
            'LineWidth',1.5,'Color','white')

        % --- ERP power
        nt4 = nexttile(6);
        title(nt4,'ERP power','FontSize',14)
        nt4.TitleHorizontalAlignment = 'left';
        yyaxis left;
        ylabel(nt4,'frequency (Hz)');
        xlabel('time (ms)')
        pcolor(1000*eta{d,i}.window,f,wtp,EdgeColor="none");
        colorbar();
        hold on; yyaxis right
        plot(1000*eta{d,i}.window, eta{d,i}.avg, ...
            'LineWidth',1.5,'Color','white')
        

        % --- ERP power dB corrected
        nt5 = nexttile(7);
        pcolor(1000*eta{d,i}.window,f,erpp,EdgeColor="none");
        colorbar();
        title(nt5,'ERP power (dB corrected)','FontSize',14)
        nt5.TitleHorizontalAlignment = 'left';
        ylabel('frequency (Hz)');
        xlabel('time (ms)')
        s = gca;
        % clim([0-(diff(round(s.CLim))/2) 0+(diff(round(s.CLim))/2)]);

        % --- non-phase locked power (induced)
        nt6 = nexttile(3);
        pcolor(1000*eta{d,i}.window,f,mean(dbcorr_ip,3),EdgeColor="none");
        colorbar();
        title(nt6,'induced power (npl)','FontSize',14)
        nt6.TitleHorizontalAlignment = 'left';
        ylabel('frequency (Hz)');
        xlabel('time (ms)')
        s = gca;
        % clim([0-(diff(round(s.CLim))/2) 0+(diff(round(s.CLim))/2)]);

        % --- phase locked power (evoked)
        nt7 = nexttile(8);
        pcolor(1000*eta{d,i}.window,f,mean(dbcorr_ep,3),EdgeColor="none");
        colorbar();
        title(nt7,'evoked power (pl)','FontSize',14)
        nt7.TitleHorizontalAlignment = 'left';
        ylabel('frequency (Hz)');
        xlabel('time (ms)')
        s = gca;
        % clim([0-(diff(round(s.CLim))/2) 0+(diff(round(s.CLim))/2)]);

        % --- baseline inter-trial phase coherence
        nt8 = nexttile(12);
        itpc_bl = abs(mean(exp(1i*phang_bl),3));
        pcolor(1000*eta{d,i}.window,f,itpc_bl,EdgeColor="none");
        colorbar();
        title(nt8,'baseline ITPC','FontSize',14)
        nt8.TitleHorizontalAlignment = 'left';
        ylabel('frequency (Hz)');
        xlabel('time (ms)')
        s = gca;
        % clim([0-(diff(round(s.CLim))/2) 0+(diff(round(s.CLim))/2)]);

        % --- inter-trial phase coherence
        nt9 = nexttile(13);
        itpc_tp = abs(mean(exp(1i*phang_tp),3));
        pcolor(1000*eta{d,i}.window,f,itpc_tp-itpc_bl,EdgeColor="none");
        colorbar();
        title(nt9,'ITPC (baseline subtracted)','FontSize',14)
        nt9.TitleHorizontalAlignment = 'left';
        ylabel('frequency (Hz)');
        xlabel('time (ms)')
        s = gca;
        % clim([0-(diff(round(s.CLim))/2) 0+(diff(round(s.CLim))/2)]);

        % pause
        % bz_eventWavelet(pyrLFP, optogenetics.timestamps(stimGroup{d,i},1), ...
        %     'samplingRate',pyrLFP.samplingRate,'twin',[.1 .1],'ncyc',5,'frange',[1 350]);
    end
end

%% wavelets ripples
dt = pyrLFP.data;
ts = pyrLFP.timestamps;
sr = pyrLFP.samplingRate;
ev = ripples.peaks;
tw = [-.15 .15];
bw = [-.5 -.2];
fr = [1 300];


rta = byl_GetETA(ev,dt,ts,'durations',tw,'sampleRate',sr);
rtb = byl_GetETA(ev,dt,ts,'durations',bw,'sampleRate',sr);

[wt,f] = cwt(rta.avg,'amor',pyrLFP.samplingRate,'FrequencyLimits',fr);
bl = cwt(rtb.avg,'amor',pyrLFP.samplingRate,'FrequencyLimits',fr);
blp = mean(abs(bl).^2,2);
wtp = abs(wt).^2;
erpp = 10*log10(wtp./blp);

for n = 1:size(rta.chunks,1)
    % --- total baseline power
    bwt = cwt(rtb.chunks(n,:),'amor',pyrLFP.samplingRate,'FrequencyLimits',fr);
    bslpwr(:,:,n) = abs(bwt).^2;
    bslmean(:,n) = mean(bslpwr(:,:,n),2);

    % --- total power
    [wt] = cwt(rta.chunks(n,:),'amor',pyrLFP.samplingRate,'FrequencyLimits',fr);
    tp(:,:,n) = abs(wt).^2;
    dbcorr_tp(:,:,n) = 10*log10(tp(:,:,n)./bslmean(:,n));

    % --- non-phase locked (induced) power
    npwf = rta.chunks(n,:) - rta.avg;
    [iwt, f] = cwt(rtb.chunks(n,:),'amor',pyrLFP.samplingRate,'FrequencyLimits',fr);
    ip(:,:,n) = abs(iwt).^2;
    dbcorr_ip(:,:,n) = 10*log10(ip(:,:,n)./bslmean(:,n));

    % --- phase locked (evoked) power
    dbcorr_ep(:,:,n) = dbcorr_tp(:,:,n) - dbcorr_ip(:,:,n);

    % --- phase angles
    phang_tp(:,:,n) = angle(wt);
    phang_bl(:,:,n) = angle(bwt);
end

figure(10);
tt = tiledlayout(3,5,'TileSpacing','compact','Padding','compact');
title(tt,sprintf('Sharp-Wave Ripples (%i)',numel(ripples.peaks)), ...
    'Color','b','FontSize',20,'FontWeight','bold');
colormap(turbo)

% --- total power
nt1 = nexttile(1);
pcolor(1000*rta.window,f,mean(tp,3),EdgeColor="none");
colorbar();
title(nt1,'total power','FontSize',14)
nt1.TitleHorizontalAlignment = 'left';
ylabel('frequency (Hz)');
xlabel('time (ms)')

% --- total power dB corrected
nt2 = nexttile(2);
pcolor(1000*rta.window,f,mean(dbcorr_tp,3),EdgeColor="none");
colorbar();
title(nt2,'total power (dB corrected)','FontSize',14)
nt2.TitleHorizontalAlignment = 'left';
ylabel('frequency (Hz)');
xlabel('time (ms)')
s = gca;
% clim([0-(diff(round(s.CLim))/2) 0+(diff(round(s.CLim))/2)]);

% --- baseline power
nt3 = nexttile(11);
title(nt3,'baseline','FontSize',14)
nt3.TitleHorizontalAlignment = 'left';
yyaxis left;
ylabel(nt3,'frequency (Hz)');
xlabel('time (ms)')
pcolor(1000*rtb.window,f,mean(bslpwr,3),EdgeColor="none");
colorbar();
hold on; yyaxis right;
plot(1000*rtb.window, rtb.avg, ...
    'LineWidth',1.5,'Color','white')

% --- ERP power
nt4 = nexttile(6);
title(nt4,'ERP power','FontSize',14)
nt4.TitleHorizontalAlignment = 'left';
yyaxis left;
ylabel(nt4,'frequency (Hz)');
xlabel('time (ms)')
pcolor(1000*rta.window,f,wtp,EdgeColor="none");
colorbar();
hold on; yyaxis right
plot(1000*rta.window, rta.avg, ...
    'LineWidth',1.5,'Color','white')


% --- ERP power dB corrected
nt5 = nexttile(7);
pcolor(1000*rta.window,f,erpp,EdgeColor="none");
colorbar();
title(nt5,'ERP power (dB corrected)','FontSize',14)
nt5.TitleHorizontalAlignment = 'left';
ylabel('frequency (Hz)');
xlabel('time (ms)')
s = gca;
% clim([0-(diff(round(s.CLim))/2) 0+(diff(round(s.CLim))/2)]);

% --- non-phase locked power (induced)
nt6 = nexttile(3);
pcolor(1000*rta.window,f,mean(dbcorr_ip,3),EdgeColor="none");
colorbar();
title(nt6,'induced power (npl)','FontSize',14)
nt6.TitleHorizontalAlignment = 'left';
ylabel('frequency (Hz)');
xlabel('time (ms)')
s = gca;
% clim([0-(diff(round(s.CLim))/2) 0+(diff(round(s.CLim))/2)]);

% --- phase locked power (evoked)
nt7 = nexttile(8);
pcolor(1000*rta.window,f,mean(dbcorr_ep,3),EdgeColor="none");
colorbar();
title(nt7,'evoked power (pl)','FontSize',14)
nt7.TitleHorizontalAlignment = 'left';
ylabel('frequency (Hz)');
xlabel('time (ms)')
s = gca;
% clim([0-(diff(round(s.CLim))/2) 0+(diff(round(s.CLim))/2)]);

% --- baseline inter-trial phase coherence
nt8 = nexttile(12);
itpc_bl = abs(mean(exp(1i*phang_bl),3));
pcolor(1000*rta.window,f,itpc_bl,EdgeColor="none");
colorbar();
title(nt8,'baseline ITPC','FontSize',14)
nt8.TitleHorizontalAlignment = 'left';
ylabel('frequency (Hz)');
xlabel('time (ms)')
s = gca;
% clim([0-(diff(round(s.CLim))/2) 0+(diff(round(s.CLim))/2)]);

% --- inter-trial phase coherence
nt9 = nexttile(13);
itpc_tp = abs(mean(exp(1i*phang_tp),3));
pcolor(1000*rta.window,f,itpc_tp-itpc_bl,EdgeColor="none");
colorbar();
title(nt9,'ITPC (baseline subtracted)','FontSize',14)
nt9.TitleHorizontalAlignment = 'left';
ylabel('frequency (Hz)');
xlabel('time (ms)')
s = gca;
% clim([0-(diff(round(s.CLim))/2) 0+(diff(round(s.CLim))/2)]);
%%
% --- ripple stats
figure(10);

nt10 = nexttile(4);
dur = rippleStats.data.duration;
nbins = 50;
edges = logspace(floor(log10(min(dur))), ceil(log10(max(dur))), nbins+1);
histogram(dur, 'BinEdges',edges);
set(gca, "Xscale", "log")
title(nt10, 'log ripple duration','FontSize',14);
nt10.TitleHorizontalAlignment = 'left';



nt11 = nexttile(5);
iri = diff(ripples.peaks);
nbins = 50;
edges = logspace(floor(log10(min(iri))), ceil(log10(max(iri))), nbins+1);
histogram(iri, 'BinEdges',edges);
set(gca, "Xscale", "log")
title(nt11, 'log inter-ripple interval','FontSize',14);
nt11.TitleHorizontalAlignment = 'left';


nt12 = nexttile(9);
leadlags = optogenetics.timestamps(:,1)' - ripples.peaks(:);
closest_stim_ab = min(abs(leadlags),[],2);
closest_stim_logi = ismember(abs(leadlags),closest_stim_ab);
closest_stim = leadlags(closest_stim_logi);
% closest_stim(abs(closest_stim) > 1) = [];
nbins = 50;
edges = logspace(floor(log10(min(iri))), ceil(log10(max(iri))), nbins+1);
histogram(closest_stim, 'BinEdges',edges);
set(gca, "Xscale", "log")