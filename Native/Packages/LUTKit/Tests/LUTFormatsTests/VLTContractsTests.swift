import Foundation
import XCTest
import LUTCore
import LUTFormats

final class VLTContractsTests: XCTestCase {
    func testVaricamRowsUseRedFastOrderAndTwelveBitCodes() throws {
        var source = "# panasonic vlt file version 1.0\n# source vlt file \"\"\nLUT_3D_SIZE 17\n\n"
        for blue in 0..<17 {
            for green in 0..<17 {
                for red in 0..<17 {
                    source += "\(red) \(green) \(blue)\n"
                }
            }
        }
        let lut = try VLTParser.parse(Data(source.utf8))
        XCTAssertEqual(lut.size, 17)
        XCTAssertEqual(lut.samples[1], try RGB64(1.0 / 4095, 0, 0))
        XCTAssertEqual(lut.samples[17], try RGB64(0, 1.0 / 4095, 0))
        XCTAssertEqual(lut.samples[289], try RGB64(0, 0, 1.0 / 4095))
        XCTAssertEqual(lut.samples[4912], try RGB64(16.0 / 4095, 16.0 / 4095, 16.0 / 4095))
    }

    func testWriterRoundsHalfUpAndRoundTripsCodes() throws {
        let samples: [RGB64] = try (0..<4913).map { index in
            let red = index == 0 ? 0.5 / 4095.0 : Double(index % 4096) / 4095.0
            let green = Double((index * 3) % 4096) / 4095.0
            return try RGB64(red, green, 1)
        }
        let lut = try CubeLUT(dimension: .three, size: 17, domain: .unit, samples: samples)
        let text = try VLTWriter.serialize(lut)
        XCTAssertTrue(text.hasPrefix("# panasonic vlt file version 1.0\n"))
        let rows = text.split(separator: "\n").filter { !$0.hasPrefix("#") && !$0.hasPrefix("LUT_") }
        XCTAssertEqual(rows.count, 4913)
        XCTAssertEqual(rows[0], "1 0 4095")
        let reread = try VLTParser.parse(Data(text.utf8))
        XCTAssertEqual(reread.samples[0], try RGB64(1.0 / 4095, 0, 1))
        XCTAssertEqual(reread.samples[4912], samples[4912])
    }

    func testRejectsUnsupportedOrDamagedFiles() throws {
        let header = "# panasonic vlt file version 1.0\n# source vlt file \"\"\nLUT_3D_SIZE 17\n"
        let cases: [(String, VLTFailureCategory)] = [
            (header + "0 0 0\n", .rowCountMismatch),
            (header + "0 0 NaN\n", .nonFiniteValue),
            (header + "0 0 4096\n", .invalidCodeValue),
            (header + "0 0 0 0\n", .invalidNumber),
            ("LUT_3D_SIZE 16\n", .unsupported),
            ("LUT_3D_SIZE 17\n", .malformedHeader),
        ]
        for (source, category) in cases {
            XCTAssertThrowsError(try VLTParser.parse(Data(source.utf8)), source) {
                XCTAssertEqual(($0 as? VLTFailure)?.category, category)
            }
        }
    }

    func testWriterRejectsUnrepresentableValuesAndDomain() throws {
        let samples = try (0..<4913).map { index in try RGB64(index == 0 ? -0.1 : 0, 0, 0) }
        let lut = try CubeLUT(dimension: .three, size: 17, domain: .unit, samples: samples)
        XCTAssertThrowsError(try VLTWriter.serialize(lut)) {
            XCTAssertEqual(($0 as? VLTFailure)?.category, .lossyRepresentation)
        }
        let nonUnit = try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(1, 1, 1))
        let domainLUT = try CubeLUT(dimension: .three, size: 17, domain: nonUnit, samples: samples)
        XCTAssertThrowsError(try VLTWriter.serialize(domainLUT)) {
            XCTAssertEqual(($0 as? VLTFailure)?.category, .lossyRepresentation)
        }
    }
}
