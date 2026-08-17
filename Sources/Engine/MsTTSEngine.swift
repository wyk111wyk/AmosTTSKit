//
//  MsTTSEngine.swift
//  AmosTTSKit
//
//  Created by AmosFitness on 2023/4/5.
//

import Foundation
import SwiftUI
import AmosBase
import MicrosoftCognitiveServicesSpeech

// https://docs.azure.cn/zh-cn/?product=popular

/// 微软 Azure TTS 引擎封装。
///
/// 内部用 `currentSessionID` 保证一次合成的回调只能收尾一次；上层（`TTSManager.outputContents`
/// 等）可以放心地把 `.stop` / `.error` 任一作为"结束"信号，不会重复触发。
///
/// 线程说明：SDK 回调可能在非主线程触发，状态字段通过 `lock` 串行化；除 SDK 入口以外的所有状态读写都应在同一线程上下文。
final class MsTTSEngine: @unchecked Sendable {
    @AppStorage("TotalPlayCount") private var totalPlayCount: Int = 0

    var synthesizer = SPXSpeechSynthesizer()
    var speechConfig: SPXSpeechConfiguration?

    let isDebuging: Bool
    private let lock = NSLock()
    private var _isSpeaking: Bool = false
    var isSpeaking: Bool {
        lock.lock(); defer { lock.unlock() }
        return _isSpeaking
    }

    private var currentSessionID: UUID? = nil
    private var hasFinishedCurrentSession: Bool = false
    
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
        speechCallBack: @escaping (PlayStatus) -> Void
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
    
    // 合并文字和停顿成为一个SSML文本。倒序遍历避免 remove 导致的索引越界。
    func combineContents(for allContents: [TTSContent]) -> [TTSContent] {
        if isDebuging {
            let pauses = allContents.filter { $0.type != .text }.count
            debugPrint("共有\(pauses)个停顿")
        }
        
        var contents = allContents
        // 倒序处理，找到 pause 时把 <break> 合并到前一段
        if let lastIndex = contents.indices.last {
            for index in stride(from: lastIndex, through: 1, by: -1) {
                if case let .pause(level) = contents[index].type {
                    let pauseSign = "<break time=\"\(level.pause())ms\" />"
                    contents[index - 1].speechText += pauseSign
                    contents.remove(at: index)
                }
            }
        }
        return contents
    }
    
    // 传入 defaultConfig 则所有的文件都使用默认设置进行播放
    // 传入 nil 则使用SSML的方式自定义每一段文字的播放属性
    func synthesisToSpeaker(
        _ allContents: [TTSContent],
        defaultConfig: TTSConfig,
        audioFileName: String? = nil,
        audioFomat: SPXSpeechSynthesisOutputFormat,
        speechCallBack: @escaping (PlayStatus) -> Void
    ) {
        debugPrint("微软TTS：开始播放")
        // 获取播放属性
        guard let config = speechConfig else {
            speechCallBack(.error(error: SimpleError.customError(
                title: "微软TTS未初始化",
                msg: "SpeechConfig 创建失败，请检查网络或密钥"
            )))
            return
        }
        config.setSpeechSynthesisOutputFormat(audioFomat)

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
                speechConfiguration: config,
                audioConfiguration: audioConfig
            )
            let sessionID = UUID()
            lock.lock()
            currentSessionID = sessionID
            hasFinishedCurrentSession = false
            lock.unlock()

            // 预先计算需要累加的字数（避免在闭包里捕获 self）
            let charsToAdd = allContents.reduce(0) { partialResult, cont in
                partialResult + cont.speechText.count
            }

