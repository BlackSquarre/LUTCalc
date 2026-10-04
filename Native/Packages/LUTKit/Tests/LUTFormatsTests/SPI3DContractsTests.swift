import Foundation
import XCTest
import LUTCore
import LUTFormats

final class SPI3DContractsTests: XCTestCase {
    func testBlueFastRowsMapToRedFastInternalIndex() throws {
        let source = """
        SPILUT 1.0
        3 3
        2 2 2
        0 0 0 0 0 0
        0 0 1 0 0 1
        0 1 0 0 1 0
        0 1 1 0 1 1
        1 0 0 1 0 0
        1 0 1 1 0 1
        1 1 0 1 1 0
        1 1 1 1 1 1

        """
        let lut = try SPI3DParser.parse(Data(source.utf8))
        XCTAssertEqual(lut.dimension, .three)
        XCTAssertEqual(lut.size, 2)
        for blue in 0..<2 {
            for green in 0..<2 {
                for red in 0..<2 {
                    let index = red + 2 * (green + 2 * blue)
                    XCTAssertEqual(lut.samples[index], try RGB64(Double(red), Double(green), Double(blue)))
                }
            }
        }
        let sampled = try lut.sample(RGB64(0.25, 0.5, 0.75), interpolation: .tetrahedral, outside: .reject)
        XCTAssertEqual(sampled.r, 0.25, accuracy: 1e-15)
        XCTAssertEqual(sampled.g, 0.5, accuracy: 1e-15)
        XCTAssertEqual(sampled.b, 0.75, accuracy: 1e-15)
        XCTAssertEqual(try SPI3DParser.parse(Data(SPI3DWriter.serialize(lut).utf8)), lut)
    }

    func testShuffledRowsAndExtendedDoubleRoundTrip() throws {
        var source = "SPILUT 1.0\n3 3\n2 2 2\n"
        var expected: [RGB64] = []
        for blue in 0..<2 {
            for green in 0..<2 {
                for red in 0..<2 {
                    expected.append(try RGB64(Double(red) + 0.0000000000000002,
                                              Double(green) - 0.125,
                                              Double(blue) * 3.141592653589793))
                }
            }
        }
        for red in (0..<2).reversed() {
            for green in (0..<2).reversed() {
                for blue in (0..<2).reversed() {
                    let value = expected[red + 2 * (green + 2 * blue)]
                    source += "\(red) \(green) \(blue) \(value.r) \(value.g) \(value.b)\n"
                }
            }
        }
        let parsed = try SPI3DParser.parse(Data(source.utf8))
        XCTAssertEqual(parsed.samples, expected)
        let reread = try SPI3DParser.parse(Data(SPI3DWriter.serialize(parsed).utf8))
        for index in 0..<8 {
            for channel in 0..<3 {
                XCTAssertEqual(reread.samples[index][channel].bitPattern, expected[index][channel].bitPattern)
            }
        }
    }

    func testDuplicateMissingAndOutOfBoundsIndicesRejected() throws {
        let header = "SPILUT 1.0\n3 3\n2 2 2\n"
        let identity = (0..<2).flatMap { red in
            (0..<2).flatMap { green in
                (0..<2).map { blue in "\(red) \(green) \(blue) \(red) \(green) \(blue)" }
            }
        }
        let duplicate = header + (identity + [identity[0]]).joined(separator: "\n") + "\n"
        XCTAssertThrowsError(try SPI3DParser.parse(Data(duplicate.utf8))) {
            XCTAssertEqual(($0 as? SPI3DFailure)?.category, .duplicateIndex)
        }
        let missing = header + identity.dropLast().joined(separator: "\n") + "\n"
        XCTAssertThrowsError(try SPI3DParser.parse(Data(missing.utf8))) {
            XCTAssertEqual(($0 as? SPI3DFailure)?.category, .rowCountMismatch)
        }
        let outside = header + "2 0 0 0 0 0\n"
        XCTAssertThrowsError(try SPI3DParser.parse(Data(outside.utf8))) {
            XCTAssertEqual(($0 as? SPI3DFailure)?.category, .invalidIndex)
        }
    }

    func testMalformedHeaderRowsAndNonFiniteRejected() throws {
        let cases: [(String, SPI3DFailureCategory)] = [
            ("SPILUT 2.0\n3 3\n2 2 2\n", .unsupported),
            ("SPILUT 1.0\n2 3\n2 2 2\n", .unsupported),
            ("SPILUT 1.0\n3 3\n2 3 2\n", .unsupported),
            ("SPILUT 1.0\n3 3\n1 1 1\n", .invalidDimension),
            ("SPILUT 1.0\n3 3\n999999999999 999999999999 999999999999\n", .resourceLimit),
            ("SPILUT 1.0\n3 3\n2 2 2\n0.0 0 0 0 0 0\n", .invalidIndex),
            ("SPILUT 1.0\n3 3\n2 2 2\n0 0 0 NaN 0 0\n", .nonFiniteValue),
            ("SPILUT 1.0\n3 3\n2 2 2\n0 0 0 0 0\n", .invalidNumber),
        ]
        for (source, category) in cases {
            XCTAssertThrowsError(try SPI3DParser.parse(Data(source.utf8)), source) {
                XCTAssertEqual(($0 as? SPI3DFailure)?.category, category, source)
            }
        }
    }

    func testWriterRequiresUnitDomainAndThreeDimensions() throws {
        let nonUnit = try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(1, 1, 1))
        let eight = try (0..<8).map { _ in try RGB64(0, 0, 0) }
        let volume = try CubeLUT(dimension: .three, size: 2, domain: nonUnit, samples: eight)
        XCTAssertThrowsError(try SPI3DWriter.serialize(volume)) {
            XCTAssertEqual(($0 as? SPI3DFailure)?.category, .lossyRepresentation)
        }
        let one = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                              samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)])
        XCTAssertThrowsError(try SPI3DWriter.serialize(one)) {
            XCTAssertEqual(($0 as? SPI3DFailure)?.category, .lossyRepresentation)
        }
        let signedZeroDomain = try LUTDomain(min: RGB64(-0.0, 0, 0), max: RGB64(1, 1, 1))
        let signedZero = try CubeLUT(dimension: .three, size: 2, domain: signedZeroDomain, samples: eight)
        XCTAssertThrowsError(try SPI3DWriter.serialize(signedZero)) {
            XCTAssertEqual(($0 as? SPI3DFailure)?.category, .lossyRepresentation)
        }
        let titled = try CubeLUT(dimension: .three, size: 2, domain: .unit, samples: eight, title: "keep me")
        XCTAssertThrowsError(try SPI3DWriter.serialize(titled)) {
            XCTAssertEqual(($0 as? SPI3DFailure)?.category, .lossyRepresentation)
        }
    }
}
