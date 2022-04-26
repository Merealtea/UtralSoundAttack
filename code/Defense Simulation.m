clc;close all;

[attack_upsample_sig,upsample_fs] = audioread('40khz.wav');
disp(upsample_fs);
disp(length(attack_upsample_sig));
attack_upsample_sig=resample(attack_upsample_sig,96000,48000);
length_attack = size(attack_upsample_sig,1);
N = length_attack;%采样点数
t=(0:N-1)/96000;%采样时间s
f = 10000;
defense_sig = sin(2*pi*f*t)'/1;

attack_upsample_sig = attack_upsample_sig + defense_sig;
attack_upsample_sig = attack_upsample_sig/max(attack_upsample_sig);
figure;subplot(211),plot_fft(attack_upsample_sig,96000)

xlabel("f/kHz");
title("攻击信号基带频谱")

t = (1:1:length(attack_upsample_sig))/upsample_fs;
subplot(212),plot(t,attack_upsample_sig);
xlabel("t/s");
title("攻击信号时域图")


nonlinear_sig = attack_upsample_sig.*attack_upsample_sig + attack_upsample_sig;
nonlinear_sig = nonlinear_sig/max(nonlinear_sig);
figure;subplot(211),plot_fft(nonlinear_sig, 96000)
xlabel("f/kHz");
title("非线性混声信号基带频谱")
%  
t = (1:1:size(nonlinear_sig,1))/upsample_fs;
subplot(212),plot(t,nonlinear_sig);
xlabel("t/s");
title("非线性混声信号时域图")
% saveas(gcf,'nonlinear.jpg');

d = fdesign.lowpass('Fp,Fst,Ap,Ast',5/48,8/48,1,60);
d_low = fdesign.lowpass('Fp,Fst,Ap,Ast',12/48,14/48,1,60);
d_high = fdesign.highpass('Fst,Fp,Ast,Ap',12/48,14/48,60,1);
% d = fdesign.lowpass('Fp,Fst,Ap,Ast',4/48,7.5/48,1,60);
Hd = design(d,'butter');
Hd_low=design(d_low,'butter');
Hd_high = design(d_high,'butter');
%[mix_base_sig, attack_upsample_sig] = butter(6,15000*2/96000);
% 除去15khz高频的低频基带信号，用作LMS的dn
mix_base_sig=filter(Hd,nonlinear_sig);
mix_base_sig=mix_base_sig/max(mix_base_sig);

figure;subplot(211),plot_fft(mix_base_sig, 96000)
% figure;subplot(211),plot(f/1000,mix_base_fft);ylim([0 0.01]),xlim([0 15])
xlabel("f/kHz");
title("before anc sig 的低通分量")

subplot(212),plot(t,mix_base_sig);
xlabel("t/s");
title("before anc sig 的低通分量时域图")

% 15khz高频攻击信号（卷积后），用于自卷积得到低频攻击信号
high_freq_sig=filter(Hd_low,nonlinear_sig);
high_freq_sig=filter(Hd_high,high_freq_sig);
high_freq_sig = high_freq_sig/max(high_freq_sig);
high_freq_sig = high_freq_sig(100:end);
% N = size(high_freq_sig,1);
% high_freq_fft = abs(fft(high_freq_sig));
% f = upsample_fs/size(high_freq_fft,1):upsample_fs/size(high_freq_fft,1):upsample_fs;
figure;subplot(211),plot_fft(high_freq_sig,48000)
xlabel("f/kHz");
title("攻击信号基带频谱")
% 
t = (1:1:size(high_freq_sig,1))/upsample_fs;
subplot(212),plot(t,high_freq_sig);
xlabel("t/s");
title("攻击信号时域图")

% 高频自卷积
d_con_low = fdesign.lowpass('Fp,Fst,Ap,Ast',10/48,13/48,1,60);
Hd_con_low = design(d_con_low, 'butter');
high_freq_sig_col = high_freq_sig .* high_freq_sig;
%high_freq_sig_col = conv(high_freq_sig, high_freq_sig);
high_freq_sig_col = high_freq_sig_col/max(high_freq_sig_col);
high_freq_sig_col = high_freq_sig_col(100:end);
high_freq_sig_col = filter(Hd_con_low,high_freq_sig_col);
% N = size(high_freq_sig_col,1);
% high_freq_fft_col = abs(fft(high_freq_sig_col))/N*2;
% f = upsample_fs/size(high_freq_fft_col,1):upsample_fs/size(high_freq_fft_col,1):upsample_fs;
figure;subplot(211),plot_fft(high_freq_sig_col,48000)
xlabel("f/kHz");
title("攻击信号自卷积频谱")
t = (1:1:size(high_freq_sig_col,1));
subplot(212),plot(t,high_freq_sig_col-0.4);
xlabel("t/s");
title("攻击信号自卷积时域图")
saveas(gcf,'attack_conv.jpg');
t = (1:1:size(record_sig,1));
plot(t,record_sig)


