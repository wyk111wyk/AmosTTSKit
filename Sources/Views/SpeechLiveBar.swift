//
//  SpeechLiveBar.swift
//  AmosTTSKit
//
//  Created by AmosFitness on 2024/10/13.
//

import SwiftUI
import AmosBase

public struct SpeechLiveBar: View {
    @Bindable var ttsManager: TTSManager
    let showDismissButton: Bool
    let hasShadow: Bool

    @State private var isDismissButtonOn: Bool = false

    public init(
        ttsManager: TTSManager = .init(),
        showDismissButton: Bool = true,
        hasShadow: Bool = false
    ) {
        self.ttsManager = ttsManager
        self.showDismissButton = showDismissButton
        self.hasShadow = hasShadow
    }

    public var body: some View {
        controlBar()
            .onChange(of: ttsManager.playState) {
                withAnimation {
                    // 准备中(preparing)或空闲/暂停(idle/paused)都允许关闭
                    isDismissButtonOn = (ttsManager.playState != .playing)
                }
            }
            .onDisappear {
                stop()
            }
    }

    @MainActor
    private func dismissBar() {
        ttsManager.stopSpeech()
        withAnimation {
            ttsManager.showSpeechBar = false
        }
    }
}

extension SpeechLiveBar {
    @ViewBuilder
    private func controlBar() -> some View {
        if let playingContent = ttsManager.playingContent {
            VStack(spacing: 10) {
                HStack(spacing: 15) {
                    controlButton()
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(ttsManager.playState == .playing ? "正在播放" : "点击播放")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if isMSTTSReady {
                                Text("准备播放")
                                    .simpleTag(.border())
                            }
                            Text(playingContent.playWord)
                                .foregroundStyle(.primary)
                                .layoutPriority(1)
                            Spacer()
                            Text("\(playingContent.textOffset) / \(playingContent.fullText.count)")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .layoutPriority(2)
                        }
                        ProgressView(
                            value: playingContent.textOffset.toDouble,
                            total: max(playingContent.fullText.count, playingContent.textOffset).toDouble
                        )
                        .progressViewStyle(.linear)
                    }
                }
                .padding()
                .contentBackground(verticalPadding: 0, horizontalPadding: 0, cornerRadius: 8)

                if showDismissButton && isDismissButtonOn {
                    dismissButton()
                }
            }
            .padding(.top)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func dismissButton() -> some View {
        HStack {
            Spacer()
            Button {
                dismissBar()
            } label: {
                DismissButtonLabel()
            }
            .padding(.trailing, 6)
        }
    }

    private var isMSTTSReady: Bool {
        ttsManager.playingContent?.engine == .ms &&
        ttsManager.playState == .preparing &&
        (ttsManager.playingContent?.wordLength ?? 0) == 0
    }

    private func play() {
        ttsManager.continueSpeech()
        withAnimation {
            isDismissButtonOn = false
        }
    }

    private func pause() {
        ttsManager.pauseSpeech()
        withAnimation {
            isDismissButtonOn = true
        }
    }

    private func stop() {
        ttsManager.stopSpeech()
        withAnimation {
            isDismissButtonOn = true
        }
    }

    @ViewBuilder
    private func controlButton() -> some View {
        if ttsManager.playingContent?.engine == .system {
            HStack(spacing: 15) {
                if ttsManager.playState == .paused {
                    PlainButton(action: play, label: { playButton() })
                    PlainButton(action: stop, label: { stopButton() })
                } else if ttsManager.playState == .playing {
                    PlainButton(action: pause, label: { pauseButton() })
                    PlainButton(action: stop, label: { stopButton() })
                } else {
                    PlainButton(action: play, label: { playButton() })
                }
            }
        } else {
            switch ttsManager.playState {
            case .preparing:
                PlainButton(action: stop, label: { loadingButton() })
                    .disabled(true)
            case .playing:
                PlainButton(action: stop, label: { stopButton() })
            case .idle, .paused:
                PlainButton(action: play, label: { playButton() })
                    .disabled(!isMSTTSReady)
            }
        }
    }

    @ViewBuilder
    var buttonCircle: some View {
        if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
            Circle()
                .foregroundStyle(.secondary.opacity(0.01))
                .glassEffect(.clear.interactive())
                .frame(width: 36, height: 36)
                .shadow(radius: 1)
        }else {
            Circle()
                .stroke(lineWidth: 2)
                .frame(width: 36)
                .foregroundStyle(.secondary.opacity(0.6))
        }
    }

    private func loadingButton() -> some View {
        ZStack {
            buttonCircle
            ProgressView()
                .tint(.red)
        }
    }

    private func playButton() -> some View {
        ZStack {
            buttonCircle
            Image(systemName: "play.fill")
                .foregroundStyle(.blue)
        }
    }

    private func pauseButton() -> some View {
        ZStack {
            buttonCircle
            Image(systemName: "pause.fill")
                .foregroundStyle(.orange)
        }
    }

    private func stopButton() -> some View {
        ZStack {
            buttonCircle
            Image(systemName: "square.fill")
                .foregroundStyle(.red)
        }
    }
}

/// 抽取关闭按钮样式，分支处理 iOS 26+ 的玻璃效果。
private struct DismissButtonLabel: View {
    var body: some View {
        if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                Text("关闭")
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .font(.caption)
            .glassEffect(.regular, in: .capsule)
        } else {
            HStack(spacing: 4) {
                Image(systemName: "xmark")
                Text("关闭")
            }
            #if os(iOS)
            .simpleTag(.border(verticalPad: 4, horizontalPad: 8, cornerRadius: 15, contentColor: .secondary))
            #endif
        }
    }
}

#Preview {
    @Previewable @State var tts = TTSManager()
    NavigationStack {
        VStack(spacing: 20) {
            SpeechLiveBar(ttsManager: tts, showDismissButton: true, hasShadow: true)

            Text("Hello world")
        }
    }
}
