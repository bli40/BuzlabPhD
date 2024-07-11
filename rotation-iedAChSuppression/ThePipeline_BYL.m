%% The Pipeline for plotting Ripple and IED dynamics relative to ACh
% Description:
% 
% Dependencies:
% (1) SleepScoreLFP - sharp wave and theta lfp from SleepScoreMaster
% (2) SleepState - sleep states from SleepScoreMaster
% (3) StateInfo - 
% (4) IEDclean
%   [a] needs rippleStats
% (5) EMFfromLFP
% (6) AChAnalyzis
% 
% Optional:
% (1) Ripples
%   [a] needs rippleStats
% (2) Acceleration (not implemented)



%% Start Up
clear all; close all;

% Add BUZCODE and personal code paths on your system
addpath(genpath('C:\Users\brian\buzcode'));
addpath(genpath('C:\Users\brian\BuzlabPhD\rotation-iedAChSuppression'));

% Add path to parent directory containing all ACh## sub-directories.
% rootpath = '\\research-cifs.nyumc.org\research\buzsakilab\Buzsakilabspace\LabShare\AnnaMaslarova\YZ';
rootpath = 'E:\BuzLabTemporaryCopies';

% Find mouse/session children directories
sessions = dir([rootpath,'/**/ACh*/*Session*']);
dirIDX = find([sessions.isdir]);
sessions = sessions(dirIDX);
dirIDX = ~contains({sessions.name},'for upload') & ~contains({sessions.name},"don't use");
sessions = sessions(dirIDX);

% Switch to parent directory
cd(rootpath)

%% Manual Variables
% Thresholds for micro-arousal detection using byl_FindStatePatch (wip fxn).
mvmtThresh = [0.18, 0.2, 0.23, 0.5, ...
              0.2,  0.5, 0.2,  0.2, 0.2, ...
              0.2,  0.2, 0.5,  0.2, 0.5, ...
              0.4,  0.5, 0.5];

% Manually curated 'bad' peaks using findpeaks (MATLAB fxn).
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

% Mouse Indices
ACh01 = 1:4;
ACh02 = 5:9;
ACh03 = 10:14;
ACh06 = [15,17];

%% Packet Identification
tic;
% Action Variables
plotting            = false;
loadData            = true;
manualCheck         = false;
stackOnTrace        = false;
saveNREM            = false;
saveACH             = true;
sessionsToRun       = ACh01; % Check 'Mouse Indices' in 'Manual Variables'

% (Re)Initiate Data Variables
% nREMrelevIED = {};
% nREMrelevRip = {};
% AChrelevIED = {};
% AChrelevRip = {};
clear ach nrem;

