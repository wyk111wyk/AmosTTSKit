//
//  SystemTTSEngine.swift
//  AmosTTSKit
//
//  Created by AmosFitness on 2024/9/20.
//

import Foundation
import AVFAudio
import AmosBase
import SwiftUI

/// `AVSpeechSynthesizer` 不是线程安全的，但回调都在同一线程上（通常是 main）。
/// 通过 `nonisolated(unsafe)` 让编译器不再追究，而不是 `@retroactive Sendable`。
private nonisolated(unsafe) var _speechSynthesizerRetainer: Any? = nil

/// 系统 TTS 引擎封装。所有可变状态由 `lock` 串行化；`AVSpeechSynthesizer` 的所有调用都在同一线程。
final class SystemTTSEngine: NSObject, @unchecked Sendable {
    let systemSynthesizer = AVSpeechSynthesizer()
    private let lock = NSLock()
    private var _speechCallBack: (PlayStatus) -> Void = { _ in }
    private var _hasFinishedCurrentSession: Bool = false
    private var _currentSessionID: UUID = UUID()

    private var speechCallBack: (PlayStatus) -> Void {
        get {
            lock.lock(); defer { lock.unlock() }
            return _speechCallBack
        }
        set {
            lock.lock(); defer { lock.unlock() }
            _speechCallBack = newValue
        }
    }

    private var hasFinishedCurrentSession: Bool {
        get {
            lock.lock(); defer { lock.unlock() }
            return _hasFinishedCurrentSession
        }
        set {
            lock.lock(); defer { lock.unlock() }
            _hasFinishedCurrentSession = newValue
        }
    }

    private var currentSessionID: UUID {
        get {
            lock.lock(); defer { lock.unlock() }
            return _currentSessionID
        }
        set {
            lock.lock(); defer { lock.unlock() }
            _currentSessionID = newValue
        }
    }

    override init() {
        super.init()
        // 维持系统合成器在生命周期内不被回收。
        _speechSynthesizerRetainer = systemSynthesizer
    }

    /// 开始播放 / 停止播放。
    /// 每次 `play` 都会重新分配 sessionID 与 delegate 闭包，避免上一次的回调影响本次。
    func play(
        for allContent: [TTSContent],
        defaultConfig: TTSConfig,
        speechCallBack: @escaping (PlayStatus) -> Void
    ) {
        if systemSynthesizer.isSpeaking {
            systemSynthesizer.stopSpeaking(at: .immediate)
            return
        }
        debugPrint("系统TTS：开始播放")

        let sessionID = UUID()
        currentSessionID = sessionID
        hasFinishedCurrentSession = false
        self.speechCallBack = { [weak self] status in
            guard let self else { return }
            let matches: Bool = {
                self.lock.lock(); defer { self.lock.unlock() }
                return self._currentSessionID == sessionID
            }()
            guard matches else { return }
            speechCallBack(status)
        }
        systemSynthesizer.delegate = self

        let allText: String = allContent.fullText

        var language: String? = nil
        if let possibleLanguage = SimpleLanguage().detectLanguage(
            for: allText
        )?.rawValue, possibleLanguage.hasPrefix("en") {
            language = possibleLanguage
        } else {
            language = "zh-CN"
        }

        let baseRate: Float = defaultConfig.wrappedRate.toFloat

        let utterance = AVSpeechUtterance(string: allText)
        utterance.rate = baseRate
        utterance.postUtteranceDelay = 0.5
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: language)

        systemSynthesizer.speak(utterance)
    }

    /// 当前会话是否仍在进行。
    var isCurrentSessionActive: Bool {
        !hasFinishedCurrentSession
    }
}

// 系统TTS委托代理
extension SystemTTSEngine: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        debugPrint("TTS - 开始播放")
        speechCallBack(.start)
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        debugPrint("TTS - 暂停播放")
        speechCallBack(.pause)
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        guard !hasFinishedCurrentSession else { return }
        hasFinishedCurrentSession = true
        debugPrint("TTS - 取消播放")
        speechCallBack(.stop)
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard !hasFinishedCurrentSession else { return }
        hasFinishedCurrentSession = true
        debugPrint("TTS - 停止播放")
        speechCallBack(.stop)
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        debugPrint("TTS - 继续播放")
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let fullText = utterance.speechString as NSString
        let subString = fullText.substring(with: characterRange)
        speechCallBack(
            .play(
                reading: Reading(
                    word: String(subString).firstCharacters(count: 8),
                    offset: characterRange.location,
                    length: characterRange.length
                )
            )
        )
    }
}
