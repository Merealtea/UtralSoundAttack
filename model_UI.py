# -*- coding: utf-8 -*-
"""
Created on Sun Dec 12 19:07:56 2021

@author: DELL
"""

import tkinter as tk
import windnd
from tkinter import ttk
import torch
import torch.nn as nn
import torch.nn.functional as F
import python_speech_features
import wavfile
import os
import numpy as np

class M5(nn.Module):
    def __init__(self, n_input=1, n_output=2, stride=16, n_channel=32):
        super().__init__()
        self.conv1 = nn.Conv1d(n_input, n_channel, kernel_size=5, stride=1, padding=2, bias=False)
        self.bn1 = nn.BatchNorm1d(n_channel)
        self.pool1 = nn.MaxPool1d(2)
        self.conv2 = nn.Conv1d(n_channel, n_channel, kernel_size=3, padding=1, bias=False)
        self.bn2 = nn.BatchNorm1d(n_channel)
        self.pool2 = nn.MaxPool1d(2)
        self.conv3 = nn.Conv1d(n_channel, 2 * n_channel, kernel_size=3, padding=1, bias=False)
        self.bn3 = nn.BatchNorm1d(2 * n_channel)
        self.pool3 = nn.MaxPool1d(2)
        self.conv4 = nn.Conv1d(2 * n_channel, 2 * n_channel, kernel_size=3, padding=1, bias=False)
        self.bn4 = nn.BatchNorm1d(2 * n_channel)
        self.pool4 = nn.MaxPool1d(2)
        self.fc1 = nn.Linear(2 * n_channel, n_output)

        for m in self.modules():
            if isinstance(m, nn.Conv1d):
                nn.init.kaiming_normal_(m.weight, mode='fan_out', nonlinearity='relu')
            elif isinstance(m, nn.Linear):
                nn.init.kaiming_normal_(m.weight, mode='fan_out', nonlinearity='relu')
            elif isinstance(m, nn.BatchNorm1d):
                nn.init.constant_(m.weight, 1)
                nn.init.constant_(m.bias, 0)

    def forward(self, x):
        x = self.conv1(x)
        x = F.relu(self.bn1(x))
        x = self.pool1(x)
        x = self.conv2(x)
        x = F.relu(self.bn2(x))
        x = self.pool2(x)
        x = self.conv3(x)
        x = F.relu(self.bn3(x))
        x = self.pool3(x)
        x = self.conv4(x)
        x = F.relu(self.bn4(x))
        x = self.pool4(x)
        x = F.avg_pool1d(x, x.shape[-1])
        x = x.permute(0, 2, 1)
        x = torch.squeeze(x, dim=1)
        x = self.fc1(x)
        return F.softmax(x, dim=1)

