//
//  VoiceData.swift
//  AmosVoice
//
//  Created by AmosFitness on 2023/4/5.
//

import Foundation
import SwiftUI
import AmosBase

public typealias _TTSManager = TTSManager

@Observable
public final class TTSManager: @unchecked Sendable {
    @ObservationIgnored
    @AppStorage("DefaultConfig") private var savedDefaultConfig: Data?
    
    // TTS引擎
    let msTTS: MsTTSEngine?
    let systemTTS: SystemTTSEngine
    public var msEngineIsReady: Bool {
        msTTS != nil
    }
    
    public var playingContent: HLContent? = nil
    public var playOffset: Int = 0
    public var defaultConfig: TTSConfig {
        if let savedConfig = savedDefaultConfig?.decode(type: TTSConfig.self) {
            savedConfig
        } else { TTSConfig() }
    }
    public var defaultSystemConfig: TTSConfig {
        if let savedConfig = savedDefaultConfig?.decode(type: TTSConfig.self) {
            savedConfig
        } else { TTSConfig.system }
    }
    
    public var showLiveSpeechPage: Bool = false
    public var showSpeechBar: Bool = false
    public var occurError: Error? = nil
    
    // 当该值为nil，代表微软TTS正在载入
    public var isPlaying: Bool? = nil
    let isDebuging: Bool
    // 当开始播放的时候赋值，重复播放时调用
    var currentConfig: TTSConfig? = nil
    
    public init(
        sub: String = "",
        region: String = "",
        isDebuging: Bool = false,
        defaultConfig: TTSConfig? = nil
    ) {
        self.isDebuging = isDebuging
        
        self.msTTS = MsTTSEngine(isDebuging: isDebuging)
        self.systemTTS = SystemTTSEngine()
        
        if isPreviewCondition {
            playingContent = HLContent(
                allContent: [.example(.chinesePoem)],
                engine: .system
            )
        }
    }
}

// MARK: - Speech Methods
extension TTSManager {
    // 统一播放的入口
    // 1. 系统TTS 2.默认设置 3.分别播放设置
    // 注意：系统TTS仅使用默认设置，会忽略Content的单独设置
    public func playContents(
        engine: TTSEngine,
        config: TTSConfig? = nil,
        allContent: [TTSContent],
        showLive: Bool = false,
        showLiveBar: Bool = false,
        isHighLightWord: Bool = false
    ) throws {
        self.currentConfig = config
        self.playingContent = HLContent(
            isDebuging: isDebuging,
            allContent: allContent,
            engine: engine,
            isHighLightWord: isHighLightWord
        )
        switch engine {
        case .system:
            systemTTS.play(
                for: allContent,
                defaultConfig: config ?? defaultSystemConfig
            ) { playStatus in
                try self.updatePlayLive(playStatus)
            }
        case .ms:
            guard let msTTS else {
                throw SimpleError.customError(title: "播放错误", msg: "引擎没有初始化")
            }
            msTTS.play(
                for: allContent,
                defaultConfig: config ?? defaultConfig
            ) { playStatus in
                try self.updatePlayLive(playStatus)
            }
        }
        
        /*
         播放的同时出现播放进度页面
         需要在root页面放置sheet：
         
         @State var ttsManager = TTSManager(
             sub: MS_SUB,
             region: MS_REGION,
             isDebuging: false
         )
         
         .sheet(
             isPresented: $ttsManager.showLiveSpeechPage,
             onDismiss: {
                 ttsManager.stopSpeech()
             }) {
             SpeechLiveView(ttsManager: ttsManager)
         }
        */
        if showLive {
            if engine == .system {
                showLiveSpeechPage = true
            }else if (engine == .ms && msTTS != nil) {
                showLiveSpeechPage = true
            }
        }else if showLiveBar {
            withAnimation {
                if engine == .system {
                    showSpeechBar = true
                }else if (engine == .ms && msTTS != nil) {
                    showSpeechBar = true
                }
            }
        }
    }
    
    private func updatePlayLive(
        _ playStatus: PlayStatus
    ) throws {
        switch playStatus {
        case .start:
            if isDebuging {
                debugPrint("开始播放：\(playingContent?.engine.title ?? "N/A")")
            }
            DispatchQueue.main.async {
                self.playOffset = 0
                self.isPlaying = true
            }
        case .play(let reading):
            DispatchQueue.main.async {
                if self.isPlaying == true {
                    self.playingContent?.playWord = reading.word
                    self.playingContent?.wordLength = reading.length
                    if self.playingContent?.engine == .system {
                        self.playingContent?.textOffset = reading.offset
                    }else {
                        self.playingContent?.textOffset = self.playOffset
                        self.playOffset += reading.length
                    }
                }
            }
        case .stop:
            debugPrint("停止播放：\(playingContent?.engine.title ?? "N/A")")
            self.resetSpeech()
        case .error(let error):
            DispatchQueue.main.async {
                self.occurError = error
                self.resetSpeech()
            }
            throw error
        default: break
        }
    }
    
