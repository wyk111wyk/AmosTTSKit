//
//  TTSDefault.swift
//  AmosTTSKit
//
//  Created by AmosFitness on 2024/10/16.
//

import AmosBase
import SwiftUI

extension SimpleDefaults.Keys {
    /// 累计已合成的字数。
    static let totalPlayedWord = Key<Int>("TTS_TotalPlayedWord", default: 0, iCloud: true)
    /// 用户设置的默认播放属性。`TTSConfig` 自身已是 `Codable`，可直接走 SimpleDefaults 默认桥接。
    static let defaultConfig = Key<TTSConfig?>("TTS_DefaultConfig", iCloud: true)
}

extension TTSConfig: SimpleDefaults.Serializable {
    public static let bridge = TTSConfigBridge()
}

public struct TTSConfigBridge: SimpleDefaults.Bridge, Sendable {
    public typealias Value = TTSConfig
    public typealias Serializable = Data

    public init() {}

    public func serialize(_ value: Value?) -> Serializable? {
        guard let value else { return nil }
        return value.toData()
    }

    public func deserialize(_ object: Serializable?) -> Value? {
        guard let object else { return nil }
        return object.decode(type: Value.self)
    }
}
