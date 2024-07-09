%% Start Up
clear all; close all;
addpath(genpath('C:\Users\brian\buzcode'));
addpath(genpath('C:\Users\brian\fooof_mat\fooof_mat'));
basePath = 'C:\Users\brian\OneDrive - NYU Langone Health\buzlab-phd\e13\e13_26m1\e13_26m1_210913';
cd(basePath)
%% Load LFP, Session, and Spike Data

lfp = bz_GetLFP(15, 'basepath', 'C:\Users\brian\OneDrive - NYU Langone Health\buzlab-phd\e13\e13_26m1\e13_26m1_210913');
load(fullfile(basePath,'\e13_26m1_210913.spikes.cellinfo.mat'));
load(fullfile(basePath,'\e13_26m1_210913.Behavior.mat'));
load(fullfile(basePath,'\e13_26m1_210913.cell_metrics.cellinfo.mat'));

%% Notes
% Following Geisler et al. 2010. 
% (1) Perform multi-taper estimates of lfp time-frequency (done)
% (2) Identify regions of high theta/delta ratio (done)
% (3) Isolate spikes within said regions (done)
% (4) Find the MUA oscillations and high-pass filter at 4Hz (done)
% (5) Perform multi-taper estimates of mua time-frequency (done)
% (6) Find MUA oscilations averaged over trials

%% Multitaper!!! Testing for general knowledge
figure(10);
[spectrogram, t, f] = MTSpectrogram(double(lfp.data), ...
                                    'window',1,...
                                    'range',[0 30], ...
                                    'show','off');
t = t - t(1);
thetaPower = mean(spectrogram(f>4 & f<12,:),1);
deltaPower = mean(spectrogram(f>0 & f<=4,:),1);
thetaDeltaRatio = thetaPower./deltaPower;

% Find Patches of High Theta:Delta Ratio
qt = ismember(behavior.timestamps, behavior.trials.position_trcat.timestamps);
wholeSpeed = zeros(size(behavior.timestamps));
wholeSpeed(qt) = behavior.trials.position_trcat.v;

highTDR = FindStatePatch(thetaDeltaRatio,mean(diff(t)), ...
    'maxDur',inf, ...
    'minDur',0, ...
    'lowThresholdFactor',2);


% Compute spectrum
[stat, int, ind] = InIntervals(t,highTDR.timestamps);
mu = mean(spectrogram(:,stat),2);
v = var(spectrogram(:,stat),0,2);

figure(1); clf; hold on;
%logSpectrum = log(spectrum);         % classic value
logSpectrum = log(mu)-v./(2*mu.*mu);  % corrected value, valid for mu/s > 1.5
logS = sqrt(v./mu.^2);               % valid for mu/s > 2.5
PlotMean(f,logSpectrum,logSpectrum-logS,logSpectrum+logS,':','b');
xlabel('Frequency (Hz)');
ylabel('Power');
title('Power Spectrum LFP');




%% Plot Multi-Taper Estimates

fig = gcf;
fig.Units = 'normalized';
fig.Position = [0 0.3 1 0.45];
colormap("jet")

windows = t(1:500:numel(t));
win = 1;
livePlot = true;
logTransformed = log(abs(spectrogram));

while livePlot
    clf; hold on;
    xlabel('Time (s)');
	ylabel('Frequency (Hz)');
	title('Power Spectrogram');
    xlim([windows(win) windows(win+1)]);

    specIdx = t >= windows(win) & t <= windows(win+1);
    velIdx = behavior.timestamps >= windows(win) & behavior.timestamps <= windows(win+1);
    tdrIndA = find(highTDR.timestamps(:,1) <= windows(win),1,'first');
    if isempty(tdrIndA)
        tdrIndA = find(highTDR.timestamps(:,1) >= windows(win),1,'first');
    end
    tdrIndB = find(highTDR.timestamps(:,2) >= windows(win+1),1,'first');
    if isempty(tdrIndB)
        tdrIndB = find(highTDR.timestamps(:,2) <= windows(win+1),1,'first');
    end
    tdrIdx = tdrIndA:tdrIndB;

    PlotColorMap(logTransformed(:,specIdx),1, ...
        'x',t(specIdx), ...
        'y',f, ...
        'cutoffs',[0 13], ...
        'newfig','off');
	
    
    yyaxis right;
    plot(t(specIdx),thetaDeltaRatio(specIdx),'color',[0.5 0.5 0.5],'LineWidth',1)
    plot(behavior.timestamps, wholeSpeed,'-r')
    ylim([-20 30])
    yline(2);
    % ylim([-20 30])
    for i = 1:numel(tdrIdx)
        x = sort([highTDR.timestamps(tdrIdx(i),:) highTDR.timestamps(tdrIdx(i),:)]);
        y = [ylim flip(ylim)];
        patch(x,y,'black','FaceAlpha',0.4,'EdgeAlpha',0)
    end


    % UI stuff
    was_a_key = waitforbuttonpress;
    if was_a_key && strcmp(get(fig,'CurrentKey'),'rightarrow')
        if win < numel(windows)-1
            win = win+1;
        else
            disp('At session end!')
            continue;
        end
    elseif was_a_key && strcmp(get(fig,'CurrentKey'),'leftarrow')
        if win > 1
            win = win-1;
        else
            disp('At session start!')
            continue;
        end
    elseif was_a_key && strcmp(get(fig,'CurrentKey'),'0')
        win = 1;
    elseif was_a_key && strcmp(get(fig,'CurrentKey'),'9')
        win = numel(windows)-1;
    elseif was_a_key && any(strcmp(get(fig,'CurrentKey'),{'1','2','3','4','5','6','7','8'}))
        keyhit = str2double(get(fig,'CurrentKey'));
        [~,E,~] = histcounts(1:numel(windows)-1,9);
        E = floor(E);
        win = E(keyhit+1); 
    elseif was_a_key && strcmp(get(fig,'CurrentKey'),'escape')
        livePlot = false;
        close all;
    
    else
        continue;
    end
