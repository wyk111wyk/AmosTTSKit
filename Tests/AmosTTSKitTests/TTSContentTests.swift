import Testing
import Foundation
@testable import AmosTTSKit

@Suite("TTSContent")
struct TTSContentTests {

    @Test("Array fullText joins segments with newlines")
    func array_fullText_joinsWithNewlines() {
        let contents: [TTSContent] = [
            TTSContent(speechText: "你好"),
            TTSContent(speechText: "世界"),
        ]
        #expect(contents.fullText == "你好\n世界")
    }

    @Test("Array fullText for a single content")
    func array_fullText_singleContent() {
        let contents = [TTSContent(speechText: "单段")]
        #expect(contents.fullText == "单段")
    }

    @Test("Array fullText for empty array")
    func array_fullText_empty() {
        #expect([TTSContent]().fullText == "")
    }

    @Test("pause factory builds a pause content")
    func pauseFactory_buildsPauseContent() {
        let content = TTSContent.pause(.medium)
        #expect(content.speechText == "")
        if case let .pause(level) = content.type {
            #expect(level == .medium)
        } else {
            Issue.record("Expected .pause type, got \(content.type)")
        }
    }

    @Test("clearStyle resets style to noneStyle")
    func clearStyle_resetsToNone() {
        var content = TTSContent(speechText: "test")
        content.config.style = TTSStyle(style: "x", title: "X", instruction: "")
        content.clearStyle()
        #expect(content.config.style == .noneStyle)
    }

    @Test("clearRole resets role to noneRole")
    func clearRole_resetsToNone() {
        var content = TTSContent(speechText: "test")
        content.config.role = TTSRole(role: "x", title: "X", instruction: "")
        content.clearRole()
        #expect(content.config.role == .noneRole)
    }

    @Test("Codable roundtrip preserves payload")
    func codable_roundtrip() throws {
        let original = TTSContent(speechText: "x", useDefaultConfig: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TTSContent.self, from: data)
        #expect(decoded.speechText == "x")
        #expect(decoded.useDefaultConfig == false)
    }
}