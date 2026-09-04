function photometry = byl_preprocessPhotometry(varargin)
%byl_preprocessingPhotometry - preprocess fiber photometry data
%
% USAGE
%    [photometry] = byl_preprocessPhotometry(basepath,<options>)
%
%
% INPUTS - note these are NOT name-value pairs... just raw values
%    basepath       path to a single session to run preprocessPhotometry on
%
%    =========================================================================
%     Properties    Values
%    -------------------------------------------------------------------------
%     'source'      recording system used (default = 'rbfmc'). 
%     'show'        plot results (default = false)
%     'saveMat'     logical (default=false) to save in buzcode format
%     'plotType'    0=off; 1=original version (several plots); 2=only
%                   preprocessed result
%    =========================================================================
%
% OUTPUT
%
%    photometry     buzcode format .photometry. struct with the following fields
%                   .timestamps        Nx2 matrix of start/stop times for
%                                      each ripple
%                   .detectorName      string ID for detector function used
%                   .peaks             Nx1 matrix of peak power timestamps 
%                   .stdev             standard dev used as threshold
%                   .noise             candidate ripples that were
%                                      identified as noise and removed
%                   .peakNormedPower   Nx1 matrix of peak power values
%                   .detectorParams    struct with input parameters given
%                                      to the detector
% SEE ALSO
%
%    See also bz_Filter, bz_RippleStats, bz_SaveRippleEvents, bz_PlotRippleStats.
%
% 2026-09-04 by Brian Y. Li
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 3 of the License, or
% (at your option) any later version.

warning('this function is under development and may not work... yet. currently only applicable for Doric RBFMC data structures.')

% Default values
p = inputParser;
addParameter(p,'source','rbfmc',@isstr)
addParameter(p,'show',false,@islogical)
addParameter(p,'saveMat',false,@islogical)
addParameter(p,'plotType',2,@isnumeric)
addParameter(p,'syncDI',1,@isnumeric)
addParameter(p,'fpCamDI',16,@isnumeric)

if isstr(varargin{1})  % if first arg is basepath
    addRequired(p,'basepath',@isstr)
    parse(p,varargin{:})
    basename = bz_BasenameFromBasepath(p.Results.basepath);
    basepath = p.Results.basepath;

elseif isnumeric(varargin{1}) % if first arg is filtered LFP
    addRequired(p,'lfp',@isnumeric)
    addRequired(p,'timestamps',@isnumeric)
    parse(p,varargin{:})
    basepath = pwd;
    basename = bz_BasenameFromBasepath(basepath);
end

% assign parameters (either defaults or given)
source = p.Results.source;
show = p.Results.show;
saveMat = p.Results.saveMat;
plotType = p.Results.plotType;
syncDI = p.Results.syncDI;
fpCamDI = p.Results.fpCamDI;


%% Load data files
switch source 
    case 'rbfmc'
        datafiles = dir("*_*_*.csv");

        fprintf("Found %i putative RBFMC data files.\n",numel(datafiles));
        tknames = cellfun(@(x) regexp(x, "(?<animal>\w+)_(?<date>\w+)_(?<time>\w+)_(?<epoch>\w+)_(?<channel>\w+)",'names'), ...
                            {datafiles.name});
        mouse = string(unique({tknames.animal}));
        date = string(unique({tknames.date}));
        time = string(unique({tknames.time}));
        epochs = string(unique({tknames.epoch}));
        channels = string(unique({tknames.channel}));
        numEpochs = numel(epochs);
        numChannels = numel(channels);
        
        fprintf('\t  <strong>Epochs:</strong> %i\n\t<strong>Channels:</strong> %i\n',numEpochs,numChannels);
        
        fprintf('Building session cell structure...\n')
        sessioncell = cell(numChannels, numEpochs);
        for e = 1:numEpochs
            for c = 1:numChannels
                dirstr = join([mouse, date, time, epochs(e), channels(c)],'_') + ".csv";
                sessioncell{c,e} = readtable(dirstr);
            end
            % --- make all lengths the same
            chanLength = cellfun(@(x) size(x,1),sessioncell);
            if numel(unique(chanLength)) ~= 1
                fprintf(2,'\tChannel sample numbers unequal. Removing extra samples.\n')
                minLength = min(chanLength);
                for c = 1:numChannels
                    sessioncell{c,e} = sessioncell{c,e}(1:minLength,:);
                end
            end
        end
        
    case 'pyphotometry'
        % work-in-progress

    otherwise
        error("'%s' is not a recognized fiber photometry recording platform.",source);
end


%%
EI = sessioncell{1,1};
E1 = sessioncell{2,1};
E2 = sessioncell{3,1};