end

%% MUA
figure(2)
pyramidal = (strcmp(cell_metrics.putativeCellType, "Pyramidal Cell"))';
narrowinter = (strcmp(cell_metrics.putativeCellType, "Narrow Interneuron"))';
wideinter = (strcmp(cell_metrics.putativeCellType, "Wide Interneuron"))';

mua = cat(1,spikes.times{pyramidal});
mua = sort(mua);
[stat,int,ind] = InIntervals(mua,highTDR.timestamps);
mua = mua(stat);
muaFreq = Frequency(mua,'binSize',0.02);

fc = 4;
fs = 1/0.02;
[b,a] = butter(5,(fc/(fs/2)),'high');
muaFreqFilt = filtfilt(b,a,muaFreq(:,2));
[unitSpectrogram,t,f] = MTSpectrogram(muaFreqFilt, ...
                                      'frequency',50,...
                                      'window',1, ...
                                      'range',[0 30], ...
                                      'show','on');
% [stat, int, ind] = InIntervals(t,highTDR.timestamps);
mu = mean(unitSpectrogram,2);
v = var(unitSpectrogram,0,2);

figure(3); clf; hold on;
%logSpectrum = log(spectrum);         % classic value
logSpectrum = log(mu)-v./(2*mu.*mu);  % corrected value, valid for mu/s > 1.5
logS = sqrt(v./mu.^2);               % valid for mu/s > 2.5
PlotMean(f,logSpectrum,logSpectrum-logS,logSpectrum+logS,':','r');
xlabel('Frequency (Hz)');
ylabel('Power');
title('Power Spectrum MUA');

%% Bandpass filter and Hilbert Transform -> Theta Phase Precession
fb = [5 12];
fs = lfp.samplingRate;
[b,a] = butter(3, fb./(fs/2));
thetaBand = filtfilt(b,a,double(lfp.data));
thetaComplex = hilbert(thetaBand);
instantPhase = unwrap(angle(thetaComplex));

rightArm = find(behavior.trials.visitedArm);
leftArm = find(~behavior.trials.visitedArm);

rightIdx = ismember(behavior.masks.trials, rightArm);
leftIdx = ismember(behavior.masks.trials, leftArm);

rightInts = bz_IDXtoINT(rightIdx,'timestamps',behavior.timestamps);
leftInts = bz_IDXtoINT(leftIdx,'timestamps',behavior.timestamps);

qt = ismember(behavior.timestamps, behavior.trials.position_trcat.timestamps);
wholeSpeed = zeros(size(behavior.timestamps));
wholeSpeed(qt) = behavior.trials.position_trcat.v;

for unit = 1:spikes.numcells
    spikeTimes = spikes.times{unit};
    spikePos = interp1(behavior.timestamps, behavior.position.lin, spikeTimes);
    spikePhase = interp1(lfp.timestamps, instantPhase, spikes.times{unit});
    spikePhase= wrapTo2Pi(spikePhase);
    spikeVels = interp1(behavior.timestamps, wholeSpeed, spikes.times{unit});
    fastEnough = spikeVels >= 10;

    [right,~,~] = InIntervals(spikeTimes,rightInts.state1);
    [left,~,~] = InIntervals(spikeTimes,leftInts.state1);

    spikeRtTimes = spikeTimes(right);
    spikeLtTimes = spikeTimes(left);

    spikeRPos = spikePos(right & fastEnough);
    spikeLPos = spikePos(left & fastEnough);
    
    spikeRPhz = spikePhase(right & fastEnough);
    spikeLPhz = spikePhase(left & fastEnough);

    figure(1); clf; hold on;
    plot(spikeRPos, spikeRPhz,'.r','MarkerSize',12);
    plot(spikeLPos, spikeLPhz,'.b','MarkerSize',12);
    xlabel('Linearized Position');
    ylabel('Theta Phase');
    title(sprintf('Cell #%d - %s, %f',...
        unit,cell_metrics.putativeCellType{unit}),cell_metrics.thetaModulationIndex(unit));
    pause;

end

%% Trial Velocity Masking (scratch)
trials = unique(behavior.masks.trials(~isnan(behavior.masks.trials)));
trialTimesInds = ismember(behavior.timestamps, behavior.trials.position_trcat.timestamps);

% % Calculated speed from recorded positions is the same as the velocity
% % field in behavior.
% spd = sqrt((diff(behavior.position.x).^2)+(diff(behavior.position.y).^2))./diff(behavior.timestamps);
% spd = [movmean(spd,15); spd(end)];
hold on;
rewardTimes = sort([behavior.events.lReward; behavior.events.rReward]);

