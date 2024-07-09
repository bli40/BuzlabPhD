clear all;clc; close all
%% STATISTIC OXYTOCIN BEHAVIRO
dataname = ['F:\oxytocin\OXYT010\OXYT010_004_220126_112539',
            'F:\oxytocin\OXYT011\OXYT011_005_220224_160927',
            %'F:\oxytocin\OXYT012\OXYT012_001_220323_130702',
            'F:\oxytocin\OXYT013\OXYT013_002_220412_124441',
            'F:\oxytocin\OXYT014\OXYT014_001_220429_155806']

%%Ch = [45,93,37,31,42];%% theta channel
Ch = [21,71,15,46];%% Ripple channel
for ii = 1: size(dataname,1)
    cd(dataname(ii,:))
    basepath = pwd;
    basename = bz_BasenameFromBasepath(basepath);
    load([basename,'.SleepState.states.mat']);
    load([basename,'.SleepScoreLFP.LFP.mat']);
    load([basename,'.eegstates.mat']);

        
    info = read_Intan_RHD2000_file(basepath);
    analogin = read_Intan_analogin_file('analogin.dat',info.num_board_adc_channels);     
    lfp_fbtime = find(analogin(1,:)> (min(analogin(1,:))+max(analogin(1,:)))/2,1);lfp_fbtime(1,2) = find(analogin(1,:)> (min(analogin(1,:))+max(analogin(1,:)))/2,1,'last');
    delete analogin    
        
    
    % sitmulation and signal
    if exist('dFoverF.mat')==0
        name = basename(1:11);
        ext = '.mat';
        load([name,ext],[name,'_AChSti']);
        ACh_sti = eval([name,'_AChSti']);
        fbtime = ACh_sti.times(find(ACh_sti.values(:,1)>0.5,1));fbtime(1,2) = ACh_sti.times(find(ACh_sti.values(:,1)>0.5,1,'last'));
        fbIDX = round(fbtime*20000);
        load([name,ext],[name,'_AChSig1']);
        ACh_signal = eval([name,'_AChSig1']);
        ACh_signal.data = downsample(ACh_signal.values((fbIDX(1,1)):(fbIDX(1,2))),200);
        ACh_signal.time = downsample(ACh_signal.times((fbIDX(1,1)):(fbIDX(1,2))),200)- fbtime(1,1);
        p = [];
        p = polyfit(ACh_signal.time,ACh_signal.data,2);
        Ybaseline = polyval(p,ACh_signal.time);
        figure
        plot(ACh_signal.time, ACh_signal.data); hold on;
        plot(ACh_signal.time,Ybaseline);
        dFoverF = smoothdata((ACh_signal.data - Ybaseline)./Ybaseline,'movmean',10);
        hold on;
        plot(ACh_signal.time, dFoverF);xlim([0 inf]);
    else load('dFoverF.mat')
    end
    
    GammaCh = Ch(ii);
    THLFPs = bz_GetLFP(GammaCh,'basepath',basepath,'noPrompts',true);
    thetarange = linspace(0.5,250,1000);
    lfp = double(THLFPs.data);
    lfp(abs(lfp)>8000) = nan;
    lfp = fillmissing(lfp,'linear');
    [ss,ft,tt] = spectrogram(lfp,2*THLFPs.samplingRate,0.6*THLFPs.samplingRate,thetarange,THLFPs.samplingRate);
    [spectrogrammt,tm,fm] = MTSpectrogram(lfp,'window',2);
    bands = SpectrogramBands(spectrogrammt,fm);
    
    %% get NREM packet and micro arousal(accelrate > 0.5 and <40)
    statesIDX = bz_INTtoIDX(SleepState.ints);  %% need to check
    ix = linspace(1, numel(statesIDX.states), numel(StateInfo.motion));
    Mov = interp1(ix, StateInfo.motion, 1:numel(statesIDX.states));
    figure;plot(50*statesIDX.states-50);xlim([0 inf]);
    hold on;
    %plot(Mov/50);xlim([0 inf]);
   
    plot(50*statesIDX.states-50);xlim([0 inf]);
    idx_ = find(statesIDX.states ~= 2);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%get microarousals 
    MovNREM1 = Mov;
    MovNREM1(idx_) = 0;
    plot(MovNREM1/10);xlim([0 inf]);
    
    MovNREM = smoothdata(MovNREM1,"gaussian",5);

    peak_mean_diff = 1;
    threshold_ = 0.02;
    [pks, locs, width] = findpeaks(MovNREM,'MinPeakProminence',threshold_,...
        'WidthReference','halfprom','MinPeakDistance',peak_mean_diff);
    
    figure; plot(MovNREM);
    hold on;
    plot(locs,pks,'o');
    plot(MovNREM1)

    [arousals] = FindMicroArousal_eeg(statesIDX, Mov);

    figure; plot(arousals.times,arousals.movNREM,'k');
    hold on;
    xline(arousals.timestamps(:,1),'b')
    xline(arousals.timestamps(:,2),'r')

    %%%%%%%%%%%%%%%%%get NREM packets
    nREMnoArousals = ones(size(Mov));
    
    for i = 1:length(arousals.peaks)
        idx = arousals.timestamps(i,1):arousals.timestamps(i,2);
        nREMnoArousals(idx) = 0;
    end
  
    idx_ = find(statesIDX.states ~= 2);
    nREMnoArousals(idx_) = 0;
    
    figure;plot(nREMnoArousals*2500);
    hold on
    plot(arousals.times,Mov,'k');
    plot(1000*statesIDX.states,'r');xlim([0 inf]);
    nNREMpackets = cell2mat(IDXtoINT(nREMnoArousals));