class UI():
    def __init__(self):
        self.root = tk.Tk()
        self.root.geometry('600x300')
        self.root.title('攻击信号识别')
        
        path = os.path.abspath('.')
        
        self.discriminator = M5(n_input=1,n_output=2)
        state_dict = torch.load(path+'\parameter.pkl',map_location='cpu')
        self.discriminator.load_state_dict(state_dict)
        self.discriminator.eval()
        
        self.scollar = tk.Scrollbar(orient=tk.VERTICAL)
        self.scollar.pack(side = tk.RIGHT,fill = tk.Y)
        title = ['1','2','3']
        self.box = ttk.Treeview(self.root,columns=title,
                                show='headings',yscrollcommand=self.scollar.set)
        self.box.pack()
        self.box.column('1',width=100,anchor='center')
        self.box.column('2',width=300,anchor='center')
        self.box.column('3',width=100,anchor='center')
        self.box.heading('1',text='File num')
        self.box.heading('2',text='Flim path')
        self.box.heading('3',text='State')
        
        
        self.add_button = tk.Button(self.root,text ="点击添加文件",font=('幼圆',15,'bold'),command = self.add_files)
        self.add_button.place(x = 50,y = 250)
        self.file_list = []
        
        self.test_button = tk.Button(self.root,text ="开始检测",font=('幼圆',15,'bold'),command = self.detection)
        self.test_button.place(x = 270,y = 250)
        
        self.clear_button = tk.Button(self.root,text ="清空",font=('幼圆',15,'bold'),command = self.clear)
        self.clear_button.place(x = 450,y = 250)
        
        self.style = ttk.Style()
        self.style.configure('Treeview', font=('Arial',10,'bold'))
        def fixed_map(option):
            return [elm for elm in self.style.map('Treeview',query_opt=option)
                    if elm[:2]!=('!disabled','!selected')]
        self.style.map('Treeview',background = fixed_map('background'),foreground=fixed_map('foreground'))
        self.box.tag_configure('tag_attack', background = 'red')
        self.box.tag_configure('tag_normal', background = 'green')
        self.box.tag_configure('tag_standby', background = 'yellow')
        self.scollar.config(command = self.box.yview)
        self.res = []
        
        self.root.mainloop()
        
        
    def drag_files(self,files): 
        for file in files:
            file = file.decode('utf-8')
            cat = file.split('.')[1]
            if cat != 'wav':
                tk.messagebox.showinfo('错误','当前版本只支持wav文件')
                return
            self.file_list.append(file)
            self.box.insert('',len(self.file_list),values=[len(self.file_list),file,'Standby'],tags = 'tag_standby')

    def add_files(self):
        self.drag_win = tk.Toplevel(self.root)
        self.drag_win.title('将测试音频拖到该窗口')
        self.drag_win.geometry('300x120')
        windnd.hook_dropfiles(self.drag_win.winfo_id(),func=self.drag_files)
        self.confirm = tk.Button(self.drag_win,text = '确定',font=('幼圆',15,'bold'),command = self.drag_win.destroy)
        self.confirm.place(x = 120,y = 80)
        
        
    def detection(self):
        bathc_wav = []
        length = []
        
        with torch.no_grad():
            for path in self.file_list:
                x,sample_rate,_ = wavfile.read(path)
                # x, sample_rate = librosa.load(path)
                x = np.array(x)
                l = x.shape[0] // 10
                mfcc = python_speech_features.mfcc(signal = x[:l], samplerate = sample_rate,
                                              winlen = 0.0426,winstep = 0.01065,nfft = 2048, nfilt = 128,numcep = 128)
                # mfcc =  librosa.feature.mfcc(y=x, sr=sample_rate,n_mfcc=128,
                #                                        n_fft = 2048,hop_length = 512,n_mels = 128)
                mfcc = torch.FloatTensor(mfcc).unsqueeze(1)#.permute(1,2,0)
                length.append(mfcc.shape[0])
                bathc_wav.append(mfcc)
        mfcc = torch.cat(bathc_wav)
        prediction = torch.argmax(self.discriminator(mfcc),dim=1)
        start = 0
        for l in length:
            pre = prediction[start:start+l].double().mean()
            if pre > 0.5:
                self.res.append(1)
            else:
                self.res.append(0)
            start += l
        self.show_res()
        
    def discriminator(self):
        if len(self.file_list) == 0:
            tk.messagebox.showinfo('错误','您未导入音频进行测试')
        pass
    
    def show_res(self):
        for item,state in zip(self.box.get_children(),self.res):
            if state == 1:
                string = 'Normal'
                tag = 'tag_normal'
            else:
                string = 'Attack'
                tag = 'tag_attack'
            values = self.box.item(item)['values']
            values[2] = string
            self.box.item(item,values=values,tags=tag)
        
    def clear(self):
        x = self.box.get_children()
        for item in x:
            self.box.delete(item)
        self.file_list.clear()
        self.res.clear()
            
    def quit(self):
        self.root.destroy()
        
        

if __name__ == '__main__':
    UI()
