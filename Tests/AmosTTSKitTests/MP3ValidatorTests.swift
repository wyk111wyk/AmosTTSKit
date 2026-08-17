import Testing
import Foundation
@testable import AmosTTSKit

@Suite("MP3FileValidator")
struct MP3ValidatorTests {

    @Test("ID3 header is accepted")
    func validData_id3Header() {
        var data = Data([0x49, 0x44, 0x33])
        data.append(Data(repeating: 0x00, count: 2000))
        #expect(MP3FileValidator.isValidData(data))
    }

    @Test("MPEG frame sync 0xFFFB is accepted")
    func validData_mpegFrameSync() {
        var data = Data([0xFF, 0xFB])
        data.append(Data(repeating: 0xAA, count: 2000))
        #expect(MP3FileValidator.isValidData(data))
    }

    @Test("MPEG frame sync 0xFFF3 is accepted")
    func validData_alternateMpegSync() {
        var data = Data([0xFF, 0xF3])
        data.append(Data(repeating: 0xAA, count: 2000))
        #expect(MP3FileValidator.isValidData(data))
    }

    @Test("Too-short data is rejected")
    func invalidData_tooShort() {
        #expect(!MP3FileValidator.isValidData(Data([0xFF, 0xFB])))
        #expect(!MP3FileValidator.isValidData(Data()))
    }

    @Test("Random header bytes are rejected")
    func invalidData_wrongHeader() {
        var data = Data([0x00, 0x01])
        data.append(Data(repeating: 0xAA, count: 2000))
        #expect(!MP3FileValidator.isValidData(data))
    }

    @Test("Random byte below size threshold is rejected")
    func invalidData_randomByteBelowThreshold() {
        var data = Data([0xAA, 0xBB])
        data.append(Data(repeating: 0xCC, count: 500))
        #expect(!MP3FileValidator.isValidData(data))
    }
}