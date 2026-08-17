//
//  TTSContent.swift
//  AmosTTSKit
//
//  Created by AmosFitness on 2023/4/6.
//

import Foundation
import AmosBase

public struct TTSContent: Identifiable, Codable, Sendable {

    public let id: UUID
    public var type: ContentType
    /// 播报的文字内容
    public var speechText: String
    /// 是否使用全局默认配置；为 false 时使用 `config` 内的自定义配置
    public var useDefaultConfig: Bool
    /// 播报属性（仅在 `useDefaultConfig == false` 时生效）
    public var config: TTSConfig

    public init(id: UUID = UUID(),
         type: ContentType = .text,
         speechText: String = "",
         useDefaultConfig: Bool = true,
         config: TTSConfig = .init()) {
        self.id = id
        self.type = type
        self.speechText = speechText
        self.useDefaultConfig = useDefaultConfig
        self.config = config
    }

    public enum CodingKeys: String, CodingKey {
        case id, type, speechText, useDefaultConfig, config
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.speechText, forKey: .speechText)
        try container.encode(self.useDefaultConfig, forKey: .useDefaultConfig)
        try container.encode(self.config, forKey: .config)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.type = try container.decode(ContentType.self, forKey: .type)
        self.speechText = try container.decode(String.self, forKey: .speechText)
        self.useDefaultConfig = try container.decode(Bool.self, forKey: .useDefaultConfig)
        self.config = try container.decode(TTSConfig.self, forKey: .config)
    }

    /// 将语气还原为"无"（保留为 `noneStyle` 而非 nil，方便调用方比较）。
    public mutating func clearStyle() {
        self.config.style = .noneStyle
    }
    /// 兼容旧名称 `emptyStyle`。
    public mutating func emptyStyle() { clearStyle() }

    /// 将角色还原为"无"（保留为 `noneRole` 而非 nil）。
    public mutating func clearRole() {
        self.config.role = .noneRole
    }
    /// 兼容旧名称 `emptyRole`。
    public mutating func emptyRole() { clearRole() }

    /// 将 config 重置为系统默认配置。
    public mutating func useDefaultConfigReset() {
        self.config = .init()
    }
    /// 兼容旧拼写 `defautConfig()`。
    public mutating func defautConfig() { useDefaultConfigReset() }
}

extension TTSContent {
    public static func example(_ textType: String.TestType) -> TTSContent {
        .init(speechText: textType.content)
    }

    public static func pause(_ level: BreakLevel) -> TTSContent {
        .init(type: .pause(level: level))
    }
}

extension Array where Element == TTSContent {
    public var fullText: String {
        let pureText = self.reduce("") { partialResult, content in
            if partialResult.isNotEmpty {
                partialResult + "\n" + content.speechText
            }else {
                partialResult + content.speechText
            }
        }
        return pureText
    }
}
