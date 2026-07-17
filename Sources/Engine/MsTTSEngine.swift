//
//  TextToSpeechBot.swift
//  AmosVoice
//
//  Created by AmosFitness on 2023/4/5.
//

import Foundation
import SwiftUI
import AmosBase
import MicrosoftCognitiveServicesSpeech

// https://docs.azure.cn/zh-cn/?product=popular

class MsTTSEngine {
    @AppStorage("TotalPlayCount") private var totalPlayCount: Int = 0
    
    var synthesizer = SPXSpeechSynthesizer()
    var speechConfig: SPXSpeechConfiguration?
    
    let isDebuging: Bool
    var isSpeaking: Bool = false
    
    // MARK: - Initialization
    init(
        isDebuging: Bool = false
    ) {
        self.isDebuging = isDebuging
        initSpeechConfig()
    }
    
    private func initSpeechConfig() {
        guard let key = key else { return }
        do {
            try speechConfig = SPXSpeechConfiguration(subscription: key, region: "eastus")
        } catch {
            debugPrint("MsTTS Config 初始化错误: \(error)")
        }
    }
    
    private var cryptoKey: String {
        "KZ3teSj9WXufJconjBuO0KX5++N40Li+XKbeDzvf05uTxr43qdAxjuYO3AhyaDK/"
    }
    
    private var key: String? {
        let crypto = SimpleAESCrypto(key: publicKey, iv: publicIV)
        return try? crypto.decrypt(encryptedText: cryptoKey)
    }
    
    // MARK: Method
    @discardableResult
    func stop() -> Bool {
        guard isSpeaking else { return true }
        do {
            try synthesizer.stopSpeaking()
            return true
        } catch {
            debugPrint("结束播放时发生错误：\(error)")
            return false
        }
    }
    
    func play(
        for allContents: [TTSContent],
        defaultConfig: TTSConfig,
        audioFomat: SPXSpeechSynthesisOutputFormat = .audio24Khz48KBitRateMonoMp3,
        speechCallBack: @escaping (PlayStatus) throws -> Void
    ) {
        if isSpeaking {
            stop()
        }else {
            synthesisToSpeaker(
                combineContents(for: allContents),
                defaultConfig: defaultConfig,
                audioFomat: audioFomat,
                speechCallBack: speechCallBack
            )
        }
    }
    
    // 合并文字和停顿成为一个HTML文本
    func combineContents(for allContents: [TTSContent]) -> [TTSContent] {
        var playableContents = allContents
        
        // 合并停顿
        var breakIndexs: [Int] = []
        // 提取停顿的内容的index
        for index in playableContents.indices {
            if playableContents[index].type != .text {
                breakIndexs.append(index)
            }
        }
        // 合并文字内容
        if isDebuging {
            debugPrint("共有\(breakIndexs.count)个停顿")
        }
        for index in breakIndexs {
            if index > 0 {
                let type = playableContents[index].type
                if case let .pause(level) = type {
                    let pauseSign =
                    """
                    <break time="\(level.pause())ms" />
                    """
                    playableContents[index-1].speechText = playableContents[index-1].speechText + pauseSign
                    
                    // 删除停顿内容
                    playableContents.remove(at: index)
                }
            }
        }
        
        return playableContents
    }
    
    // 传入 defaultConfig 则所有的文件都使用默认设置进行播放
    // 传入 nil 则使用SSML的方式自定义每一段文字的播放属性
    func synthesisToSpeaker(
        _ allContents: [TTSContent],
        defaultConfig: TTSConfig,
        audioFileName: String? = nil,
        audioFomat: SPXSpeechSynthesisOutputFormat,
        speechCallBack: @escaping (PlayStatus) throws -> Void
    ) {
        debugPrint("微软TTS：开始播放")
        // 获取播放属性
        guard speechConfig != nil else { return }
        // 设置播放属性
        // 如果同时设置了 SpeechSynthesisVoiceName 和 SpeechSynthesisLanguage 会忽略 SpeechSynthesisLanguage 设置。 系统会讲你使用 SpeechSynthesisVoiceName 指定的语音。
        // 如果使用语音合成标记语言 (SSML) 设置了 voice 元素，则会忽略 SpeechSynthesisVoiceName 和 SpeechSynthesisLanguage 设置
//            if let config {
//                speechConfig?.speechSynthesisLanguage = config.speaker.region
//                speechConfig?.speechSynthesisVoiceName = config.speaker.audioName
//            }
        // riff16Khz16BitMonoPcm 格式的比特率为 384 kbps
        // audio24Khz48KBitRateMonoMp3 的比特率仅为 48 kbps
        speechConfig?.setSpeechSynthesisOutputFormat(audioFomat)
        
        do {
            // 创建播放合成器
            var audioConfig: SPXAudioConfiguration
            if let audioFileName,
               let audioFolder = try? SimpleFolder.documents?.createSubfolderIfNeeded(at: "audioFile"),
               let file = try? audioFolder.createFileIfNeeded(withName: "\(audioFileName).mp3") {
                audioConfig = try SPXAudioConfiguration(wavFileOutput: file.path)
                if isDebuging {
                    debugPrint("储存音频文件的地址:\(file.url)")
                }
            }else {
                audioConfig = SPXAudioConfiguration()
            }
            synthesizer = try SPXSpeechSynthesizer(
                speechConfiguration: speechConfig!,
                audioConfiguration: audioConfig
            )
            attachAction(
                allContents: allContents,
                speechCallBack: speechCallBack
            )
            let pureText = allContents.fullText
            var textLang: String = SimpleLanguage().detectLanguage(
                for: pureText
            )?.rawValue ?? Locale.current.identifier
            if textLang.hasPrefix("zh") {
                textLang = "zh-CN"
            }
            if isDebuging {
                debugPrint("播放内容文字:\(pureText)")
            }
            
            // 合成用来播放的SSML（包含文字和播放属性）
            let contentText = allContents.reduce("") {
                partialResult,
                content in
                partialResult + assembleSSML(
                    content,
                    defaultConfig: defaultConfig
                )
            }
            let finalText = addBase(
                for: contentText,
                language: textLang
            )
            let _ = try synthesizer.startSpeakingSsml(finalText)
            
//                debugPrint("TTS - 播放时长：\(result.audioDuration.toDuration(units: [.second, .minute]))")
//                let dataCount = Double(result.audioData?.count ?? 0)
//                debugPrint("TTS - 播放文件：\(dataCount.toStorage())")
//                let stream = try SPXAudioDataStream.init(from: result)
        } catch {
            debugPrint("播放发生错误:\(error)")
            try? speechCallBack(.error(error: error))
        }
    }
    
