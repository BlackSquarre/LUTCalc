import Foundation
import XCTest
import LUTCore
import LUTFormats

final class OLUTContractsTests: XCTestCase {
    func testParserUsesSixCommaSeparatedCodesAndFixedLength() throws {
        var text = String()
        for index in 0..<4_096 {
            let red = index
            let green = 4_095 - index
            let blue = 2_048
            text += "\(red),\(green),\(blue),\(red),\(green),\(blue)\n"
        }
        let lut = try OLUTParser.parse(Data(text.utf8))
        XCTAssertEqual(lut.dimension, .one)
        XCTAssertEqual(lut.size, 4_096)
        XCTAssertEqual(lut.domain, .unit)
        XCTAssertEqual(lut.samples[0], try RGB64(0, 1, 2_048.0 / 4_095))
        XCTAssertEqual(lut.samples[4_095], try RGB64(1, 0, 2_048.0 / 4_095))
    }

    func testWriterQuantizesHalfUpAndRoundTrips() throws {
        var samples: [RGB64] = []
        samples.reserveCapacity(4_096)
        for index in 0..<4_096 {
            let red = index == 0 ? 0.5 / 4_095.0 : Double(index) / 4_095.0
            let green = Double(4_095 - index) / 4_095.0
            samples.append(try RGB64(red, green, 0))
        }
        let lut = try CubeLUT(dimension: .one, size: 4_096, domain: .unit, samples: samples)
        let text = try OLUTWriter.serialize(lut)
        XCTAssertEqual(text.split(separator: "\n").count, 4_096)
        XCTAssertTrue(text.hasPrefix("1,4095,0,1,4095,0\n"))
        let reread = try OLUTParser.parse(Data(text.utf8))
        XCTAssertEqual(reread.samples[0], try RGB64(1.0 / 4_095, 1, 0))
        XCTAssertEqual(reread.samples[4_095], samples[4_095])
    }

    func testRejectsMalformedCodesAndRowCounts() throws {
        let cases: [(String, OLUTFailureCategory)] = [
            ("0,0,0,0,0,0\n", .rowCountMismatch),
            ("0,0,0,0,0\n", .invalidNumber),
            ("0,0,0,0,0,1\n", .unsupported),
            ("0,0,4096,0,0,4096\n", .invalidCodeValue),
            ("0,0,NaN,0,0,NaN\n", .nonFiniteValue),
            ("0,0,1.5,0,0,1.5\n", .invalidNumber),
        ]
        for (text, category) in cases {
            XCTAssertThrowsError(try OLUTParser.parse(Data(text.utf8)), text) {
                XCTAssertEqual(($0 as? OLUTFailure)?.category, category)
            }
        }
    }

    func testWriterRejectsUnrepresentableCubeAndDuplicateMismatch() throws {
        var samples: [RGB64] = []
        samples.reserveCapacity(4_096)
        for index in 0..<4_096 {
            samples.append(try RGB64(index == 0 ? -0.1 : 0, 0, 0))
        }
        let lut = try CubeLUT(dimension: .one, size: 4_096, domain: .unit, samples: samples)
        XCTAssertThrowsError(try OLUTWriter.serialize(lut)) {
            XCTAssertEqual(($0 as? OLUTFailure)?.category, .lossyRepresentation)
        }
        let domain = try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(1, 1, 1))
        let nonUnit = try CubeLUT(dimension: .one, size: 4_096, domain: domain, samples: samples)
        XCTAssertThrowsError(try OLUTWriter.serialize(nonUnit)) {
            XCTAssertEqual(($0 as? OLUTFailure)?.category, .lossyRepresentation)
        }
        let mismatch = "0,0,0,0,0,1\n"
        XCTAssertThrowsError(try OLUTParser.parse(Data(mismatch.utf8))) {
            XCTAssertEqual(($0 as? OLUTFailure)?.category, .unsupported)
        }
    }
}
