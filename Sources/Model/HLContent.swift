//
//  HLContent.swift
//  AmosTTSKit
//
//  Created by AmosFitness on 2024/4/8.
//

import Foundation
import SwiftUI

public struct HLContent {
    @ObservationIgnored
    let isDebuging: Bool

    public let fullText: String
    public let allContent: [TTSContent]
    public let engine: TTSEngine

    public var textOffset: Int
    public var wordLength: Int
    public var playWord: String

    /// 是否跳过回车（微软 TTS 需要跳过，因为 SDK 在 SSML 中会规范化换行）
    public let isSkipReturn: Bool

    public let fontSize: CGFloat
    public let rowSpace: CGFloat

    public let isHighLightWord: Bool

    /// 缓存：换行/空格偏移表，仅在 `fullText` 变化时重建，避免 `highlightedText` O(n²) 重算。
    /// 使用串行锁保护，跨线程安全。
    @ObservationIgnored
    private static let crlfCache = CachedTableStore()

    public init(
        isDebuging: Bool = false,
        allContent: [TTSContent],
        engine: TTSEngine,
        textOffset: Int = 0,
        wordLength: Int = 0,
        playWord: String = .init(),
        fontSize: CGFloat = 18,
        rowSpace: CGFloat = 8,
        isHighLightWord: Bool = false
    ) {
        self.isDebuging = isDebuging
        self.fullText = allContent.fullText
        self.allContent = allContent
        self.engine = engine
        self.textOffset = textOffset
        self.wordLength = wordLength
        self.playWord = playWord
        self.isSkipReturn = engine == .ms
        self.fontSize = fontSize
        self.rowSpace = rowSpace
        self.isHighLightWord = isHighLightWord
    }

    public func highlightedText(
        options: String.CompareOptions = []
    ) -> AttributedString {
        if isHighLightWord {
            var offSet = textOffset
            if isSkipReturn {
                let table = Self.crlfTable(for: fullText)
                let nlCount = table.countNewLines(before: offSet)
                if nlCount > 0 { offSet += nlCount }
                let spCount = table.countSpaces(before: offSet)
                if spCount > 0 { offSet += spCount }
            }
            let totalCount = fullText.count
            let safeStart = min(offSet, totalCount)
            let start = fullText.index(fullText.startIndex, offsetBy: safeStart, limitedBy: fullText.endIndex) ?? fullText.endIndex
            let end = fullText.index(start, offsetBy: min(wordLength, totalCount - safeStart), limitedBy: fullText.endIndex) ?? fullText.endIndex

            let beforeText = String(fullText[..<start])
            let selectedText = String(fullText[start..<end])
            let afterText = String(fullText[end...])

            var before = AttributedString(beforeText)
            var selected = AttributedString(selectedText)
            var after = AttributedString(afterText)

            if isDebuging && (textOffset > 0 || wordLength > 0) {
                debugPrint("- 高亮播放进度 -")
                debugPrint("Total Text Count: \(fullText.count)")
                debugPrint("Offset: \(offSet)")
                debugPrint("Length: \(wordLength)")
                debugPrint("Select Word: \(selected)")
                debugPrint("Play Word: \(playWord)")
            }

            Self.applyStyle(before: &before, selected: &selected, after: &after, fontSize: fontSize)

            var attributedString = before + selected + after
#if os(iOS)
            attributedString.uiKit.foregroundColor = .label
#elseif os(macOS)
            attributedString.appKit.foregroundColor = .labelColor
#endif
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = rowSpace
            attributedString.paragraphStyle = paragraphStyle
            return attributedString
        } else {
            var fullString = AttributedString(fullText)
            Self.applyPlainStyle(to: &fullString, fontSize: fontSize)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = rowSpace
            fullString.paragraphStyle = paragraphStyle
            return fullString
        }
    }

    /// 统计字符串 `[0, before)` 区间内的换行数量（兼容 CRLF / LF）。
    public func countNewLines(before textOffset: Int, in fullText: String) -> Int {
        Self.crlfTable(for: fullText).countNewLines(before: textOffset)
    }

    /// 统计字符串 `[0, before)` 区间内的 ASCII 空格数量。
    public func countSpaces(before textOffset: Int, in fullText: String) -> Int {
        Self.crlfTable(for: fullText).countSpaces(before: textOffset)
    }

    // MARK: - Helpers

