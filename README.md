# UltraSoundAttack

## 这个是IOT超声波攻击大作业的整合支撑材料
小组成员：徐翰文、陈星元、陈修元、高弈杰、杨刘佳

	code文件夹里包含了攻击、防御、跳频攻击和CNN网络训练的代码
	Video Presentation文件夹中包含了攻击、防御、跳频攻击和CNN防御实现的视频
	model_UI.py包含可执行文件界面UI的设计代码文件

## 所用到的编程语言：

	MATLAB
 	Python3.8

## requirements为：

	numpy == 1.20.3
	torch==1.10.0
	torchaudio==0.10.0
	tkinter==8.5.0
	windnd==1.0.7
	python_speech_features==0.6
	wavfile==2.2.0

## 原理展示

### 攻击原理
由于智能手机放大器模组存在一定程度的高频非线性放大现象。我们利用该现象，将攻击信号调制到高频，使得信号通过手机放大器模组后发生自卷积效应，使得高频信号回到低频，被手机接收
[!image text](https://github.com/Merealtea/UtralSoundAttack/blob/main/fig/AttackTheory.png)
		
### 卷积防御原理
由于手机接收到的攻击信号存在明显的失真和高频分量部分较大，我们认为可以使用神经网络实现二分类任务，从而屏蔽攻击信号，只接收正常的语音信号。
[!image text](https://github.com/Merealtea/UtralSoundAttack/blob/main/fig/CNNStructure.png)