%% Synchronize Time 
digifile = dir("*DigitalIn.events.mat");

% Load digital input events
if ~isempty(digifile)
    load(digifile.name, 'digitalIn');
    fprintf('Digital input events loaded.\n');
else
    fprintf(2,'No digital input events file found. Running bz_getDigitalIn.\n');
    sessionfile = dir('*session.mat');
    load(sessionfile(1).name, 'session');
    digitalIn = bz_getDigitalIn(basepath,'fs',session.extracellular.sr);
end

allFpTTL = sort([EI.Time; E1.Time; E2.Time]);
perA = round(mean(diff(allFpTTL)),5);
perB = round(mean(diff(digitalIn.timestampsOn{fpCamDI})),5);
if perA == perB
    fprintf('FP -> EPhys TTL durations match.\n');
else
    error('FP -> EPhys TTL durations DO NOT MATCH. Check session-/global-xml sample rate.');
end

tlag = digitalIn.timestampsOn{fpCamDI}(1);
fprintf("Applying timelag to photometry signal.\n");
fprintf(2,"\t%f s -> %f s\n",allFpTTL(1), tlag);
EI.Time = EI.Time + tlag;
E1.Time = E1.Time + tlag;
E2.Time = E2.Time + tlag;

%% initiate preprocessing
if show && plotType == 1
    % --- plot ROIs and traces
    f1 = figure(1);
    t1 = tiledlayout(3,1,'TileSpacing','tight','Padding','compact');
    tt1 = title(t1, 'Step 1: Raw Data');
    col = lines(7);
    lw = 1;
    
    % --- region 1
    nt1 = nexttile(1); hold on; grid on;
    title("ROI 1 (NAc)");
    nt1.TitleHorizontalAlignment = 'left';
    % xlabel("time (s)");
    xticklabels('');
    ylabel("CMOS Intensity");
    
    i1 = plot(EI.Time, EI.ROI01, 'LineWidth',lw,'Color',col(6,:));
    g1 = plot(E1.Time, E1.ROI01,'-','LineWidth',lw,'Color',col(5,:));
    r1 = plot(E2.Time, E2.ROI01,'-', 'LineWidth',lw,'Color',col(2,:));
    
    % --- region 2
    nt2 = nexttile(2); hold on; grid on;
    title("ROI 2 (empty)");
    nt2.TitleHorizontalAlignment = 'left';
    % xlabel("time (s)");
    xticklabels('');
    
    ylabel("CMOS Intensity");
    
    i2 = plot(EI.Time, EI.ROI01, 'LineWidth',lw,'Color',col(6,:));
    g2 = plot(E1.Time, E1.ROI02,'-','LineWidth',lw,'Color',col(5,:));
    r2 = plot(E2.Time, E2.ROI02,'-', 'LineWidth',lw,'Color',col(2,:));
    
    % --- region 3
    nt3 = nexttile(3); hold on; grid on;
    title("ROI 3 (HPC)");
    nt3.TitleHorizontalAlignment = 'left';
    xlabel("time (s)");
    ylabel("CMOS Intensity");
    
    i3 = plot(EI.Time, EI.ROI01, 'LineWidth',lw,'Color',col(6,:));
    g3 = plot(E1.Time, E1.ROI03,'-','LineWidth',lw,'Color',col(5,:));
    r3 = plot(E2.Time, E2.ROI03,'-', 'LineWidth',lw,'Color',col(2,:));
end

%% De-Noising
fprintf('De-noising - 10 hz bandpass filtering...\n')
fs = 30; 
fc = 10;
[b, a] = butter(2,fc/(fs/2));

g1dn = filtfilt(b,a,E1.ROI01);
r1dn = filtfilt(b,a,E2.ROI01);
i1dn = filtfilt(b,a,EI.ROI01);

g2dn = filtfilt(b,a,E1.ROI02);
r2dn = filtfilt(b,a,E2.ROI02);
i2dn = filtfilt(b,a,EI.ROI02);

g3dn = filtfilt(b,a,E1.ROI03);
r3dn = filtfilt(b,a,E2.ROI03);
i3dn = filtfilt(b,a,EI.ROI03);

if show && plotType == 1
    tt1.String = "Step 2: De-noising via 10 Hz Low-Pass Filter";
    
    g1.YData = g1dn;
    r1.YData = r1dn;
    i1.YData = i1dn;
    
    g2.YData = g2dn;
    r2.YData = r2dn;
    i2.YData = i2dn;
    
    g3.YData = g3dn;
    r3.YData = r3dn;
    i3.YData = i3dn;
    drawnow;
end

