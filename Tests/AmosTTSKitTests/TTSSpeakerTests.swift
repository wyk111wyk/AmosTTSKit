import Testing
import Foundation
@testable import AmosTTSKit

@Suite("TTSSpeaker")
struct TTSSpeakerTests {

    @Test("TTSSpeakerDic id is stable across accesses")
    func speakerDic_idIsStable() {
        let langs = TTSSpeakerDic.allLanguages
        #expect(!langs.isEmpty)
        let firstId = langs[0].id
        #expect(firstId == langs[0].id)
    }

    @Test("onlyMSLanguages excludes the system language bucket")
    func onlyMSLanguages_excludesSystem() {
        for dic in TTSSpeakerDic.onlyMSLanguages {
            #expect(dic.language != .system)
        }
    }

    @Test("speaker lookup by audioName")
    func speaker_lookup_byAudioName() {
        #expect(TTSSpeaker.speaker(from: "zh-CN-XiaoxiaoNeural") != nil)
        #expect(TTSSpeaker.speaker(from: "non-existent") == nil)
    }

    @Test("allStyles split by '&' separator")
    func speaker_allStyles_splitByAmpersand() {
        let speaker = TTSSpeaker.xiaomo
        #expect(speaker.allStyles.contains("calm"))
    }
}