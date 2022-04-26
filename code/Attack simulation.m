%% Clear Variables and Load Signal 
clc; close all;
clear;
[call_signal,upsample_fs] = audioread('wechat.m4a');
call_signal = call_signal(:,1);
sound(call_signal,upsample_fs);
%% Plot Orignal Singal FFT
freq = abs(fft(call_signal));
Y = fftshift(freq);
f = (-length(freq(:,1))/2:length(freq(:,1))/2-1)*(upsample_fs/length(freq(:,1)));
plot(f,Y);
title('Orignal Signal')
xlabel('Freq/Hz')
%% AM
fc = 24000;
high_freq=resample(call_signal,96000,upsample_fs)+1;

% carrier = (0:1:length(high_freq)-1);
% carrier = cos(fc * carrier * 2*pi /96000);
x = modulate(high_freq,fc,96000,'am');
freq = abs(fft(x));
Y = fftshift(freq);
f = (-length(freq(:,1))/2:length(freq(:,1))/2-1)*(96000/length(freq(:,1)));
plot(f,Y);
xlabel('Freq/Hz');
title('AM modulate');
% x = (high_freq + 1) .* carrier';
% x = resample(x,upsample_fs,96000);
audiowrite('40khz.wav',x,48000);
%% Plot Signal After AM
freq = abs(fft(x));
n = length(x);
Y = fftshift(freq);
f = (-n/2:n/2-1)*(48000/n);
plot(f,Y);
sound(x,upsample_fs);
%% Self Convolution and Plot its FFT
x_2 = x .* x ;
freq = abs(fft(x_2));
n = length(x);
freq(1)=0;
[m,index] = max(freq);
freq(index) = 0;
% Y = fftshift(freq);
f = (-n/2:n/2-1)*(96000/n);
plot(f,freq)
title('Self Conv Signal')
%% Lower-Freq Filter
[b, a] = butter(9,20000/96000,'low');
x_new = filter(b,a,x_2);

freq = abs(fft(x_new));
freq(1) = 0;
n = length(x_new);
Y = fftshift(freq);
f = (-n/2:n/2-1)*(96000/n);
plot(f,Y);
title('Recover signal');
xlabel('Freq/Hz')
% sound(x_new,fc);