for sesh = sessionsToRun
    if manualCheck
        livePlot = true;
    else
        livePlot = false;
    end
    if loadData
        clear ripples IED SleepScoreLFP SleepState AChAnalyzis EMGFromLFP digitalIn
        sessionInd = sesh;
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.SleepState.states.mat']));
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.SleepScoreLFP.LFP.mat']));
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.IEDclean.events.mat']));
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.EMGFromLFP.LFP.mat']));
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.AChAnalyzis.mat']));
        load(fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.DigitalIn.events.mat']));
        rippleFile = fullfile(sessions(sessionInd).folder,sessions(sessionInd).name,[sessions(sessionInd).name,'.ripples.events.mat']);
        if isfile(rippleFile)
            load(rippleFile);
        else
            fprintf("Ripple file does not exist. Continuing Analysis.\n");
        end
    end
    
    % Create ACh Timestamps with proper start time offset
    AChAnalyzis.offsetS = digitalIn.intsPeriods{2}(1);
    AChAnalyzis.time = 1:numel(AChAnalyzis.AChTrace);
    AChAnalyzis.time = AChAnalyzis.time./AChAnalyzis.samplingRate + AChAnalyzis.offsetS;
    
    % Sleep State Vectorization 
    statesIdx = bz_INTtoIDX(SleepState.ints); 
   
    % Movement Vector
    ix = linspace(1, numel(statesIdx.states), numel(EMGFromLFP.data));
    mvmt = interp1(ix, EMGFromLFP.data, 1:numel(statesIdx.states));

    % session specific manual pre-processing of ACh and EMG data.
    if sesh == 12
        EMGFromLFP.data = EMGFromLFP.data + abs(min(EMGFromLFP.data));
        EMGFromLFP.data = (EMGFromLFP.data).*4;
    elseif sesh == 14
        EMGFromLFP.data = EMGFromLFP.data + abs(min(EMGFromLFP.data));
        EMGFromLFP.data = (EMGFromLFP.data).*3;
    elseif sesh == 16 || sesh == 17 || sesh == 18
        AChAnalyzis.AChTrace = smooth(AChAnalyzis.AChTrace,35);
    end

    % get microarousals during non-REM sleep using movement data
    [arousals] = FindMicroArousal_eeg_BYL(statesIdx,mvmt,mvmtThresh(sesh)); % Need to update
    if ~plotting
        close all;
    end
    
    if plotting
        f1 = figure(1); clf; hold on;
        f1.Units = 'no rmalized';
        f1.Position = [0.33 0.53 0.4 0.3];
        
        plot(arousals.times,arousals.movNREM,'k');
        xline(arousals.timestamps(:,1),'b')
        xline(arousals.timestamps(:,2),'r')
        xlim([arousals.times(1) arousals.times(end)])
        title('Micro-Arousal Times')
    end
    
    % get NREM packets that have been cleared of arousals and micro-arousals
    nREMnoArousals = ones(size(mvmt));
    
    for i = 1:length(arousals.peaks)
        idx = arousals.timestamps(i,1):arousals.timestamps(i,2);
        nREMnoArousals(idx) = 0;
    end
    statenum = find(strcmp(statesIdx.statenames,'NREM'));
    idx_ = find(statesIdx.states ~= statenum); 
    nREMnoArousals(idx_) = 0;
    
    if plotting
        f2 = figure(2); clf; hold on;
        f2.Units = 'normalized';
        f2.Position = [0.36 0.56 0.4 0.3];
        
        plot(nREMnoArousals);
        plot(statesIdx.states,'r');xlim([0 inf]);
        yyaxis right
        plot(arousals.times,mvmt);
        YLnew = ylim;
        YLnew(2) = YLnew(2)*4;
        ylim(YLnew);
    end

    % Extract Session Data into Cell Array
    nREMpackets = bz_IDXtoINT(nREMnoArousals);

    % Detect ACh Packet Peaks and remove overdetected peaks.
    [pks,locs] = findpeaks(AChAnalyzis.AChTrace, ...
        'MinPeakProminence',5e-3, ...
        'MinPeakWidth',50, ...
        'WidthReference','halfprom');
    pks(badPeaks{sesh}) = [];
    locs(badPeaks{sesh}) = [];
    
    if livePlot
        windows = 1:250:ceil(max(AChAnalyzis.time)/1000)*1000;
        win = 1;
        fig = figure(3); clf; hold on;
        fig.Units = 'normalized';
        fig.Position = [0 0.5 1 0.415];
        colormap(fig,'hot');
        
        numstrs = num2str((1:numel(pks))');
                
        % Interpolate ACh Value at IED and Ripple Times
        if stackOnTrace
            iedAchVal = interp1(AChAnalyzis.time,AChAnalyzis.AChTrace,IED.peaks);
            ripAchVal = interp1(AChAnalyzis.time,AChAnalyzis.AChTrace,ripples.peaks);
        end

        while livePlot
            % Window different indices for improved latency on live plotting
            locIdx = transpose(AChAnalyzis.time(locs) >= windows(win) & AChAnalyzis.time(locs) <= windows(win+1));
            achIdx = AChAnalyzis.time >= windows(win) & AChAnalyzis.time <= windows(win+1);
            iedIdx = IED.timestamps(:,1) >= windows(win) & IED.timestamps(:,1) <= windows(win+1);
            if isfile(rippleFile)
                ripIdx = ripples.peaks >= windows(win) & ripples.peaks <= windows(win+1);
            end
            
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
    
            emgIdx = EMGFromLFP.timestamps >= windows(win) & EMGFromLFP.timestamps <= windows(win+1);
            
            clf; hold on;
            title('Acetylcholine Peaks');
            ylim([-0.15 0.15])
            xlim([windows(win) windows(win+1)]); % UI for plot navigation

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
            if ~stackOnTrace
                plot(IED.timestamps(iedIdx,1),zeros(size(IED.timestamps(iedIdx,1)))-0.05, ...
                    '|r','Markersize',30);
                if isfile(rippleFile)
                    plot(ripples.peaks(ripIdx),zeros(size(ripples.peaks(ripIdx)))-0.05, ...
                        '|b','Markersize',15);
                end
            elseif stackOnTrace
                plot(IED.timestamps(iedIdx,1),iedAchVal(iedIdx), ...
                    '|m','Markersize',30);
                if isfile(rippleFile)
                    plot(ripples.peaks(ripIdx),ripAchVal(ripIdx), ...
                        '|k','Markersize',15);
                end
            end
        
            yyaxis right;
            % plot(EMGFromLFP.timestamps, EMGFromLFP.data,'-b');
            plot(EMGFromLFP.timestamps(emgIdx), (EMGFromLFP.data(emgIdx)).^2,'-','color',[0 0.4470 0.7410]);
            yline(mvmtThresh(sesh),'-k');
            ylim([0 5])
        
            % User Interface For Plot Inspection
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
    
    % Acetylcholine Peak Index to ACh Packet Index Conversion
    pt = [0; locs];
    p2p = [];
    for i = 1:numel(pt)-1
        p2p(i,:) = [pt(i)+1 pt(i+1)];
    end

    %%%%%%% SAVE DATA %%%%%%%
    if saveNREM % TO-DO: Implentation of tables
        % NREM Packets IED & Ripples
        %   extract for:    IEDs (time, size)
        %                   Ripples (time, size)
        %                   LFP (time, sw, th)
        %                   ACh (time, trace)
        [~, intervalI, ~] = InIntervals(IED.timestamps(:,1),nREMpackets.state1);
        nREMsI = unique(intervalI);
        nREMsI = nREMsI(nREMsI ~= 0);
        
        nREMrelevIED{sesh} = nREMpackets.state1(nREMsI,:);
        nrem.ied.packets{sesh,1} = nREMrelevIED{sesh};
        
        [~, intervalLFP, ~] = InIntervals(SleepScoreLFP.t,nREMrelevIED{sesh});
        [~, intervalACh, ~] = InIntervals(AChAnalyzis.time,nREMrelevIED{sesh});
        [~, intervalIED, ~] = InIntervals(IED.timestamps(:,1),nREMrelevIED{sesh});
        if isfile(rippleFile)
            [~, intervalRip, ~] = InIntervals(ripples.peaks,nREMrelevIED{sesh});
        end
        for pack = 1:size(nREMrelevIED{sesh},1)
            lfpIdx = intervalLFP==pack;
            iedIdx = intervalIED==pack;
            achIdx = intervalACh==pack;
            nrem.ied.lfp{sesh,1}{pack,1} = SleepScoreLFP.t(lfpIdx);
            nrem.ied.lfp{sesh,1}{pack,2} = double(SleepScoreLFP.swLFP(lfpIdx));
            nrem.ied.lfp{sesh,1}{pack,3} = double(SleepScoreLFP.thLFP(lfpIdx));
            nrem.ied.ach{sesh,1}{pack,1} = AChAnalyzis.time(achIdx);
            nrem.ied.ach{sesh,1}{pack,2} = AChAnalyzis.AChTrace(achIdx);
            nrem.ied.ied{sesh,1}{pack,1} = IED.timestamps(iedIdx,1);
            nrem.ied.ied{sesh,1}{pack,2} = IED.rippleStats.data.peakAmplitude(iedIdx);
            if isfile(rippleFile)
                ripIdx = intervalRip==pack;
                nrem.ied.rip{sesh,1}{pack,1} = ripples.peaks(ripIdx);
                nrem.ied.rip{sesh,1}{pack,2} = ripples.peakNormedPower(ripIdx);
            end
        end   
    
        if isfile(rippleFile)
            % NREM Packets Ripples Only
            %   extract for:    
            %                   Ripples (time, size)
            %                   LFP (time, sw, th)
            %                   ACh (time, trace)    [~, intervalRip, ~] = InIntervals(ripples.peaks(:,1),nREMpackets.state1);
            [~, intervalR, ~] = InIntervals(ripples.peaks(:,1),nREMpackets.state1);
        
            nREMsR = unique(intervalR);
            nREMsR = nREMsR(nREMsR ~= 0);
            nREMsR = nREMsR(~ismember(nREMsR,nREMsI));
        
            nREMrelevRip{sesh} = nREMpackets.state1(nREMsR,:);
            nrem.no_ied.packets{sesh,1} = nREMrelevRip{sesh};

            [~, intervalRip, ~] = InIntervals(ripples.peaks,nREMrelevRip{sesh});
            [~, intervalLFP, ~] = InIntervals(SleepScoreLFP.t,nREMrelevRip{sesh});
            [~, intervalACh, ~] = InIntervals(AChAnalyzis.time,nREMrelevRip{sesh});        
            for pack = 1:size(nREMrelevRip{sesh},1)
                lfpIdx = intervalLFP==pack;
                iedIdx = intervalIED==pack;
                achIdx = intervalACh==pack;
                ripIdx = intervalRip==pack;
                nrem.no_ied.lfp{sesh,1}{pack,1} = SleepScoreLFP.t(lfpIdx);
                nrem.no_ied.lfp{sesh,1}{pack,2} = double(SleepScoreLFP.swLFP(lfpIdx));
                nrem.no_ied.lfp{sesh,1}{pack,3} = double(SleepScoreLFP.thLFP(lfpIdx));
                nrem.no_ied.ach{sesh,1}{pack,1} = AChAnalyzis.time(achIdx);
                nrem.no_ied.ach{sesh,1}{pack,2} = AChAnalyzis.AChTrace(achIdx);
                nrem.no_ied.rip{sesh,1}{pack,1} = ripples.peaks(ripIdx);
                nrem.no_ied.rip{sesh,1}{pack,2} = ripples.peakNormedPower(ripIdx);
            end   
        end
    end

    if saveACH
        % Acetylcholine Packets IED & Ripples
        %   extract for:    IEDs (time, pkAmp, pkFreq, dur)
        %                   Ripples (time, size)
        %                   LFP (time, sw, th)
        %                   ACh (time, trace)
        [~, intD, ~] = InIntervals(IED.timestamps(:,1),AChAnalyzis.time(p2p));
        
        relevantP2PI = unique(intD); % Isoate the Acetylcholine P2P packets that have IEDs.
        relevantP2PI = relevantP2PI(relevantP2PI ~= 0);
        
        AChrelevIED = AChAnalyzis.time(p2p(relevantP2PI,:));
        ach.ied.packets{sesh,1} = AChrelevIED;

        [~, intervalLFP, ~] = InIntervals(SleepScoreLFP.t,AChrelevIED);
        [~, intervalACh, ~] = InIntervals(AChAnalyzis.time,AChrelevIED);
        [~, intervalIED, ~] = InIntervals(IED.timestamps(:,1),AChrelevIED);
        if isfile(rippleFile)
            [~, intervalRip, ~] = InIntervals(ripples.peaks,AChrelevIED);
        end 

        for pack = 1:size(AChrelevIED,1)
            lfpIdx = intervalLFP==pack;
            iedIdx = intervalIED==pack;
            achIdx = intervalACh==pack;
            
            ach.ied.ach{sesh,1}.timestamps{pack,1} = AChAnalyzis.time(achIdx)';
            ach.ied.ach{sesh,1}.trace{pack,1} = AChAnalyzis.AChTrace(achIdx);

            ach.ied.ied{sesh,1}.timestamps{pack,1} = IED.timestamps(iedIdx,1);
            ach.ied.ied{sesh,1}.pkAmp{pack,1} = IED.rippleStats.data.peakAmplitude(iedIdx); 
            ach.ied.ied{sesh,1}.pkFreq{pack,1} = IED.rippleStats.data.peakFrequency(iedIdx); 
            ach.ied.ied{sesh,1}.dur{pack,1} = IED.rippleStats.data.duration(iedIdx);

            ach.ied.lfp{sesh,1}.timestamps{pack,1} = SleepScoreLFP.t(lfpIdx);
            ach.ied.lfp{sesh,1}.sw{pack,1} = double(SleepScoreLFP.swLFP(lfpIdx));
            ach.ied.lfp{sesh,1}.th{pack,1} = double(SleepScoreLFP.thLFP(lfpIdx));

            if isfile(rippleFile)
                ripIdx = intervalRip==pack;
                ach.ied.rip{sesh,1}.timestamps{pack,1} = ripples.peaks(ripIdx);
                ach.ied.rip{sesh,1}.peakNormedPower{pack,1} = ripples.peakNormedPower(ripIdx);
            end
        end 
        
        if isfile(rippleFile)
            % Acetycholine Packets Ripples only
            %   extract for:    IEDs (time, pkAmp, pkFreq, dur)
            %                   Ripples (time, size)
            %                   LFP (time, sw, th)
            %                   ACh (time, trace)
            [~, intR, ~] = InIntervals(ripples.peaks,AChAnalyzis.time(p2p));
            
            relevantP2PR = unique(intR); % Isoate the Acetylcholine P2P packets that have ripples.
            relevantP2PR = relevantP2PR(relevantP2PR ~= 0);
            relevantP2PR = relevantP2PR(~ismember(relevantP2PR,relevantP2PI));
                
            AChrelevRip = AChAnalyzis.time(p2p(relevantP2PR,:));
            ach.no_ied.packets{sesh,1} = AChrelevRip;

            [~, intervalRip, ~] = InIntervals(ripples.peaks,AChrelevRip);
            [~, intervalLFP, ~] = InIntervals(SleepScoreLFP.t,AChrelevRip);
            [~, intervalACh, ~] = InIntervals(AChAnalyzis.time,AChrelevRip);
        
            for pack = 1:size(AChrelevRip,1)
                lfpIdx = intervalLFP==pack;
                achIdx = intervalACh==pack;
                ripIdx = intervalRip==pack;
                ach.no_ied.lfp{sesh,1}.timestamps{pack,1} = SleepScoreLFP.t(lfpIdx);
                ach.no_ied.lfp{sesh,1}.sw{pack,1} = double(SleepScoreLFP.swLFP(lfpIdx));
                ach.no_ied.lfp{sesh,1}.th{pack,1} = double(SleepScoreLFP.thLFP(lfpIdx));
                ach.no_ied.ach{sesh,1}.timestamps{pack,1} = AChAnalyzis.time(achIdx)';
                ach.no_ied.ach{sesh,1}.trace{pack,1} = AChAnalyzis.AChTrace(achIdx);
                ach.no_ied.rip{sesh,1}.timestamps{pack,1} = ripples.peaks(ripIdx);
                ach.no_ied.rip{sesh,1}.peakNormedPower{pack,1} = ripples.peakNormedPower(ripIdx);
            end 
        end
    end
end
toc;
%% IED-based ACh Packet Normalization of IED, Ripples, and ACh
% Find the max resample factor numerator, P.
tic;
maxP = 0;
for sesh = 1:numel(ach.ied.packets) % over sessions
    for pack = 1:size(ach.ied.packets{sesh},1) % over packets
        newP = numel(ach.ied.ach{sesh}.timestamps{pack});
        maxP = max([newP maxP]);
    end
end

plotting = false;

for sesh = 1:numel(ach.ied.packets) % over sessions
    for pack = 1:size(ach.ied.ach{sesh}.timestamps,1) % over packets
        % resample the acetylcholine traces and interpolate the timestamps.
        Q = numel(ach.ied.ach{sesh}.timestamps{pack});
        ogTidx = normalize(1:numel(ach.ied.ach{sesh}.timestamps{pack}),'range');
        ipTidx = normalize(1:maxP,'range');
        ts = interp1(ogTidx,...
                     ach.ied.ach{sesh}.timestamps{pack},...
                     ipTidx);
        ts = transpose(ts);
        tr = resample(ach.ied.ach{sesh}.trace{pack},maxP,Q);
        ach.ied.ach_resamp{sesh,1}.timestamps{pack,1} = ts;
        ach.ied.ach_resamp{sesh,1}.trace{pack,1} = tr;

        % Normalized Data (ACh, IED, Ripples)
        [normAChTime, C, S] = normalize(ach.ied.ach{sesh}.timestamps{pack},'range');
        normIEDTime = normalize(ach.ied.ied{sesh}.timestamps{pack},'center',C,'scale',S);
        normRipTime = normalize(ach.ied.rip{sesh}.timestamps{pack},'center',C,'scale',S);
        
        if plotting
            figure(1); clf; hold on;
            plot(normAChTime, ach.ach{i,1}{j,2});
            xline(normIEDTime,'Color','red','LineWidth',2);
            if ~isempty(normRipTime)
                xline(normRipTime,'Color','blue','LineWidth',2);
            end
        end
        ach.ied.ach_normed{sesh,1}.timestamps{pack,1} = normAChTime;
        ach.ied.ied_normed{sesh,1}.timestamps{pack,1} = normIEDTime;
        ach.ied.rip_normed{sesh,1}.timestamps{pack,1} = normRipTime;

        % Zero Data (IED, Ripples)
        ach.ied.ied_zeroed{sesh,1}.timestamps{pack,1} = ach.ied.ied{sesh}.timestamps{pack} - ach.ied.ach{sesh}.timestamps{pack}(1);
        ach.ied.rip_zeroed{sesh,1}.timestamps{pack,1} = ach.ied.rip{sesh}.timestamps{pack} - ach.ied.ach{sesh}.timestamps{pack}(1);
    end
    fprintf('Session %d Resampled\n',sesh);
end

ach.ied = orderfields(ach.ied);
toc;
%% Ripple-based ACh Packet Normalization of Ripples and ACh
% Find the max resample factor numerator, P.
tic;
maxP = 0;
for sesh = 1:numel(ach.no_ied.packets)
    for pack = 1:size(ach.no_ied.packets{sesh},1)
        newP = numel(ach.no_ied.ach{sesh}.timestamps{pack});
        maxP = max([newP maxP]);
    end
end


for sesh = 1:numel(ach.no_ied.packets)
    for pack = 1:size(ach.no_ied.ach{sesh}.timestamps,1)
        % resample the acetylcholine traces and timestamps.
        Q = numel(ach.no_ied.ach{sesh}.timestamps{pack});
        if Q == 0
            continue;
        end
        ogTidx = normalize(1:numel(ach.no_ied.ach{sesh}.timestamps{pack}),'range');
        ipTidx = normalize(1:maxP,'range');
        ts = interp1(ogTidx,...
                     ach.no_ied.ach{sesh}.timestamps{pack},...
                     ipTidx);
        ts = transpose(ts);
        tr = resample(ach.no_ied.ach{sesh}.trace{pack},maxP,Q);
        ach.no_ied.ach_resamp{sesh,1}.timestamps{pack,1} = ts;
        ach.no_ied.ach_resamp{sesh,1}.trace{pack,1} = tr;

        % normalize data (ACh, ripples)
        [normAChTime, C, S] = normalize(ach.no_ied.ach{sesh}.timestamps{pack},'range');
        normRipTime = normalize(ach.no_ied.rip{sesh}.timestamps{pack},'center',C,'scale',S);

        if plotting
            figure(1); clf; hold on;
            plot(normAChTime, ach.ach{i,2}{j,2});
            xline(normRipTime,'Color','blue','LineWidth',2);
        end
        ach.no_ied.ach_normed{sesh,1}.timestamps{pack,1} = normAChTime;
        ach.no_ied.rip_normed{sesh,1}.timestamps{pack,1} = normRipTime;

        % zero data (Ripples)
        ach.no_ied.rip_zeroed{sesh,1}.timestamps{pack,1} = ach.no_ied.rip{sesh}.timestamps{pack} - ach.no_ied.ach{sesh}.timestamps{pack}(1);

    end
    fprintf('Session %d Resampled\n',sesh);
end

plotting = false;

for sesh = 1:numel(ach.no_ied.packets)
    for pack = 1:size(ach.no_ied.packets{sesh},1)

    end
end 
ach.no_ied = orderfields(ach.no_ied);
toc;

%% Concatenate Packet Data for Session Wide Plots
% Define Colors
numCols = 15;
threshLines = copper(numCols);
bIedLines = spring(numCols);
pRipLines = abyss(numCols);
ripripLines = summer(numCols);
iedripLines = winter(numCols);

% Pick session(s) you want to plot
subset = [1:4]; 
[achIedTs, achNoIedTs, achIedResamp, achNoIedResamp, iedNormTimes,...
    iedZeroTimes, iedSizes, iedDuras, ripIedNormTimes, ripIedZeroTimes,...
    ripRipNormTimes, ripRipZeroTimes] = deal({});
for sesh = subset
    achIedTs{sesh} = transpose(cat(2,ach.ied.ach_resamp{sesh}.timestamps{:}));
    achNoIedTs{sesh} = transpose(cat(2,ach.no_ied.ach_resamp{sesh}.timestamps{:}));
    achIedResamp{sesh} = transpose(cat(2,ach.ied.ach_resamp{sesh}.trace{:}));
    achNoIedResamp{sesh} = transpose(cat(2,ach.no_ied.ach_resamp{sesh}.trace{:}));
    iedNormTimes{sesh} = cat(1,ach.ied.ied_normed{sesh}.timestamps{:});
    iedZeroTimes{sesh} = cat(1,ach.ied.ied_zeroed{sesh}.timestamps{:});
    iedSizes{sesh} = cat(1,ach.ied.ied{sesh}.pkAmp{:});
    iedDuras{sesh} = cat(1,ach.ied.ied{sesh}.dur{:});
    ripIedNormTimes{sesh} = cat(1,ach.ied.rip_normed{sesh}.timestamps{:});
    ripIedZeroTimes{sesh} = cat(1,ach.ied.rip_zeroed{sesh}.timestamps{:});
    ripRipNormTimes{sesh} = cat(1,ach.no_ied.rip_normed{sesh}.timestamps{:});
    ripRipZeroTimes{sesh} = cat(1,ach.no_ied.rip_zeroed{sesh}.timestamps{:});
end
achIedTs = cat(1,achIedTs{:});
achNoIedTs = cat(1,achNoIedTs{:});
achIedResamp = cat(1,achIedResamp{:});
achNoIedResamp = cat(1,achNoIedResamp{:});
iedNormTimes = cat(1,iedNormTimes{:});
iedZeroTimes = cat(1,iedZeroTimes{:});
iedSizes = cat(1,iedSizes{:});
iedDuras = cat(1,iedDuras{:});
ripIedNormTimes = cat(1,ripIedNormTimes{:});
ripIedZeroTimes = cat(1,ripIedZeroTimes{:});
ripRipNormTimes = cat(1,ripRipNormTimes{:});
ripRipZeroTimes = cat(1,ripRipZeroTimes{:});

%% Figure 1
[IEDTrain,I] = sort(iedNormTimes(:,1));
IEDTrainSizes = iedSizes(I);
bigEnough = IEDTrainSizes > 5000;

bIedFreq = Frequency(IEDTrain(bigEnough),'binSize',0.05,'show','off');
pRipFreq = Frequency(IEDTrain(~bigEnough),'binSize',0.05,'show','off');

[RipRipTrain,~] = sort(ripRipNormTimes(:,1));
% sizeRipRipTrain = riprs(I);
ripRipFreq = Frequency(RipRipTrain,'binSize',0.05,'show','off');

[IedRipTrain,~] = sort(ripIedNormTimes(:,1));
% sizeIedRipTrain = iedrs(I);
iedRipFreq = Frequency(IedRipTrain,'binSize',0.05,'show','off');

achIedNormAvg = normalize(mean(achIedResamp,1));
achNoIedNormAvg = normalize(mean(achNoIedResamp,1));
achIedNormTs = normalize(1:numel(achIedNormAvg),'range');
achNoIedNormTs = normalize(1:numel(achNoIedNormAvg),'range');

nBIED = normalize(bIedFreq(:,2));
nPRip = normalize(pRipFreq(:,2));
nRipRip = normalize(ripRipFreq(:,2));
nIedRip = normalize(iedRipFreq(:,2));

% plotting
fig1 = figure(1); clf; hold on;
fig1.Units = 'Normalized';
fig1.Position = [0 0.05 1 0.875];

tl = tiledlayout(3,5);
tl.Padding = 'compact';

% Normalized Time ACh Packets and Event Frequency
nexttile([1]); cla; hold on; 
bi = plot(bIedFreq(:,1),nBIED,'color',bIedLines(1,:),'LineWidth',2);
pr = plot(pRipFreq(:,1),nPRip,'color',pRipLines(15,:),'LineWidth',2);
rr = plot(ripRipFreq(:,1),nRipRip,'color',ripripLines(3,:),'LineWidth',2);
ir = plot(iedRipFreq(:,1),nIedRip,'color',iedripLines(3,:),'LineWidth',2);
YL = ylim;
YL(2) = YL(2) + 2;
ylim(YL);
ylabel('ZScore Signal')

yyaxis right;
ai = plot(achIedNormTs,achIedNormAvg,'-','color',threshLines(5,:),'LineWidth',2);
ar = plot(achNoIedNormTs,achNoIedNormAvg,'-','color',threshLines(10,:),'LineWidth',2);
YL = ylim;
YL(2) = YL(2) + 2;
ylim(YL);

title('ACh Packets')
legend([ai ar bi pr rr ir],...
    {'ACh Packets w/ IED','ACh Packets w/o IED','Big IED Frequency','Small IED Frequency','Ripple Frequency (packets w/ IED)','Ripple Frequency (packets w/o IED'}, ...
    'location','north', ...
    'FontSize',6)
xlabel('Normalized Time')
ylabel('ZScore Signal')

%% ACh Packet Duration Kernel Densities
nexttile([6]); cla; hold on;
achIedDurs = range(achIedTs,2);
achNoIedDurs = range(achNoIedTs,2);

[fI, xI] = ksdensity(achIedDurs);
[fNI, xNI] = ksdensity(achNoIedDurs);

plot(xI, fI,'color',bIedLines(1,:),'LineWidth',2);
plot(xNI, fNI,'color',threshLines(1,:),'LineWidth',2);

xline(xI(fI==max(fI)),'--','color',bIedLines(1,:),'LineWidth',2)
xline(xNI(fNI==max(fNI)),'--','color',threshLines(1,:),'LineWidth',2)
text(xI(fI==max(fI))+4, fI(fI==max(fI)), ...
     num2str(xI(fI==max(fI))), ...
     'FontSize',10, ...
     'Color',bIedLines(1,:));
text(xNI(fNI==max(fNI))-2, fNI(fNI==max(fNI)), ...
     num2str(xNI(fNI==max(fNI))), ...
     'FontSize',10, ...
     'Color',threshLines(1,:), ...
     'HorizontalAlignment','right');


title('Kernel Density of ACh Packet Durations')
xlabel('Packet Duration (s)')
ylabel('Probability')
legend({'IED Packets','IED-less Packets'},'location','best')

fprintf('Ripple-Only Packet Peak Duration: %f\n', xNI(fNI==max(fNI)));
fprintf('IED Packet Peak Duration: %f\n', xI(fI==max(fI)));

%% Event Time Kernel Densities
nexttile([11]); cla; hold on;
bigEnough = iedSizes>5000;
% [fBIz,xBIz] = ksdensity(iedZeroTimes(bigEnough));
[fPRz,xPRz] = ksdensity(iedZeroTimes);
[fRIz,xRIz] = ksdensity(ripIedZeroTimes);
[fRRz,xRRz] = ksdensity(ripRipZeroTimes);

% plot(xBIz, fBIz,'color',bIedLines(1,:),'LineWidth',2);
plot(xPRz, fPRz,'color',pRipLines(1,:),'LineWidth',2);
plot(xRIz, fRIz,'color',iedripLines(1,:),'LineWidth',2);
plot(xRRz, fRRz,'color',ripripLines(1,:),'LineWidth',2);
% legend({'Big IED','Small IED','Ripples','Ripples (no IED)'});
legend({'IED','Ripples','Ripples (no IED)'});

%%
xline(xI(fI==max(fI)),'--','color',bIedLines(1,:),'LineWidth',2)
xline(xNI(fNI==max(fNI)),'--','color',threshLines(1,:),'LineWidth',2)
text(xI(fI==max(fI))+4, fI(fI==max(fI)), ...
     num2str(xI(fI==max(fI))), ...
     'FontSize',10, ...
     'Color',bIedLines(1,:));
text(xNI(fNI==max(fNI))-2, fNI(fNI==max(fNI)), ...
     num2str(xNI(fNI==max(fNI))), ...
     'FontSize',10, ...
     'Color',threshLines(1,:), ...
     'HorizontalAlignment','right');