    /// 保存为音频文件（不播放）
    /// ⚠️ 已迁移：SimpleFileHelper → SimpleFile/SimpleFolder
    public func outputContents(
        for allContent: [TTSContent],
        config: TTSConfig? = nil,
        saveName: String
    ) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            // 新 API: 定位 audioFile 文件夹
            guard let audioFolder = try? SimpleFolder.documents?
                .createSubfolderIfNeeded(at: "audioFile") else {
                let error = SimpleError.customError(
                    title: "生成音频文件失败",
                    msg: "无法定位音频文件夹"
                )
                continuation.resume(throwing: error)
                return
            }
            
            let fileName = "\(saveName).mp3"
            
            // 新 API: 检查文件是否已存在
            if audioFolder.containsFile(named: fileName),
               let existingFile = try? audioFolder.file(named: fileName) {
                continuation.resume(returning: existingFile.url)
                return
            }
            
            guard let msTTS else {
                continuation.resume(throwing: SimpleError.customError(
                    title: "生成音频文件失败", msg: "音频引擎没有成功初始化"
                ))
                return
            }
            
            msTTS.synthesisToSpeaker(
                allContent,
                defaultConfig: config ?? defaultConfig,
                audioFileName: saveName,
                audioFomat: .audio24Khz48KBitRateMonoMp3
            ) { playStatus in
                switch playStatus {
                case .stop:
                    let error = SimpleError.customError(
                        title: "生成音频文件失败", msg: "请确保网络环境后重试"
                    )
                    // 新 API: 获取文件引用并检查内容
                    if let file = try? audioFolder.file(named: fileName),
                       let data = try? file.read(), data.count > 0 {
                        continuation.resume(returning: file.url)
                    } else {
                        try? audioFolder.file(named: fileName).delete()
                        continuation.resume(throwing: error)
                    }
                case .error(let error):
                    try? audioFolder.file(named: fileName).delete()
                    continuation.resume(throwing: error)
                default: break
                }
            }
        }
    }
    
    /// 检测任何引擎是否在播放
    public func isSpeaking() -> Bool {
        systemTTS.systemSynthesizer.isSpeaking || msTTS?.isSpeaking == true
    }
    
    public func resetSpeech() {
        debugPrint("重置播放进度的展示")
        DispatchQueue.main.async {
            self.playingContent?.playWord = ""
            self.playingContent?.textOffset = 0
            self.playingContent?.wordLength = 0
            self.playOffset = 0
            self.isPlaying = false
        }
    }
    
    /// 只有系统TTS支持暂停
    public func pauseSpeech() {
        if systemTTS.systemSynthesizer.isSpeaking {
            systemTTS.systemSynthesizer.pauseSpeaking(at: .word)
        }else {
            guard let msTTS else { return }
            DispatchQueue.main.async {
                msTTS.stop()
                self.isPlaying = nil
            }
        }
    }
    
    public func continueSpeech() {
        if systemTTS.systemSynthesizer.isPaused {
            systemTTS.systemSynthesizer.continueSpeaking()
        }else if let playingContent {
            try? playContents(
                engine: playingContent.engine,
                config: currentConfig,
                allContent: playingContent.allContent,
                showLive: false
            )
        }
    }
    
    public func stopSpeech() {
        if isDebuging {
            debugPrint("用户停止播放")
        }
        if systemTTS.systemSynthesizer.isSpeaking || systemTTS.systemSynthesizer.isPaused {
            DispatchQueue.main.async {
                self.systemTTS.systemSynthesizer.stopSpeaking(at: .immediate)
                self.resetSpeech()
            }
        }else {
            guard let msTTS else { return }
            DispatchQueue.main.async {
                msTTS.stop()
                self.isPlaying = nil
            }
        }
    }
    
    public func testSpeaker(
        for speaker: TTSSpeaker,
        style: TTSStyle? = nil,
        role: TTSRole? = nil
    ) {
        let inputText = speaker.language.testSpeech(speaker.speakerName)
        stopSpeech()
        
        let content = TTSContent(
            speechText: inputText,
            useDefaultConfig: false,
            config: .init(
                speaker: speaker,
                role: role,
                style: style
            )
        )
        
        // 直接播放
        try? playContents(
            engine: speaker.language == .system ? .system : .ms,
            allContent: [content],
            showLive: false
        )
    }
}
