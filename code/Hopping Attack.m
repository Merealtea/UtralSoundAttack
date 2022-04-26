%%
clc; clear; close all

%%
[signal,Fs] = audioread('attack record.m4a');
fs = 96000;
sound_in = resample(signal,fs,Fs);
sound_in = sound_in/max(sound_in);

%%
delta = 1200;
[B,A] = butter(10,delta/(fs/2));
s = filter(B,A,sound_in);
s = s + 1;

%%
fcList = [25000,32000,40000];
deltaList = [800,800,800];

interval = 7200; % hopping interval
% Divided into 100ms tracks
group_num = floor(length(sound_in)/interval);
freq_ord = 1;
hopping = zeros(length(sound_in),1);
time = length(sound_in)/fs;
hopping_interval = interval/fs;
%%
for i=1:group_num
    fc = fcList(freq_ord + 1);
    delta = deltaList(freq_ord + 1);
    freq_ord = mod(freq_ord + 1,3);
    
    x = modulate(s((i-1)*interval+1:i*interval),fc,fs,'am');
    
    hopping((i-1)*interval+1:i*interval) = x/max(abs(x));
    [B,A] = butter(10,(fc-delta)/(fs/2),'high');
    out = filter(B,A,hopping((i-1)*interval+1:i*interval));
    [D,C] = butter(10,(fc+delta)/(fs/2));
    out = filter(D,C,out);
    
    hopping((i-1)*interval+1:i*interval) = out/max(abs(out));
end
%%
sound(hopping,fs);
% attack_upsample_fft = abs(fft(hopping));
% N = size(attack_upsample_fft,1);
% f = fs/size(attack_upsample_fft,1):fs/size(attack_upsample_fft,1):fs;
% figure;subplot(211),plot(f/1000,attack_upsample_fft/size(attack_upsample_fft,1)*2);ylim([0,0.01]);xlim([0,45]);
% xlabel("f/kHz");
% title("Spectrum of frequency hopping attack signal")
% 
% t = (1:1:size(attack_upsample_fft,1))/fs;
% subplot(212),plot(t,hopping);
% xlabel("t/s");
% title("Time domain diagram of frequency hopping attack signal")
% % audiowrite('hopping_160ms.wav',30*hopping,fs);
