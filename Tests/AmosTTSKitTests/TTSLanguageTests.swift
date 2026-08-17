import Testing
import Foundation
@testable import AmosTTSKit

@Suite("TTSLanguage")
struct TTSLanguageTests {

    @Test("testSpeech returns non-empty string for every language")
    func testSpeech_returnsNonEmptyForAllLanguages() {
        for lang in [TTSLanguage.system, .cn, .jp, .en, .ko, .multi] {
            #expect(!lang.testSpeech("Tester").isEmpty, "Language \(lang) should produce test speech")
        }
    }

    @Test("testSpeech substitutes the speaker name")
    func testSpeech_substitutesName() {
        let s = TTSLanguage.en.testSpeech("Alice")
        #expect(s.contains("Alice"))
    }
}