for i = 1:numel(trials)
%     trx = behavior.masks.trials==i;
    trx = (behavior.timestamps >= behavior.events.endDelay(i) & ...
        behavior.timestamps <= behavior.events.startDelay(i+1));
    startDelayWin = find(behavior.timestamps >= behavior.events.startDelay(i) & ...
               behavior.timestamps <= behavior.events.endDelay(i));
    endDelayWin = find(behavior.timestamps >= behavior.events.startDelay(i+1) & ...
               behavior.timestamps <= behavior.events.endDelay(i+1));
    rewardInd = find(behavior.timestamps>=rewardTimes(i),1,'first');

    trialRunInds = ismember(behavior.trials.position_trcat.timestamps,behavior.timestamps(trx));

    goalRunInds = behavior.trials.position_trcat.timestamps >= behavior.events.endDelay(i) & ...
                  behavior.trials.position_trcat.timestamps <= rewardTimes(i);

    fastEnough = behavior.trials.position_trcat.v >= 10;
    fastEnough = ismember(behavior.timestamps,behavior.trials.position_trcat.timestamps(fastEnough));
    trialVel = behavior.trials.position_trcat.v(trialRunInds);
    goalVel = behavior.trials.position_trcat.v(goalRunInds);
    trTime = behavior.trials.position_trcat.timestamps(trialRunInds);
    
    clf; hold on;

%     plot(behavior.trials.position_trcat.timestamps(trialRunInds), trialVel);
%     plot(behavior.trials.position_trcat.timestamps(goalRunInds), goalVel,'.r','MarkerSize',4);


    plot(behavior.position.x(trx),...
         behavior.position.y(trx),...
         '.','color',[0.5 0.5 0.5],'MarkerSize',4)
    plot(behavior.position.x(fastEnough&trx),...
         behavior.position.y(fastEnough&trx),...
         'ob','MarkerSize',4)
    plot(behavior.position.x(endDelayWin),...
         behavior.position.y(endDelayWin),...
         'sr','MarkerSize',5)
    plot(behavior.position.x(startDelayWin),...
         behavior.position.y(startDelayWin),...
         'sm','MarkerSize',5)
    plot(behavior.position.x(rewardInd),...
         behavior.position.y(rewardInd),...
         '.g','MarkerSize',20)


%     plot(behavior.timestamps(trx),...
%          behavior.position.lin(trx),...
%          '.k','MarkerSize',4)
%     plot(behavior.timestamps(fastEnough&trx),...
%          behavior.position.lin(fastEnough&trx),...
%          '.b','MarkerSize',4)
%     plot(behavior.timestamps(delayWin),...
%          behavior.position.lin(delayWin),...
%          'sr','MarkerSize',4)
%     plot(behavior.timestamps(rewardInd),...
%          behavior.position.lin(rewardInd),...
%          'og','MarkerSize',6)


    ylim([0 90])
    title(sprintf('Trial %d',i))


    pause;


end


%% Time Averaged Wavelet Spectrum (1)
% (1) Isolate LFP during the behavioral task
%       [a] in order to use the whole recording LFP, theta ratios
%       need to be used instead of mouse velocity
% (2) Perform the continuous wavelet transform on the abridged LFP
%       [a] Morse(3,60), 0.5-12Hz
% (3) Perform mouse velocity filtering to analyze only theta-state LFP and
%       spikes

Fs = lfp.samplingRate;
dSF = 250;

% ts = downsample(lfp.timestamps,Fs/dSF);
% lfpx = downsample(lfp.data,Fs/dSF);
ts = lfp.timestamps;
lfpx = lfp.data;

behavx = find(ts>=behavior.timestamps(1) & ts<=behavior.timestamps(end));

[wt,f1,coi,fb] = cwt(single(lfpx(behavx)),Fs,FrequencyLimits=[1 12],VoicesPerOctave=20);


% Speed Filtering Indices
spdInterp = interp1(behavior.trials.position_trcat.timestamps,...
                 behavior.trials.position_trcat.v,...
                 ts(behavx));
spdIdx = abs(spdInterp) > 10;


% Theta Ratio Filtering Indices
plotFreqs = find(f1>=5 & f1<=10);
dtInds = find(f1>=1 & f1<=4);

thPower = mean(abs(wt(plotFreqs,:)),1);
dtPower = mean(abs(wt(dtInds,:)),1);
allPower = mean(abs(wt),1);

thRatio = thPower./allPower;
tdRatio = thPower./dtPower;

tdrIdx = transpose(tdRatio > 1.5);

%% (2)
% A quick comparison and proof of concept for the timeSpectrum function in
% MATLAB which by default needs the full time-series and also normalizes
% the output power to equal the time-series variance. We need to perform
% the time-averaged wavelet spectrum on velocity-filtered data.

fig = figure(1); clf;

tavgp = timeSpectrum(fb,single(lfpx(behavx)),'Normalization','none');
ownTAWS = mean(abs(wt).^2,2);

hold on;
plot(f1,(tavgp))
plot(f1,ownTAWS,'.r')

title('Time-Averaged Wavelet Spectrum')
xlabel('Frequency (Hz)')
ylabel('Power')

l = legend({'timeSpectrum Function','timeSpectrum Re-created'},...
    'Location','best');

%% (3)
% Comparison between velocity filtering theta-delta ratio filtering, and
% using both to determine high theta-state timepoints.

fig = figure(2); clf;

velFilt = mean(abs(wt(:,spdIdx)).^2,2);
tdrFilt = mean(abs(wt(:,tdrIdx)).^2,2);
bothFilt = mean(abs(wt(:,tdrIdx & spdIdx)).^2,2);