sound( record_sig, 48000)

t = (1:1:size(high_freq_fft_col,1))/upsample_fs;
subplot(212),plot(t,high_freq_sig_col);
xlabel("t/s");
title("攻击信号时域图")
audiowrite('attack.wav',high_freq_sig_col,96000);

% %初始化系数 
% fir_co = zeros(order+1,1);
% 梯度下降利用能量最小的原则
% 输出信号为sig - sighp*co 能量最小。
order = 50;
error_anc = zeros( size(high_freq_sig ,1),1);
y_anc = zeros( size(mix_base_sig, 1),1);
% 参考内容为前80个采样时刻信息

after_anc = ifft(mix_base_fft(1:size(attack_base_sig,1)) - attack_base_fft(1:size(attack_base_sig,1)));

FrameSize = 256;
Length = size(high_freq_sig,1);
NIter = Length/FrameSize;
lmsfilt2 = dsp.LMSFilter('Length',100,'Method','Normalized LMS', 'StepSize',0.01);
mix = zeros( size(high_freq_sig,1),1);
wout = zeros(100,ceil(NIter));

for k = 1:NIter-1
    x = high_freq_sig_col((k-1)*FrameSize+1:k*FrameSize);
    d = mix_base_sig((k-1)*FrameSize+1:k*FrameSize);

    [y,e,w] = lmsfilt2(x,d);

    error_anc((k-1)*FrameSize+1:k*FrameSize) = e;
    mix((k-1)*FrameSize+1:k*FrameSize) = d;
    y_anc((k-1)*FrameSize+1:k*FrameSize) = y;
    wout(:,k)  = w;
end

N = size(error_anc,1);
%error_anc_fft = abs(fft(error_anc))/N*2;
error_anc_fft = abs(fft(error_anc))/N*2;
f = 96000/N:96000/N:96000;
figure;subplot(211),plot(f/1000,error_anc_fft);ylim([0 0.01]),xlim([0 15])
xlabel("f/kHz");
title("error anc fft");
y_anc_fft = abs(fft(y_anc))/size(y_anc,1)*2;
f = 96000/size(y_anc,1):96000/size(y_anc,1):96000;
subplot(222),plot(f/1000,y_anc_fft);ylim([0 0.01]),xlim([0 15])
xlabel("f/kHz");
title("before anc sig 的低通分量")
f = 96000/size(mix_base_fft,1):96000/size(mix_base_fft,1):96000;
subplot(212),plot(f/1000,mix_base_fft);ylim([0 0.01]),xlim([0 15])
xlabel("f/kHz");
title("before anc sig 的低通分量")
% saveas(gcf,'after_anc.jpg');
t = (1:1:N)/96000;
subplot(212),plot(t,error_anc);
xlabel("t/s");
title("error anc 时域图")
saveas(gcf,'after_anc.jpg');

final_anc = mix_base_sig - error_anc;
final_anc_fft = abs(fft(final_anc));
figure;subplot(211),plot(f/1000,final_anc_fft);ylim([0 0.001]),xlim([0 25])
xlabel("f/kHz");
title("error anc fft");

t = (1:1:N)/96000;
subplot(212),plot(t,final_anc);
xlabel("t/s");
audiowrite('error_out.wav',error_anc,96000);
audiowrite('y_out.wav',y_anc,96000);

function m=plot_fft(X,fs)
Fs=fs;
L=length(X);
n = 2^nextpow2(L);
Y = fft(X,n);
P2 = abs(Y/L);
P1 = P2(1:n/2+1);
P1(2:end-1) = 2*P1(2:end-1);
plot(0:(Fs/n):(Fs/2-Fs/n),P1(1:n/2))
ylim([0,0.0005]);
m=1;
end
