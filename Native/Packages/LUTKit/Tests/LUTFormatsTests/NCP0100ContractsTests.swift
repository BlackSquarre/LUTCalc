import Foundation
import XCTest
import LUTFormats

final class NCP0100ContractsTests: XCTestCase {
    private func sample() -> Data {
        var bytes = [UInt8](repeating: 0, count: 638)
        bytes.replaceSubrange(0..<4, with: [0x4e, 0x43, 0x50, 0])
        bytes[7] = 1
        bytes[11] = 36
        bytes.replaceSubrange(12..<16, with: Array("0100".utf8))
        bytes.replaceSubrange(16..<20, with: Array("Test".utf8))
        bytes[36] = 0x03
        bytes[37] = 0xc2
        bytes[38] = 0x02
        bytes[39] = 0xff
        bytes[51] = 2
        bytes[54] = 0x02
        bytes[55] = 0x42
        bytes[56] = 0x49
        bytes[57] = 0x30
        bytes[59] = 0xff
        bytes[63] = 0
        bytes[64] = 2
        bytes[65] = 0
        bytes[66] = 0
        bytes[67] = 255
        bytes[68] = 255
        bytes[122] = 0x7f
        bytes[123] = 0xff
        bytes[632] = 0x40
        bytes[633] = 0x00
        return Data(bytes)
    }

    func testReadsFixed0100RecordsWithoutAssumingMonotonicCurve() throws {
        let control = try NCP0100Reader.read(sample())
        XCTAssertEqual(control.name, "Test")
        XCTAssertEqual(control.profileCode, 0x03c2)
        XCTAssertEqual(control.rawAdjustments.count, 8)
        XCTAssertEqual(control.controlPoints.count, 2)
        XCTAssertEqual(control.controlPoints[1].x, 255)
        XCTAssertEqual(control.lutCodes.count, 256)
        XCTAssertEqual(control.lutCodes[0], 32767)
        XCTAssertEqual(control.lutCodes[255], 16384)
        XCTAssertEqual(control.lutValues[255], Double(16384) / 32767)
    }

    func testRejectsUnsupportedAndMalformedLayouts() throws {
        let cases: [(Int, UInt8, NCP0100FailureCategory)] = [
            (0, 0, .invalidSignature),
            (7, 2, .unsupportedLayout),
            (11, 35, .unsupportedLayout),
            (15, 0, .unsupportedLayout),
            (36, 0xff, .unsupportedProfile),
            (51, 3, .unsupportedLayout),
            (55, 0x41, .unsupportedLayout),
            (64, 29, .invalidControlPoints),
            (67, 0, .invalidControlPoints),
            (122, 0x80, .invalidLUTCode),
            (637, 1, .unsupportedLayout),
        ]
        for (offset, replacement, expected) in cases {
            var bytes = sample()
            bytes[offset] = replacement
            XCTAssertThrowsError(try NCP0100Reader.read(bytes), "offset \(offset)") {
                XCTAssertEqual(($0 as? NCP0100Failure)?.category, expected)
            }
        }
        XCTAssertThrowsError(try NCP0100Reader.read(sample().dropLast())) {
            XCTAssertEqual(($0 as? NCP0100Failure)?.category, .invalidLength)
        }
    }

    func testPublicSpecimenWhenProvided() throws {
        guard let path = ProcessInfo.processInfo.environment["LUTCALC_NCP0100_SPECIMEN"] else {
            throw XCTSkip("Set LUTCALC_NCP0100_SPECIMEN to a public NCP specimen")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let control = try NCP0100Reader.read(data)
        XCTAssertEqual(data.count, 638)
        XCTAssertEqual(control.name, "HS Linear v01")
        XCTAssertEqual(control.profileCode, 0x03c2)
        XCTAssertEqual(control.controlPoints.count, 2)
        XCTAssertEqual(control.lutCodes[0], 162)
        XCTAssertEqual(control.lutCodes[127], 11812)
        XCTAssertEqual(control.lutCodes[255], 32767)
    }

    func testWriterRejectsWithoutChangingTarget() throws {
        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-ncp-write-(UUID().uuidString).ncp")
        let original = Data("existing target".utf8)
        try original.write(to: target)
        defer { try? FileManager.default.removeItem(at: target) }

        let control = try NCP0100Reader.read(sample())
        do {
            try NCP0100Writer.write(control, to: target)
            XCTFail("NCP 0100 writing must remain unavailable without vendor evidence")
        } catch let error as NCP0100Failure {
            XCTAssertEqual(error.category, .writeUnsupported)
        }
        XCTAssertEqual(try Data(contentsOf: target), original)
    }
}
