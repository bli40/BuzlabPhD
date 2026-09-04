%% preprocessRBFMC.m
% Code to preprocess fiber photometry and photoactuation data from Doric 
% RBFMC Gen 2 via BBC300.

% created by Brian Y. Li - 2026/08/16

% clear all;
% close all;

%% Load Data CSV
subepoch = 1;
lw = 1;

EI_file = dir("*_0000.csv");
E1_file = dir("*_0001.csv");
E2_file = dir("*_0002.csv");

EI = readtable(string(EI_file(subepoch).name));
E1 = readtable(string(E1_file(subepoch).name));
E2 = readtable(string(E2_file(subepoch).name));

% --- make all lengths the same
chanLens = min([size(EI,1), size(E1,1), size(E2,1)]);
EI = EI(1:chanLens,:);
E1 = E1(1:chanLens,:);
E2 = E2(1:chanLens,:);

% --- plot ROIs and traces
f1 = figure(1);
t1 = tiledlayout(3,1,'TileSpacing','tight','Padding','compact');
tt1 = title(t1, 'Step 1: Raw Data');
col = lines(7);


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

%% De-Noising
tt1.String = "Step 2: De-noising via 10 Hz Low-Pass Filter";
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
%% Photobleaching Correction
f2 = figure(2); clf; hold on;
t2 = tiledlayout(3,1);
title(t2, 'Double Exponential Fit Output')

nexttile(1); hold on;
% --- double exponential fit for green ROI1
g1fit1 = fit(E1.Time, g1dn, 'exp2');
coeffs = coeffvalues(g1fit1);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4); 
g1e = plot(g1fit1,E1.Time, g1dn);
g1e(1).Color = col(5,:);
g1e(1).MarkerSize = 5;
g1e(2).Color = col(4,:);

% --- double exponential fit for red ROI1
r1fit1 = fit(E2.Time, r1dn, 'exp2');
coeffs = coeffvalues(r1fit1);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4);
r1e = plot(r1fit1,E2.Time, r1dn);
r1e(1).Color = col(2,:);
r1e(1).MarkerSize = 5;
r1e(2).Color = col(1,:);

% --- double exponential fit for iso ROI1
i1fit1 = fit(EI.Time, i1dn, 'exp2');
coeffs = coeffvalues(i1fit1);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4);
i1e = plot(i1fit1,EI.Time, i1dn);
i1e(1).Color = col(6,:);
i1e(1).MarkerSize = 5;
i1e(2).Color = col(3,:);

nexttile(2); hold on;
% --- double exponential fit for green ROI2
g2fit1 = fit(E1.Time, g2dn, 'exp2');
coeffs = coeffvalues(g2fit1);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4);
g2e = plot(g2fit1,E1.Time, g2dn);
g2e(1).Color = col(5,:);
g2e(1).MarkerSize = 5;
g2e(2).Color = col(4,:);

% --- double exponential fit for red ROI2
r2fit1 = fit(E2.Time, r2dn, 'exp2');
coeffs = coeffvalues(r2fit1);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4);
r2e = plot(r2fit1,E2.Time, r2dn);
r2e(1).Color = col(2,:);
r2e(1).MarkerSize = 5;
r2e(2).Color = col(1,:);

% --- double exponential fit for iso ROI2
i2fit1 = fit(EI.Time, i2dn, 'exp2');
coeffs = coeffvalues(i2fit1);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4);
i2e = plot(i2fit1,EI.Time, i2dn);
i2e(1).Color = col(6,:);
i2e(1).MarkerSize = 5;
i2e(2).Color = col(3,:);

nexttile(3); hold on;
% --- double exponential fit for green ROI3
g3fit1 = fit(E1.Time, g3dn, 'exp2');
coeffs = coeffvalues(g3fit1);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4);
g3e = plot(g3fit1,E1.Time, g3dn);
g3e(1).Color = col(5,:);
g3e(1).MarkerSize = 5;
g3e(2).Color = col(4,:);

% --- double exponential fit for red ROI3
r3fit1 = fit(E2.Time, r3dn, 'exp2');
coeffs = coeffvalues(r3fit1);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4);
r3e = plot(r3fit1,E2.Time, r3dn);
r3e(1).Color = col(2,:);
r3e(1).MarkerSize = 5;
r3e(2).Color = col(1,:);

% --- double exponential fit for iso ROI1
i3fit1 = fit(EI.Time, i3dn, 'exp2');
coeffs = coeffvalues(i3fit1);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4);
i3e = plot(i3fit1,EI.Time, i3dn);
i3e(1).Color = col(6,:);
i3e(1).MarkerSize = 5;
i3e(2).Color = col(3,:);

