import Foundation
import XCTest
import LUTCore
import LUTFormats

final class ILUTContractsTests: XCTestCase {
    func testParserUsesFourCommaSeparatedCodesAndFixedLength() throws {
        var text = String()
        for index in 0..<16_384 {
            text += "\(index),\(16_383 - index),8192,0\n"
        }
        let lut = try ILUTParser.parse(Data(text.utf8))
        XCTAssertEqual(lut.dimension, .one)
        XCTAssertEqual(lut.size, 16_384)
        XCTAssertEqual(lut.domain, .unit)
        XCTAssertEqual(lut.samples[0], try RGB64(0, 1, 8192.0 / 16_383))
        XCTAssertEqual(lut.samples[16_383], try RGB64(1, 0, 8192.0 / 16_383))
    }

    func testWriterQuantizesHalfUpAndRoundTrips() throws {
        var samples: [RGB64] = []
        samples.reserveCapacity(16_384)
        for index in 0..<16_384 {
            let red = index == 0 ? 0.5 / 16_383.0 : Double(index) / 16_383.0
            let green = Double(16_383 - index) / 16_383.0
            samples.append(try RGB64(red, green, 0))
        }
        let lut = try CubeLUT(dimension: .one, size: 16_384, domain: .unit, samples: samples)
        let text = try ILUTWriter.serialize(lut)
        XCTAssertEqual(text.split(separator: "\n").count, 16_384)
        XCTAssertTrue(text.hasPrefix("1,16383,0,0\n"))
        let reread = try ILUTParser.parse(Data(text.utf8))
        XCTAssertEqual(reread.samples[0], try RGB64(1.0 / 16_383, 1, 0))
        XCTAssertEqual(reread.samples[16_383], samples[16_383])
    }

    func testWriterMatchesIndependentHalfUpIntegerReference() throws {
        let codes = [0, 1, 2, 8_191, 8_192, 16_382, 16_383]
        var samples: [RGB64] = []
        samples.reserveCapacity(ILUTParser.size)
        for index in 0..<ILUTParser.size {
            let code = codes[index % codes.count]
            let value = Double(code) / Double(ILUTParser.codeMax)
            samples.append(try RGB64(value, value, value))
        }
        let lut = try CubeLUT(dimension: .one, size: ILUTParser.size, domain: .unit, samples: samples)
        let rows = try ILUTWriter.serialize(lut).split(separator: "\n")
        for (index, row) in rows.enumerated() {
            let expected = codes[index % codes.count]
            XCTAssertEqual(String(row), "\(expected),\(expected),\(expected),0", "row \(index)")
        }
    }

    func testParserAcceptsCRLFWithoutChangingIntegerReference() throws {
        let first = "0,16383,8192,0\r\n"
        let last = "16383,0,0,0\r\n"
        var text = String()
        text.reserveCapacity(16_384 * 18)
        text += first
        for _ in 1..<16_383 { text += "8192,8192,8192,0\r\n" }
        text += last
        let lut = try ILUTParser.parse(Data(text.utf8))
        XCTAssertEqual(lut.samples.first, try RGB64(0, 1, 8192.0 / 16_383))
        XCTAssertEqual(lut.samples.last, try RGB64(1, 0, 0))
    }

    func testRejectsMalformedCodesAndRowCounts() throws {
        let cases: [(String, ILUTFailureCategory)] = [
            ("0,0,0,0\n", .rowCountMismatch),
            ("0,0,0\n", .invalidNumber),
            ("0,0,0,1\n", .unsupported),
            ("0,0,16384,0\n", .invalidCodeValue),
            ("0,0,NaN,0\n", .nonFiniteValue),
            ("0,0,1.5,0\n", .invalidNumber),
        ]
        for (text, category) in cases {
            XCTAssertThrowsError(try ILUTParser.parse(Data(text.utf8)), text) {
                XCTAssertEqual(($0 as? ILUTFailure)?.category, category)
            }
        }
    }

    func testWriterRejectsUnrepresentableCube() throws {
        var samples: [RGB64] = []
        samples.reserveCapacity(16_384)
        for index in 0..<16_384 {
            samples.append(try RGB64(index == 0 ? -0.1 : 0, 0, 0))
        }
        let lut = try CubeLUT(dimension: .one, size: 16_384, domain: .unit, samples: samples)
        XCTAssertThrowsError(try ILUTWriter.serialize(lut)) {
            XCTAssertEqual(($0 as? ILUTFailure)?.category, .lossyRepresentation)
        }
        let domain = try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(1, 1, 1))
        let nonUnit = try CubeLUT(dimension: .one, size: 16_384, domain: domain, samples: samples)
        XCTAssertThrowsError(try ILUTWriter.serialize(nonUnit)) {
            XCTAssertEqual(($0 as? ILUTFailure)?.category, .lossyRepresentation)
        }
    }
}
