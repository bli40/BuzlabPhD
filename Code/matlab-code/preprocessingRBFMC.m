%% preprocessRBFMC.m
% Code to preprocess fiber photometry and photoactuation data from Doric 
% RBFMC Gen 2 via BBC300.

% created by Brian Y. Li - 2026/08/16

clear all;
close all;

%% Load Data CSV
EI_file = dir("*_0000.csv");
E1_file = dir("*_0001.csv");
E2_file = dir("*_0002.csv");

EI = readtable(string(EI_file(1).name));
E1 = readtable(string(E1_file(1).name));
E2 = readtable(string(E2_file(1).name));

% --- plot ROIs and traces
f1 = figure(1);
t1 = tiledlayout(3,1);
tt1 = title(t1, 'Step 1: Raw Data');
col = lines(7);

% --- region 1
nt1 = nexttile(1); hold on;
title("ROI 1 (NAc)");
nt1.TitleHorizontalAlignment = 'left';
xlabel("time (s)");
ylabel("CMOS Intensity");

% EI_1 = plot(EI.Time, EI.ROI01, 'LineWidth',1,'Color',col(7,:));
g1 = plot(E1.Time, E1.ROI01,'-','LineWidth',2,'Color',col(5,:));
r1 = plot(E2.Time, E2.ROI01,'-', 'LineWidth',2,'Color',col(2,:));

% --- region 2
nt2 = nexttile(2); hold on;
title("ROI 2 (empty)");
nt2.TitleHorizontalAlignment = 'left';
xlabel("time (s)");
ylabel("CMOS Intensity");

% EI_1 = plot(EI.Time, EI.ROI01, 'LineWidth',1,'Color',col(7,:));
g2 = plot(E1.Time, E1.ROI02,'-','LineWidth',2,'Color',col(5,:));
r2 = plot(E2.Time, E2.ROI02,'-', 'LineWidth',2,'Color',col(2,:));

% --- region 3
nt3 = nexttile(3); hold on;
title("ROI 3 (HPC)");
nt3.TitleHorizontalAlignment = 'left';
xlabel("time (s)");
ylabel("CMOS Intensity");

% EI_1 = plot(EI.Time, EI.ROI01, 'LineWidth',1,'Color',col(7,:));
g3 = plot(E1.Time, E1.ROI03,'-','LineWidth',2,'Color',col(5,:));
r3 = plot(E2.Time, E2.ROI03,'-', 'LineWidth',2,'Color',col(2,:));

%% De-Noising
tt1.String = "Step 2: De-noising via 10 Hz Low-Pass Filter"
fs = 30; 
fc = 10;
[b, a] = butter(2,fc/(fs/2));

g1dn = filtfilt(b,a,E1.ROI01);
r1dn = filtfilt(b,a,E2.ROI01);

g2dn = filtfilt(b,a,E1.ROI02);
r2dn = filtfilt(b,a,E2.ROI02);

g3dn = filtfilt(b,a,E1.ROI03);
r3dn = filtfilt(b,a,E2.ROI03);

g1.YData = g1dn;
r1.YData = r1dn;

g2.YData = g2dn;
r2.YData = r2dn;

g3.YData = g3dn;
r3.YData = r3dn;

drawnow;
%% Photobleaching Correction
f2 = figure(2); clf; hold on;
t2 = tiledlayout(3,1);

nexttile(1); hold on;
% --- double exponential fit for green ROI1
g1fit = fit(E1.Time, g1dn, 'exp2');
coeffs = coeffvalues(g1fit);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4); 
g1e = plot(g1fit,E1.Time, g1dn);
g1e(1).Color = col(5,:);
g1e(1).MarkerSize = 5;
g1e(2).Color = col(4,:);

% --- double exponential fit for red ROI1
r1fit = fit(E2.Time, r1dn, 'exp2');
coeffs = coeffvalues(r1fit);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4);
r1e = plot(r1fit,E2.Time, r1dn);
r1e(1).Color = col(2,:);
r1e(1).MarkerSize = 5;
r1e(2).Color = col(7,:);

nexttile(2); hold on;
% --- double exponential fit for green ROI1
g2fit = fit(E1.Time, g2dn, 'exp2');
coeffs = coeffvalues(g2fit);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4);
g2e = plot(g2fit,E1.Time, g2dn);
g2e(1).Color = col(5,:);
g2e(1).MarkerSize = 5;
g2e(2).Color = col(4,:);

% --- double exponential fit for red ROI1
r2fit = fit(E2.Time, r2dn, 'exp2');
coeffs = coeffvalues(r2fit);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4);
r2e = plot(r2fit,E2.Time, r2dn);
r2e(1).Color = col(2,:);
r2e(1).MarkerSize = 5;
r2e(2).Color = col(7,:);

nexttile(3); hold on;
% --- double exponential fit for green ROI1
g3fit = fit(E1.Time, g3dn, 'exp2');
coeffs = coeffvalues(g3fit);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4);
g3e = plot(g3fit,E1.Time, g3dn);
g3e(1).Color = col(5,:);
g3e(1).MarkerSize = 5;
g3e(2).Color = col(4,:);

% --- double exponential fit for red ROI1
r3fit = fit(E2.Time, r3dn, 'exp2');
coeffs = coeffvalues(r3fit);
a = coeffs(1); b = coeffs(2); c = coeffs(3); d = coeffs(4);
r3e = plot(r3fit,E2.Time, r3dn);
r3e(1).Color = col(2,:);
r3e(1).MarkerSize = 5;
r3e(2).Color = col(7,:);

% --- de-trend raw signals
figure(1);
tt1.String = 'Step 3: Photobleaching Correction via Double Exponential Fit';
g1dt = g1dn - g1fit(E1.Time); 
g1.YData = g1dt;

r1dt = r1dn - r1fit(E2.Time);
r1.YData = r1dt;

g2dt = g2dn - g2fit(E1.Time);
g2.YData = g2dt;

r2dt = r2dn - r2fit(E2.Time);
r2.YData = r2dt;

g3dt = g3dn - g3fit(E1.Time);
g3.YData = g3dn;

r3dt = r3dn - r3fit(E2.Time);
r3.YData = r3dn;

%% Motion correction

%% Normalize signals
tt1.String = 'Step 5: Normalize FP signal via dF/F';

g1dff = 100*(g1dt./g1fit(E1.Time));
g1.YData = g1dff;
r1dff = 100*(r1dt./r1fit(E2.Time));
r1.YData = r1dff;
ylabel(nt1, '\DeltaF / F')

g2dff = 100*(g2dt./g2fit(E1.Time));
g2.YData = g2dff;
r2dff = 100*(r2dt./r2fit(E2.Time));
r2.YData = r2dff;
ylabel(nt2, '\DeltaF / F');

g3dff = 100*(g3dt./g3fit(E1.Time));
g3.YData = g3dff;
r3dff = 100*(r3dt./r3fit(E2.Time));
r3.YData = r3dff;
ylabel(nt3, '\DeltaF / F');
