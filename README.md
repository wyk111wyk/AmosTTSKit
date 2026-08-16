# AmosTTSKit
[![Supported Swift Version](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fargmaxinc%2FWhisperKit%2Fbadge%3Ftype%3Dswift-versions&labelColor=353a41&color=32d058)](https://www.amosstudio.com.cn/)
[![Supported Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fargmaxinc%2FWhisperKit%2Fbadge%3Ftype%3Dplatforms&labelColor=353a41&color=32d058)](https://www.amosstudio.com.cn/)
[![Swift Package Manager](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)](https://img.shields.io/badge/Swift_Package_Manager-compatible-orange?style=flat-square)

作者 Amos 网址 [AmosStudio](https://www.amosstudio.com.cn/)。
<img width="1030" height="211" alt="Logo-Black" src="https://github.com/user-attachments/assets/566ff915-d24e-4c37-9fb8-3a450e93d206" />

# 主要功能
这是一款基于 Swift 构建的语音合成（TTS）管理库，统一封装系统 `AVSpeechSynthesizer` 与微软 Azure 认知服务语音 SDK，提供简洁、可控的语音合成与播放能力。

> 核心依赖：AVFoundation、Microsoft Cognitive Services Speech；最低支持 **iOS 17 / macOS 14 / watchOS 10**。

1. 系统 / 微软双引擎统一调度，底层切换对业务无感
2. 多语音音色切换，支持中、英、日、韩、多语言
3. 播放控制：播放、暂停、停止、语速 / 音调 / 音量调节
4. 合成语音本地保存为 MP3（自动验证文件合法性、缓存复用）
5. 词级实时高亮（兼容 LF / CRLF 换行）

# 相关特性
- **三态播放状态机**：`idle` / `playing` / `paused` / `preparing`，回调安全收敛，避免重复 resume
- **线程安全**：所有可变状态由 `NSLock` 串行化或显式派发到主 actor；`@Observable` 字段统一在主 actor 上读写
- **SwiftUI 原生**：基于 `@Observable` 与 `@Bindable`，可直接绑定到视图
- **资源文件内置**：发音人 / 语气 / 角色数据通过 SwiftPM `Resources` 打包

# 使用语音合成库
## 初始化 TTS 管理器
```swift
import AmosTTSKit

@State var ttsManager = TTSManager(isDebuging: false)

// 监听播放状态
withObservationTracking {
    _ = ttsManager.playState
} onChange: {
    print("播放状态: \(ttsManager.playState)")
}
```

`TTSManager.playState` 是核心状态：
- `.idle` 空闲
- `.preparing` 微软 TTS 准备中
- `.playing` 正在播放
- `.paused` 已暂停（仅系统引擎支持真正暂停）

## 播放文本
```swift
func speak(_ text: String) {
    let content = TTSContent(speechText: text)
    do {
        try ttsManager.playContents(
            engine: .system,            // 或 .ms
            allContent: [content],
            showLive: true              // 是否弹出 SpeechLiveView
        )
    } catch {
        print("播放失败：\(error)")
    }
}
```

## 暂停 / 继续 / 停止
```swift
ttsManager.pauseSpeech()   // 系统引擎调用 AVSpeechSynthesizer.pause；微软引擎通过 stop 模拟
ttsManager.continueSpeech()// 恢复系统引擎；微软引擎重新播放
ttsManager.stopSpeech()    // 强制停止并清理高亮
```

## 保存为 MP3
```swift
func synthesizeToFile(_ text: String) async {
    do {
        let url = try await ttsManager.outputContents(
            for: [TTSContent(speechText: text)],
            saveName: "demo"
        )
        print("已保存：\(url?.path ?? "未生成")")
    } catch {
        print("保存失败：\(error)")
    }
}
```

- 文件落地到 `Documents/audioFile/<saveName>.mp3`
- 已存在且合法的 MP3（ID3 / MPEG 同步头 + ≥1KB）会直接返回缓存
- 命中但损坏的文件会被删除后重新合成

## 自定义播放配置
```swift
let config = TTSConfig(
    speaker: .xiaomo,
    style: TTSStyle(style: "gentle", title: "温柔", instruction: ""),
    rate: 30,      // -50 ~ 200 百分比偏移
    pitch: 0,      // -50 ~ 50  音调
    volume: 100    // 0 ~ 100    音量
)
```

`TTSConfig` 字段：
| 字段 | 范围 | 含义 |
| --- | --- | --- |
| `speaker` | — | 发音人（`TTSSpeaker.xiaoxiao` 等） |
| `role` | 可选 | 角色 |
| `style` | 可选 | 语气 |
| `styledegree` | 0.01 ~ 2 | 语气强度，注入 SSML |
| `rate` | -50 ~ 200 | 语速百分比偏移（系统引擎由 `wrappedRate` 二次映射） |
| `pitch` | -50 ~ 50 | 音调百分比偏移 |
| `volume` | 0 ~ 100 | 音量百分比 |

系统引擎下的 `rate` 会被 `wrappedRate` 映射到 `AVSpeechUtterance.rate` 的 0 ~ 1 区间。

## 切换默认发音人
```swift
ttsManager.saveDefaultConfig(
    TTSConfig(speaker: .xiaoxiao, style: .poemStyle)
)

let current = ttsManager.defaultConfig
print("当前默认发音人：\(current.speaker.speakerName)")
```

默认配置通过 `SimpleDefaults` 持久化（iCloud 同步），无需关心 `UserDefaults` key。

## 高级：自定义 TTSContent
```swift
let content = TTSContent(
    type: .text,
    speechText: "你好",
    useDefaultConfig: false,            // 使用本段独立 config
    config: .init(speaker: .xiaomo, rate: 50)
)
```

段落可以插入停顿：
```swift
let segments: [TTSContent] = [
    TTSContent(speechText: "第一段"),
    TTSContent.pause(.medium),          // 750 ms 停顿
    TTSContent(speechText: "第二段"),
]
```

## 监听播放进度（高亮）
```swift
@Bindable var ttsManager: TTSManager

SpeechLiveView(ttsManager: ttsManager)        // 完整高亮页
SpeechLiveBar(ttsManager: ttsManager)        // 底部播放条
```

内部通过 `HLContent.highlightedText()` 把 `textOffset / wordLength` 投射到原文，并兼容 LF / CRLF 换行（Microsoft 引擎会把换行折叠为 1 字符，已自动补偿）。

# 模型与枚举速查

## `TTSEngine`
- `.system` 系统 `AVSpeechSynthesizer`
- `.ms` 微软 Azure 认知服务

## `PlayState`
四态枚举：`idle` / `preparing` / `playing` / `paused`，比旧版 `Bool?` 更明确。

`TTSManager.isPlaying` 仍以 `Bool?` 兼容旧调用：
- `true` ⇒ `.playing`
- `nil` ⇒ `.preparing`
- `false` ⇒ `.idle` 或 `.paused`

## `BreakLevel`
| 值 | 名称 | 毫秒 |
| --- | --- | --- |
| `.x_weak` | 极弱停顿 | 250 |
| `.weak` | 弱停顿 | 500 |
| `.medium` | 中停顿 | 750 |
| `.strong` | 强停顿 | 1000 |
| `.x_strong` | 极强停顿 | 1250 |

通过 `BreakLevel.allCases` 或 `BreakLevel.allLevels()` 枚举全部档位。

## `RateLevel`
| 值 | 名称 | rate |
| --- | --- | --- |
| `.slow` | 慢速 | -25 |
| `.normal` | 正常 | 0 |
| `.fast` | 快速 | 30 |
| `.superFast` | 飞快 | 60 |

`RateLevel.from(rate:)` 根据数值反查档位；同时保留 `RateLevel.level(_:)` 别名以兼容旧代码。

# 单元测试
```bash
swift test
```
共 48 个测试，覆盖：
- `TTSConfig` Codable 往返、`wrappedRate` 边界
- `RateLevel` 分档、`BreakLevel` 毫秒与 `CaseIterable`
- `HLContent` 高亮文本与换行 / 空格计数（含 CRLF）
- `MP3FileValidator` 文件头校验
- `TTSContent.fullText` 拼接、`PlayState` 与 `isPlaying` 兼容
- `TTSSpeakerDic` 稳定 id、字典查找

# 兼容性说明
- 本次重写不改变既有公开 API 的函数签名；旧字段名（如 `TTSContent.defautConfig()`、`RateLevel.level(_:)`）以别名形式保留
- `SimpleDefaults` 是 `AmosBase` 提供的强类型键值库，本库已迁移默认配置存储
- 微软 TTS 引擎仍依赖 `MicrosoftCognitiveServicesSpeech.xcframework` 与 `SimpleAESCrypto`（密钥从 `DoubaoEngine` 共享的两个常量派生），相关密钥不在本计划范围内