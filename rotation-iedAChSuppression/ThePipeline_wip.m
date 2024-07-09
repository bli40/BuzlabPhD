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


% User Defined Stuff
mvmtThresh = [0.18, 0.2, 0.23, 0.5, ...
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
badPeaks{5} = [720,991,992,1280,1375,1405,1718,2298,2299,2335,2378,2379,2396,...
               2417,2521,2557];
badPeaks{6} = [331,509,543,633,644,729,783,827,1129,1187,1280,1283,1330,1331,...
               2205,2253,2285,2286,2314,2329,2332,2349];
badPeaks{7} = [424,478,603,723,1355,1358,1359,1449,1450,1582,1923,1929,2122,2255,2262];
badPeaks{8} = [283,892,1804,1847,1917,1963,1969,1978,2089,2107,2108,2178,2464,2518];
badPeaks{10}= [275,479,603,685,723,1581,2021,2077,2097,2121,2255,2486,2502];
badPeaks{11}= [256,319,308,309,358,362,379,407,463,646,479,502,543,656,661,665,755,...
               1032,1053,1162,1240,1268,1269,1349,1566,1567,1573,1651,1702];
badPeaks{12}= [187,926,1132,1185,1311,1345,1379];
badPeaks{13}= [464,1240];
badPeaks{15}= [183:186,350,528,574,599,629,754,760,770,786,792,795,799,803,806,845,853,...
               881,898,918,921,923,928,935,949,956:958,961,992,995,1111,1235,1416,1422,...
               1431,1447,1464,1543,1548,1550:1552,1576,1597,1605,1614,1615,1623,1638,...
               1660,1668,1677,1681:1683,1693,1833,1984,1994,2009,2045,2061,2065,2130,...
               2131,2134,2135,2145,2168,2170,2466,2512,2576];
badPeaks{16}= [283,293,379,393,394,414,421,425,436,446,449,460,559,560,584,585,600,...
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
badPeaks{17}= [330,340,345,358,639,656,676,702,709,717,718,723,727,728,763,773,774,790,...
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



for sesh = 1:4
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