% --- de-trend raw signals
figure(1);
tt1.String = 'Step 3: Photobleaching Correction via Double Exponential Fit';
g1dt = g1dn - g1fit1(E1.Time); 
g1.YData = g1dt;

r1dt = r1dn - r1fit1(E2.Time);
r1.YData = r1dt;

i1dt = i1dn - i1fit1(EI.Time);
i1.YData = i1dt;

g2dt = g2dn - g2fit1(E1.Time);
g2.YData = g2dt;

r2dt = r2dn - r2fit1(E2.Time);
r2.YData = r2dt;

i2dt = i2dn - i2fit1(EI.Time);
i2.YData = i2dt;

g3dt = g3dn - g3fit1(E1.Time);
g3.YData = g3dt;

r3dt = r3dn - r3fit1(E2.Time);
r3.YData = r3dt;

i3dt = i3dn - i3fit1(EI.Time);
i3.YData = i3dt;

%% Motion correction
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

g1fit2 = fitlm(i1dt, g1dt);
r1fit2 = fitlm(i1dt, r1dt);

xplot = linspace(min(i1dt), max(i1dt), 200)';
y1 = predict(g1fit2, xplot);
y2 = predict(r1fit2, xplot);
plot(xplot, y1, 'k-', 'LineWidth', 2,'Color',col(4,:));
plot(xplot, y2, 'k-', 'LineWidth', 2,'Color',col(1,:));

g1est = predict(g1fit2,i1dt);
g1mc = g1dt - g1est;
r1est = predict(r1fit2,i1dt);
r1mc = r1dt - r1est;
i1mc = i1dt - i1dt;

% --- ROI 2
nexttile(2); hold on;
n = gca;
n.TitleHorizontalAlignment = 'left';
title('ROI02','FontSize',15);
xlabel('isosbestic (415 nm)','FontSize',15,'Color',col(6,:));
ylabel('emissions','FontSize',15);
plot(i2dt, g2dt,'.','MarkerSize',5,'Color',col(5,:))
plot(i2dt, r2dt,'.','MarkerSize',5,'Color',col(2,:))

g2fit2 = fitlm(i2dt, g2dt);
r2fit2 = fitlm(i2dt, r2dt);

xplot = linspace(min(i2dt), max(i2dt), 200)';
y1 = predict(g2fit2, xplot);
y2 = predict(r2fit2, xplot);
plot(xplot, y1, 'k-', 'LineWidth', 2,'Color',col(4,:));
plot(xplot, y2, 'k-', 'LineWidth', 2,'Color',col(1,:));

g2est = predict(g2fit2,i2dt);
g2mc = g2dt - g2est;
r2est = predict(r2fit2,i2dt);
r2mc = r2dt - r2est;
i2mc = i2dt - i2dt;

% --- ROI 3
nexttile(3); hold on;
n = gca;
n.TitleHorizontalAlignment = 'left';
title('ROI03','FontSize',15);
xlabel('isosbestic (415 nm)','FontSize',15,'Color',col(6,:));
ylabel('emissions','FontSize',15);
plot(i3dt, r3dt,'.','MarkerSize',5,'Color',col(2,:))
plot(i3dt, g3dt,'.','MarkerSize',5,'Color',col(5,:))

g3fit2 = fitlm(i3dt, g3dt);
r3fit2 = fitlm(i3dt, r3dt);

xplot = linspace(min(i3dt), max(i3dt), 200)';
y1 = predict(g3fit2, xplot);
y2 = predict(r3fit2, xplot);
plot(xplot, y1, 'k-', 'LineWidth', 2,'Color',col(4,:));
plot(xplot, y2, 'k-', 'LineWidth', 2,'Color',col(1,:));

g3est = predict(g3fit2,i3dt);
g3mc = g3dt - g3est;
r3est = predict(r3fit2,i3dt);
r3mc = r3dt - r3est;
i3mc = i3dt - i3dt;


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


%% Normalize signals
tt1.String = 'Step 5: Normalize FP signal via dF/F';

% --- dF/F
g1dff = 100*(g1mc./g1fit1(E1.Time));
g1.YData = g1dff;
r1dff = 100*(r1mc./r1fit1(E2.Time));
r1.YData = r1dff;
ylabel(nt1, '\DeltaF / F')

g2dff = 100*(g2mc./g2fit1(E1.Time));
g2.YData = g2dff;
r2dff = 100*(r2mc./r2fit1(E2.Time));
r2.YData = r2dff;
ylabel(nt2, '\DeltaF / F');

