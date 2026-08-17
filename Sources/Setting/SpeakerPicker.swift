//
//  SpeakerPicker.swift
//  AmosTTSKit
//
//  Created by AmosFitness on 2023/4/6.
//

import SwiftUI
import AmosBase

struct SpeakerPicker: View {
    // 单段文字定制不可选择系统语音，会导致无法合成
    enum PickerType {
        case all, onlyMS
    }

    @Environment(\.dismiss) private var dismissPage

    private let allLanguages: [TTSSpeakerDic]
    /// 各语言分类的展开状态。拆出 struct，避免 struct 元素上的 `var` 在视图重建时被覆盖。
    @State private var expansionStates: [String: Bool]

    @State var selectedSpeaker: TTSSpeaker

    @Bindable var ttsManager: TTSManager
    let saveAction: (TTSSpeaker) -> Void

    init(
        ttsManager: TTSManager,
        type: PickerType = .onlyMS,
        selectedSpeaker: TTSSpeaker,
        saveAction: @escaping (TTSSpeaker) -> Void
    ) {
        self.ttsManager = ttsManager
        let langs: [TTSSpeakerDic]
        switch type {
        case .all:
            langs = TTSSpeakerDic.allLanguages
        case .onlyMS:
            langs = TTSSpeakerDic.onlyMSLanguages
        }
        self.allLanguages = langs
        self._expansionStates = State(initialValue: Dictionary(
            uniqueKeysWithValues: langs.map { ($0.language.rawValue, true) }
        ))
        self._selectedSpeaker = State(initialValue: selectedSpeaker)
        self.saveAction = saveAction
    }

    var body: some View {
        Form {
            ForEach(allLanguages) { lang in
                Section {
                    let isExpanded = Binding<Bool>(
                        get: { expansionStates[lang.language.rawValue] ?? true },
                        set: { expansionStates[lang.language.rawValue] = $0 }
                    )
                    DisclosureGroup(isExpanded: isExpanded) {
                        ForEach(lang.speakers) { speaker in
                            Button {
                                selectedSpeaker = speaker
                            } label: {
                                speakerCell(speaker)
                            }
                        }
                    } label: {
                        Label(lang.language.rawValue, systemImage: lang.language.iconName())
                    }
                }
            }
        }
        .navigationTitle("选择发音人")
        .buttonCircleNavi(role: .destructive) {
            saveAction(selectedSpeaker)
            dismissPage()
        }
    }
}

// Methods
extension SpeakerPicker {
    private func playSpeaker(
        for speaker: TTSSpeaker,
        style: TTSStyle? = nil,
        role: TTSRole? = nil
    ) {
        ttsManager.testSpeaker(for: speaker, style: style, role: role)
    }
}

// Views
extension SpeakerPicker {
    @ViewBuilder
    private func speakerCell(_ speaker: TTSSpeaker) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center,
                   spacing: 8) {
                if hasSelect(speaker) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(speaker.speakerName)
                        .foregroundColor(.blue)
                        .bold()
                }else {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(.secondary)
                    Text(speaker.speakerName)
                        .foregroundStyle(.secondary)
                }

                Text(speaker.gender.displayName)
                    .simpleTag(.full(verticalPad: 1.5, horizontalPad: 5, cornerRadius: 3, bgColor: speaker.gender.color))
                .opacity(hasSelect(speaker) ? 1 : 0.5)

                Text(speaker.sublanguage)
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    playSpeaker(for: speaker)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                        Text("试听").lineLimit(1)
                    }
                    .simpleTag(.full(verticalPad: 4,
                                     horizontalPad: 6,
                                     bgColor: .blue.opacity(0.8)))
                }
                .foregroundColor(.blue)
            }

            if !speaker.speakerIntro.isEmpty {
                Text(speaker.speakerIntro)
                    .font(.footnote)
                    .foregroundStyle(hasSelect(speaker) ? .primary : .secondary)
            }

            if !speaker.style.isEmpty || !speaker.role.isEmpty {
                VStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if !speaker.style.isEmpty {
                                ForEach(speaker.allStyleModel,
                                        id: \.self.title) { style in
                                    Button {
                                        playSpeaker(for: speaker, style: style)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "play.fill")
                                            Text(style.title).lineLimit(1)
                                        }
                                        .simpleTag(.full(verticalPad: 3,
                                                         horizontalPad: 6,
                                                         cornerRadius: 4,
                                                         bgColor: .green))
                                    }
                                }
                            }
                        }.opacity(hasSelect(speaker) ? 1 : 0.8)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if !speaker.role.isEmpty {
                                ForEach(speaker.allRoleModel,
                                        id: \.self.title) { role in
                                    Button {
                                        playSpeaker(for: speaker, role: role)
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "play.fill")
                                            Text(role.title).lineLimit(1)
                                        }
                                        .simpleTag(.full(verticalPad: 3,
                                                         horizontalPad: 6,
                                                         cornerRadius: 4,
                                                         bgColor: .indigo))
                                    }
                                }
                            }
                        }.opacity(hasSelect(speaker) ? 1 : 0.7)
                    }
                }
            }
        }
        .foregroundColor(.primary)
    }

    private func hasSelect(_ speaker: TTSSpeaker) -> Bool {
        selectedSpeaker == speaker
    }
}

#Preview {
    NavigationStack {
        SpeakerPicker(
            ttsManager: .init(),
            type: .all,
            selectedSpeaker: .xiaomo
        ) {_ in }
    }
}
