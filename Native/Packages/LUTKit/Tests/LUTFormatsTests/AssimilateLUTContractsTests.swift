import Foundation
import XCTest
import LUTCore
import LUTFormats

final class AssimilateLUTContractsTests: XCTestCase {
    func testWriterBoundsIntegerConversionAtMaximumCode() throws {
        let maximum = Double(Int32.max)
        let lut = try CubeLUT(dimension: .one, size: 2, domain: .unit, samples: [
            RGB64(maximum, -maximum, 0), RGB64(0, 0, 0)
        ])
        let text = try AssimilateLUTWriter.serialize(lut)
        XCTAssertEqual(text, "LUT: 3 2\n2147483647\n0\n-2147483647\n0\n0\n0\n")
        let tooLarge = try CubeLUT(dimension: .one, size: 2, domain: .unit, samples: [
            RGB64(maximum.nextUp, 0, 0), RGB64(0, 0, 0)
        ])
        XCTAssertThrowsError(try AssimilateLUTWriter.serialize(tooLarge)) {
            XCTAssertEqual(($0 as? AssimilateLUTFailure)?.category, .lossyRepresentation)
        }
    }

    func testThreeChannelBlocksAndSignedCodes() throws {
        let data = Data("# sample\nLUT: 3 3\n0\n1\n2\n2\n1\n0\n-1\n0\n3\n".utf8)
        let lut = try AssimilateLUTParser.parse(data)
        XCTAssertEqual(lut.dimension, .one)
        XCTAssertEqual(lut.size, 3)
        XCTAssertEqual(lut.domain, .unit)
        XCTAssertEqual(lut.samples, try [RGB64(0, 1, -0.5), RGB64(0.5, 0.5, 0), RGB64(1, 0, 1.5)])
    }

    func testSingleChannelReadReplicatesScalar() throws {
        let lut = try AssimilateLUTParser.parse(Data("LUT: 1 3\n0\n1\n2\n".utf8))
        XCTAssertEqual(lut.samples, try [RGB64(0, 0, 0), RGB64(0.5, 0.5, 0.5), RGB64(1, 1, 1)])
    }

    func testLegacyPreset4096PointRoundTrip() throws {
        let samples = try (0..<4_096).map { index in
            try RGB64(Double(index) / 4_095, Double(4_095 - index) / 4_095, 0.25)
        }
        let lut = try CubeLUT(dimension: .one, size: 4_096, domain: .unit, samples: samples)
        let text = try AssimilateLUTWriter.serialize(lut)
        XCTAssertTrue(text.hasPrefix("LUT: 3 4096\n0\n1\n"))
        let reread = try AssimilateLUTParser.parse(Data(text.utf8))
        XCTAssertEqual(reread.samples[0], try RGB64(0, 1, 1024.0 / 4095))
        XCTAssertEqual(reread.samples[4_095], try RGB64(1, 0, 1024.0 / 4095))
    }

    func testWriterUsesRGBBlocksAndLegacyPositiveHalfUp() throws {
        let lut = try CubeLUT(dimension: .one, size: 3, domain: .unit, samples: [
            RGB64(0.25, 1, -0.75), RGB64(0.5, 0.5, 0), RGB64(1, 0, 1.5)
        ])
        let text = try AssimilateLUTWriter.serialize(lut)
        XCTAssertEqual(text, "LUT: 3 3\n1\n1\n2\n2\n1\n0\n-1\n0\n3\n")
        let reread = try AssimilateLUTParser.parse(Data(text.utf8))
        XCTAssertEqual(reread.samples, try [RGB64(0.5, 1, -0.5), RGB64(0.5, 0.5, 0), RGB64(1, 0, 1.5)])
    }

    func testRejectsMalformedAndUnsupportedInput() throws {
        let cases: [(String, AssimilateLUTFailureCategory)] = [
            ("0\n1\n", .malformedHeader),
            ("LUT: 2 3\n0\n1\n2\n", .unsupported),
            ("LUT: 3 1\n0\n0\n0\n", .unsupported),
            ("LUT: 3 3\n0\n", .rowCountMismatch),
            ("LUT: 1 2\n0\n1\n2\n", .rowCountMismatch),
            ("LUT: 1 2\n0\nNaN\n", .nonFiniteValue),
            ("LUT: 1 2\n0\n0.5\n", .invalidNumber),
            ("LUT: 1 2\n0\n1 2\n", .invalidNumber),
            ("LUT: 1 16385\n", .unsupported),
            ("LUT: 1 2\n0\nLUT: 1 2\n", .invalidNumber),
            ("LUT: 1 2\n0\n# misplaced\n1\n", .unsupported),
        ]
        for (source, category) in cases {
            XCTAssertThrowsError(try AssimilateLUTParser.parse(Data(source.utf8)), source) {
                XCTAssertEqual(($0 as? AssimilateLUTFailure)?.category, category)
            }
        }
        XCTAssertThrowsError(try AssimilateLUTParser.parse(Data(repeating: 65, count: AssimilateLUTParser.maxFileBytes + 1))) {
            XCTAssertEqual(($0 as? AssimilateLUTFailure)?.category, .resourceLimit)
        }
        XCTAssertThrowsError(try AssimilateLUTParser.parse(Data([0xFF]))) {
            XCTAssertEqual(($0 as? AssimilateLUTFailure)?.category, .invalidEncoding)
        }
    }

    func testWriterRejectsUnrepresentableMetadataAndDimensions() throws {
        let samples = try [RGB64(0, 0, 0), RGB64(1, 1, 1)]
        let titled = try CubeLUT(dimension: .one, size: 2, domain: .unit, samples: samples, title: "lost title")
        XCTAssertThrowsError(try AssimilateLUTWriter.serialize(titled)) {
            XCTAssertEqual(($0 as? AssimilateLUTFailure)?.category, .lossyRepresentation)
        }
        let extended = try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(1, 1, 1))
        let nonUnit = try CubeLUT(dimension: .one, size: 2, domain: extended, samples: samples)
        XCTAssertThrowsError(try AssimilateLUTWriter.serialize(nonUnit)) {
            XCTAssertEqual(($0 as? AssimilateLUTFailure)?.category, .lossyRepresentation)
        }
    }
}
