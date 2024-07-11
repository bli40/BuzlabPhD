%% Start Up
clear all; close all;
addpath(genpath('C:\Users\brian\buzcode'));

rootpath = '\\research-cifs.nyumc.org\research\buzsakilab\Buzsakilabspace\LabShare\AnnaMaslarova\YZ';
% rootpath = 'E:\BuzLabTemporaryCopies';
sessions = dir([rootpath,'/**/ACh*/*Session*']);
dirIDX = find([sessions.isdir]);
sessions = sessions(dirIDX);
dirIDX = ~contains({sessions.name},'for upload');
sessions = sessions(dirIDX);
cd(rootpath)

%%
sessionInd = 18;

% load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.eegstates.mat']));
% load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.SleepState.states.mat']));
% load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.SleepScoreLFP.LFP.mat']));
load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.IEDclean.events.mat']));
% load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.AChAnalyzis.mat']));
% load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.ripples.events.mat']));
% load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.EMGFromLFP.LFP.mat']));
% load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.DigitalIn.events.mat']));

%% Get Ripple Stats if non-existent
lfpChan = IED.detectorinfo.detectionchannel;
lfp = bz_GetLFP(lfpChan, 'basepath', [sessions(sessionInd).folder,'\',sessions(sessionInd).name]);

%%
fs = lfp.samplingRate;
fb = [100 200];
[b,a] = butter(5,fb/(fs/2));
rippleBand = filtfilt(b,a,double(lfp.data));
filtered = [lfp.timestamps, rippleBand];
[ripples,sd,bad] = FindRipples(filtered);
IED.rippleStats = RippleStats(filtered,ripples);

%% get NREM packet and micro arousal(accelerate >0.5 and <40)
% This is a snippet of code copied from Yiyao's Oxytocin paper code and
% modified.
% close all;
nREMrelevIED = {};
nREMrelevRip = {};
nrem.lfp = {};
nrem.ied = {};
relevantACHI = {};
relevantACHR = {};

plotting = false;
loadData = true;

manualCheck = false;


fig = figure(1); clf; hold on;
fig.Units = 'normalized';
fig.Position = [0 0.5 1 0.40];

% User Defined Stuff
mvmtThresh = [0.18, 0.2, 0.23, 0.5, 0.4, ...
              0.2,  0.5, 0.2,  0.2, 0.2, ...
              0.2,  0.2, 0.5,  0.2, 0.5, ...
              0.4,  0.5, 0.5];
badPeaks = cell(18,1);
badPeaks{1} = [455, 972];
badPeask{2} = [1043,1260,1313,1340,1454,1514,1830,1867,1973,1981,2014:2017];
badPeaks{3} = [197,221,370,461,796,872,956,995,1021,1022,1100,1131,1171,1333,...
               1460,1732,2107];
badPeaks{4} = [259,304,351,523,618,733,792,832,833,866,924,1042,1264,1359,1360,...
               1735,1792,2007,2008,2087,2122,2179,2197,2184,2199,2222,2257,2284,...
               2266,2309,2362];
badPeaks{5} = [831,1509,1538,1571];
badPeaks{6} = [720,991,992,1280,1375,1405,1718,2298,2299,2335,2378,2379,2396,...
               2417,2521,2557];
badPeaks{7} = [331,509,543,633,644,729,783,827,1129,1187,1280,1283,1330,1331,...
               2205,2253,2285,2286,2314,2329,2332,2349];
badPeaks{8} = [424,478,603,723,1355,1358,1359,1449,1450,1582,1923,1929,2122,2255,2262];
badPeaks{9} = [283,892,1804,1847,1917,1963,1969,1978,2089,2107,2108,2178,2464,2518];
badPeaks{11}= [275,479,603,685,723,1581,2021,2077,2097,2121,2255,2486,2502];
badPeaks{12}= [256,319,308,309,358,362,379,407,463,646,479,502,543,656,661,665,755,...
               1032,1053,1162,1240,1268,1269,1349,1566,1567,1573,1651,1702];
badPeaks{13}= [187,926,1132,1185,1311,1345,1379];
badPeaks{14}= [464,1240];
badPeaks{16}= [183:186,350,528,574,599,629,754,760,770,786,792,795,799,803,806,845,853,...
               881,898,918,921,923,928,935,949,956:958,961,992,995,1111,1235,1416,1422,...
               1431,1447,1464,1543,1548,1550:1552,1576,1597,1605,1614,1615,1623,1638,...
               1660,1668,1677,1681:1683,1693,1833,1984,1994,2009,2045,2061,2065,2130,...
               2131,2134,2135,2145,2168,2170,2466,2512,2576];
badPeaks{17}= [283,293,379,393,394,414,421,425,436,446,449,460,559,560,584,585,600,...
               601,604,605,619,620,623,624,649,650,655,659,663:666,675,689,690,698,...
               699,705,706,708,709:713,721:726,763,764,795,796,806,807,820:822,846,...
               861:863,891,903,914,916:918,940:943,1017,1022,1029:1035,1051,1056:1061,...
               1074:1077,1117,1141:1145,1150:1152,1179,1180,1193:1196,1214:1217,1241,...
               1250:1257,1260:1262,1293,1301,1348,1349,1408,1412,1413,1436,1442,1452,...
               1453,1535,1540,1541,1547,1548,1570,1571,1585,1586,1594:1596,1614:1617,...
               1622,1723,1734,1761:1763,1775,1780,1781:1800,1808,1825:1827,1843,1848,...
               1849,1853:1855,1864,1865,1897,1911,1912,1915:1917,1923,1924,1928:1932,...
               1949,1954,1961:1963,1970,1974,1975,1982,1983,1985,1990,2036,2039:2042,...
               2047:2049,2061,2066,2067,2077,2079,2083,2084,2101:2104,2106,2017,2110:...
               2113,2138,2141,2144,2181,2192,2196:2198,2206:2208,2216,2218,2219,2226,...
               2239,2240,2246,2257,2322:2325,2349,2366,2370:2373,2404:2407,2422,2543,...
               2544,2679,2685,2691,2692,2699,3259,3264,3271,3364,3377,3402,3406,3407,...
               3409:3411,3416:3419,3440:3443,3453:3456,3493,3559,3573,3581,3975,3976,...
               4056,4247,4248,4252,4262,4340,4341,4348,4349,4355,4374,4375,4382:4384,...
               4477,4608,4614,4617:4619,4635,4636,4680,4681,4685,4687:4690,4694,4702,...
               4709,4745,4748,4749,4751,4754,4759,4760,4762:4765,4768,4770,4771,4773,...
               4778,4781,4797,4798,4801,4802,4810,4812:4817,4828,4830];
badPeaks{18}= [330,340,345,358,639,656,676,702,709,717,718,723,727,728,763,773,774,790,...
               797,840,846,854,858,863,864,877,881,902,903,910,921,928,947,948,982,988,...
               1025,1026,1033,1034,1062,1079,1080,1084,1089,1092,1093,1034,1062,1079,...
               1080,1084,1089,1092,1093,1114:1116,1122,1127,1137:1139,1187,1189,1198,...
               1226,1227,1232,1238,1240,1278,1279,1282,1283,1492,1498,1499,1506,1512,...
               1514,1515,1524:1526,1553,1557,1558,1578,1588,1589,1599,1601,1634,1637,...
               1650,1661:1665,1682,1694:1696,1728,1730,1732,1741,1745,1750,1761,1795,...
               1800:1802,1814,1856,1860,1864,1869,1870,1873,1877,1887,1890,1897,1910,...
               1921,1922,1968,1978,1980,1985,1997:1999,2001,2007,2012,2021,2023,2024,...
               2040,2041,2049:2051,2057,2070,2090,2393,2394,2401,2432,2466,2514,2515,...
               2518,2519,2529,2533,2536,2538,2541,2549,2550,2564,2565,2567:2569,2594,...
               2612,2617,2619:2621,2626,2627,2639,2640,2668,2669];

for sesh = 11:15
    if manualCheck
        livePlot = true;
    else
        livePlot = false;
    end
    
    if loadData
        clear ripples IED SleepScoreLFP SleepState StateInfo
        sessionInd = sesh;
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.SleepState.states.mat']));
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.SleepScoreLFP.LFP.mat']));
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.IEDclean.events.mat']));
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.EMGFromLFP.LFP.mat']));
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.AChAnalyzis.mat']));
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.ripples.events.mat']));
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.DigitalIn.events.mat']));
        % load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.spikes.cellinfo.mat']));
        % load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.cell_metrics.cellinfo.mat']));
        % lfp = bz_GetLFP(SleepScoreLFP.THchanID+1, 'basepath', [sessions(sessionInd).folder,'\',sessions(sessionInd).name]);
    end

    % session specific manual stuff
    if sesh == 12
        EMGFromLFP.data = EMGFromLFP.data + abs(min(EMGFromLFP.data));
        EMGFromLFP.data = (EMGFromLFP.data).*4;
    elseif sesh == 14
        EMGFromLFP.data = EMGFromLFP.data + abs(min(EMGFromLFP.data));
        EMGFromLFP.data = (EMGFromLFP.data).*3;
    elseif sesh == 16 || sesh == 17 || sesh == 18
        AChAnalyzis.AChTrace = smooth(AChAnalyzis.AChTrace,35);
    end

    % [spectrogram, t, f] = MTSpectrogram(double(lfp.data), ...
    %                                     'window',1,...
    %                                     'frequency',1250,...
    %                                     'range',[0 50], ...
    %                                     'show','off');

    AChAnalyzis.offsetS = digitalIn.intsPeriods{2}(1);
    AChAnalyzis.time = 1:numel(AChAnalyzis.AChTrace);
    AChAnalyzis.time = AChAnalyzis.time./AChAnalyzis.samplingRate + AChAnalyzis.offsetS;
    
    statesIdx = bz_INTtoIDX(SleepState.ints); 
   
    ix = linspace(1, numel(statesIdx.states), numel(EMGFromLFP.data));
    mvmt = interp1(ix, EMGFromLFP.data, 1:numel(statesIdx.states));

    if plotting
        f1 = figure(1); clf; hold on;
        f1.Units = 'normalized';
        f1.Position = [0.3 0.5 0.4 0.3];
        plot(statesIdx.states-50);xlim([0 inf]);
        title(sprintf('Sleep States: %s/%s/%s',statesIdx.statenames{:}));
        
        f2 = figure(2); clf; hold on;
        f2.Units = 'normalized';
        f2.Position = [0.3 0.1 0.4 0.3];
        plot(mvmt);xlim([0 inf]);
        title('Mouse Movement')
    end
    
    idx_ = find(statesIdx.states ~= 2);
    
    %%%%%%% get microarousals during non-REM sleep using movement data
    movNREM1 = mvmt;
    movNREM1(idx_) = 0;
    
    movNREM = smoothdata(movNREM1,"gaussian",5);
    
    peak_mean_diff = 1;
    threshold_ = 0.02;
    [peaks, locations, width] = findpeaks(movNREM,'MinPeakProminence',threshold_,...
        'WidthReference','halfprom','MinPeakDistance',peak_mean_diff);
    
    if plotting
        f3 = figure(3); clf; hold on;
        f3.Units = 'normalized';
        f3.Position = [0.33 0.13 0.4 0.3];
        plot(movNREM1,'-k'); xlim([0 inf]);
        plot(movNREM,'-r')
        plot(locations,peaks,'o','MarkerSize',3);
        title('Mouse Movements Outside of NREM')
    end
    
    [arousals] = FindMicroArousal_eeg_BYL(statesIdx,mvmt,mvmtThresh(sesh));

    if ~plotting
        close all;
    end
    
    if plotting
        f4 = figure(4); clf; hold on;
        f4.Units = 'no rmalized';
        f4.Position = [0.33 0.53 0.4 0.3];
        
        plot(arousals.times,arousals.movNREM,'k');
        xline(arousals.timestamps(:,1),'b')
        xline(arousals.timestamps(:,2),'r')
        xlim([arousals.times(1) arousals.times(end)])
        title('Micro-Arousal Times')
    end
    
    %%%%%%% get NREM packets that have been cleared of arousals and micro-arousals
    nREMnoArousals = ones(size(mvmt));
    
    for i = 1:length(arousals.peaks)
        idx = arousals.timestamps(i,1):arousals.timestamps(i,2);
        nREMnoArousals(idx) = 0;
    end
    
    idx_ = find(statesIdx.states ~= 2);
    nREMnoArousals(idx_) = 0;
    
    if plotting
        f5 = figure(5); clf; hold on;
        f5.Units = 'normalized';
        f5.Position = [0.36 0.56 0.4 0.3];
        
        plot(nREMnoArousals);
        plot(statesIdx.states,'r');xlim([0 inf]);
        yyaxis right
        plot(arousals.times,mvmt);
        YLnew = ylim;
        YLnew(2) = YLnew(2)*4;
        ylim(YLnew);
    end

    %%%%%%% Extract Session Data into Cell Array
    nREMpackets = bz_IDXtoINT(nREMnoArousals);

    %%%%%%% ACh Packet Peaks
    [pks,locs] = findpeaks(AChAnalyzis.AChTrace, ...
        'MinPeakProminence',5e-3, ...
        'MinPeakWidth',50, ...
        'WidthReference','halfprom');

    pks(badPeaks{sesh}) = [];
    locs(badPeaks{sesh}) = [];
    
    if livePlot
        windows = 1:250:ceil(max(AChAnalyzis.time)/1000)*1000;
        win = 1;
        fig = figure(10); clf; hold on;
        fig.Units = 'normalized';
        fig.Position = [0 0.5 1 0.415];
        colormap(fig,'hot');
        
        numstrs = num2str((1:numel(pks))');
                
        % Log Transform Spectrogram
        % logTransformed = log(abs(spectrogram));

        % Interpolate ACh Value at IED and Ripple Times
        % iedAchVal = interp1(AChAnalyzis.time,AChAnalyzis.AChTrace,IED.peaks);
        % ripAchVal = interp1(AChAnalyzis.time,AChAnalyzis.AChTrace,ripples.peaks);

        while livePlot
            clf; hold on;
            % Window Different Indices
            locIdx = transpose(AChAnalyzis.time(locs) >= windows(win) & AChAnalyzis.time(locs) <= windows(win+1));
            achIdx = AChAnalyzis.time >= windows(win) & AChAnalyzis.time <= windows(win+1);
            iedIdx = IED.timestamps(:,1) >= windows(win) & IED.timestamps(:,1) <= windows(win+1);
            ripIdx = ripples.peaks >= windows(win) & ripples.peaks <= windows(win+1);
            
            nremIndA = find(nREMpackets.state1(:,1) >= windows(win),1,'first');
            nremIndB = find(nREMpackets.state1(:,2) >= windows(win+1),1,'first');
            if isempty(nremIndB)
                nremIndB = nremIndA;
            end
            nremIdx = nremIndA:nremIndB;
            arousalIndA = find(arousals.timestamps(:,1) >= windows(win),1,'first');
            arousalIndB = find(arousals.timestamps(:,2) >= windows(win+1),1,'first');
            if isempty(arousalIndB)
                arousalIndB = arousalIndA;
            end
            arousalIdx = arousalIndA:arousalIndB;
    
            % specIdx = t >= windows(win) & t <= windows(win+1);
            emgIdx = EMGFromLFP.timestamps >= windows(win) & EMGFromLFP.timestamps <= windows(win+1);

            title('Acetylcholine Peaks');
            ylim([-0.15 0.15])
            xlim([windows(win) windows(win+1)]);

	        % PlotColorMap(logTransformed(:,specIdx),1, ...
            %     'x',t(specIdx), ...
            %     'y',f, ...
            %     'cutoffs',[0 13], ...
            %     'newfig','off', ...
            %     'colorspace','RGB');
	        % xlabel('Time (s)');
	        % ylabel('Frequency (Hz)');
	        % title('Power Spectrogram');
            % 
            % yyaxis right
            % ylim([-0.15 0.15])
            plot(AChAnalyzis.time(achIdx), AChAnalyzis.AChTrace(achIdx),'Color',[0.5 0.5 0.5]);
            plot(AChAnalyzis.time(locs(locIdx)),pks(locIdx),'om','MarkerSize',7)
            text(AChAnalyzis.time(locs(locIdx))-1,pks(locIdx)+0.01, ...
                numstrs(locIdx,:), ...
                "FontSize",5, ...
                "HorizontalAlignment",'center')

            for i = 1:numel(nremIdx)
                x = sort([nREMpackets.state1(nremIdx(i),:) nREMpackets.state1(nremIdx(i),:)]);
                y = [ylim flip(ylim)];
                patch(x,y,'blue','FaceAlpha',0.2,'EdgeAlpha',0)
            end
            for i = 1:numel(arousalIdx)
                x = sort([arousals.timestamps(arousalIdx(i),:) arousals.timestamps(arousalIdx(i),:)]);
                y = [ylim flip(ylim)];
                patch(x,y,'magenta','FaceAlpha',0.2,'EdgeAlpha',0)
            end
            plot(IED.timestamps(iedIdx,1),zeros(size(IED.timestamps(iedIdx,1)))-0.05, ...
                '|r','Markersize',30);
            plot(ripples.peaks(ripIdx),zeros(size(ripples.peaks(ripIdx)))-0.05, ...
                '|b','Markersize',15);
            % plot(IED.timestamps(iedIdx,1),iedAchVal(iedIdx), ...
            %     '|m','Markersize',30);
            % plot(ripples.peaks(ripIdx),ripAchVal(ripIdx), ...
            %     '|k','Markersize',15);
        
            yyaxis right;
            % plot(EMGFromLFP.timestamps, EMGFromLFP.data,'-b');
            plot(EMGFromLFP.timestamps(emgIdx), (EMGFromLFP.data(emgIdx)).^2,'-','color',[0 0.4470 0.7410]);
            yline(mvmtThresh(sesh),'-k');
            ylim([0 5])
        
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
    end

    %%%%%%% SAVE DATA %%%%%%%
    
    %%%%%%% NREM Packets IED
    % nREM packets with IEDs
    %   extract for:    IEDs (time, size)
    %                   Ripples (time, size)
    %                   LFP (time, sw, th)
    %                   ACh (time, trace)
    [~, intervalI, ~] = InIntervals(IED.timestamps(:,1),nREMpackets.state1);
    nREMsI = unique(intervalI);
    nREMsI = nREMsI(nREMsI ~= 0);
    
    nREMrelevIED{sesh} = nREMpackets.state1(nREMsI,:);
        
    [~, intervalRip, ~] = InIntervals(ripples.peaks,nREMrelevIED{sesh});
    [~, intervalLFP, ~] = InIntervals(SleepScoreLFP.t,nREMrelevIED{sesh});
    [~, intervalACh, ~] = InIntervals(AChAnalyzis.time,nREMrelevIED{sesh});
    [~, intervalIED, ~] = InIntervals(IED.timestamps(:,1),nREMrelevIED{sesh});
    for j = 1:size(nREMrelevIED{sesh},1)
        lfpIdx = intervalLFP==j;
        iedIdx = intervalIED==j;
        achIdx = intervalACh==j;
        ripIdx = intervalRip==j;
        nrem.lfp{sesh,1}{j,1} = SleepScoreLFP.t(lfpIdx);
        nrem.lfp{sesh,1}{j,2} = double(SleepScoreLFP.swLFP(lfpIdx));
        nrem.lfp{sesh,1}{j,3} = double(SleepScoreLFP.thLFP(lfpIdx));
        nrem.ach{sesh,1}{j,1} = AChAnalyzis.time(achIdx);
        nrem.ach{sesh,1}{j,2} = AChAnalyzis.AChTrace(achIdx);
        nrem.rip{sesh,1}{j,1} = ripples.peaks(ripIdx);
        nrem.rip{sesh,1}{j,2} = ripples.peakNormedPower(ripIdx);
        nrem.ied{sesh,1}{j,1} = IED.timestamps(iedIdx,1);
        nrem.ied{sesh,1}{j,2} = IED.rippleStats.data.peakAmplitude(iedIdx);
    end   

    % %{
    %%%%%%% NREM Packets Ripple 
    % nREM packets with Ripples
    %   extract for:    IEDs (time, size)
    %                   Ripples (time, size)
    %                   LFP (time, sw, th)
    %                   ACh (time, trace)    [~, intervalRip, ~] = InIntervals(ripples.peaks(:,1),nREMpackets.state1);
    [~, intervalR, ~] = InIntervals(ripples.peaks(:,1),nREMpackets.state1);

    nREMsR = unique(intervalR);
    nREMsR = nREMsR(nREMsR ~= 0);
    nREMsR = nREMsR(~ismember(nREMsR,nREMsI));

    
    nREMrelevRip{sesh} = nREMpackets.state1(nREMsR,:);


    [~, intervalRip, ~] = InIntervals(ripples.peaks,nREMrelevRip{sesh});
    [~, intervalLFP, ~] = InIntervals(SleepScoreLFP.t,nREMrelevRip{sesh});
    [~, intervalACh, ~] = InIntervals(AChAnalyzis.time,nREMrelevRip{sesh});
    [~, intervalIED, ~] = InIntervals(IED.timestamps(:,1),nREMrelevRip{sesh});

    for j = 1:size(nREMrelevRip{sesh},1)
        lfpIdx = intervalLFP==j;
        iedIdx = intervalIED==j;
        achIdx = intervalACh==j;
        ripIdx = intervalRip==j;
        nrem.lfp{sesh,2}{j,1} = SleepScoreLFP.t(lfpIdx);
        nrem.lfp{sesh,2}{j,2} = double(SleepScoreLFP.swLFP(lfpIdx));
        nrem.lfp{sesh,2}{j,3} = double(SleepScoreLFP.thLFP(lfpIdx));
        nrem.ach{sesh,2}{j,1} = AChAnalyzis.time(achIdx);
        nrem.ach{sesh,2}{j,2} = AChAnalyzis.AChTrace(achIdx);
        nrem.rip{sesh,2}{j,1} = ripples.peaks(ripIdx);
        nrem.rip{sesh,2}{j,2} = ripples.peakNormedPower(ripIdx);
        nrem.ied{sesh,2}{j,1} = IED.timestamps(iedIdx,1);
        nrem.ied{sesh,2}{j,2} = IED.rippleStats.data.peakAmplitude(iedIdx);
    end   
    %}

    pt = [0; locs];
    p2p = [];
    for i = 1:numel(pt)-1
        p2p(i,:) = [pt(i)+1 pt(i+1)];
        
    end

    
    %%%%%%% Acetylcholine Packets IED
    % ACh packets with IEDs
    %   extract for:    IEDs (time, size)
    %                   Ripples (time, size)
    %                   LFP (time, sw, th)
    %                   ACh (time, trace)
    [~, intD, ~] = InIntervals(IED.timestamps(:,1),AChAnalyzis.time(p2p));
    
    relevantP2PI = unique(intD); % Isoate the Acetylcholine P2P packets that have IEDs.
    relevantP2PI = relevantP2PI(relevantP2PI ~= 0);
    
    achrelevIED{sesh} = AChAnalyzis.time(p2p(relevantP2PI,:));
    
    [~, intervalRip, ~] = InIntervals(ripples.peaks,achrelevIED{sesh});
    [~, intervalLFP, ~] = InIntervals(SleepScoreLFP.t,achrelevIED{sesh});
    [~, intervalACh, ~] = InIntervals(AChAnalyzis.time,achrelevIED{sesh});
    [~, intervalIED, ~] = InIntervals(IED.timestamps(:,1),achrelevIED{sesh});

    for j = 1:size(achrelevIED{sesh},1)
        lfpIdx = intervalLFP==j;
        iedIdx = intervalIED==j;
        achIdx = intervalACh==j;
        ripIdx = intervalRip==j;
        ach.lfp{sesh,1}{j,1} = SleepScoreLFP.t(lfpIdx);
        ach.lfp{sesh,1}{j,2} = double(SleepScoreLFP.swLFP(lfpIdx));
        ach.lfp{sesh,1}{j,3} = double(SleepScoreLFP.thLFP(lfpIdx));
        ach.ied{sesh,1}{j,1} = IED.timestamps(iedIdx,1);
        ach.ied{sesh,1}{j,2} = IED.rippleStats.data.peakAmplitude(iedIdx);
        ach.ied{sesh,1}{j,3} = IED.rippleStats.data.peakFrequency(iedIdx);
        ach.ied{sesh,1}{j,4} = IED.rippleStats.data.duration(iedIdx);
        ach.ach{sesh,1}{j,1} = AChAnalyzis.time(achIdx);
        ach.ach{sesh,1}{j,2} = AChAnalyzis.AChTrace(achIdx);
        ach.rip{sesh,1}{j,1} = ripples.peaks(ripIdx);
        ach.rip{sesh,1}{j,2} = ripples.peakNormedPower(ripIdx);
        
    end 
    
    
    % %{
    %%%%%%% Acetycholine Packets RIPPLES 
    % ACh packets with IEDs
    %   extract for:    IEDs (time, size)
    %                   Ripples (time, size)
    %                   LFP (time, sw, th)
    %                   ACh (time, trace)
    [~, intR, ~] = InIntervals(ripples.peaks,AChAnalyzis.time(p2p));
    
    relevantP2PR = unique(intR); % Isoate the Acetylcholine P2P packets that have ripples.
    relevantP2PR = relevantP2PR(relevantP2PR ~= 0);
    relevantP2PR = relevantP2PR(~ismember(relevantP2PR,relevantP2PI));
        
    achrelevRip{sesh} = AChAnalyzis.time(p2p(relevantP2PR,:));

    
    [~, intervalRip, ~] = InIntervals(ripples.peaks,achrelevRip{sesh});
    [~, intervalLFP, ~] = InIntervals(SleepScoreLFP.t,achrelevRip{sesh});
    [~, intervalACh, ~] = InIntervals(AChAnalyzis.time,achrelevRip{sesh});
    [~, intervalIED, ~] = InIntervals(IED.timestamps(:,1),achrelevRip{sesh});

    for j = 1:size(achrelevRip{sesh},1)
        lfpIdx = intervalLFP==j;
        iedIdx = intervalIED==j;
        achIdx = intervalACh==j;
        ripIdx = intervalRip==j;
        ach.lfp{sesh,2}{j,1} = SleepScoreLFP.t(lfpIdx);
        ach.lfp{sesh,2}{j,2} = double(SleepScoreLFP.swLFP(lfpIdx));
        ach.lfp{sesh,2}{j,3} = double(SleepScoreLFP.thLFP(lfpIdx));
        ach.ied{sesh,2}{j,1} = IED.timestamps(iedIdx,1);
        ach.ied{sesh,2}{j,2} = IED.rippleStats.data.peakAmplitude(iedIdx);
        ach.ied{sesh,2}{j,3} = IED.rippleStats.data.peakFrequency(iedIdx);
        ach.ied{sesh,2}{j,4} = IED.rippleStats.data.duration(iedIdx);
        ach.ach{sesh,2}{j,1} = AChAnalyzis.time(achIdx);
        ach.ach{sesh,2}{j,2} = AChAnalyzis.AChTrace(achIdx);
        ach.rip{sesh,2}{j,1} = ripples.peaks(ripIdx);
        ach.rip{sesh,2}{j,2} = ripples.peakNormedPower(ripIdx);
        
    end 
    
    %}

    
end

%% Cell Spiking Stuff
% [spectrogram, t, f] = MTSpectrogram(double(lfp.data), ...
%                                         'window',1,...
%                                         'frequency',1250,...
%                                         'range',[0 50], ...
%                                         'show','on');
[spectrogram, f, t] = stft(double(lfp.data), lfp.samplingRate, 'FrequencyRange','onesided');
logTransformed = log(abs(spectrogram));
PlotColorMap(logTransformed(f<50,:), ...
                'x',t, ...
                'y',f(f<50), ...
                'cutoffs',[0 12], ...
                'newfig','off', ...
                'colorspace','RGB');
	        xlabel('Time (s)');
	        ylabel('Frequency (Hz)');
	        title('Power Spectrogram');

%% IED-based nREM Packet Normalization of IED, Ripples, and ACh
% Find the max resample factor numerator, P.
maxP = 0;
for sesh = 1:size(nREMrelevIED,2)
    for j = 1:size(nREMrelevIED{sesh},1)
        newP = numel(nrem.ach{sesh,1}{j,1});
        maxP = max([newP maxP]);
    end
    
end

% resample the acetylcholine traces and timestamps.
resampACH = {};
resampACHTs = {};
for sesh = 1:size(nREMrelevIED,2)
    resampACH{sesh,1} = [];
    resampACHTs{sesh,1} = [];
    for i = 1:size(nrem.ach{sesh,1},1)
        
        
        Q = numel(nrem.ach{sesh,1}{i});
        resampACH{sesh,1}(i,:) = resample(nrem.ach{sesh,1}{i,2},maxP,Q);
        resampACHTs{sesh,1}(i,:) = resample(nrem.ach{sesh,1}{i,1},maxP,Q);

    end
end

% normalize IEDs, Ripples, and ACh times to the newly resampled ACh data.
k = 1;
dt = [];
ds = [];
rt = [];
rs = [];
for i = 1:size(nREMrelevIED,2)
    for j = 1:size(nREMrelevIED{i},1)
        [normTime, C, S] = normalize(nrem.lfp{i,1}{j,1},'range');
        normIEDTime = normalize(nrem.ied{i,1}{j,1},'center',C,'scale',S);
        normAChTime = normalize(nrem.ach{i,1}{j,1},'center',C,'scale',S);
        normRipTime = normalize(nrem.rip{i,1}{j,1},'center',C,'scale',S);

        figure(1); clf; hold on;
        plot(normTime, nrem.lfp{i,1}{j,3},'Color',[0.6 0.6 0.6]);
        xline(normIEDTime,'Color','red','LineWidth',2);
        xline(normRipTime,'Color','blue','LineWidth',2);
        yyaxis right;
        plot(normAChTime, nrem.ach{i,1}{j,2});

        dt = [dt; normIEDTime];
        ds = [ds; nrem.ied{i,1}{j,2}];

        rt = [rt; normRipTime];
        rs = [rs; nrem.rip{i,1}{j,2}];
        % pause;
    end
end 

%% Ripple-based nREM Packet Normalization of Ripples, and ACh
%%%%%%% 
% Find the max resample factor numerator, P.
maxP = 0;
for sesh = 1:size(nREMrelevRip,2)
    for j = 1:size(nREMrelevRip{sesh},1)
        newP = numel(nrem.ach{sesh,2}{j,1});
        maxP = max([newP maxP]);
    end
    
end

% resample the acetylcholine traces and timestamps.
resampACHr = {};
resampACHrTs = {};
for sesh = 1:size(nREMrelevRip,2)
    resampACHr{sesh,1} = [];
    resampACHrTs{sesh,1} = [];
    for i = 1:size(nrem.ach{sesh,2},1)
        
        Q = numel(nrem.ach{sesh,2}{i});
        if Q == 0
            continue;
        end
        resampACHr{sesh,1}(i,:) = resample(nrem.ach{sesh,2}{i,2},maxP,Q);
        resampACHrTs{sesh,1}(i,:) = resample(nrem.ach{sesh,2}{i,1},maxP,Q);

    end
end

% normalize Ripples, and ACh times to the newly resampled ACh data.
k = 1;

rt = [];
rs = [];
for i = 1:size(nREMrelevRip,2)
    for j = 1:size(nREMrelevRip{i},1)
        [normTime, C, S] = normalize(nrem.lfp{i,2}{j,1},'range');
        normAChTime = normalize(nrem.ach{i,2}{j,1},'center',C,'scale',S);
        normRipTime = normalize(nrem.rip{i,2}{j,1},'center',C,'scale',S);

        figure(1); clf; hold on;
        plot(normTime, nrem.lfp{i,2}{j,3},'Color',[0.6 0.6 0.6]);
        xline(normRipTime,'Color','blue','LineWidth',2);
        yyaxis right;
        plot(normAChTime, nrem.ach{i,2}{j,2});

        rt = [rt; normRipTime];
        rs = [rs; nrem.rip{i,2}{j,2}];
        % pause;
    end
end 
%% (2) PLOT NREM PACKET STUFF
allACH = cat(1,resampACH{:});
allACHr = cat(1,resampACHr{:});
bigEnough = ds > 2500;

figure(2); clf; hold on;
[IEDTrain, I] = sort(dt(:,1));
sizeIEDTrain = ds(I);
nrem.iedFreq = Frequency(IEDTrain,'binSize',0.05,'show','off');

[RipRipTrain, I] = sort(rt(:,1));
sizeRipRipTrain = rs(I);
nrem.ripFreq = Frequency(RipRipTrain,'binSize',0.05,'show','off');

nrem.achavg = normalize(mean(allACH,1));
nrem.achravg = normalize(mean(allACHr,1));
nrem.achts = normalize(1:numel(nrem.achavg),'range');
nrem.achrts = normalize(1:numel(nrem.achravg),'range');

nIED = normalize(nrem.iedFreq(:,2));
nRipRip = normalize(nrem.ripFreq(:,2));

plot(nrem.iedFreq(:,1),nIED,'-b','LineWidth',2);
plot(nrem.ripFreq(:,1),nRipRip,'-c','LineWidth',2);
plot(nrem.achts,nrem.achavg,'-r','LineWidth',2);
plot(nrem.achrts,nrem.achravg,'-m','LineWidth',2);

title('NREM Packets')
legend({'IED Frequency','Ripple Frequency (no IED)','ACh signal (w/ IED)','ACh signal (no IED)'},'Location','best');
xlabel('Normalized Time')
ylabel('ZScore Signal')

xlim([0 1])


%% IED-based ACh Packet Normalization of IED, Ripples, and ACh
% Find the max resample factor numerator, P.
tic;
maxP = 0;
for sesh = 1:size(achrelevIED,2)
    for j = 1:size(achrelevIED{sesh},1)
        newP = numel(ach.ach{sesh,1}{j,1});
        maxP = max([newP maxP]);
    end
end

% resample the acetylcholine traces and timestamps.
resampACH = {};
resampACHTs = {};
for sesh = 1:size(achrelevIED,2)
    resampACH{sesh,1} = [];
    resampACHTs{sesh,1} = [];
    for i = 1:size(ach.ach{sesh,1},1)
        Q = numel(ach.ach{sesh,1}{i});
        resampACH{sesh,1}(i,:) = resample(ach.ach{sesh,1}{i,2},maxP,Q);
        resampACHTs{sesh,1}(i,:) = resample(ach.ach{sesh,1}{i,1},maxP,Q);
    end
    fprintf('Session %d Resampled\n',sesh);
end
% normalize IEDs, Ripples, and ACh times to the newly resampled ACh data.
k = 1;
dt = {};
ds = {};
dd = {};
rt = {};
rs = {};
for i = 1:size(achrelevIED,2)

    dt{i} = [];
    ds{i} = [];
    dd{i} = [];
    rt{i,1} = [];
    rs{i,1} = [];
    for j = 1:size(achrelevIED{i},1)
        [normAChTime, C, S] = normalize(ach.ach{i,1}{j,1},'range');
        normIEDTime = normalize(ach.ied{i,1}{j,1},'center',C,'scale',S);
        normRipTime = normalize(ach.rip{i,1}{j,1},'center',C,'scale',S);

        % figure(1); clf; hold on;
        % plot(normAChTime, ach.ach{i,1}{j,2});
        % xline(normIEDTime,'Color','red','LineWidth',2);
        % if ~isempty(normRipTime)
        %     xline(normRipTime,'Color','blue','LineWidth',2);
        % end

        dt{i} = [dt{i}; normIEDTime];
        ds{i} = [ds{i}; ach.ied{i,1}{j,2}];
        dd{i} = [dd{i}; ach.ied{i,1}{j,4}];

        rt{i,1} = [rt{i,1}; normRipTime];
        rs{i,1} = [rs{i,1}; ach.rip{i,1}{j,2}];
        % pause;
    end
end 

% Ripple-based ACh Packet Normalization of Ripples and ACh
% Find the max resample factor numerator, P.
maxP = 0;
for sesh = 1:size(achrelevRip,2)
    for j = 1:size(achrelevRip{sesh},1)
        newP = numel(ach.ach{sesh,2}{j,1});
        maxP = max([newP maxP]);
    end
end

% resample the acetylcholine traces and timestamps.
resampACHr = {};
resampACHrTs = {};
for sesh = 1:size(achrelevRip,2)
    resampACHr{sesh,1} = [];
    resampACHrTs{sesh,1} = [];
    for i = 1:size(ach.ach{sesh,2},1)
        Q = numel(ach.ach{sesh,2}{i});
        if Q == 0
            continue;
        end
        resampACHr{sesh,1}(i,:) = resample(ach.ach{sesh,2}{i,2},maxP,Q);
        resampACHrTs{sesh,1}(i,:) = resample(ach.ach{sesh,2}{i,1},maxP,Q);
    end
    fprintf('Session %d Resampled\n',sesh);
end

% normalize Ripples, and ACh times to the newly resampled ACh data.
k = 1;

for i = 1:size(achrelevRip,2)
    rt{i,2} = [];
    rs{i,2} = [];
    for j = 1:size(achrelevRip{i},1)
        [normAChTime, C, S] = normalize(ach.ach{i,2}{j,1},'range');
        normRipTime = normalize(ach.rip{i,2}{j,1},'center',C,'scale',S);

        % figure(1); clf; hold on;
        % plot(normAChTime, ach.ach{i,2}{j,2});
        % xline(normRipTime,'Color','blue','LineWidth',2);

        rt{i,2} = [rt{i,2}; normRipTime];
        rs{i,2} = [rs{i,2}; ach.rip{i,2}{j,2}];
        % pause;
    end
end 
toc;
%% (2) PLOT ACh Packet Duration Kernel Density
% Define Colors!!
numCols = 15;
threshLines = copper(numCols);
iediedLines = spring(numCols);
ripripLines = summer(numCols);
iedripLines = winter(numCols);

subset = [4];
allACH = cat(1,resampACH{subset});
allACHr = cat(1,resampACHr{subset});
alldt = cat(1,dt{subset});
allds = cat(1,ds{subset});
alldd = cat(1,dd{subset});
iedrt = cat(1,rt{subset,1});
iedrs = cat(1,rs{subset,1});
riprt = cat(1,rt{subset,2});
riprs = cat(1,rs{subset,2});
bigEnough = allds > 2500;

fig10 = figure(10); clf; hold on;
fig10.Units = 'Normalized';
fig10.Position = [0.6 0.05 0.3 0.4];

[IEDTrain, I] = sort(alldt(:,1));
sizeIEDTrain = allds(I);
duraIEDTrain = alldd(I);
iedSubset = sizeIEDTrain>4000;
iedFreq = Frequency(IEDTrain,'binSize',0.05,'show','off');
% iedFreq = Frequency(IEDTrain(iedSubset),'binSize',0.05,'show','off');
% pathRipFreq = Frequency(IEDTrain(sizeIEDTrain<=5000),'binSize',0.05,'show','off');
% iedFreq = Frequency(IEDTrain(duraIEDTrain>0.06),'binSize',0.05,'show','off');

[RipRipTrain, I] = sort(riprt(:,1));
sizeRipRipTrain = riprs(I);
ripRipFreq = Frequency(RipRipTrain,'binSize',0.05,'show','off');

[IedRipTrain, I] = sort(iedrt(:,1));
sizeIedRipTrain = iedrs(I);
iedRipFreq = Frequency(IedRipTrain,'binSize',0.05,'show','off');

nrem.achavg = normalize(mean(allACH,1));
nrem.achravg = normalize(mean(allACHr,1));
nrem.achts = normalize(1:numel(nrem.achavg),'range');
nrem.achrts = normalize(1:numel(nrem.achravg),'range');

nIED = normalize(iedFreq(:,2));
nRipRip = normalize(ripRipFreq(:,2));
nIedRip = normalize(iedRipFreq(:,2));

ii = plot(iedFreq(:,1),nIED,'color',iediedLines(3,:),'LineWidth',2);
rr = plot(ripRipFreq(:,1),nRipRip,'color',ripripLines(3,:),'LineWidth',2);
ir = plot(iedRipFreq(:,1),nIedRip,'color',iedripLines(3,:),'LineWidth',2);

yyaxis right;
ai = plot(nrem.achts,nrem.achavg,'-','color',threshLines(5,:),'LineWidth',2);
ar = plot(nrem.achrts,nrem.achravg,'-','color',threshLines(10,:),'LineWidth',2);

title('ACh Packets')
% legend({'IED Frequency','Ripple Frequency (no IED)','ACh signal (w/ IED)','ACh signal (no IED)'},'Location','best');
% legend({'IED Frequency','Ripple Frequency','ACh signal (w/ IED)'},'Location','best');
legend([ai ar ii rr ir], ...
    {'ACh Packets w/ IED','ACh Packets w/o IED','IED Frequency','Ripple Frequency (packets w/ IED)','Ripple Frequency (packets w/o IED'}, ...
    'location','southoutside')
xlabel('Normalized Time')
ylabel('ZScore Signal')

% xlim([0 1])


%% Absolute ACh Time stuff
% get ACh packet start times
achStart = {};
for sesh = 1:size(ach.ach,1)
    for i = 1:size(ach.ach{sesh,1},1)
        achStart{sesh,1}(i,1) = ach.ach{sesh,1}{i,1}(1);
        achDur{sesh,1}(i,1) = range(ach.ach{sesh,1}{i,1});
    end
    for i = 1:size(ach.ach{sesh,2},1)
        achStart{sesh,2}(i,1) = ach.ach{sesh,2}{i,1}(1);
        achDur{sesh,2}(i,1) = range(ach.ach{sesh,2}{i,1});
    end
end

% zero the IED and Ripple times relative to ACh packet start times
[iediedzero, iedripzero, ripripzero, iedSize] = deal({});

for sesh = 1:size(ach.ied,1)
    for i = 1:size(ach.ied{sesh,1})
        iediedzero{sesh,1}{i,1} = ach.ied{sesh,1}{i,1} - achStart{sesh,1}(i);
        iedripzero{sesh,1}{i,1} = ach.rip{sesh,1}{i,1} - achStart{sesh,1}(i);
    end
    for i = 1:size(ach.rip{sesh,2})
        ripripzero{sesh,1}{i,1} = ach.rip{sesh,2}{i,1} - achStart{sesh,2}(i);
    end
end
%% Plot Event Time Kernel Density Distribution
subset = [1:4];
allIedAchTimes = cat(1,achDur{subset,1});
allRipAchTimes = cat(1,achDur{subset,2});

AchDurThresh = 0:10:40;
AchDurThresh = 0;
fig1 = figure(1); clf; hold on;
fig1.Units = 'Normalized';
fig1.Position = [0.3 0.52 0.3 0.4];
% xlim([0 60])

% fig2 = figure(2); clf; hold on;
% fig2.Units = 'Normalized';
% fig2.Position = [0.3 0.05 0.3 0.4];
% xlim([0 60])

% fig3 = figure(3); clf; hold on;
% fig3.Units = 'Normalized';
% fig3.Position = [0 0.05 0.3 0.4];
% xlim([0 60])

% fig6 = figure(6); clf; hold on;
% fig6.Units = 'Normalized';
% fig6.Position = [0.6 0.05 0.3 0.4];


for thresh = 1:numel(AchDurThresh)
    longEnoughRipAch = allRipAchTimes > AchDurThresh(thresh);
    longEnoughIedAch = allIedAchTimes > AchDurThresh(thresh);

    allIedIedTimes = cat(1,iediedzero{subset});
    allIedIedTimes = cat(1,allIedIedTimes{longEnoughIedAch});
    [fII, xII] = ksdensity(allIedIedTimes);
    
    allIedRipTimes = cat(1,iedripzero{subset});
    allIedRipTimes = cat(1,allIedRipTimes{longEnoughIedAch});
    [fIR, xIR] = ksdensity(allIedRipTimes);
    
    allRipRipTimes = cat(1,ripripzero{subset});
    allRipRipTimes = cat(1,allRipRipTimes{longEnoughRipAch});
    [fRR, xRR] = ksdensity(allRipRipTimes);

    allRipTimes = [allIedRipTimes; allRipRipTimes];
    [fR, xR] = ksdensity(allRipTimes);
   

    % histogram(allIedIedTimes, ...
    %     'DisplayStyle','stairs', ...
    %     'EdgeColor','red', ...
    %     'LineWidth',2);
    % histogram(allRipRipTimes, ...
    %     'DisplayStyle','stairs', ...
    %     'EdgeColor','blue', ...
    %     'LineWidth',2);
    % histogram(allIedRipTimes, ...
    %     'DisplayStyle','stairs', ...
    %     'EdgeColor','cyan', ...
    %     'LineWidth',2);

    ii(thresh) = plot(get(fig1,'CurrentAxes'),xII, fII,'Color',iediedLines(thresh,:),'LineWidth',2);
    r(thresh) = plot(get(fig1,'CurrentAxes'),xR, fR,'Color',threshLines(thresh,:),'LineWidth',2);
    % th(thresh) = xline(get(fig1,'CurrentAxes'),AchDurThresh(thresh),'Color',threshLines(thresh,:),'LineWidth',1);
    % rr(thresh) = plot(get(fig2,'CurrentAxes'),xRR, fRR,'Color',ripripLines(thresh,:),'LineWidth',2);
    % ir(thresh) = plot(get(fig2,'CurrentAxes'),xIR, fIR,'Color',iedripLines(thresh,:),'LineWidth',2);
    % th(thresh) = xline(get(fig2,'CurrentAxes'),AchDurThresh(thresh),'Color',threshLines(thresh,:),'LineWidth',1);

    xline(xII(fII==max(fII)),'--','Color',iediedLines(thresh,:),'LineWidth',2);
    xline(xR(fR==max(fR)),'--','Color',threshLines(thresh,:),'LineWidth',2);
    % xline(xRR(fRR==max(fRR)),'--b','LineWidth',2);
    % xline(xIR(fIR==max(fIR)),'--c','LineWidth',2);

    text(xII(fII==max(fII))+2, fII(fII==max(fII)), ...
         num2str(xII(fII==max(fII))),'FontSize',12,'Color',iediedLines(thresh,:));
    text(xR(fR==max(fR))+2, fR(fR==max(fR)), ...
         num2str(xR(fR==max(fR))),'FontSize',12,'Color',threshLines(thresh,:));
    

end

% legend(get(fig1,'CurrentAxes'),[ii(1)],{'IED in IED ACh packets'}, ...
%     'Location','northeast')
% xlabel(get(fig1,'CurrentAxes'),'Time (s) after ACh Peak')
% ylabel(get(fig1,'CurrentAxes'),'Probability')

chH = get(get(fig1,'CurrentAxes'),'Children');
set(get(fig1,'CurrentAxes'),'Children',[chH(2:2:end),chH(1:2:end)])
legend(get(fig1,'CurrentAxes'),[ii(1),r(1)],{'IEDs','Ripples'}, ...
    'Location','northeast')
xlabel(get(fig1,'CurrentAxes'),'Time (s) after ACh Peak')
ylabel(get(fig1,'CurrentAxes'),'Probability of Event')

% chH = get(get(fig2,'CurrentAxes'),'Children');
% set(get(fig2,'CurrentAxes'),'Children',[chH(1:2:end),chH(2:2:end)])
% legend(get(fig2,'CurrentAxes'),[ir(1), rr(1)],{'Ripples in IED ACh packets','Ripples in Ripple ACh packets'}, ...
%     'Location','northeast')
% xlabel(get(fig2,'CurrentAxes'),'Time (s) after ACh Peak')
% ylabel(get(fig2,'CurrentAxes'),'Probability')
% 
% legend(get(fig3,'CurrentAxes'),[r(1)],{'Ripples in All ACh packets'}, ...
%     'Location','northeast')
% xlabel(get(fig3,'CurrentAxes'),'Time (s) after ACh Peak')
% ylabel(get(fig3,'CurrentAxes'),'Probability')

%%%%%%% ACh Packet Durations.
for i = 1:size(ach.ach,1)
    for j = 1:size(ach.ach{i,1},1)
        packetLengthIED{i,1}(j,1) = range(ach.ach{i,1}{j,1});
    end
    for j = 1:size(ach.ach{i,2},1)
        packetLengthRIP{i,1}(j,1) = range(ach.ach{i,2}{j,1});
    end
end

allPacketIED = cat(1,packetLengthIED{subset});
allPacketRIP = cat(1,packetLengthRIP{subset});
allPacketAll = [allPacketIED; allPacketRIP];

fig4 = figure(4); clf; hold on;
fig4.Units = 'Normalized';
fig4.Position = [0 0.52 0.3 0.4];
[fI, xI] = ksdensity(allPacketIED);
[fR, xR] = ksdensity(allPacketRIP);
[fA, xA] = ksdensity(allPacketAll);

plot(xI, fI,'color',iediedLines(1,:),'LineWidth',2);
% plot(xR, fR,'color',ripripLines(1,:),'LineWidth',2);
plot(xA, fA,'color',threshLines(1,:),'LineWidth',2);

xline(xI(fI==max(fI)),'--','color',iediedLines(1,:),'LineWidth',2)
% xline(xR(fR==max(fR)),'--b','LineWidth',2)
xline(xA(fA==max(fA)),'--','color',threshLines(1,:),'LineWidth',2)
text(xI(fI==max(fI))+2, fI(fI==max(fI)), ...
     num2str(xI(fI==max(fI))),'FontSize',12,'Color',iediedLines(thresh,:));
text(xA(fA==max(fA))+2, fA(fA==max(fA)), ...
     num2str(xA(fA==max(fA))),'FontSize',12,'Color',threshLines(thresh,:));
% for thresh = 1:numel(AchDurThresh)
%     xline(AchDurThresh(thresh),'-','Color',threshLines(thresh,:),'LineWidth',2)
% end


title('Kernel Density of ACh Packet Durations')
xlabel('Packet Duration (s)')
ylabel('Probability')
legend({'IED ACh Packets','Ripple ACh Packets'},'location','best')

fprintf('Ripple-Only Packet Peak Duration: %f\n', xR(fR==max(fR)));
fprintf('IED Packet Peak Duration: %f\n', xI(fI==max(fI)));

%{
fig5 = figure(5); clf; hold on;
fig5.Units = 'Normalized';
fig5.Position = [0.6 0.52 0.3 0.4];
histogram(allPacketIED,1:2:60, ...
    'DisplayStyle','stairs', ...
    'EdgeColor','red', ...
    'LineWidth',2);
xline(median(allPacketIED),'--r','LineWidth',2);
histogram(allPacketRIP,1:2:60, ...
    'DisplayStyle','stairs', ...
    'EdgeColor','blue', ...
    'LineWidth',2);
xline(median(allPacketRIP),'--b','LineWidth',2);
histogram(allPacketAll,1:2:60, ...
    'DisplayStyle','stairs', ...
    'EdgeColor','black', ...
    'LineWidth',2);
xline(median(allPacketAll),'--k','LineWidth',2);

fprintf('Ripple-Only Packet Duration: \n mean: %f\n variance: %f\n', mean(allPacketRIP), var(allPacketRIP));
fprintf('IED Packet Duration: \n mean: %f\n variance: %f\n', mean(allPacketIED), var(allPacketIED));
%}



%% IED waveforms exploration
loadData = true;

col = lines(10);
close all;
fig = figure(1); clf; hold on;
fig.Units = 'Normalize';
fig.Position = [0 0.05 1 0.865];
for sesh = [11:15]
    if loadData
        clear ripples IED SleepScoreLFP SleepState StateInfo
        sessionInd = sesh;
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.IEDclean.events.mat']));
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.ripples.events.mat']));
    end
    
    
    % reps = 200;
    % idx = [];
    % for i = 1:reps
    %     idx(:,i) = kmeans(IED.rippleStats.maps.ripples_filtered,6);
    % end
    % idx = mode(idx,2);
    % cluIdx = unique(idx);
    % for i = 1:numel(cluIdx)
    %     fig = figure(i); hold on; 
    %     fig.Units = 'Normalized';
    %     fig.Position = [mod(i-1,round(numel(unique(idx))/2))*1/round(numel(unique(idx))/2), round((i-1)/numel(unique(idx)))*0.45 + 0.05, 1/ceil(numel(unique(idx))/2), 0.38];
    %     plot(IED.rippleStats.maps.timestamps, IED.rippleStats.maps.ripples_filtered(idx==cluIdx(i),:), ...
    %         'Color',col(i,:),'LineWidth',1);
    % end
    % numFigs = 6;
    % for i = 1:numFigs
    %     fig = figure(i); clf; hold on; 
    %     fig.Units = 'Normalized';
    %     fig.Position = [mod(i-1,round(numFigs/2))*1/round(numFigs/2), ...
    %                     round((i-1)/numFigs)*0.45 + 0.05, ...
    %                     1/ceil(numFigs/2), ...
    %                     0.38];
    % end
    bigEnough = IED.rippleStats.data.peakAmplitude > 5000;

    subplot(2,3,1)
    plot(ripples.rippleStats.maps.timestamps, ripples.rippleStats.maps.ripples_filtered, ...
                'LineWidth',1);
    subplot(2,3,4)
    plot(ripples.rippleStats.maps.timestamps, mean(ripples.rippleStats.maps.ripples_filtered,1), ...
                'LineWidth',1);
    subplot(2,3,2)
    plot(IED.rippleStats.maps.timestamps, IED.rippleStats.maps.ripples_filtered(bigEnough,:), ...
                'LineWidth',1);
    YLim = ylim;
    subplot(2,3,5)
    plot(IED.rippleStats.maps.timestamps, mean(IED.rippleStats.maps.ripples_filtered(bigEnough,:),1), ...
                'LineWidth',1);
    subplot(2,3,3)
    plot(IED.rippleStats.maps.timestamps, IED.rippleStats.maps.ripples_filtered(~bigEnough,:), ...
                'LineWidth',1);
    ylim(YLim);
    subplot(2,3,6)
    plot(IED.rippleStats.maps.timestamps, mean(IED.rippleStats.maps.ripples_filtered(~bigEnough,:),1), ...
                'LineWidth',1);
    % plot(IED.rippleStats.data.duration, IED.rippleStats.data.peakAmplitude,'.')

    pause;
end

%%
close all;

%% Ripple/IED Time vs. ACh Packet Duration

ripachdur = {};
for sesh = 1:size(ripripzero,1)
    numRipPerAch = cellfun(@size, ripripzero{sesh},'UniformOutput',false);
    numRipPerAch = cat(1, numRipPerAch{:});
    numRipPerAch = numRipPerAch(:,1);
    for i = 1:numel(numRipPerAch)
        ripachdur{sesh,2}{i,1} = repmat(achDur{sesh,2}(i),numRipPerAch(i),1);
    end
end

iedachdur = {};
for sesh = 1:size(iedripzero,1)
    numRipPerAch = cellfun(@size, iedripzero{sesh},'UniformOutput',false);
    numRipPerAch = cat(1, numRipPerAch{:});
    numRipPerAch = numRipPerAch(:,1);

    numIedPerAch = cellfun(@size, iediedzero{sesh},'UniformOutput',false);
    numIedPerAch = cat(1, numIedPerAch{:});
    numIedPerAch = numIedPerAch(:,1);

    for i = 1:numel(numRipPerAch)
        ripachdur{sesh,1}{i,1} = repmat(achDur{sesh,1}(i),numRipPerAch(i),1);
        iedachdur{sesh,1}{i,1} = repmat(achDur{sesh,1}(i),numIedPerAch(i),1);
    end
end



allRipRipTimes = cat(1,ripripzero{:});
allRipRipTimes = cat(1,allRipRipTimes{:});
allRipAchDuxns = cat(1,ripachdur{:,2});
allRipAchDuxns = cat(1,allRipAchDuxns{:});

allIedRipTimes = cat(1,iedripzero{:});
allIedRipTimes = cat(1,allIedRipTimes{:});
ripIedAchDuxns = cat(1,ripachdur{:,1});
ripIedAchDuxns = cat(1,ripIedAchDuxns{:});

allIedIedTimes = cat(1,iediedzero{:});
allIedIedTimes = cat(1,allIedIedTimes{:});
iedIedAchDuxns = cat(1,iedachdur{:,1});
iedIedAchDuxns = cat(1,iedIedAchDuxns{:});

figure(11); clf; hold on;
plot(allRipAchDuxns, allRipRipTimes, ...
    '.b')
plot(ripIedAchDuxns, allIedRipTimes, ...
    '.r')
plot(iedIedAchDuxns, allIedIedTimes, ...
    '.g')

%% Rip/IED frequency 
allIedIed = cat(1,iediedzero{:});
allIedIed = cat(1,allIedIed{:});
allRipIed = cat(1,iedripzero{:});
allRipIed = cat(1,allRipIed{:});
allRipRip = cat(1,ripripzero{:});
allRipRip = cat(1,allRipRip{:});
allRip = [allRipIed; allRipRip];

freqIedIed = Frequency(sort(allIedIed));
freqRip = Frequency(sort(allRip));

fig11 = figure(11); clf; hold on;
% plot(freqIedIed(:,1),freqIedIed(:,2),'Color',iediedLines(1,:),'LineWidth',1);
% plot(freqIedRip(:,1),freqIedRip(:,2),'Color',iedripLines(1,:),'LineWidth',1);
% yyaxis right;
% plot(freqRipRip(:,1),freqRipRip(:,2),'Color',ripripLines(1,:),'LineWidth',1);

[xcorrIIRR, lags] = xcorr(freqIedIed(:,2),freqRip(:,2));
plot(lags,zscore(xcorrIIRR),'LineWidth',1)

xline(0)

%%
for j = 1:size(nREMrelevIED{sesh},1)
    lfpIdx = intervalLFP==j;
    iedIdx = intervalIED==j;
%         nrem.lfp{sesh}{j,1} = SleepScoreLFP.t(lfpIdx);
%         nrem.lfp{sesh}{j,2} = SleepScoreLFP.swLFP(lfpIdx);
%         nrem.lfp{sesh}{j,3} = SleepScoreLFP.thLFP(lfpIdx);
    nrem.lfp{sesh}{j,1} = lfp.timestamps(lfpIdx);
    nrem.lfp{sesh}{j,2} = lfp.data(lfpIdx);

    nrem.ied{sesh}{j,1} = IED.timestamps(iedIdx,1);
    nrem.ied{sesh}{j,2} = IED.peaks(iedIdx);
    

end  



%%
wake = bz_IDXtoINT(statesIdx.states==1);
nrem = bz_IDXtoINT(statesIdx.states==2);
rem = bz_IDXtoINT(statesIdx.states==3);

%%
fig = figure(1); clf; hold on;
fig.Units = 'normalized';
fig.Position = [0 0.05 1 0.87];

tl = tiledlayout(fig,5,1);
title(tl, 'Brain States Identified');


nexttile(tl); hold on;
% plot(SleepScoreLFP.t, SleepScoreLFP.thLFP, 'Color',[0.6 0.6 0.6])
plot(lfp.timestamps,lfp.data,'Color',[0.6 0.6 0.6]);
for i = 1:size(nREMpackets.state1,1)
    x = sort([nREMpackets.state1(i,:) nREMpackets.state1(i,:)]);
    y = [ylim flip(ylim)];
    patch(x,y,'blue','FaceAlpha',0.2,'EdgeAlpha',0)
end
% xlim([0 ceil(max(lfp.timestamps)/1000)*1000])



nexttile(tl,[2 1]); hold on;
plot(AChAnalyzis.time, AChAnalyzis.AChTrace,'k');
ylim([-0.2 0.2])
% xlim([0 ceil(max(AChAnalyzis.time)/1000)*1000])
for i = 1:size(nREMpackets.state1,1)
    x = sort([nREMpackets.state1(i,:) nREMpackets.state1(i,:)]);
    y = [ylim flip(ylim)];
    patch(x,y,'blue','FaceAlpha',0.2,'EdgeAlpha',0)
end
for i = 1:size(arousals.timestamps,1)
    x = sort([arousals.timestamps(i,:) arousals.timestamps(i,:)]);
    y = [ylim flip(ylim)];
    patch(x,y,'magenta','FaceAlpha',0.2,'EdgeAlpha',0)
end
% xline(IED.time,'red');



nexttile(tl,[2 1]); hold on;
plot(1:numel(mvmt),mvmt,'b');
% for i = 1:size(nREMpackets.state1,1)
%     x = sort([nREMpackets.state1(i,:) nREMpackets.state1(i,:)]);
%     y = [ylim flip(ylim)];
%     patch(x,y,'blue','FaceAlpha',0.2,'EdgeAlpha',0)
% end
% for i = 1:size(arousals.timestamps,1)
%     x = sort([arousals.timestamps(i,:) arousals.timestamps(i,:)]);
%     y = [ylim flip(ylim)];
%     patch(x,y,'red','FaceAlpha',0.2,'EdgeAlpha',0)
% end
for i = 1:size(wake.state1,1)
    x = sort([wake.state1(i,:) wake.state1(i,:)]);
    y = [ylim flip(ylim)];
    patch(x,y,'green','FaceAlpha',0.2,'EdgeAlpha',0)
end
for i = 1:size(nrem.state1,1)
    x = sort([nrem.state1(i,:) nrem.state1(i,:)]);
    y = [ylim flip(ylim)];
    patch(x,y,'blue','FaceAlpha',0.2,'EdgeAlpha',0)
end
for i = 1:size(rem.state1,1)
    x = sort([rem.state1(i,:) rem.state1(i,:)]);
    y = [ylim flip(ylim)];
    patch(x,y,'red','FaceAlpha',0.2,'EdgeAlpha',0)
end
% xline(IED.time,'red');
% ylim([0 2])
% xlim([0 ceil(numel(mvmt)/1000)*1000])

% xline(nREMpackets.state1(:,1),'--r');
% xline(nREMpackets.state1(:,2),'--b');

%% Plot Inspection (WIP)
livePlot = true;
windows = 1:500:ceil(max(AChAnalyzis.time)/1000)*1000;
% windows = 1:20000:numel(AChAnalyzis.time);
win = 1;
fig = figure(1); clf; hold on;
fig.Units = 'normalized';
fig.Position = [0 0.5 1 0.45];

% tl = tiledlayout(fig,1,1);
% tl.TileSpacing = 'compact';
% tl.Padding = 'tight';
% title(tl, 'Brain States Identified');


[pks,locs,wid,prom] = findpeaks(AChAnalyzis.AChTrace,...
    'MinPeakProminence',1e-2, ...
    'MinPeakWidth',1e-2, ...
    'WidthReference','halfprom');

% findpeaks(AChAnalyzis.AChTrace,...
%     'MinPeakProminence',5e-3, ...
%     'MinPeakWidth',50, ...
%     'WidthReference','halfprom', ...
%     'Annotate','extents');

% deltaAChP = zeros(size(AChAnalyzis.AChTrace));
% deltaAChP(locs) = 1;


while livePlot
    clf; hold on;
    title('Acetylcholine Peaks'); 
    plot(AChAnalyzis.time, AChAnalyzis.AChTrace,'k');
    plot(AChAnalyzis.time(locs),pks,'.m','MarkerSize',12)
    ylim([-0.15 0.15])
    for i = 1:size(nREMpackets.state1,1)
        x = sort([nREMpackets.state1(i,:) nREMpackets.state1(i,:)]);
        y = [ylim flip(ylim)];
        patch(x,y,'blue','FaceAlpha',0.2,'EdgeAlpha',0)
    end
    for i = 1:size(arousals.timestamps,1)
        x = sort([arousals.timestamps(i,:) arousals.timestamps(i,:)]);
        y = [ylim flip(ylim)];
        patch(x,y,'magenta','FaceAlpha',0.2,'EdgeAlpha',0)
    end
    xline(IED.timestamps(1,:),'red');

    yyaxis right;
    % plot(1:numel(accel.acceleration.motion),accel.acceleration.motion/1600,'-r');
    % ylim([0 8000])
    % 
    plot(EMGFromLFP.timestamps, EMGFromLFP.data,'-b');
    plot(EMGFromLFP.timestamps, (EMGFromLFP.data).^2,'-','color',[0 0.4470 0.7410]);

    ylim([0 5])

    xlim([windows(win) windows(win+1)]);


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
    elseif was_a_key && strcmp(get(fig,'CurrentKey'),'escape')
        livePlot = false;
        close all;
    else
        continue;
    end

end







%% Peri-IED ACh Signal
AChWindow = [];
for dc = 1:numel(IED.timestamps(:,1))
    windWidth = 50; %seconds
    ach.iedstart = find(AChAnalyzis.time >= IED.timestamps(dc,1)-windWidth,1,'first');
    ach.iedstop = find(AChAnalyzis.time >= IED.timestamps(dc,1)+windWidth,1,'first');

    AChWindow(dc,:) = AChAnalyzis.AChTrace(ach.iedstart:ach.iedstop);
    % hold on;
    % plot(AChWindow(dc,:));



end

pIEDt = -1*windWidth:0.01:windWidth;
pIEDavg = mean(AChWindow,1);
pIEDsd = std(AChWindow,1);


curve1 = pIEDavg + pIEDsd;
curve2 = pIEDavg - pIEDsd;
x2 = [pIEDt, fliplr(pIEDt)];
inBetween = [curve1, fliplr(curve2)];
fill(x2, inBetween, [0.7 0.7 0.7], ...
    'EdgeColor','none', ...
    'FaceAlpha',0.5);
hold on;
plot(pIEDt, pIEDavg, 'r', 'LineWidth', 2);

%% Peak-2-Peak Packets
% deltaACh = diff(AChAnalyzis.AChTrace);
% deltaAChSq = deltaACh.^2;
% deltaAChBig = deltaAChSq > 0.3e-6;
% deltaAChSqTh = deltaAChSq;
% deltaAChSqTh(~deltaAChBig) = 0;
% deltaAChSqTh(deltaAChBig) = 1;

[pks,locs,wid,prom] = findpeaks(AChAnalyzis.AChTrace, ...
    'MinPeakProminence',5e-3, ...
    'MinPeakWidth',50, ...
    'WidthReference','halfprom');

delta   AChP = zeros(size(AChAnalyzis.AChTrace));
deltaAChP(locs) = 1;

pt = [0; locs];
for i = 1:numel(pt)-1
    p2p(i,:) = [pt(i)+1 pt(i+1)];
    
end

%%%%%%% IEDs %%%%%%%
[ied_p2p, intD, indD] = InIntervals(IED.timestamps(:,1),AChAnalyzis.time(p2p));

relevantP2PI = unique(intD); % Isoate the Acetylcholine P2P packets that have IEDs.
relevantP2PI = relevantP2PI(relevantP2PI ~= 0);
relevantACHI = {};
for i = 1:numel(relevantP2PI)
    relevantACHI{i,1} = AChAnalyzis.AChTrace(p2p(relevantP2PI(i),1):p2p(relevantP2PI(i),2));
    relevantACHI{i,2} = AChAnalyzis.time(p2p(relevantP2PI(i),1):p2p(relevantP2PI(i),2));
end
% Normalize all IED times
maxP = 0;
for i = 1:size(relevantACHI,1)
    newP = numel(relevantACHI{i,1});
    maxP = max([maxP newP]);
end
normIED = [];
ied_ach = [];
resampTsI = [];
for i = 1:size(relevantACHI,1)
    Q = numel(relevantACHI{i,1});
    ied_ach(i,:) = resample(relevantACHI{i,1},maxP,Q);
    resampTsI(i,:) = resample(relevantACHI{i,2},maxP,Q);

    [N,C,S] = normalize(resampTsI(i,:),'range');
    iedTs = IED.timestamps(intD==relevantP2PI(i),1);
    normIED = [normIED; normalize(iedTs,'center',C,'scale',S)];
    
    % figure(1); hold on;
    % plot(ied_ach(i,:),'Color',[0.6 0.6 0.6])
end



%%%%%%% RIPPLES %%%%%%%
[rip_p2p, intR, indR] = InIntervals(ripples.peaks,AChAnalyzis.time(p2p));

relevantP2PR = unique(intR); % Isoate the Acetylcholine P2P packets that have ripples.
relevantP2PR = relevantP2PR(relevantP2PR ~= 0);
relevantP2PR = relevantP2PR(~ismember(relevantP2PR,relevantP2PI));
relevantACHR = {};
for i = 1:numel(relevantP2PR)
    relevantACHR{i,1} = AChAnalyzis.AChTrace(p2p(relevantP2PR(i),1):p2p(relevantP2PR(i),2));
    relevantACHR{i,2} = AChAnalyzis.time(p2p(relevantP2PR(i),1):p2p(relevantP2PR(i),2));
    
end
% Normalize all Ripple Times
maxP = 0;
for i = 1:size(relevantACHR,1)
    newP = numel(relevantACHR{i,1});
    maxP = max([maxP newP]);
end

normRip = [];
rip_ach = [];
resampTsR = [];
for i = 1:size(relevantACHR,1)
    Q = numel(relevantACHR{i,1});
    rip_ach(i,:) = resample(relevantACHR{i,1},maxP,Q);
    resampTsR(i,:) = resample(relevantACHR{i,2},maxP,Q);

    [N,C,S] = normalize(resampTsR(i,:),'range');
        
    ripTs = ripples.peaks(intR==relevantP2PR(i),1);
    normRip = [normRip; normalize(ripTs,'center',C,'scale',S)];
    
    % figure(2); hold on;
    % plot(rip_ach(i,:),'Color',[0.6 0.6 0.6])
end

%%
%%%%%%% Plotting %%%%%%%
figure(3); clf; hold on;
% pIEDavg = normalize(mean(ied_ach,1));
% pIEDsd = normalize(std(ied_ach,1));
pIEDt = normalize(1:size(resampTsI,2),'range');
pIEDavg = (mean(ied_ach,1));
pIEDsd = (std(ied_ach,1));

curve1 = pIEDavg + pIEDsd;
curve2 = pIEDavg - pIEDsd;
x2 = [pIEDt, fliplr(pIEDt)];
inBetween = [curve1, fliplr(curve2)];
fill(x2, inBetween, [0.7 0.7 0.7], ...
    'EdgeColor','none', ...
    'FaceAlpha',0.5);
hold on;
plot(pIEDt, pIEDavg, 'r', 'LineWidth', 2);

%%%%%%%
figure(4); clf; hold on;
% pRIPavg = normalize(mean(rip_ach,1));
% pRIPsd = normalize(std(rip_ach,1));
pRIPt = normalize(1:size(resampTsR,2),'range');
pRIPavg = (mean(rip_ach,1));
pRIPsd = (std(rip_ach,1));

curve1 = pRIPavg + pRIPsd;
curve2 = pRIPavg - pRIPsd;
x2 = [pRIPt, fliplr(pRIPt)];
inBetween = [curve1, fliplr(curve2)];
fill(x2, inBetween, [0.7 0.7 0.7], ...
    'EdgeColor','none', ...
    'FaceAlpha',0.5);
hold on;
plot(pRIPt, pRIPavg, 'r', 'LineWidth', 2);

%%%%%%%
figure(5); clf; hold on;
normRip = sort(normRip);
ripNormFreq = Frequency(normRip,'binSize',0.05);
plot(ripNormFreq(:,1),normalize(ripNormFreq(:,2)),'-b','LineWidth',2);
plot(pRIPt, normalize(pRIPavg), 'r', 'LineWidth', 2);

normIED = sort(normIED);
iedNormFreq = Frequency(normIED,'binSize',0.05);
plot(iedNormFreq(:,1),normalize(iedNormFreq(:,2)),'-c','LineWidth',2);
plot(pIEDt, normalize(pIEDavg), 'm', 'LineWidth', 2);


title('ACh Peak-to-Peak Packet')
legend({'IED Frequency','ACh Signal (IED)', ...
        'Ripple Frequency','ACh Signal (Ripple)'},'location','northwest')
xlabel('Normalized Time (ACh peak-to-peak)');
ylabel('ZScored Signal');
xlim([0 1])

%%%%%%%
for i = 1:size(relevantACHI,1)
    packetLengthIED(i,1) = range(relevantACHI{i,2});
end

for i = 1:size(relevantACHR,1)
    packetLengthRIP(i,1) = range(relevantACHR{i,2});
end

figure(6); clf; hold on;
[fI, xI] = ksdensity(packetLengthIED);
[fR, xR] = ksdensity(packetLengthRIP);
plot(xI, fI,'-b','LineWidth',2);
plot(xR, fR,'-c','LineWidth',2);
title('Kernel Density of ACh Packet Durations')
xlabel('Packet Duration (s)')
ylabel('Probability')
legend({'IED ACh Packets','Ripple ACh Packets'},'location','best')





%% Re-run Sleep Score Master
basepath = pwd;
SleepScoreMaster(basepath,'savedir',fullfile(basepath,'tempDir'));


    
%% The State Editor
basepath = pwd;
basename = bz_BasenameFromBasepath(basepath);
TheStateEditor(basename)

    
    