    private func attachAction(
        allContents: [TTSContent],
        speechCallBack: @escaping (PlayStatus) throws -> Void
    ) {
        // 开始语音播放
        synthesizer.addSynthesisStartedEventHandler { _, evt in
            if self.isDebuging {
                debugPrint("TTS语音播放 - 开始:\(evt.description)")
            }
            self.isSpeaking = true
            try? speechCallBack(.start)
        }
        
        // 语音正在继续播放
        synthesizer.addSynthesizingEventHandler { _, _ in
//            self.isSpeaking = true
//            speechCallBack(.play(reading: "Continue"))
        }
        
        // 播放完成或被停止
        synthesizer.addSynthesisCompletedEventHandler { _, _ in
            debugPrint("TTS语音播放 - 结束")
            self.isSpeaking = false
            try? speechCallBack(.stop)
            self.totalPlayCount += allContents.reduce(0, { partialResult, cont in
                partialResult + cont.speechText.count
            })
        }
        
        // 播放被取消
        synthesizer.addSynthesisCanceledEventHandler { _, evt in
            debugPrint("TTS语音播放 - 取消")
            let cancellationDetails = try! SPXSpeechSynthesisCancellationDetails(
                fromCanceledSynthesisResult: evt.result
            )
            if self.isDebuging {
                debugPrint("CANCELED: ErrorCode: \(cancellationDetails.errorCode.rawValue)")
                debugPrint("CANCELED: ErrorDetails: \(cancellationDetails.errorDetails as String?)")
            }
            self.isSpeaking = false
            try? speechCallBack(
                .error(
                    error: SimpleError.customError(
                        title: "播放被取消",
                        msg: (cancellationDetails.errorDetails as String?).wrapped
                    )
                )
            )
        }
        
        // 播放的进度
        synthesizer.addSynthesisWordBoundaryEventHandler { synthesis, evt in
            let inputText = evt.text
            //            debugPrint("TTS - 正在播放：\(inputText)")
            //            debugPrint("text offset: \(evt.textOffset), word length: \(evt.wordLength)")
            //            self.isSpeaking = true
            try? speechCallBack(
                .play(
                    reading: (inputText, Int(evt.textOffset), Int(evt.wordLength))
                )
            )
        }
    }
}

extension MsTTSEngine {
    private func assembleSSML(_ cont: TTSContent, defaultConfig: TTSConfig) -> String {
        let config =
        if cont.useDefaultConfig { defaultConfig }
        else { cont.config }
        
        switch cont.type {
        case .text:
            var finalText = ""
            // 发音人
            let voiceFront =
"""
<voice name="\(config.speaker.audioName)">
"""
            finalText += voiceFront
            
            // 语速
            let rateFront =
"""
<prosody rate="\(config.rate)%">
"""
            finalText += rateFront
            
            // 身分和语气
            if let role = config.role,
               let style = config.style {
                let roleFront =
"""
<mstts:express-as role="\(role.role)" style="\(style.style)">
"""
                finalText += roleFront
            }else if let style = config.style {
                let styleFront =
"""
<mstts:express-as style="\(style.style)">
"""
                finalText += styleFront
            }else if let role = config.role {
                let roleFront =
"""
<mstts:express-as role="\(role.role)">
"""
                finalText += roleFront
            }
            
            let voiceBottom = "</voice>"
            let rateBottom = "</prosody>"
            let roleBottom = "</mstts:express-as>"
            
            // 朗读的内容
            finalText += cont.speechText
            
            // 加上尾部
            if finalText.contains("mstts:express-as") {
                finalText += roleBottom
            }
            finalText += rateBottom
            finalText += voiceBottom
            
//            if isDebuging {
//                debugPrint("单独合成SSML：")
//                debugPrint(finalText)
//            }
            
            return finalText
        case .pause(let level):
            return
"""
<break time="\(level.pause())ms" />
"""
        }
    }
    
    // language: 根文档的语言。 该值可以包含语言代码，例如 en（英语），也可以包含区域设置，例如 en-US（美国英语）。
    private func addBase(
        for text: String,
        language: String
    ) -> String {
        var baseFront = ""
        if text.contains(/mstts/) {
            baseFront =
"""
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"
       xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="\(language)">
"""
        }else {
            baseFront =
"""
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="\(language)">
"""
        }
        let baseBottom = "</speak>"
        
        let finalText = baseFront + text + baseBottom
        
        if isDebuging {
            debugPrint("最终组合的合成SSML：")
            print(finalText)
        }
        
        return finalText
    }
}