hold on;
plot(f1,ownTAWS,'LineWidth',2)
plot(f1,velFilt,'LineWidth',2)
plot(f1,tdrFilt,'LineWidth',2)
plot(f1,bothFilt,'LineWidth',2)

title('Time-Averaged Wavelet Spectrum')
xlabel('Frequency (Hz)')
ylabel('Power')

l = legend({'No Fitering','Velocity Filtering','Theta-Delta Ratio Filtering','Both'},...
    'Location','best');

%% Plot CWT +/- Spect
fig = figure(3); clf;
fig.Units = 'Normalized';
fig.Position = [0.2 0.2 0.5 0.7];

h = pcolor(lfp.timestamps(behavx(50000:100000)),f1,abs(wt(:,50000:100000)));

set(h, 'edgecolor','none');
axis tight
title('Chunk of CWT output')
xlabel('Time Bins')
ylabel('Frequency (Hz)')
yticks(1:numel(f1));
% yticklabels(cellstr(string(round((f2),2))));
set(gca,'YScale','log','TickDir','out')



%% Single Neuron Oscillations
% (1) Perform Time Histogram estimation of neuronal firing rate across all
% trials
% (2) Obtain the time-averaged wavelet histogram of the neuronal
% oscillation
%       [a] Average only timestamps that have been velocity filtered
tic;

behavTrials = behavior.trials.startPoint;
trEdges = unique(behavTrials);
trDurations = behavTrials(:,2) - behavTrials(:,1);

binWidths = 0:0.0005:0.04;
binWidths = binWidths(2:end);
c = nan(size(binWidths));

plotting = false;
storeData = true;

if storeData
    tAvgWavSpect = nan(numel(spikes.ids),size(velFilt,1));
    totSpikes = nan(size(spikes.ids));
    cellFiringRates = cell(numel(spikes.ids),1);
end

for unit = 1:numel(spikes.ids)

    spikeTimes = spikes.times{unit};
    [spikesPerTrial,~,spikeFromTrial] = histcounts(spikeTimes,trEdges);
    spikeTimesRelative = spikeTimes(spikeFromTrial~=0);
    spikeTrials = spikeFromTrial(spikeFromTrial~=0);
    [trials,ia,ic] = unique(spikeTrials,'first');
    fastEnough = behavior.trials.position_trcat.v >= 10;
    fastEnough = ismember(behavior.timestamps,behavior.trials.position_trcat.timestamps(fastEnough));
    
    % Zero spike times by end of delay
    spikeTimesRelative = spikeTimesRelative - behavior.events.endDelay(trials(ic));
    
    for tr = 1:numel(trials)
        % Zero trial times by end of delay
        trx = behavior.masks.trials==tr;
        temp1 = behavior.timestamps(trx&fastEnough)-behavior.events.endDelay(tr);
        temp2 = tr*ones(size(temp1));
        if tr == 1
            trSpdFiltTx = [temp1, temp2];
        else
            trSpdFiltTx = [trSpdFiltTx; temp1, temp2];
        end
    end
    
    for d = 1:numel(binWidths)
        nEdges = min(spikeTimesRelative):binWidths(d):max(spikeTimesRelative);
        k = histcounts(spikeTimesRelative,nEdges);
        k_mu = mean(k);
        k_var = var(k);
        c(d) = bl_binSizeCostFx(k_mu,k_var,numel(trials),binWidths(d));
    end
    optimalBinWidth = binWidths(c==min(c));
    optimalEdges = min(spikeTimesRelative):optimalBinWidth:max(spikeTimesRelative);
    
    [timeHist,~,binInds] = histcounts(spikeTimesRelative,optimalEdges);
    
    firingRate = timeHist/optimalBinWidth/numel(trials);
    
    tsHist = histcounts(trSpdFiltTx(:,1),optimalEdges);
    tsHist(tsHist>100) = tsHist(find(tsHist>100)-1);
    spdFiltBins = tsHist>5;

    [wt_u,f_u,coi_u,fb_u] = cwt(timeHist,1/optimalBinWidth,FrequencyLimits=[1 12],VoicesPerOctave=20);
    tavgp_u = mean(abs(wt_u).^2,2);
    tavgp_velFilt = mean(abs(wt_u(:,spdFiltBins)).^2,2);
    velFilt = mean(abs(wt(:,spdIdx)).^2,2);

    if storeData
        tAvgWavSpect(unit,:) = tavgp_velFilt;
        totSpikes(unit) = numel(spikeTrials);
        cellFiringRates{unit} = firingRate;
    end
    
    if plotting
        fig1 = figure(11); clf; hold on;
        fig1.Units = 'normalized';
        fig1.Position = [0 .525 .15 .39];

        plot(binWidths, c);
        plot([optimalBinWidth optimalBinWidth],ylim,'Color','r','LineWidth',2);
        title('Optimal Bin Width Cost Function')
        xlabel('Bin Width (s)')
        ylabel('Cost')
    
        
        fig2 = figure(12); clf; hold on;
        fig2.Units = 'normalized';
        fig2.Position = [.15 .525 .4 .39];
        
    %     binTrialContrib = nan(size(transpose(nEdges)));
    %     for i = 1:numel(nEdges)-1
    %         binTrialContrib(i) = numel(unique(spikeTrials(binInds==i)));
    %     end
    %     binTrialContrib(binTrialContrib==0) = 1;
        plot(optimalEdges(1:end-1),firingRate);
        title(sprintf('Time Histogram w/ Optimal Bin Width: Unit %d',unit))
        xlabel('Time (s)')
        ylabel('Firing Rate (spikes/s)');
    
    
        fig3 = figure(13); clf; hold on;
        fig3.Units = 'normalized';
        fig3.Position = [0 .05 .15 .39];
            
        plot(optimalEdges(1:end-1),tsHist);
        plot(optimalEdges(spdFiltBins),tsHist(spdFiltBins),'.r','MarkerSize',3)
        title('Across-Trial Distribution of V>10m/s')
        xlabel('Time (s)')
        ylabel('Counts')
        
    
        fig4 = figure(14); clf; hold on;
        fig4.Units = 'normalized';
        fig4.Position = [0.15 0.05 0.4 0.39];
        
        plot(f_u,tavgp_u,'LineWidth',2);
        plot(f_u,tavgp_velFilt,'LineWidth',2);
        ylabel('Power')

        yyaxis right
        plot(f1,velFilt,'--k','LineWidth',2);
        title(sprintf('Time-Averaged Wavelet Spectrum: Unit %d',unit))
        xlabel('Frequency (Hz)')
        ylabel('Power')
        legend({'Single Cell Spectrum','Velocity-Filtered','LFP Spectrum'},'Location','northwest')
    end

