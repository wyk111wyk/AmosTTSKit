import Testing
import Foundation
@testable import AmosTTSKit

@Suite("HLContent")
struct HLContentTests {

    @Test("countNewLines counts LF occurrences")
    func countNewLines_lf() {
        let text = "第一行\n第二行\n第三行"
        let content = HLContent(
            allContent: [TTSContent(speechText: text)],
            engine: .ms,
            isHighLightWord: true
        )
        #expect(content.countNewLines(before: 3, in: text) == 0)
        #expect(content.countNewLines(before: 4, in: text) == 1)
        #expect(content.countNewLines(before: 10, in: text) == 2)
    }

    @Test("countNewLines counts CRLF as 2 characters")
    func countNewLines_crlfCountsTwo() {
        let text = "first\r\nsecond\r\nthird"
        let content = HLContent(
            allContent: [TTSContent(speechText: text)],
            engine: .ms,
            isHighLightWord: true
        )
        #expect(content.countNewLines(before: 5, in: text) == 0)
        #expect(content.countNewLines(before: 7, in: text) == 2)
        #expect(content.countNewLines(before: 14, in: text) == 4)
    }

    @Test("countNewLines counts bare CR as 1 character")
    func countNewLines_crAlone() {
        let text = "a\rb\rc"
        let content = HLContent(
            allContent: [TTSContent(speechText: text)],
            engine: .ms,
            isHighLightWord: true
        )
        #expect(content.countNewLines(before: 2, in: text) == 1)
    }

    @Test("countSpaces counts ASCII spaces in prefix")
    func countSpaces() {
        let text = "hello world foo bar"
        let content = HLContent(
            allContent: [TTSContent(speechText: text)],
            engine: .ms,
            isHighLightWord: true
        )
        // "[0..5)" = "hello" → 0
        #expect(content.countSpaces(before: 5, in: text) == 0)
        // "[0..6)" = "hello " → 1
        #expect(content.countSpaces(before: 6, in: text) == 1)
        // "[0..12)" = "hello world " → 2
        #expect(content.countSpaces(before: 12, in: text) == 2)
        // "[0..16)" = "hello world foo " → 3
        #expect(content.countSpaces(before: 16, in: text) == 3)
    }

    @Test("countNewLines returns 0 for out-of-range offsets")
    func countNewLines_outOfRangeReturnsZero() {
        let content = HLContent(
            allContent: [TTSContent(speechText: "abc")],
            engine: .ms
        )
        #expect(content.countNewLines(before: -1, in: "abc") == 0)
        #expect(content.countNewLines(before: 99, in: "abc") == 0)
    }

    @Test("highlightedText (MS engine) compensates for skipped newlines")
    func highlightedText_isSkipReturnAdjustsOffset() {
        let text = "你好\n世界"
        let content = HLContent(
            allContent: [TTSContent(speechText: text)],
            engine: .ms,
            textOffset: 2,
            wordLength: 1,
            isHighLightWord: true
        )
        let attributed = content.highlightedText()
        let str = String(attributed.characters)
        #expect(str.contains("好"))
        #expect(str.contains("世界"))
    }

    @Test("highlightedText without highlight mode returns plain text")
    func highlightedText_notHighLightWord_returnsPlainString() {
        let content = HLContent(
            allContent: [TTSContent(speechText: "plain")],
            engine: .system,
            isHighLightWord: false
        )
        let attributed = content.highlightedText()
        #expect(String(attributed.characters) == "plain")
    }

    @Test("Codable roundtrip excludes isDebuging")
    func codable_roundtrip_excludesIsDebuging() throws {
        let content = HLContent(
            isDebuging: true,
            allContent: [TTSContent(speechText: "x")],
            engine: .system,
            isHighLightWord: true
        )
        let data = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(HLContent.self, from: data)
        let mirror = Mirror(reflecting: decoded)
        if let isDebug = mirror.children.first(where: { $0.label == "isDebuging" })?.value as? Bool {
            #expect(!isDebug, "isDebuging should not be persisted")
        }
    }

    @Test("CachedTableStore returns consistent results for the same text")
    func cache_store_returnsSameInstanceForSameText() {
        let store = CachedTableStore()
        let a = store.table(for: "abc")
        let b = store.table(for: "abc")
        #expect(a.countNewLines(before: 4) == b.countNewLines(before: 4))
    }

    @Test("CachedTableStore distinguishes between different texts")
    func cache_store_distinguishesTexts() {
        let store = CachedTableStore()
        let a = store.table(for: "abc\n")
        #expect(a.countNewLines(before: 4) == 1)
        let b = store.table(for: "abc")
        #expect(b.countNewLines(before: 4) == 0)
    }
}