%% Photo-bleaching Correction
fprintf('Photo-bleaching correction - double exponential regression...\n')
g1fit1 = fit(E1.Time, g1dn, 'exp2');
r1fit1 = fit(E2.Time, r1dn, 'exp2');
i1fit1 = fit(EI.Time, i1dn, 'exp2');
g2fit1 = fit(E1.Time, g2dn, 'exp2');
r2fit1 = fit(E2.Time, r2dn, 'exp2');
i2fit1 = fit(EI.Time, i2dn, 'exp2');
g3fit1 = fit(E1.Time, g3dn, 'exp2');
r3fit1 = fit(E2.Time, r3dn, 'exp2');
i3fit1 = fit(EI.Time, i3dn, 'exp2');

g1dt = g1dn - g1fit1(E1.Time); 
r1dt = r1dn - r1fit1(E2.Time);
i1dt = i1dn - i1fit1(EI.Time);
g2dt = g2dn - g2fit1(E1.Time);
r2dt = r2dn - r2fit1(E2.Time);
i2dt = i2dn - i2fit1(EI.Time);
g3dt = g3dn - g3fit1(E1.Time);
r3dt = r3dn - r3fit1(E2.Time);
i3dt = i3dn - i3fit1(EI.Time);

if show && plotType == 1
    f2 = figure(2); clf; hold on;
    t2 = tiledlayout(3,1);
    title(t2, 'Double Exponential Fit Output')
    
    nexttile(1); hold on;
    % --- double exponential fit for green ROI1
    g1e = plot(g1fit1,E1.Time, g1dn);
    g1e(1).Color = col(5,:);
    g1e(1).MarkerSize = 5;
    g1e(2).Color = col(4,:);
    
    % --- double exponential fit for red ROI1
    r1e = plot(r1fit1,E2.Time, r1dn);
    r1e(1).Color = col(2,:);
    r1e(1).MarkerSize = 5;
    r1e(2).Color = col(1,:);
    
    % --- double exponential fit for iso ROI1
    i1e = plot(i1fit1,EI.Time, i1dn);
    i1e(1).Color = col(6,:);
    i1e(1).MarkerSize = 5;
    i1e(2).Color = col(3,:);
    
    nexttile(2); hold on;
    % --- double exponential fit for green ROI2
    g2e = plot(g2fit1,E1.Time, g2dn);
    g2e(1).Color = col(5,:);
    g2e(1).MarkerSize = 5;
    g2e(2).Color = col(4,:);
    
    % --- double exponential fit for red ROI2
    r2e = plot(r2fit1,E2.Time, r2dn);
    r2e(1).Color = col(2,:);
    r2e(1).MarkerSize = 5;
    r2e(2).Color = col(1,:);
    
    % --- double exponential fit for iso ROI2
    i2e = plot(i2fit1,EI.Time, i2dn);
    i2e(1).Color = col(6,:);
    i2e(1).MarkerSize = 5;
    i2e(2).Color = col(3,:);
    
    nexttile(3); hold on;
    % --- double exponential fit for green ROI3
    g3e = plot(g3fit1,E1.Time, g3dn);
    g3e(1).Color = col(5,:);
    g3e(1).MarkerSize = 5;
    g3e(2).Color = col(4,:);
    
    % --- double exponential fit for red ROI3
    r3e = plot(r3fit1,E2.Time, r3dn);
    r3e(1).Color = col(2,:);
    r3e(1).MarkerSize = 5;
    r3e(2).Color = col(1,:);
    
    % --- double exponential fit for iso ROI1
    i3e = plot(i3fit1,EI.Time, i3dn);
    i3e(1).Color = col(6,:);
    i3e(1).MarkerSize = 5;
    i3e(2).Color = col(3,:);
    
    % --- de-trend raw signals
    figure(1);
    tt1.String = 'Step 3: Photobleaching Correction via Double Exponential Fit';
    g1.YData = g1dt;
    r1.YData = r1dt;
    i1.YData = i1dt;
    g2.YData = g2dt;
    r2.YData = r2dt;
    i2.YData = i2dt;
    g3.YData = g3dt;
    r3.YData = r3dt;
    i3.YData = i3dt;
end


%% Motion correction
fprintf('Motion correction - linear regression against isosbestic...\n')
g1fit2 = fitlm(i1dt, g1dt);
r1fit2 = fitlm(i1dt, r1dt);
g1est = predict(g1fit2,i1dt);
g1mc = g1dt - g1est;
r1est = predict(r1fit2,i1dt);
r1mc = r1dt - r1est;
i1mc = i1dt - i1dt;