%     pause;

end

toc;

%% 
pyrNeur = (strcmp(cell_metrics.putativeCellType, "Pyramidal Cell"))';

%% Single Cell Oscillation and LFP
cellsEnoughSpikes = (transpose(totSpikes)>50);

plotFreqs = find(f_u>=4 & f_u<=12);
thInds = find(f_u>=6 & f_u<=10);


thetaPowerCells = tAvgWavSpect(cellsEnoughSpikes&pyrNeur,plotFreqs);
tpCells2 = tAvgWavSpect(cellsEnoughSpikes,thInds);

minThPwr = transpose(min(transpose(thetaPowerCells)));  
thetaPowerCells = thetaPowerCells - minThPwr;
maxThPwr = transpose(max(transpose(thetaPowerCells)));
thetaPowerCells = thetaPowerCells./maxThPwr;

[~, maxThIdx] = max(transpose(thetaPowerCells));
[sx, maxThSrt] = sort(maxThIdx);
[~,mxIx] = max(velFilt(plotFreqs));
mxLFP = f_u(plotFreqs(mxIx));

peakFreq = f_u(sx);
freqEdges = flip(f_u(plotFreqs));
peakFreqDist = histcounts(peakFreq,freqEdges);

fig1 = figure(21); clf;
fig1.Units = 'normalized';
fig1.Position = [0.4 0.05 0.2 0.6];

% h = imagesc(f1(plotFreqs),1:numel(cellsEnoughSpikes),thetaPowerCells(maxThSrt,:),'Parent',ax1);
h = pcolor(f1(plotFreqs),1:sum(cellsEnoughSpikes&pyrNeur),flip(thetaPowerCells(maxThSrt,:)));
set(h, 'edgecolor','none');
colormap(jet);
xline(mean(peakFreq),'LineStyle','--','Color','b','LineWidth',2);
xline(mxLFP,'LineStyle','--','Color','w','LineWidth',2)
ylabel('Cell No.')

yyaxis right
line(f_u(plotFreqs),velFilt(plotFreqs),'LineStyle','-','Color','w','LineWidth',2);
ylabel('Power');

title('Single Cell Oscillation Spectra')
xlabel('Frequency (Hz)')



fig2 = figure(22); clf; hold on;
fig2.Units = 'normalized';
fig2.Position = [0.4 0.735 0.2 0.15];

histogram(peakFreq,freqEdges);
ylabel('Cell Counts')

% yyaxis right
% plot(f_u(plotFreqs),velFilt(plotFreqs),'-k','LineWidth',2);
% xline(mean(peakFreq),'LineStyle','--','Color','b','LineWidth',2);
% xline(mxLFP,'LineStyle','--','Color','k','LineWidth',2)


title('Peak Frequency Distribution')
ylabel('Power')
xlabel('Freq. (Hz)')

%% Find Place Fields

binEdges{1} = 1:1:100;
binEdges{2} = 1:1:100;
linEdges = 1:225;

% trialIDX = ismember(behavior.timestamps,behavior.trials.position_trcat.timestamps);
% trialINT = bz_IDXtoINT(trialIDX);
% trialINT = behavior.timestamps(trialINT.state1);

plotMap = false;
saveMap = true;

nbins = 100;
convSize = 5;

% Linearized
rightArm = find(behavior.trials.visitedArm);
leftArm = find(~behavior.trials.visitedArm);

rightIdx = ismember(behavior.masks.trials, rightArm);
leftIdx = ismember(behavior.masks.trials, leftArm);

rightInts = bz_IDXtoINT(rightIdx,'timestamps',behavior.timestamps);
leftInts = bz_IDXtoINT(leftIdx,'timestamps',behavior.timestamps);

dwellMapRight = histcounts(behavior.position.lin(rightIdx),linEdges);
dwellMapRight = Smooth(dwellMapRight,4,'type','l');

dwellMapLeft = histcounts(behavior.position.lin(leftIdx),linEdges);
dwellMapLeft = Smooth(dwellMapLeft,4,'type','l');