g3dff = 100*(g3mc./g3fit1(E1.Time));
g3.YData = g3dff;
r3dff = 100*(r3mc./r3fit1(E2.Time));
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

figure(1);
%
% --- z-score
g1z = (g1mc - mean(g1mc))./(std(g1mc));
r1z = (r1mc - mean(r1mc))./(std(r1mc));
g1.YData = g1z;
r1.YData = r1z;
ylabel(nt1, 'z-score')

g2z = (g2mc - mean(g2mc))./(std(g2mc));
r2z = (r2mc - mean(r2mc))./(std(r2mc));
g2.YData = g2z;
r2.YData = r2z;
ylabel(nt2, 'z-score')

g3z = (g3mc - mean(g3mc))./(std(g3mc));
r3z = (r3mc - mean(r3mc))./(std(r3mc));
g3.YData = g3z;
r3.YData = r3z;
ylabel(nt3, 'z-score')

%% 
% --- softmax
% g1sm = normalize(g1mc,'range');
% r1sm = normalize(r1mc,'range');
% g3sm = normalize(g3mc,'range');
% r3sm = normalize(r3mc,'range');

% f = figure(5);
% t1 = tiledlayout(2,1,'TileSpacing','tight','Padding','compact');
% tt1 = title(t1, 'Pre-Processed Fiber Photometry Data','FontSize',30);
% col = lines(7);
% 
% nexttile(1); hold on; grid on;
% g1 = plot(E1.Time, g1z,'-','LineWidth',lw,'Color',col(5,:),'DisplayName','gDA3h');
% r1 = plot(E2.Time, r1z,'-', 'LineWidth',lw,'Color',col(2,:),'DisplayName','rACh1.7');
% title("Nucleus Accumbens",'FontSize',20);
% nt = gca;
% nt.TitleHorizontalAlignment = 'left';
% xlabel('Time (s)','FontSize',20);
% ylabel('z-score','FontSize',20);
% lgd = legend();
% lgd.FontSize = 15;
% 
% nexttile(2); hold on; grid on;
% g1 = plot(E1.Time, g3z,'-','LineWidth',lw,'Color',col(5,:),'DisplayName','gDA3h');
% r1 = plot(E2.Time, r3z,'-', 'LineWidth',lw,'Color',col(2,:),'DisplayName','rACh1.7');
% title("Hippocampus", 'FontSize',20);
% nt = gca;
% nt.TitleHorizontalAlignment = 'left';
% xlabel('Time (s)','FontSize',20);
% ylabel('z-score','FontSize',20);
% lgd = legend();
% lgd.FontSize = 15;

%% cross-correlation
f = figure(6);
t1 = tiledlayout(1,2,'TileSpacing','tight','Padding','compact');
tt1 = title(t1, 'Cross Correlation Between DA and ACh','FontSize',30);
col = lines(7);

nexttile(1); hold on; grid on;
[r,lags] = xcorr(g1z,r1z);
plot(lags*mean(diff(EI.Time)),r);
title("Nucleus Accumbens",'FontSize',20);
nt = gca;
nt.TitleHorizontalAlignment = 'left';
xlabel('Time (s)','FontSize',20);
ylabel('Cross Correlation','FontSize',20);


nexttile(2); hold on; grid on;
[r,lags] = xcorr(g3z,r3z);
plot(lags*mean(diff(EI.Time)),r,'LineWidth',1.5);
title("Hippocampus", 'FontSize',20);
nt = gca;
nt.TitleHorizontalAlignment = 'left';
xlabel('Time (s)','FontSize',20);
ylabel('Cross Correlation','FontSize',20);


%% Save Pre-Processed Data
photometry.ROI1.name = "NAc";
photometry.ROI1.E1dff = g1dff;
photometry.ROI1.E2dff = r1dff;
photometry.ROI1.E1mc = g1mc;
photometry.ROI1.E2mc = r1mc;

photometry.ROI2.name = "mPFC";
photometry.ROI2.E1dff = g2dff;
photometry.ROI2.E2dff = r2dff;
photometry.ROI2.E1mc = g2mc;
photometry.ROI2.E2mc = r2mc;

photometry.ROI3.name = "dHPC";
photometry.ROI3.E1dff = g3dff;
photometry.ROI3.E2dff = r3dff;
photometry.ROI3.E1mc = g3mc;
photometry.ROI3.E2mc = r3mc;

photometry.EI = i1dt;
photometry.EI_time = EI.Time;
photometry.E1_time = E1.Time;
photometry.E2_time = E2.Time;

basepath = pwd;
[~, basename, ~] = fileparts(pwd);

save([basepath filesep basename '.photometry.mat'],'photometry');