g2fit2 = fitlm(i2dt, g2dt);
r2fit2 = fitlm(i2dt, r2dt);
g2est = predict(g2fit2,i2dt);
g2mc = g2dt - g2est;
r2est = predict(r2fit2,i2dt);
r2mc = r2dt - r2est;
i2mc = i2dt - i2dt;

g3fit2 = fitlm(i3dt, g3dt);
r3fit2 = fitlm(i3dt, r3dt);

g3est = predict(g3fit2,i3dt);
g3mc = g3dt - g3est;
r3est = predict(r3fit2,i3dt);
r3mc = r3dt - r3est;
i3mc = i3dt - i3dt;

if show && plotType == 1
    figure(3); clf; hold on;
    tt3 = tiledlayout(1,3);
    title(tt3, 'Motion Correction via Linear Regression','FontSize',17)
    
    % --- ROI 1
    nexttile(1); hold on;
    n = gca;
    n.TitleHorizontalAlignment = 'left';
    title('ROI01','FontSize',15);
    xlabel('isosbestic (415 nm)','FontSize',15,'Color',col(6,:));
    ylabel('emissions','FontSize',15);
    plot(i1dt, g1dt,'.','MarkerSize',5,'Color',col(5,:))
    plot(i1dt, r1dt,'.','MarkerSize',5,'Color',col(2,:))
    xplot = linspace(min(i1dt), max(i1dt), 200)';
    y1 = predict(g1fit2, xplot);
    y2 = predict(r1fit2, xplot);
    plot(xplot, y1, 'k-', 'LineWidth', 2,'Color',col(4,:));
    plot(xplot, y2, 'k-', 'LineWidth', 2,'Color',col(1,:));
    
    % --- ROI 2
    nexttile(2); hold on;
    n = gca;
    n.TitleHorizontalAlignment = 'left';
    title('ROI02','FontSize',15);
    xlabel('isosbestic (415 nm)','FontSize',15,'Color',col(6,:));
    ylabel('emissions','FontSize',15);
    plot(i2dt, g2dt,'.','MarkerSize',5,'Color',col(5,:))
    plot(i2dt, r2dt,'.','MarkerSize',5,'Color',col(2,:))
    xplot = linspace(min(i2dt), max(i2dt), 200)';
    y1 = predict(g2fit2, xplot);
    y2 = predict(r2fit2, xplot);
    plot(xplot, y1, 'k-', 'LineWidth', 2,'Color',col(4,:));
    plot(xplot, y2, 'k-', 'LineWidth', 2,'Color',col(1,:));
    
    % --- ROI 3
    nexttile(3); hold on;
    n = gca;
    n.TitleHorizontalAlignment = 'left';
    title('ROI03','FontSize',15);
    xlabel('isosbestic (415 nm)','FontSize',15,'Color',col(6,:));
    ylabel('emissions','FontSize',15);
    plot(i3dt, g3dt,'.','MarkerSize',5,'Color',col(5,:))
    plot(i3dt, r3dt,'.','MarkerSize',5,'Color',col(2,:))
    
    xplot = linspace(min(i3dt), max(i3dt), 200)';
    y1 = predict(g3fit2, xplot);
    y2 = predict(r3fit2, xplot);
    plot(xplot, y1, 'k-', 'LineWidth', 2,'Color',col(4,:));
    plot(xplot, y2, 'k-', 'LineWidth', 2,'Color',col(1,:));
    
    
    % --- plot results
    figure(1);
    g1.YData = g1mc;
    r1.YData = r1mc;
    i1.YData = i1mc;
    
    g2.YData = g2mc;
    r2.YData = r2mc;
    i2.YData = i2mc;
    
    g3.YData = g3mc;
    r3.YData = r3mc;
    i3.YData = i3mc;
    drawnow;

end

%% Normalize signals

% --- dF/F
fprintf('Normalization - delta F / F...\n')
g1dff = 100*(g1mc./g1fit1(E1.Time));
r1dff = 100*(r1mc./r1fit1(E2.Time));
g2dff = 100*(g2mc./g2fit1(E1.Time));
r2dff = 100*(r2mc./r2fit1(E2.Time));
g3dff = 100*(g3mc./g3fit1(E1.Time));
r3dff = 100*(r3mc./r3fit1(E2.Time));

% --- z-score
fprintf('Normalization - z-score...\n')

g1z = (g1mc - mean(g1mc))./(std(g1mc));
r1z = (r1mc - mean(r1mc))./(std(r1mc));
g2z = (g2mc - mean(g2mc))./(std(g2mc));
r2z = (r2mc - mean(r2mc))./(std(r2mc));
g3z = (g3mc - mean(g3mc))./(std(g3mc));
r3z = (r3mc - mean(r3mc))./(std(r3mc));

