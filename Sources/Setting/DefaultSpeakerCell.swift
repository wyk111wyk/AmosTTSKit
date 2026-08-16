//
//  DefaultSpeakerCell.swift
//  AmosTTSKit
//
//  Created by AmosFitness on 2024/9/20.
//

import SwiftUI
import AmosBase

public struct DefaultSpeakerCell: View {
    @Bindable var ttsManager: TTSManager

    public init(ttsManager: TTSManager) {
        self.ttsManager = ttsManager
    }

    public var body: some View {
        let config = ttsManager.defaultConfig
        NavigationLink {
            ConfigSetting(
                ttsManager: ttsManager,
                config: config
            ) { newConfig in
                // 保存默认全局播放属性
                ttsManager.saveDefaultConfig(newConfig)
            }
        } label: {
            SimpleCell("默认播放属性") {
                Text(config.speaker.speakerName)
                    .simpleTag(.border())
            }
        }
    }
}

#Preview {
    NavigationStack {
        Form {
            Section {
                DefaultSpeakerCell(ttsManager: .init())
            }
        }
    }
}
