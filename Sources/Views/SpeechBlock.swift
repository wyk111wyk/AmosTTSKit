//
//  SpeechBlock.swift
//  AmosTTSKit
//
//  Created by AmosFitness on 2024/4/3.
//

import SwiftUI
import AmosBase

public struct SpeechBlock: View {
    @Bindable var ttsManager: TTSManager
    @Binding var content: TTSContent

    @FocusState var focused: Bool
    let isFocused: Bool

    public init(
        ttsManager: TTSManager,
        isFocused: Bool = false,
        content: Binding<TTSContent>
    ) {
        self.ttsManager = ttsManager
        self.isFocused = isFocused
        self._content = content
    }

    public var body: some View {
        switch content.type {
        case .text:
            Group {
                textFieldCell()
                customizedCell()
            }
        case .pause(_):
            Group {
                Picker("停顿", selection: $content.type) {
                    ForEach(BreakLevel.allCases, id: \.self) { level in
                        Text("\(level.displayName): \(level.pause())毫秒")
                            .tag(ContentType.pause(level: level))
                    }
                }
            }
        }
    }

    private func textFieldCell() -> some View {
        SimpleTextField(
            $content.speechText,
            tintColor: .accentColor
        )
        .focused($focused)
        .onAppear {
            focused = isFocused
        }
    }

    private func customizedCell() -> some View {
        NavigationLink {
            ConfigSetting(
                ttsManager: ttsManager,
                config: content.config,
                useDefaultConfig: content.useDefaultConfig
            ) { newConfig in
                if let newConfig {
                    debugPrint("自定义Config")
                    content.useDefaultConfig = false
                    content.config = newConfig
                }else {
                    content.useDefaultConfig = true
                }
            }
        } label: {
            SimpleCell("讲述人", systemImage: "speaker.wave.1") {
                if content.useDefaultConfig {
                    Text("默认")
                        .simpleTag(.border(contentColor: .secondary))
                }else {
                    Text(content.config.speaker.speakerName)
                        .simpleTag(.border())
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var content: TTSContent = .example(.chinesePoem)
    NavigationStack {
        Form {
            SpeechBlock(
                ttsManager: .init(),
                content: $content
            )
        }
    }
}
