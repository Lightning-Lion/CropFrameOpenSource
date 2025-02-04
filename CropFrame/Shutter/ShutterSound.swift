//
//  ShutterSound.swift
//  CropFrame
//
//  Created by LightningLion on 2025/1/29.
//

import AVFoundation
import os
import SwiftUI

struct ShutterSoundSupport<V:Equatable>: ViewModifier {
    var shutterSoundMod:ShutterSound
    var shutterTrigger:V
    func body(content: Content) -> some View {
        content
        // 预加载声音模型
        .task(id: "onLoad", { shutterSoundMod.preload() })
        // 在拍照的同时播放音效
        .onChange(of: shutterTrigger, initial: true) { oldValue, newValue in
            shutterSoundMod.play()
        }
    }
}

class ShutterSound {
    private var player: AVAudioPlayer?
    
    func preload() {
        // 获取音频文件路径
        guard let path = Bundle.main.path(forResource: "ShutterSound", ofType: "m4a") else {
            print("无法找到音频文件: ShutterSound.m4a.m4a")
            return
        }
        
        let url = URL(fileURLWithPath: path)
        
        do {
            // 配置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 创建播放器
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
           
            
        } catch let error {
            print("播放音频时出错: \(error.localizedDescription)")
        }
    }
    
    func play() {
        player?.play()
    }
}
