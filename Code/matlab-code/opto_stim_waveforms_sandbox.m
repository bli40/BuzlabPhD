%% 
% clear all; close all;
dur         = 100;  % ms
fr1         = 10;   % Hz
fr2         = 100;
maxAmp      = 1050;
minAmp      = 685;
onRamp      = 0;
offRamp     = 0;

x = linspace(0,dur,1000);

%% sinusoid envelope
phase = x*2*pi*fr1 - pi/2;
A = maxAmp - minAmp;
env = 0.5*A*(sin(phase)) + (0.5*A) + minAmp;

figure(1); clf; hold on;
plot(x,env);
fprintf("Minimum: %f\nMaximum: %f\n\n",min(env),max(env));

title('Sinusoidal Pulse');
xlabel('time (ms)');
ylabel('intensity on cyclops');

%% sinusoid ripple
phase = x*2*pi*fr2 - pi/2;
A = maxAmp - minAmp;
rip = 0.5*(sin(phase)+1);

figure(1); yyaxis right;
plot(x,rip);
fprintf("Minimum: %f\nMaximum: %f\n\n",min(rip),max(rip));

title('Sinusoidal Pulse');
xlabel('time (ms)');
ylabel('intensity on cyclops');

%% Merge
wave = minAmp + (env-minAmp) .* rip;

figure(2); clf; hold on;
plot(x,wave);

fprintf("Minimum: %f\nMaximum: %f\n\n",min(wave),max(wave));

title('Ripple Pulse');
xlabel('time (ms)');
ylabel('intensity on cyclops');

%% matlab% Define time vector
fs = 10000;          % Sampling frequency (Hz)
t = 0:1/fs:2;        % Time duration of 2 seconds

% Define frequencies
f_fast = 100;        % Fast sinusoid frequency (Hz)
f_slow = 2;          % Slow modulating sinusoid frequency (Hz)

% Generate the two signals
fast_wave = sin(2 * pi * f_fast * t);
slow_wave = (sin(2 * pi * f_slow * t) + 1) / 2; % Scales slow wave between 0 and 1

% Modulate max amplitude
modulated_wave = fast_wave .* slow_wave;

% Plot the results
figure;
plot(t, modulated_wave, 'b', t, slow_wave, 'r--');
legend('Modulated Wave', 'Slow Amplitude Envelope');
xlabel('Time (seconds)');
ylabel('Amplitude');
title('Amplitude Modulation with a Slower Sinusoid');
grid on;