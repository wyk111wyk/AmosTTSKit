//
//  TTSManager.swift
//  AmosTTSKit
//
//  Created by AmosFitness on 2023/4/5.
//

import Foundation
import SwiftUI
import AmosBase

public typealias _TTSManager = TTSManager

/// TTS 播放状态机。
/// `idle` / `preparing`（微软 SDK 准备中）/ `playing` / `paused`。
public enum PlayState: Equatable, Sendable {
    case idle
    case preparing
    case playing
    case paused

    /// 与旧版 `Bool?` 接口保持兼容：
    /// - `nil` ⇒ preparing（加载中）
    /// - `true` ⇒ playing
    /// - `false` ⇒ idle / paused（区分不开）
    public var isPlayingBool: Bool? {
        switch self {
        case .playing: return true
        case .preparing: return nil
        case .idle, .paused: return false
        }
    }
}

@Observable
@MainActor
public final class TTSManager {
    @ObservationIgnored
    @AppStorage("DefaultConfig") private var savedDefaultConfig: Data?

    // TTS引擎
    @ObservationIgnored
    let msTTS: MsTTSEngine?
    @ObservationIgnored
    let systemTTS: SystemTTSEngine
    public var msEngineIsReady: Bool {
        msTTS != nil
    }

    public var playingContent: HLContent? = nil
    public var playOffset: Int = 0

    public var defaultConfig: TTSConfig {
        SimpleDefaults[.defaultConfig] ?? Self.fallbackDefaultConfig
    }
    public var defaultSystemConfig: TTSConfig {
        SimpleDefaults[.defaultConfig] ?? Self.fallbackSystemConfig
    }

    /// 全局默认配置回退值。
    public static var fallbackDefaultConfig: TTSConfig { TTSConfig() }
    /// 系统 TTS 的默认配置回退值。
    public static var fallbackSystemConfig: TTSConfig { TTSConfig.system }

    /// 写入默认配置（替换旧的 `@AppStorage` 通道）。
    public func saveDefaultConfig(_ config: TTSConfig?) {
        SimpleDefaults[.defaultConfig] = config
    }

    public var showLiveSpeechPage: Bool = false
    public var showSpeechBar: Bool = false
    public var occurError: Error? = nil

    /// 三态播放状态：`preparing` 表示微软 TTS 正在加载。
    public var playState: PlayState = .idle

    /// 与历史接口保持兼容：`true` 表示正在播放；`nil` 表示准备中；`false` 表示空闲/暂停。
    public var isPlaying: Bool? {
        get { playState.isPlayingBool }
        set {
            switch newValue {
            case .some(true): playState = .playing
            case .some(false): playState = .idle
            case .none: playState = .preparing
            }
        }
    }

    @ObservationIgnored
    let isDebuging: Bool
    @ObservationIgnored
    var lastPlayedConfig: TTSConfig? = nil

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
    /// 统一播放入口。系统 TTS 仅使用默认设置；微软 TTS 会为每段文字生成 SSML。
    /// - Parameters:
    ///   - engine: 播放引擎
    ///   - config: 自定义默认配置；为 nil 时按引擎选择 `defaultSystemConfig` / `defaultConfig`
    ///   - allContent: 播放段落
    ///   - showLive: 是否展示 `SpeechLiveView`
    ///   - showLiveBar: 是否展示 `SpeechLiveBar`
    ///   - isHighLightWord: 是否启用词级高亮
    @MainActor
    public func playContents(
        engine: TTSEngine,
        config: TTSConfig? = nil,
        allContent: [TTSContent],
        showLive: Bool = false,
        showLiveBar: Bool = false,
        isHighLightWord: Bool = false
    ) throws {
        self.lastPlayedConfig = config
        self.playingContent = HLContent(
            isDebuging: isDebuging,
            allContent: allContent,
            engine: engine,
            isHighLightWord: isHighLightWord
        )
        self.playOffset = 0
        self.playState = (engine == .ms) ? .preparing : .playing

        switch engine {
        case .system:
            systemTTS.play(
                for: allContent,
                defaultConfig: config ?? defaultSystemConfig
            ) { [weak self] playStatus in
                Task { @MainActor in
                    self?.updatePlayLive(playStatus)
                }
            }
        case .ms:
            guard let msTTS else {
                throw SimpleError.customError(title: "播放错误", msg: "引擎没有初始化")
            }
            msTTS.play(
                for: allContent,
                defaultConfig: config ?? defaultConfig
            ) { [weak self] playStatus in
                Task { @MainActor in
                    self?.updatePlayLive(playStatus)
                }
            }
        }

        if showLive {
            showLiveSpeechPage = (engine == .system) || (engine == .ms && msTTS != nil)
        } else if showLiveBar {
            withAnimation {
                showSpeechBar = (engine == .system) || (engine == .ms && msTTS != nil)
            }
        }
    }

    private func updatePlayLive(_ playStatus: PlayStatus) {
        switch playStatus {
        case .start:
            if isDebuging {
                debugPrint("开始播放：\(playingContent?.engine.title ?? "N/A")")
            }
            playOffset = 0
            playState = .playing
        case .play(let reading):
            guard playState == .playing else { return }
            playingContent?.playWord = reading.word
            playingContent?.wordLength = reading.length
            // 系统引擎：reading.offset/length 直接是 NSString 偏移
            // 微软引擎：reading.offset 是 absolute word offset，直接使用，不做自增
            playingContent?.textOffset = reading.offset
            playOffset = reading.offset + reading.length
        case .pause:
            playState = .paused
        case .stop:
            debugPrint("停止播放：\(playingContent?.engine.title ?? "N/A")")
            resetSpeech()
        case .error(let error):
            occurError = error
            resetSpeech()
        }
    }