if show && plotType == 1
    tt1.String = 'Step 5: Normalize FP signal via dF/F';
    g1.YData = g1dff;
    r1.YData = r1dff;
    ylabel(nt1, '\DeltaF / F')

    g2.YData = g2dff;
    r2.YData = r2dff;
    ylabel(nt2, '\DeltaF / F');

    g3.YData = g3dff;
    r3.YData = r3dff;
    ylabel(nt3, '\DeltaF / F');
    
    figure(4);
    t2 = tiledlayout(1,2,'TileSpacing','loose','Padding','loose');
    title(t2,'gDA vs rACh','FontSize',30);
    nt = nexttile(1);
    plot(g1dff, r1dff,'k.','MarkerSize',5);
    title(nt, 'ROI-1: Nucleus Accumbens','FontSize',20);
    nt.TitleHorizontalAlignment = 'left';
    xlabel('gDA3h signal','Color',col(5,:),'FontSize',20);
    ylabel('rACh1.7 signal','Color',col(2,:),'FontSize',20);
    
    nt = nexttile(2);
    plot(g3dff, r3dff,'k.','MarkerSize',5);
    title(nt, 'ROI-3: Hippocampus','FontSize',20);
    nt.TitleHorizontalAlignment = 'left';
    xlabel('gDA3h signal','Color',col(5,:),'FontSize',20);
    ylabel('rACh1.7 signal','Color',col(2,:),'FontSize',20);

elseif show && plotType == 2
    f1 = figure(1);
    t1 = tiledlayout(3,1,'TileSpacing','tight','Padding','compact');
    tt1.String = 'Preprocessed Fiber Photometry Data';
    col = lines(7);
    lw = 1;

    % --- region 1
    nexttile(1); hold on; grid on;
    title("ROI 1 (NAc)");
    nt = gca;
    nt.TitleHorizontalAlignment = 'left';
    % xlabel("time (s)");
    xticklabels('');
    ylabel(nt, '\DeltaF / F')
    g1 = plot(E1.Time, g1dff,'-','LineWidth',lw,'Color',col(5,:));
    r1 = plot(E2.Time, r1dff,'-', 'LineWidth',lw,'Color',col(2,:));

    % --- region 2
    nt2 = nexttile(2); hold on; grid on;
    title("ROI 2 (empty)");
    nt2.TitleHorizontalAlignment = 'left';
    % xlabel("time (s)");
    xticklabels('');
    ylabel(nt, '\DeltaF / F')
    g2 = plot(E1.Time, g2dff,'-','LineWidth',lw,'Color',col(5,:));
    r2 = plot(E2.Time, r2dff,'-', 'LineWidth',lw,'Color',col(2,:));

    % --- region 3
    nt3 = nexttile(3); hold on; grid on;
    title("ROI 3 (HPC)");
    nt3.TitleHorizontalAlignment = 'left';
    xlabel("time (s)");
    ylabel(nt, '\DeltaF / F')
    g3 = plot(E1.Time, g3dff,'-','LineWidth',lw,'Color',col(5,:));
    r3 = plot(E2.Time, r3dff,'-', 'LineWidth',lw,'Color',col(2,:));

end

%% Save Pre-Processed Data
if saveMat
    fprintf('Saving photometry data...\n')
    photometry.source = source;
    photometry.ROI1.name = "NAc";
    photometry.ROI1.E1dff = g1dff;
    photometry.ROI1.E2dff = r1dff;
    photometry.ROI1.E1mc = g1mc;
    photometry.ROI1.E2mc = r1mc;
    photometry.ROI1.EI = i1dt;
    
    photometry.ROI2.name = "mPFC";
    photometry.ROI2.E1dff = g2dff;
    photometry.ROI2.E2dff = r2dff;
    photometry.ROI2.E1mc = g2mc;
    photometry.ROI2.E2mc = r2mc;
    photometry.ROI2.EI = i2dt;
    
    photometry.ROI3.name = "dHPC";
    photometry.ROI3.E1dff = g3dff;
    photometry.ROI3.E2dff = r3dff;
    photometry.ROI3.E1mc = g3mc;
    photometry.ROI3.E2mc = r3mc;
    photometry.ROI3.EI = i3dt;

    photometry.EI_time = EI.Time;
    photometry.E1_time = E1.Time;
    photometry.E2_time = E2.Time;
    
    basepath = pwd;
    [~, basename, ~] = fileparts(pwd);
    
    save([basepath filesep basename '.photometry.mat'],'photometry');
end

fprintf('<strong>--- Photometry data preprocessed! ---</strong>\n')
end
