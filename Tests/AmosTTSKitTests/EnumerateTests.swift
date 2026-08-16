import Testing
import Foundation
@testable import AmosTTSKit

@Suite("Enumerate")
struct EnumerateTests {

    @Test("RateLevel classifies by range")
    func rateLevel_from_classifiesCorrectly() {
        #expect(RateLevel.from(rate: -1) == .slow)
        #expect(RateLevel.from(rate: -25) == .slow)
        #expect(RateLevel.from(rate: 0) == .normal)
        #expect(RateLevel.from(rate: 9) == .normal)
        #expect(RateLevel.from(rate: 10) == .fast)
        #expect(RateLevel.from(rate: 39) == .fast)
        #expect(RateLevel.from(rate: 40) == .superFast)
        #expect(RateLevel.from(rate: 999) == .superFast)
    }

    @Test("RateLevel legacy alias classifies identically")
    func rateLevel_legacy_alias_classify() {
        #expect(RateLevel.level(15) == .fast)
        #expect(RateLevel.from(rate: 15) == RateLevel.level(15))
    }

    @Test("RateLevel canonical rate values")
    func rateLevel_values() {
        #expect(RateLevel.slow.rate == -25)
        #expect(RateLevel.normal.rate == 0)
        #expect(RateLevel.fast.rate == 30)
        #expect(RateLevel.superFast.rate == 60)
    }

    @Test("BreakLevel pause durations in ms")
    func breakLevel_pauseMillis() {
        #expect(BreakLevel.x_weak.pause() == 250)
        #expect(BreakLevel.weak.pause() == 500)
        #expect(BreakLevel.medium.pause() == 750)
        #expect(BreakLevel.strong.pause() == 1000)
        #expect(BreakLevel.x_strong.pause() == 1250)
    }

    @Test("BreakLevel CaseIterable order")
    func breakLevel_caseIterableOrder() {
        #expect(BreakLevel.allCases == [.x_weak, .weak, .medium, .strong, .x_strong])
    }

    @Test("BreakLevel legacy allLevels equals allCases")
    func breakLevel_legacyAllLevels() {
        #expect(BreakLevel.allLevels() == BreakLevel.allCases)
    }

    @Test("BreakLevel displayName / legacy name()")
    func breakLevel_displayName() {
        #expect(BreakLevel.medium.displayName == "中停顿")
        #expect(BreakLevel.x_weak.name() == "极弱停顿")
    }

    @Test("TTSEngine title")
    func ttsEngine_title() {
        #expect(TTSEngine.system.title == "系统TTS")
        #expect(TTSEngine.ms.title == "微软TTS")
    }

    @Test("TTSLanguage → engine mapping")
    func ttsLanguage_engineMapping() {
        #expect(TTSLanguage.system.engine == .system)
        #expect(TTSLanguage.cn.engine == .ms)
        #expect(TTSLanguage.en.engine == .ms)
        #expect(TTSLanguage.multi.engine == .ms)
    }

    @Test("PlayStatus.isPlaying reflects terminal vs ongoing state")
    func playStatus_isPlaying() {
        #expect(PlayStatus.start.isPlaying)
        #expect(PlayStatus.pause.isPlaying)
        #expect(PlayStatus.play(reading: Reading(word: "x", offset: 0, length: 1)).isPlaying)
        #expect(!PlayStatus.stop.isPlaying)
        #expect(!PlayStatus.error(error: NSError(domain: "t", code: 1)).isPlaying)
    }

    @Test("PlayState.isPlayingBool legacy bridge")
    func playState_isPlayingBoolBridge() {
        #expect(PlayState.preparing.isPlayingBool == nil)
        #expect(PlayState.playing.isPlayingBool == true)
        #expect(PlayState.idle.isPlayingBool == false)
        #expect(PlayState.paused.isPlayingBool == false)
    }
}