    /// 保存为音频文件（不播放）。同一个 `saveName` 已存在且 mp3 合法时直接返回缓存。
    @MainActor
    public func outputContents(
        for allContent: [TTSContent],
        config: TTSConfig? = nil,
        saveName: String
    ) async throws -> URL? {
        guard let audioFolder = try? SimpleFolder.documents?
            .createSubfolderIfNeeded(at: "audioFile") else {
            throw SimpleError.customError(
                title: "生成音频文件失败",
                msg: "无法定位音频文件夹"
            )
        }

        let fileName = "\(saveName).mp3"

        if audioFolder.containsFile(named: fileName),
           let existingFile = try? audioFolder.file(named: fileName),
           MP3FileValidator.isValid(file: existingFile) {
            return existingFile.url
        }

        // 命中但无效时删除，避免续写
        if audioFolder.containsFile(named: fileName),
           let staleFile = try? audioFolder.file(named: fileName) {
            try? staleFile.delete()
        }

        guard let msTTS else {
            throw SimpleError.customError(
                title: "生成音频文件失败",
                msg: "音频引擎没有成功初始化"
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            let resolver = SaveResultResolver(audioFolder: audioFolder, fileName: fileName) { result in
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            msTTS.synthesisToSpeaker(
                allContent,
                defaultConfig: config ?? defaultConfig,
                audioFileName: saveName,
                audioFomat: .audio24Khz48KBitRateMonoMp3
            ) { playStatus in
                resolver.handle(playStatus)
            }
        }
    }

    /// 检测任何引擎是否在播放。
    public func isSpeaking() -> Bool {
        systemTTS.systemSynthesizer.isSpeaking || msTTS?.isSpeaking == true
    }

    public func resetSpeech() {
        debugPrint("重置播放进度的展示")
        playingContent?.playWord = ""
        playingContent?.textOffset = 0
        playingContent?.wordLength = 0
        playOffset = 0
        playState = .idle
    }

    /// 只有系统 TTS 支持暂停；微软 TTS 的"暂停"通过 stop + 重新 play 实现。
    public func pauseSpeech() {
        if systemTTS.systemSynthesizer.isSpeaking {
            systemTTS.systemSynthesizer.pauseSpeaking(at: .word)
            playState = .paused
        } else {
            guard let msTTS else { return }
            msTTS.stop()
            playState = .idle
        }
    }

    public func continueSpeech() {
        if systemTTS.systemSynthesizer.isPaused {
            systemTTS.systemSynthesizer.continueSpeaking()
            playState = .playing
        } else if let playingContent {
            try? playContents(
                engine: playingContent.engine,
                config: lastPlayedConfig,
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
            systemTTS.systemSynthesizer.stopSpeaking(at: .immediate)
            resetSpeech()
        } else {
            guard let msTTS else { return }
            msTTS.stop()
            resetSpeech()
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

        try? playContents(
            engine: speaker.language == .system ? .system : .ms,
            allContent: [content],
            showLive: false
        )
    }
}

// MARK: - Save continuation helper

/// 把 `outputContents` 的 `PlayStatus` 收敛成单一的 success/failure 终态，避免重复 resume。
private final class SaveResultResolver {
    private let audioFolder: SimpleFolder
    private let fileName: String
    private let onFinish: (Result<URL, Error>) -> Void

    private var hasFinished = false
    private let lock = NSLock()

    init(audioFolder: SimpleFolder,
         fileName: String,
         onFinish: @escaping (Result<URL, Error>) -> Void) {
        self.audioFolder = audioFolder
        self.fileName = fileName
        self.onFinish = onFinish
    }

    func handle(_ status: PlayStatus) {
        lock.lock()
        if hasFinished {
            lock.unlock()
            return
        }
        switch status {
        case .stop:
            hasFinished = true
            lock.unlock()
            finishIfValid()
        case .error(let error):
            hasFinished = true
            lock.unlock()
            deleteStale()
            onFinish(.failure(error))
        default:
            lock.unlock()
        }
    }

    private func finishIfValid() {
        guard let file = try? audioFolder.file(named: fileName) else {
            onFinish(.failure(SimpleError.customError(
                title: "生成音频文件失败",
                msg: "请确保网络环境后重试"
            )))
            return
        }
        if MP3FileValidator.isValid(file: file) {
            onFinish(.success(file.url))
        } else {
            deleteStale()
            onFinish(.failure(SimpleError.customError(
                title: "生成音频文件失败",
                msg: "生成的音频文件无效，请检查网络后重试"
            )))
        }
    }

    private func deleteStale() {
        if let file = try? audioFolder.file(named: fileName) {
            try? file.delete()
        }
    }
}

/// MP3 文件合法性最小校验：文件大小 > 1024 字节，且前三字节满足 ID3/MPEG 同步。
enum MP3FileValidator {
    static func isValid(file: SimpleFile) -> Bool {
        guard let data = try? file.read() else { return false }
        return isValidData(data)
    }

    static func isValidData(_ data: Data) -> Bool {
        guard data.count > 1024 else { return false }
        // ID3v2 header: "ID3"
        if data.count >= 3,
           data[0] == 0x49, data[1] == 0x44, data[2] == 0x33 {
            return true
        }
        // MPEG audio frame sync: 0xFF + 0xFB / 0xF3 / 0xF2
        if data.count >= 2,
           data[0] == 0xFF,
           data[1] == 0xFB || data[1] == 0xF3 || data[1] == 0xF2 {
            return true
        }
        return false
    }
}