            attachAction(
                sessionID: sessionID,
                charsToAdd: charsToAdd,
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
            let contentText = allContents.reduce("") { partialResult, content in
                partialResult + assembleSSML(content, defaultConfig: defaultConfig)
            }
            let finalText = addBase(for: contentText, language: textLang)
            let _ = try synthesizer.startSpeakingSsml(finalText)
        } catch {
            debugPrint("播放发生错误:\(error)")
            speechCallBack(.error(error: error))
        }
    }

    // 每次 synthesisToSpeaker 开始合成都会分配一个新 sessionID。
    // 所有 SDK 回调先用 sessionID 比对，再决定是否触发上层收尾，避免 cancel+complete 同时到达导致回调两次。
    private func attachAction(
        sessionID: UUID,
        charsToAdd: Int,
        speechCallBack: @escaping (PlayStatus) -> Void
    ) {
        // 开始语音播放
        synthesizer.addSynthesisStartedEventHandler { [weak self] _, evt in
            guard let self else { return }
            let matches = self.lockAndCheck(sessionID: sessionID)
            guard matches else { return }
            if self.isDebuging {
                debugPrint("TTS语音播放 - 开始:\(evt.description)")
            }
            self.markSpeaking(true)
            self.lock.lock()
            self.hasFinishedCurrentSession = false
            self.lock.unlock()
            speechCallBack(.start)
        }

        // 语音正在继续播放（保留事件，便于将来扩展）
        synthesizer.addSynthesizingEventHandler { _, _ in }

        // 播放完成或被停止
        synthesizer.addSynthesisCompletedEventHandler { [weak self] _, _ in
            guard let self else { return }
            let matches = self.lockAndCheck(sessionID: sessionID)
            guard matches, !self.markFinished() else { return }
            self.markSpeaking(false)
            debugPrint("TTS语音播放 - 结束")
            speechCallBack(.stop)
            self.bumpTotalPlayCount(by: charsToAdd)
        }

        // 播放被取消
        synthesizer.addSynthesisCanceledEventHandler { [weak self] _, evt in
            guard let self else { return }
            let matches = self.lockAndCheck(sessionID: sessionID)
            guard matches, !self.markFinished() else { return }
            self.markSpeaking(false)
            debugPrint("TTS语音播放 - 取消")
            let cancellationDetails = try? SPXSpeechSynthesisCancellationDetails(
                fromCanceledSynthesisResult: evt.result
            )
            if self.isDebuging {
                debugPrint("CANCELED: ErrorCode: \(cancellationDetails?.errorCode.rawValue ?? 0)")
                debugPrint("CANCELED: ErrorDetails: \(cancellationDetails?.errorDetails as String? ?? "")")
            }
            speechCallBack(.error(
                error: SimpleError.customError(
                    title: "播放被取消",
                    msg: cancellationDetails?.errorDetails as String? ?? ""
                )
            ))
        }

        // 播放的进度
        synthesizer.addSynthesisWordBoundaryEventHandler { [weak self] _, evt in
            guard let self else { return }
            let matches = self.lockAndCheck(sessionID: sessionID)
            guard matches else { return }
            speechCallBack(.play(
                reading: Reading(word: evt.text, offset: Int(evt.textOffset), length: Int(evt.wordLength))
            ))
        }
    }

    // MARK: - Lock helpers

    private func lockAndCheck(sessionID: UUID) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return currentSessionID == sessionID
    }

    /// 把当前 session 标记为已结束。返回是否从"未结束→已结束"的状态翻转（仅在翻转时返回 true）。
    private func markFinished() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if hasFinishedCurrentSession { return false }
        hasFinishedCurrentSession = true
        return true
    }

    private func markSpeaking(_ value: Bool) {
        lock.lock(); defer { lock.unlock() }
        _isSpeaking = value
    }

    private func bumpTotalPlayCount(by delta: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.totalPlayCount += delta
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

            // prosody: 语速 / 音调 / 音量
            // 字段语义：
            //   rate: -50 ~ 200，Azure 接收百分比偏移 (例如 0 表示 "default", +30 表示 "+30%")
            //   pitch: 0 表示 100% 基准, -50 ~ +50 偏移；映射为百分比
            //   volume: 0 ~ 100，百分比音量
            let ratePct = Int(config.rate)
            let pitchPct = Int(config.pitch)
            let volumePct = max(0, min(100, Int(config.volume)))
            let prosodyFront =
"""
<prosody rate="\(ratePct)%" pitch="\(pitchPct)%" volume="\(volumePct)%">
"""
            finalText += prosodyFront

            // 身分和语气
            let hasExpressAs: Bool
            if let role = config.role,
               let style = config.style {
                let roleFront =
"""
<mstts:express-as role="\(role.role)" style="\(style.style)" styledegree="\(config.styledegree)">
"""
                finalText += roleFront
                hasExpressAs = true
            }else if let style = config.style {
                let styleFront =
"""
<mstts:express-as style="\(style.style)" styledegree="\(config.styledegree)">
"""
                finalText += styleFront
                hasExpressAs = true
            }else if let role = config.role {
                let roleFront =
"""
<mstts:express-as role="\(role.role)">
"""
                finalText += roleFront
                hasExpressAs = true
            }else {
                hasExpressAs = false
            }

            // 朗读的内容
            finalText += cont.speechText

            // 加上尾部
            if hasExpressAs {
                finalText += "</mstts:express-as>"
            }
            finalText += "</prosody>"
            finalText += "</voice>"

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
        let needsMSTTS = text.contains("mstts:express-as")
        let baseFront: String
        if needsMSTTS {
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
