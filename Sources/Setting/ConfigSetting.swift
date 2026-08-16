//
//  ConfigSetting.swift
//  AmosTTSKit
//
//  Created by AmosFitness on 2023/4/7.
//

import SwiftUI
import AmosBase

public struct ConfigSetting: View {
    @Environment(\.dismiss) private var dismissPage

    @State var config: TTSConfig
    /// 旧字段名 `saveAvtion`（保留以避免破坏外部调用方），同时提供拼写正确的别名。
    private let saveAction: (TTSConfig?) -> Void
    var saveAvtion: (TTSConfig?) -> Void { saveAction }

    @State private var useDefaultConfig: Bool = false
    // 是否是设置默认发音人（或单独语音设置）
    let isDefaultSetting: Bool

    @Bindable var ttsManager: TTSManager
    @State private var isShowLive = true

    public init(
        ttsManager: TTSManager,
        config: TTSConfig,
        useDefaultConfig: Bool? = nil,
        saveAvtion: @escaping (TTSConfig?) -> Void = {_ in}
    ) {
        self.ttsManager = ttsManager
        self._config = State(initialValue: config)
        self.saveAction = saveAvtion

        // 区分设置默认还是单独自定义
        if let useDefaultConfig {
            self._useDefaultConfig = State(initialValue: useDefaultConfig)
            isDefaultSetting = false
        }else {
            isDefaultSetting = true
        }
    }

    public var body: some View {
        Form {
            if !isDefaultSetting {
                Section {
                    Toggle("使用默认", isOn: $useDefaultConfig)
                }
            }
            Section {
                speaker()
                rate()
                style()
                role()
            }.disabled(useDefaultConfig)

            speechTest()
        }
        .navigationTitle("播放属性")
        .buttonCircleNavi(role: .destructive, callback: savePage)
    }

    private func savePage() {
        if !isDefaultSetting && useDefaultConfig {
            saveAction(nil)
        }else {
            saveAction(config)
        }
        dismissPage()
    }

    private func speaker() -> some View {
        NavigationLink {
            SpeakerPicker(
                ttsManager: ttsManager,
                type: isDefaultSetting ? .all : .onlyMS,
                selectedSpeaker: config.speaker
            ) { newSpeaker in
                config.speaker = newSpeaker
                if newSpeaker.allRoles.isNotEmpty {
                    config.role = .noneRole
                }
                if newSpeaker.allStyles.isNotEmpty {
                    config.style = .noneStyle
                }
            }
        } label: {
            LabeledContent("选择发音人") {
                VStack(spacing: 4) {
                    HStack {
                        Text(config.speaker.speakerName)
                            .bold()
                            .foregroundStyle(.primary)
                        Text(config.speaker.gender.displayName)
                            .simpleTag(
                                .full(
                                    verticalPad: 1.5,
                                    horizontalPad: 5,
                                    cornerRadius: 3,
                                    bgColor: config.speaker.gender.color
                                )
                            )
                    }
                    if !config.speaker.sublanguage.isEmpty {
                        Text(config.speaker.sublanguage)
                            .font(.footnote)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rate() -> some View {
        let rateLevel = Binding<RateLevel> (
            get: { RateLevel.from(rate: config.rate) },
            set: { config.rate = $0.rate }
        )
        VStack {
            HStack {
                Text("播报速率")
                Spacer()
                Text("\(config.rate, specifier: "%.0f")%")
                    .foregroundColor(.secondary)
            }
            Slider(value: $config.rate,
                   in: -50...200,
                   step: 1) {
                Text("播报速率")
            }
            Picker("", selection: rateLevel) {
                ForEach(RateLevel.allLevel, id: \.self) {
                    Text($0.name).tag($0)
                }
            }.pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private func style() -> some View {
        if config.speaker.allStyles.count > 0 {
            NavigationLink {
                SimplePicker(
                    title: "选择语气",
                    dismissAfterTap: true,
                    allValue: config.speaker.allStyleModelWithNone,
                    selectValues: config.style == nil ? [] : [config.style!],
                    singleSaveAction:  { newStyle in
                        config.style = newStyle
                    })
            } label: {
                SimpleCell("语气") {
                    if let style = config.style {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(style.title).bold()
                            Text(style.instruction)
                                .font(.footnote)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func role() -> some View {
        if config.speaker.allRoles.count > 0 {
            NavigationLink {
                SimplePicker(
                    title: "选择角色",
                    dismissAfterTap: true,
                    allValue: config.speaker.allRoleModelWithNone,
                    selectValues: config.role == nil ? [] : [config.role!],
                    singleSaveAction:  { newRole in
                        config.role = newRole
                    })
            } label: {
                SimpleCell("角色") {
                    if let role = config.role {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(role.title).bold()
                            Text(role.instruction)
                                .font(.footnote)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func speechTest() -> some View {
        Section {
            ForEach(
                String.TestType.allCases
            ) { testText in
                Button {
                    let newContent = TTSContent(
                        speechText: testText.content
                    )
                    try? ttsManager.playContents(
                        engine: config.speaker.language.engine,
                        config: config,
                        allContent: [newContent],
                        showLive: isShowLive
                    )
                } label: {
                    SimpleCell(
                        testText.title,
                        systemImage: "play.circle",
                        content: testText.content,
                        contentLine: 2
                    )
                }
            }
        } header: {
            HStack {
                Text("测试发音")
                Spacer()
                Toggle("显示进度", isOn: $isShowLive)
                    .labelStyle(font: .footnote)
                    .padding(.vertical, 2)
            }
        }
    }
}

#Preview("Default") {
    NavigationStack {
        ConfigSetting(
            ttsManager: .init(),
            config: .init(speakingVoice: nil)
        )
    }
}

#Preview("Toggle") {
    NavigationStack {
        ConfigSetting(
            ttsManager: .init(),
            config: .init(speakingVoice: nil),
            useDefaultConfig: false
        )
    }
}