%% compare
    figure;
    colormap('jet')
    imagesc(tt,thetarange,abs(ss));clim([0,8e4]);
    yticks([0.5,20,50,100,200]); ylabel('Frequency (Hz)'); xlabel('Time (s)');
    set(gca,'YDir','normal');
    hold on; plot(tm,(smoothdata(bands.spindles,10))/1000+110,'color','r');xlim([0 inf]);
    hold on; plot([1:length(dFoverF)]/100+lfp_fbtime(1)/20000, dFoverF*200+100,'g');xlim([0 inf])
    hold on; plot(StateInfo.fspec{1,1}.to, StateInfo.motion*50+150,'w');xlim([0 inf]);
    hold on;plot(1:length(SleepState.idx.states*10),SleepState.idx.states);xlim([0 inf]);
    hold on;plot(1:length(nREMnoArousals),nREMnoArousals*25+200);
    %% get nREMpackets of LFP and ach
    nNREMpac_Data = {};
    for jj = 1:length(nNREMpackets)
        win = diff(nNREMpackets(jj,:),1,2)*0.1;
        Dur = nNREMpackets(jj,:)*1250+win*1250;
        Dur_ach = round((nNREMpackets(jj,:)-lfp_fbtime(1)/20000)*100)+win*100;
        if Dur_ach(1)>0 & Dur(2)<length(lfp) & Dur_ach(2)<length(dFoverF)
            nNREMpac_Data.LFP{jj,1} = lfp(Dur(1):Dur(2));
            nNREMpac_Data.ACh{jj,1} = dFoverF(Dur_ach(1):Dur_ach(2));
        end
    end
    nNREMpac_Data.ints = nNREMpackets;
   %% get nREMeposide and LFP and ach
    nNREMepsode = SleepState.ints.NREMstate;
    nNREMepso_Data = {};
    for jj = 1:length( nNREMepsode)
        win = diff(nNREMepsode(jj,:),1,2)*0.1;
        Dur =  nNREMepsode(jj,:)*1250 + win*1250;
        Dur_ach = round((nNREMepsode(jj,:)-lfp_fbtime(1)/20000)*100)+ win*100;
        if Dur_ach(1)>0 & Dur(2)<length(lfp) & Dur_ach(2)<length(dFoverF)
            nNREMepso_Data.LFP{jj,1} = lfp(Dur(1):Dur(2));
            nNREMepso_Data.ACh{jj,1} = dFoverF(Dur_ach(1):Dur_ach(2));
        end
    end
    nNREMepso_Data.ints = nNREMepsode;
    
    %% save data
    nNREM_Data.nNREMepsode  = nNREMepso_Data;
    nNREM_Data.nNREMpac_Data = nNREMpac_Data;
    nNREM_Data.MA = arousals;
    datpath = 'G:\My Drive\Paper_ACh_OXT\Fig2\nonNREMpackets_data\OXT_NREM';
    save(fullfile(datpath,[basename,'_nNREM_Data.mat']),'nNREM_Data');

end
    