//
//  TTSConfig.swift
//  AmosTTSKit
//
//  Created by AmosFitness on 2023/4/6.
//

import Foundation

public struct TTSConfig: Codable, Identifiable, Sendable {
    public var id: UUID
    public var speaker: TTSSpeaker
    public var role: TTSRole?
    public var style: TTSStyle?
    public var styledegree: Double = 1 // 0.01 到 2
    /// 语速，范围 -50 ~ 200（百分比偏移）
    public var rate: Double = 0
    /// 音调，范围 -50 ~ 50（百分比偏移）
    public var pitch: Double = 0
    /// 音量，范围 0 ~ 100（百分比）
    public var volume: Double = 100

    public init(
        id: UUID = .init(),
        speaker: TTSSpeaker = .xiaomo,
        role: TTSRole? = nil,
        style: TTSStyle? = nil,
        styledegree: Double = 1,
        rate: Double = 0,
        pitch: Double = 0,
        volume: Double = 100
    ) {
        self.id = id
        self.speaker = speaker
        self.role = role
        self.style = style
        self.styledegree = styledegree
        self.rate = rate
        self.pitch = pitch
        self.volume = volume
    }

    public init(speakingVoice: String?) {
        let speaker = TTSSpeaker.speaker(from: speakingVoice)
        self.init(
            speaker: speaker ?? .systemTTSEngine
        )
    }

    /// 系统引擎的语速（0 ~ 1）。将 TTSConfig 的 -50 ~ 200 偏移映射到 AVSpeechUtterance 接受的范围。
    /// - rate > 0: 0.55 ~ 1.0
    /// - rate <= 0: 0 ~ 0.55
    public var wrappedRate: Double {
        if speaker == .systemTTSEngine {
            if rate > 0 {
                let clamped = min(rate, 200)
                return 1 - (200 - clamped) / 200 * 0.45
            } else {
                let clamped = max(rate, -50)
                return (clamped + 50) / 50 * 0.55
            }
        } else {
            return rate
        }
    }
}

extension TTSConfig {
    public static var system: TTSConfig {
        TTSConfig(speaker: .systemTTSEngine, rate: -9)
    }

    public static var poem: TTSConfig {
        TTSConfig(speaker: .xiaoxiao, style: .poemStyle)
    }

    public var tagName: String {
        speaker.audioName
    }
}

extension TTSConfig: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.speaker == rhs.speaker &&
        lhs.role == rhs.role &&
        lhs.style == rhs.style &&
        lhs.rate == rhs.rate &&
        lhs.pitch == rhs.pitch &&
        lhs.volume == rhs.volume &&
        lhs.styledegree == rhs.styledegree
    }
}
