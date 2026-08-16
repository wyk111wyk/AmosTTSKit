//
//  TTSSpeaker.swift
//  AmosTTSKit
//
//  Created by AmosFitness on 2023/4/5.
//

import Foundation
import SwiftUI
import AmosBase

public struct TTSSpeakerDic: Codable, Identifiable, Sendable {
    public let language: TTSLanguage
    public let speakers: [TTSSpeaker]

    /// 使用 `language.rawValue` 作为稳定 id，避免每次访问生成新的 UUID 导致 SwiftUI 重建。
    public var id: String { language.rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = try container.decode(TTSLanguage.self, forKey: .language)
        speakers = try container.decode([TTSSpeaker].self, forKey: .speakers)
    }

    public static let fileName = "tts_speakers.json"
    public static let allLanguages: [TTSSpeakerDic] = fileName.getFileFromBundle(bundle: .module) ?? []
    public static let onlyMSLanguages: [TTSSpeakerDic] = (fileName.getFileFromBundle(bundle: .module) ?? []).filter { dic in
        dic.language != .system
    }
}

public struct TTSSpeaker {
    public let region: String
    public let language: TTSLanguage
    public let sublanguage: String
    public let gender: TTSGender
    public let audioName, speakerName, speakerIntro, style: String
    public let role: String
    
    public init(
        region: String,
        language: TTSLanguage,
        sublanguage: String,
        gender: TTSGender,
        audioName: String,
        speakerName: String,
        speakerIntro: String,
        style: String,
        role: String
    ) {
        self.region = region
        self.language = language
        self.sublanguage = sublanguage
        self.gender = gender
        self.audioName = audioName
        self.speakerName = speakerName
        self.speakerIntro = speakerIntro
        self.style = style
        self.role = role
    }
    

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        region = try container.decode(String.self, forKey: .region)
        language = try container.decode(TTSLanguage.self, forKey: .language)
        sublanguage = try container.decode(String.self, forKey: .sublanguage)
        gender = try container.decode(TTSGender.self, forKey: .gender)
        audioName = try container.decode(String.self, forKey: .audioName)
        speakerName = try container.decode(String.self, forKey: .speakerName)
        speakerIntro = try container.decode(String.self, forKey: .speakerIntro)
        style = try container.decode(String.self, forKey: .style)
        role = try container.decode(String.self, forKey: .role)
    }
}

extension TTSSpeaker: Codable, Equatable, Identifiable, Sendable {
    public static let xiaomo: TTSSpeaker = .init(region: "zh-CN", language: .cn, sublanguage: "普通话，简体", gender: .female, audioName: "zh-CN-XiaomoNeural", speakerName: "晓墨", speakerIntro: "清晰、放松的声音，具有丰富的角色扮演和情感，适合音频书籍。", style: "affectionate&angry&calm&cheerful&depressed&disgruntled&embarrassed&envious&fearful&gentle&sad&serious", role: "Boy&Girl&OlderAdultFemale&OlderAdultMale&SeniorFemale&SeniorMale&YoungAdultFemale&YoungAdultMale")
    
    public static let xiaoxiao: TTSSpeaker = .init(region: "zh-CN", language: .cn, sublanguage: "普通话，简体", gender: .female, audioName: "zh-CN-XiaoxiaoNeural", speakerName: "晓晓", speakerIntro: "活泼、温暖的声音，具有多种场景风格和情感。", style: "affectionate&angry&assistant&calm&chat&cheerful&customerservice&disgruntled&fearful&friendly&gentle&lyrical&newscast&poetry-reading&sad&serious", role: "")
    
    // 系统离线TTS引擎
    public static let systemTTSEngine: TTSSpeaker = .init(region: "zh-CN", language: .system, sublanguage: "", gender: .female, audioName: "systemTTSEngine", speakerName: "系统自带引擎", speakerIntro: "系统合成语音，质量较差但无需联网", style: "", role: "")
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.audioName == rhs.audioName
    }
    
    public var id: String { audioName }
    
    public var allStyles: [String] {
        style
            .components(separatedBy: "&")
            .filter { $0.count > 0 }
    }
    public var allRoles: [String] {
        role
            .components(separatedBy: "&")
            .filter { $0.count > 0 }
    }
    
    // 用来挑选播报人的语气和角色
    public var allStyleModelWithNone: [TTSStyle] {
        var temp = [TTSStyle.noneStyle]
        temp.append(contentsOf: allStyles.compactMap { name in
            TTSStyle.allStyles.first { style in
                style.style == name
            }
        })
        return temp
    }
    
    public var allRoleModelWithNone: [TTSRole] {
        var temp = [TTSRole.noneRole]
        temp.append(contentsOf: allRoles.compactMap { name in
            TTSRole.allRoles.first { role in
                role.role == name
            }
        })
        return temp
    }
    
    public var allStyleModel: [TTSStyle] {
        let temp = allStyles.compactMap { name in
            TTSStyle.allStyles.first { style in
                style.style == name
            }
        }
        return temp
    }
    public var allRoleModel: [TTSRole] {
        let temp = allRoles.compactMap { name in
            TTSRole.allRoles.first { role in
                role.role == name
            }
        }
        return temp
    }
    
    public static func speaker(from name: String?) -> Self? {
        var tempSpeaker: Self? = nil
        
        for dic in TTSSpeakerDic.allLanguages {
            for speaker in dic.speakers {
                if speaker.audioName == name {
                    tempSpeaker = speaker
                    break
                }
            }
        }
        
        return tempSpeaker
    }
}