    private static func crlfTable(for text: String) -> CRLineBreakTable {
        crlfCache.table(for: text)
    }

    private static func applyStyle(
        before: inout AttributedString,
        selected: inout AttributedString,
        after: inout AttributedString,
        fontSize: CGFloat
    ) {
#if os(iOS)
        before.uiKit.font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        selected.uiKit.backgroundColor = UIColor(Color.blue.opacity(0.3))
        selected.uiKit.font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
        after.uiKit.font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
#elseif os(macOS)
        before.appKit.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        selected.appKit.backgroundColor = NSColor(Color.blue.opacity(0.3))
        selected.appKit.font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        after.appKit.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
#endif
    }

    private static func applyPlainStyle(to string: inout AttributedString, fontSize: CGFloat) {
#if os(iOS)
        string.uiKit.font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        string.uiKit.foregroundColor = .label
#elseif os(macOS)
        string.appKit.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        string.appKit.foregroundColor = .labelColor
#endif
    }
}

/// 字符串中的换行/空格前缀和表。
struct CRLineBreakTable {
    private let newLinesBefore: [Int]
    private let spacesBefore: [Int]

    init(text: String) {
        let scalars = Array(text.unicodeScalars)
        var newLines: [Int] = []
        var spaces: [Int] = []
        newLines.reserveCapacity(scalars.count + 1)
        spaces.reserveCapacity(scalars.count + 1)
        newLines.append(0)
        spaces.append(0)
        var nl = 0
        var sp = 0
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "\n" {
                nl += 1
            } else if scalar == "\r" {
                if index + 1 < scalars.count, scalars[index + 1] == "\n" {
                    nl += 2
                    index += 1
                } else {
                    nl += 1
                }
            } else if scalar == " " {
                sp += 1
            }
            newLines.append(nl)
            spaces.append(sp)
            index += 1
        }
        self.newLinesBefore = newLines
        self.spacesBefore = spaces
    }

    /// 字符串 `[0, before)` 区间内的换行数量。LF 算 1，CRLF 算 2，CR 单独算 1。
    func countNewLines(before: Int) -> Int {
        guard before >= 0, before < newLinesBefore.count else { return 0 }
        return newLinesBefore[before]
    }

    /// 字符串 `[0, before)` 区间内的 ASCII 空格数量。
    func countSpaces(before: Int) -> Int {
        guard before >= 0, before < spacesBefore.count else { return 0 }
        return spacesBefore[before]
    }
}

extension HLContent: Codable {
    public enum CodingKeys: String, CodingKey {
        case fullText
        case allContent
        case engine
        case textOffset
        case wordLength
        case playWord
        case isSkipReturn
        case fontSize
        case rowSpace
        case isHighLightWord
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fullText = try container.decode(String.self, forKey: .fullText)
        allContent = try container.decode([TTSContent].self, forKey: .allContent)
        engine = try container.decode(TTSEngine.self, forKey: .engine)
        textOffset = try container.decode(Int.self, forKey: .textOffset)
        wordLength = try container.decode(Int.self, forKey: .wordLength)
        playWord = try container.decode(String.self, forKey: .playWord)
        isSkipReturn = try container.decode(Bool.self, forKey: .isSkipReturn)
        fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        rowSpace = try container.decode(CGFloat.self, forKey: .rowSpace)
        isHighLightWord = try container.decode(Bool.self, forKey: .isHighLightWord)

        // 调试态是运行时状态，不参与持久化
        isDebuging = false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fullText, forKey: .fullText)
        try container.encode(allContent, forKey: .allContent)
        try container.encode(engine, forKey: .engine)
        try container.encode(textOffset, forKey: .textOffset)
        try container.encode(wordLength, forKey: .wordLength)
        try container.encode(playWord, forKey: .playWord)
        try container.encode(isSkipReturn, forKey: .isSkipReturn)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(rowSpace, forKey: .rowSpace)
        try container.encode(isHighLightWord, forKey: .isHighLightWord)
    }
}

/// 字符串 → 换行/空格前缀和表的线程安全缓存。
final class CachedTableStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: CRLineBreakTable] = [:]

    func table(for text: String) -> CRLineBreakTable {
        lock.lock()
        if let cached = storage[text] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let table = CRLineBreakTable(text: text)
        lock.lock()
        storage[text] = table
        lock.unlock()
        return table
    }
}