% 2-Dimensional
dwellMap = hist3([behavior.position.x behavior.position.y],'edges',binEdges);
dwellMap = transpose(dwellMap).*(mean(diff(behavior.timestamps)));
allTrialPosMask = im2bw(dwellMap); % Need a better mask of the figure-8 maze
dwellMap = Smooth(dwellMap,[4 4]);




for unit = 1:(spikes.numcells)
    spikeTimes = spikes.times{unit};
    spikePos = interp1(behavior.timestamps, behavior.position.lin, spikeTimes);

    [right,~,~] = InIntervals(spikeTimes,rightInts.state1);
    [left,~,~] = InIntervals(spikeTimes,leftInts.state1);

    spikeRtTimes = spikeTimes(right);
    spikeLtTimes = spikeTimes(left);

    spikeRPos = spikePos(right);
    spikeLPos = spikePos(left);

    spikeXPos = interp1(behavior.timestamps, ...  
        behavior.position.x, ...
        spikeTimes);
    spikeYPos = interp1(behavior.timestamps, ...
        behavior.position.y, ...
        spikeTimes);

    
    spikeMapR = histcounts(spikeRPos,linEdges);
    spikeMapR = Smooth(spikeMapR,4,'type','l');
    spikeMapL = histcounts(spikeLPos,linEdges);
    spikeMapL = Smooth(spikeMapL,4,'type','l');


    spikeMap = hist3([spikeXPos spikeYPos],'edges',binEdges);
    spikeMap = transpose(spikeMap);
    spikeMap = Smooth(spikeMap,[2 2]);


    rateMapR = spikeMapR./dwellMapRight;
    rateMapL = spikeMapL./dwellMapLeft;

    loCol = min([min(rateMapR) min(rateMapL)]);
    hiCol = max([max(rateMapL) max(rateMapL)]);
    
    rateMap = spikeMap./dwellMap;
    rateMap(~allTrialPosMask) = 0;
    
    
    
    if plotMap
        f = figure(1); clf;
        f.Units = 'normalized';
        f.Position = [0.05 0.15 0.85 0.55];
        tl = tiledlayout(7,3);
        tl.TileSpacing = 'tight';
        tl.Padding = 'compact';
    
        nexttile(tl,[5,1]);
        imagesc(dwellMap);
        colormap(jet); colorbar; 
        ax = gca;
        xt = ax.XTick;
        yt = ax.YTick;
        ax.XTickLabel = xt;
        set(ax, 'XTick',[], 'XTickLabel', [], ... 
            'YTick',[0 yt], 'YTickLabel', [flip([0 yt])])
        title(sprintf('Dwell Map: %d Trials',numel(behavior.trials.expectedArm)));
    
        nexttile(tl,[5,1]);
        imagesc(spikeMap);
        colormap(jet); colorbar;
        ax = gca;
        xt = ax.XTick;
        yt = ax.YTick;
        ax.XTickLabel = xt;
        set(ax, 'XTick',[], 'XTickLabel', [], ... 
            'YTick',[0 yt], 'YTickLabel', [flip([0 yt])])
        title(sprintf('Spiking Map: Unit %d - %s',unit,cell_metrics.putativeCellType{unit}));
    
        nexttile(tl,[5,1]);
        imagesc(rateMap);
        colormap(jet); colorbar;
        ax = gca;
        xt = ax.XTick;
        yt = ax.YTick;
        ax.XTickLabel = xt;
        set(ax, 'XTick',[], 'XTickLabel', [], ... 
            'YTick',[0 yt], 'YTickLabel', [flip([0 yt])])
        title(sprintf('Rate Map: Unit %d - %s',unit,cell_metrics.putativeCellType{unit}));

        nexttile(tl,[1,1]);
        imagesc(dwellMapRight');
        colormap(jet); colorbar;
        ylabel('Right')
        set(ax, 'XTick',[], 'XTickLabel', [])

        nexttile(tl,[1,1]);
        imagesc(spikeMapR');
        colormap(jet); colorbar;
        set(ax, 'XTick',[], 'XTickLabel', [])

        nexttile(tl,[1,1]);
        imagesc(rateMapR');
        colormap(jet); colorbar; clim([loCol hiCol]);
        set(ax, 'XTick',[], 'XTickLabel', [])

        nexttile(tl,[1,1]);
        imagesc(dwellMapLeft');
        ylabel('Left')
        colormap(jet); colorbar;
       
        nexttile(tl,[1,1]);
        imagesc(spikeMapL');
        colormap(jet); colorbar;

        nexttile(tl,[1,1]);
        imagesc(rateMapL');
        colormap(jet); colorbar; clim([loCol hiCol]);
    end

    if saveMap
        neurmaps.dwell.twoD = dwellMap;
        neurmaps.dwell.R = dwellMapRight;
        neurmaps.dwell.L = dwellMapLeft;
        neurmaps.mask = allTrialPosMask;
        neurmaps.spike.twoD{unit} = spikeMap;
        neurmaps.spike.R{unit} = spikeMapR;
        neurmaps.spike.L{unit} = spikeMapL;

        neurmaps.rate.twoD{unit} = rateMap;
        neurmaps.rate.R{unit} = rateMapR;
        neurmaps.rate.L{unit} = rateMapL;

    end

    % pause(0.01);
    % pause
end

%% Place Cell Tiling - Linearized, Directional
fig1 = figure(1); clf; hold on;
fig1.Units = 'Normalized';
fig1.Position = [0.1 0.05 0.8 0.865];

subplot(1,2,1)
rightTile = transpose(cat(2,neurmaps.rate.R{pyramidal}));
rightTile = normalize(rightTile,2);
[maxR,I] = max(rightTile,[],2);
[B,indR] = sort(I);
rightTile = rightTile(indR,:);
imagesc(1:size(rightTile,2), 1:size(rightTile,1), rightTile)
xlim([0 size(rightTile,2)]);
ylim([0 size(rightTile,1)]);
title('Right Trials')
colormap(jet)

subplot(1,2,2)
leftTile = transpose(cat(2,neurmaps.rate.L{pyramidal}));
leftTile = normalize(leftTile,2);
[maxL,I] = max(leftTile,[],2);
[B,indL] = sort(I);
leftTile = leftTile(indL,:);

imagesc(1:size(leftTile,2), 1:size(leftTile,1), leftTile)
xlim([0 size(leftTile,2)]);
ylim([0 size(leftTile,1)]);
title('Left Trials')

colormap(jet)
%%
for unit = 1:(spikes.numcells)
    figure(1);clf;hold on;
    colormap(jet);
    [~,C,S] = normalize([neurmaps.rate.R{unit};neurmaps.rate.L{unit}]);
    normR = normalize(neurmaps.rate.R{unit},'Center',C,'Scale',S);
    normL = normalize(neurmaps.rate.L{unit},'Center',C,'Scale',S);
    loCol = min([min(normR) min(normL)]);
    hiCol = max([max(normR) max(normL)]);

    subplot(4,1,[1,2]); hold on;
    plot(normR,'-r','LineWidth',2);
    plot(normL,'-b','LineWidth',2);

    subplot(4,1,3)
    imagesc(transpose(normR));
    colorbar;
    clim([loCol hiCol]);
    
    subplot(4,1,4)
    imagesc(transpose(normL));
    colorbar;
    clim([loCol hiCol]);


    pause;



end
%% cell def

pyramidals = find(strcmp(cell_metrics.putativeCellType, "Pyramidal Cell"));
for unit = 1:numel(pyramidals)

    histogram(neurmaps.rate{pyramidals(unit)}(neurmaps.rate{pyramidals(unit)}>=5),10);
    title(sprintf('Firing Rate Distribution: Unit %d - %s',pyramidals(unit),cell_metrics.putativeCellType{pyramidals(unit)}));

    pause;

end


%% Using BuzCode

plotPSD = false;
savePSD = true;

sampPer = 0.01;
sampFreq = 1/sampPer;

settings = struct;
settings = fooof_check_settings(settings);
settings.aperiodic_mode = 'knee';

[avgSpectTR, fr] = deal(cell(numel(spikes.ids),1));

trialInts = behavior.trials.startPoint;

qt = ismember(behavior.timestamps, behavior.trials.position_trcat.timestamps);
wholeSpeed = zeros(size(behavior.timestamps));
wholeSpeed(qt) = behavior.trials.position_trcat.v;

for unit = 1:numel(spikes.ids)
    % Find trial running spikes with high TDR
    [statusTR,intervalTR,indexTR] = InIntervals(spikes.times{unit},trialInts);
    [statusTD,intervalTD,indexTD] = InIntervals(spikes.times{unit},highTDR.timestamps);
    spikeVels = interp1(behavior.timestamps, wholeSpeed, spikes.times{unit});
    fastEnough = spikeVels >= 5;

    if sum(statusTR & statusTD) < 50
        fprintf('Unit %d (%s) did not have enough running spikes.\n',unit,cell_metrics.putativeCellType{unit});
        continue;
    end
    spikeTrain = spikes.times{unit};
    % spikeTrain = spikeTrain(statusTR & fastEnough);
    spikeTrain = spikeTrain(statusTR & statusTD);
        
    % Extract the trials that have spikes!
    [status1,interval1,index1] = InIntervals(spikeTrain,trialInts);
        
    unitTrials = unique(interval1);
    spectsTR = cell(1,numel(unitTrials)); %(?)
    % zero the spikes relative to their respective trial start times.
    for tr = 1:numel(unitTrials)
        trialInds = interval1==unitTrials(tr);
        spikeTrain(trialInds) = spikeTrain(trialInds) - trialInts(unitTrials(tr),1);
        % Wrong - subtract the trial start time, not the first spike.....
    end


    spikeTrain = sort(spikeTrain);
    unitFiringRate = Frequency(spikeTrain,'binSize',sampPer);
    numlags = round(numel(unitFiringRate(:,2))-1);
    [acf,lags] = autocorr(unitFiringRate(:,2),NumLags=numlags);
    [cellSpect, freqs] = pspectrum(acf,sampFreq,FrequencyLimits=[0.1 25]);
    plot(freqs,cellSpect)
    set(gca,'XScale','log','YScale','log')

    fr = fooof(freqs,cellSpect,[0 25],settings,1);
    
    if savePSD
        fooof_result{unit,1} = fr;
    end
    
    idx = freqs>= 4 & freqs<=11;
    newIdx = fr.freqs > 4 & fr.freqs < 11;

   if plotPSD
        fig = figure(1); clf; hold on;
        fig.Units = 'normalized';
        fig.Position = [0 0.3 0.4 0.4];
    
    
        plot(fr.freqs(newIdx), fr.power_spectrum(newIdx),'LineWidth',2);
        plot(fr.freqs(newIdx), fr.fooofed_spectrum(newIdx),'LineWidth',2);
        plot(fr.freqs(newIdx), fr.ap_fit(newIdx),'LineWidth',2);
    
        xline(5,'--r','LineWidth',1);
        xline(10,'--r','LineWidth',1);
        
        % set(gca,'XScale','log','YScale','log');
    
        title(sprintf('Power Spectrum: Unit %d - %s',unit,cell_metrics.putativeCellType{unit}));
        legend({'Power Spectrum','Fooofed Spectrum','ap\_fit'},'location','best')
        xlabel('Frequency (Hz)')
        ylabel('Power (dB)')
    
        fig = figure(2); clf; hold on;
        fig.Units = 'normalized';
        psdAtten = fr.power_spectrum-fr.ap_fit;
        modAtten = fr.fooofed_spectrum-fr.ap_fit;
        fig.Position = [0.4 0.3 0.4 0.4];    plot(fr.freqs(newIdx), ...
            psdAtten(newIdx), ...
            'Color',[0.3 0.3 0.3],'LineWidth',2)
        plot(fr.freqs(newIdx), ...
            modAtten(newIdx), ...
            'r','LineWidth',2)
    
        title(sprintf('Fooof Spectrum Attenuated: Unit %d - %s',unit,cell_metrics.putativeCellType{unit}));
        legend({'Power Spectrum','Fooofed Spectrum'},'location','best')
        xlabel('Frequency (Hz)')
        ylabel('Power (dB)')


        % fig = figure(3); clf; hold on;
        % fig.Units = 'normalized';
        % fig.Position = [0.8 0.3 0.2 0.4];
        % plot(lags./sampFreq, acf, ...
        % 'LineWidth',2);

   end
    
    % pause(0.1);
    % pause;

end



%% Use ACG already calculated by Roman
for unit = 1:size(cell_metrics.acg.wide,2)
    unitACG = cell_metrics.acg.wide(:,unit);
    
    fig1 = figure(1); clf; hold on;
    fig1.Units = 'normalized';
    fig1.Position = [0 0.5 0.4 0.4];
    plot(unitACG,'-b','LineWidth',1);
    title(sprintf('Unit %d - autocorrelogram',unit));

    [cellSpect, freqs] = pspectrum(unitACG);

    fig2 = figure(2); clf; hold on;
    fig2.Units = 'normalized';
    fig2.Position = [0.4 0.5 0.4 0.4];
    plot(freqs,cellSpect);
    set(gca,'xscale','log','yscale','log')
    pause;

end






%% Find Cells with Theta Peaks
hasNThetaPeaks = [];
for f = 1:numel(fooof_result)
    if isempty(fooof_result{f})
        continue;
    end
    tp = (fooof_result{f}.peak_params(:,1) >= 5 & fooof_result{f}.peak_params(:,1) <= 12);
    if sum(tp)>0
        hasNThetaPeaks(f,1) = sum(tp);

    end
end

%% Plot
thetaModCells = find(hasNThetaPeaks ~=0);
pyramidalCells = find(strcmp(cell_metrics.putativeCellType, "Pyramidal Cell"))';
subsetCells = intersect(thetaModCells, pyramidalCells); % UID of the particular subset of cells I'm looking at.
thetaMat = [];
for i = 1:numel(subsetCells)
    thetaMod = fooof_result{subsetCells(i),1}.fooofed_spectrum - fooof_result{subsetCells(i),1}.ap_fit;
    bbFreqs = fooof_result{subsetCells(i),1}.freqs;
    thetaIdx = fooof_result{subsetCells(i),1}.freqs >= 5 & fooof_result{subsetCells(i),1}.freqs <= 12;
    
    thetaMat(i,:) = thetaMod(thetaIdx);
    % figure(1); clf; hold on;
    % plot(bbFreqs(thetaIdx), thetaMod(thetaIdx),'-k','LineWidth',1);
    % pause;
end


thetaMat = normalize(thetaMat,2,'range');


[~, maxThIdx] = max(transpose(thetaMat));
[sx, maxThSrt] = sort(maxThIdx);

figure(31);
imagesc([bbFreqs(find(thetaIdx,1,'first')) bbFreqs(find(thetaIdx,1,'last'))],[1 size(thetaMat,1)],thetaMat(maxThSrt,:))
colormap(jet)
%%
idx_ = find(statesIdx.states ~= 2);

MovNREM1 = mvmt;
MovNREM1(idx_) = 0;
figure(); clf; hold on;
plot(MovNREM1)
plot(MovNREM1.^2)

%%
avgSpectTR = cellfun(@zscore,avgSpectTR,'UniformOutput',false);
allCells = [avgSpectTR{:}]';
% allCells = allcells()

h = pcolor(freqs(idx),1:numel(avgSpectTR),allCells);
set(h, 'edgecolor','none');
colormap(jet);

%% Notes

% Need to separate into place fields and then find two indicies
%   (1) InField
%   (2) FastEnough
% Single Cell Oscillation Spectrum should look at InField & FastEnough
% Baseline Spectrum should look at ~InField & FastEnough

% s/p conversation with Roman
%   (1) Using all running spikes should be fine
%   (2) smooth the autocorrelogram
%   (3) FOOOF
%       [a] there are functions to fit either fixed or knee aperiodic
%       elements in the spectrogram 
%       [b] there are also pipelines that integrate with Matlab, either
%       using a M>P>M pipeline or calling a Matlab Wrapper.
%   (4) What are the fooof outputs? like what is "fooofed spectrum"?











