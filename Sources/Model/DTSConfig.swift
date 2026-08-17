//
//  DTSConfig.swift
//  AmosTTSKit
//
//  Created by Amos on 2025/1/12.
//

import Foundation

/// 豆包（火山引擎）TTS 请求结构。Swift 属性采用 camelCase，通过 `CodingKeys` 兼容上游服务的 snake_case JSON。
public struct DTSConfig: Codable {
    public let app: AppConfig
    public let user: UserConfig
    public let audio: AudioConfig
    public let request: RequestConfig

    public init(
        app: AppConfig,
        user: UserConfig = .init(),
        audio: AudioConfig,
        request: RequestConfig
    ) {
        self.app = app
        self.user = user
        self.audio = audio
        self.request = request
    }
}

extension DTSConfig {
    public struct AppConfig: Codable {
        public let appid: String
        public let token: String
        public let cluster: String

        public init(
            appid: String,
            token: String,
            cluster: String = "volcano_tts"
        ) {
            self.appid = appid
            self.token = token
            self.cluster = cluster
        }

        private enum CodingKeys: String, CodingKey {
            case appid, token, cluster
        }
    }

    public struct UserConfig: Codable {
        public let uid: String

        public init(uid: String = UUID().uuidString) {
            self.uid = uid
        }

        private enum CodingKeys: String, CodingKey {
            case uid
        }
    }

    public struct AudioConfig: Codable {
        public let voiceType: String
        public let encoding: String
        public let speedRatio: Float

        public init(
            voiceType: String,
            encoding: String = "mp3",
            speedRatio: Float = 1
        ) {
            self.voiceType = voiceType
            self.encoding = encoding
            self.speedRatio = speedRatio
        }

        private enum CodingKeys: String, CodingKey {
            case voiceType = "voice_type"
            case encoding
            case speedRatio = "speed_ratio"
        }
    }

    public struct RequestConfig: Codable {
        public let reqid: String
        public let text: String
        public let textType: String?
        public let withTimestamp: Int?
        public let operation: String

        public init(
            reqid: String = UUID().uuidString,
            text: String,
            isSSML: Bool = false,
            withTimestamp: Int? = nil,
            operation: String = "query"
        ) {
            self.reqid = reqid
            self.text = text
            self.textType = isSSML ? "ssml" : nil
            self.withTimestamp = withTimestamp
            self.operation = operation
        }

        private enum CodingKeys: String, CodingKey {
            case reqid
            case text
            case textType = "text_type"
            case withTimestamp = "with_timestamp"
            case operation
        }
    }
}

extension DTSConfig {
    /// 将结构体内属性转换为 JSON 格式的字符串。
    public func toJSONString() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let jsonData = try encoder.encode(self)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("Error encoding DTSConfig to JSON: \(error)")
            return nil
        }
    }
}
