import Testing
import Foundation
@testable import AmosTTSKit

@Suite("TTSConfig")
struct TTSConfigTests {

    private let epsilon = 0.0001

    private func near(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < epsilon
    }

    @Test("Codable roundtrip preserves fields")
    func codable_roundtrip_preservesFields() throws {
        let original = TTSConfig(
            speaker: .xiaoxiao,
            role: nil,
            style: .poemStyle,
            styledegree: 1.5,
            rate: 30,
            pitch: -10,
            volume: 80
        )
        let data = try #require(original.toData())
        let decoded = try #require(data.decode(type: TTSConfig.self))
        #expect(decoded.speaker == original.speaker)
        #expect(decoded.style == original.style)
        #expect(decoded.rate == original.rate)
        #expect(decoded.pitch == original.pitch)
        #expect(decoded.volume == original.volume)
        #expect(decoded.styledegree == original.styledegree)
    }

    @Test("Equatable ignores id")
    func equatable_ignoresId() {
        let a = TTSConfig(speaker: .xiaomo, rate: 10, pitch: 0, volume: 100)
        let b = TTSConfig(id: UUID(), speaker: .xiaomo, rate: 10, pitch: 0, volume: 100)
        #expect(a == b)
    }

    @Test("wrappedRate (system) maps positive rate into (0.55, 1.0]")
    func wrappedRate_systemEngine_positive() {
        let cfg = TTSConfig(speaker: .systemTTSEngine, rate: 100)
        let expected = 1 - (200 - 100) / 200 * 0.45
        #expect(near(cfg.wrappedRate, expected))
    }

    @Test("wrappedRate (system) maps negative rate into [0, 0.55]")
    func wrappedRate_systemEngine_negative() {
        let cfg = TTSConfig(speaker: .systemTTSEngine, rate: -50)
        #expect(near(cfg.wrappedRate, 0.0))
    }

    @Test("wrappedRate (system) rate == 0 maps to 0.55")
    func wrappedRate_systemEngine_zero() {
        let cfg = TTSConfig(speaker: .systemTTSEngine, rate: 0)
        #expect(near(cfg.wrappedRate, 0.55))
    }

    @Test("wrappedRate passes through for MS speaker")
    func wrappedRate_ms_passthrough() {
        let cfg = TTSConfig(speaker: .xiaomo, rate: 33)
        #expect(cfg.wrappedRate == 33)
    }

    @Test("wrappedRate clamps out-of-range input")
    func wrappedRate_systemEngine_clampsOutOfRange() {
        let cfgHigh = TTSConfig(speaker: .systemTTSEngine, rate: 999)
        #expect(near(cfgHigh.wrappedRate, 1.0))
        let cfgLow = TTSConfig(speaker: .systemTTSEngine, rate: -999)
        #expect(near(cfgLow.wrappedRate, 0.0))
    }

    @Test("Init from unknown speaking voice falls back to system TTS")
    func initFromSpeakingVoice_unknownFallsBackToSystem() {
        let cfg = TTSConfig(speakingVoice: "non-existent-voice")
        #expect(cfg.speaker == .systemTTSEngine)
    }
}