import Foundation
import XCTest
import LUTCore
import LUTFormats

final class SPI1DContractsTests: XCTestCase {
    func testOneComponentAndDefaultDomain() throws {
        let source = "Version 1\nLength 2\nComponents 1\n{\n-0.25\n1.5\n}\n"
        let file = try SPI1DParser.parse(Data(source.utf8))
        XCTAssertEqual(file.components, 1)
        XCTAssertEqual(file.lut.domain, .unit)
        XCTAssertEqual(file.lut.samples, [try RGB64(-0.25, -0.25, -0.25), try RGB64(1.5, 1.5, 1.5)])
        XCTAssertEqual(try SPI1DParser.parse(Data(SPI1DWriter.serialize(file).utf8)), file)
    }

    func testTwoAndThreeComponentsKeepChannels() throws {
        let two = "Version 1\nFrom -1 2\nLength 2\nComponents 2\n{\n0.125 0.25\n0.75 1.5\n}\n"
        let twoFile = try SPI1DParser.parse(Data(two.utf8))
        XCTAssertEqual(twoFile.components, 2)
        XCTAssertEqual(twoFile.lut.domain.min, try RGB64(-1, -1, -1))
        XCTAssertEqual(twoFile.lut.samples, [try RGB64(0.125, 0.25, 0), try RGB64(0.75, 1.5, 0)])
        XCTAssertEqual(try SPI1DParser.parse(Data(SPI1DWriter.serialize(twoFile).utf8)), twoFile)

        let three = "Version 1\nFrom -1 2\nLength 2\nComponents 3\n{\n-0.125 0.25 0.5\n0.75 1.5 2.5\n}\n"
        let threeFile = try SPI1DParser.parse(Data(three.utf8))
        XCTAssertEqual(threeFile.components, 3)
        XCTAssertEqual(threeFile.lut.samples, [try RGB64(-0.125, 0.25, 0.5), try RGB64(0.75, 1.5, 2.5)])
        XCTAssertEqual(try SPI1DParser.parse(Data(SPI1DWriter.serialize(threeFile).utf8)), threeFile)
    }

    func testDoubleRoundTripAndInterpolation() throws {
        let source = "Version 1\nFrom -0.1 2.5\nLength 2\nComponents 3\n{\n-0.001 0.30000000000000004 -0.0\n2.0000000000000004 3.141592653589793 4.0\n}\n"
        let file = try SPI1DParser.parse(Data(source.utf8))
        let decoded = try SPI1DParser.parse(Data(SPI1DWriter.serialize(file).utf8))
        for index in 0..<2 {
            for channel in 0..<3 {
                XCTAssertEqual(decoded.lut.samples[index][channel].bitPattern, file.lut.samples[index][channel].bitPattern)
            }
        }
        let midpoint = try file.lut.sample(RGB64(1.2, 1.2, 1.2), interpolation: .trilinear, outside: .reject)
        XCTAssertEqual(midpoint.r, (file.lut.samples[0].r + file.lut.samples[1].r) / 2, accuracy: 1e-15)
        XCTAssertEqual(midpoint.g, (file.lut.samples[0].g + file.lut.samples[1].g) / 2, accuracy: 1e-15)
        XCTAssertThrowsError(try file.lut.sample(RGB64(-0.2, 0, 0), interpolation: .trilinear, outside: .reject))
    }

    func testWriterRejectsLossyComponentReductionAndNonUniformDomain() throws {
        let lut = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                              samples: [RGB64(0, 0.25, 0.5), RGB64(1, 1.5, 2)])
        XCTAssertThrowsError(try SPI1DFile(lut: lut, components: 1)) {
            XCTAssertEqual(($0 as? SPI1DFailure)?.category, .lossyRepresentation)
        }
        XCTAssertThrowsError(try SPI1DFile(lut: lut, components: 2)) {
            XCTAssertEqual(($0 as? SPI1DFailure)?.category, .lossyRepresentation)
        }
        let file = try SPI1DFile(lut: lut, components: 3)
        XCTAssertEqual(try SPI1DParser.parse(Data(SPI1DWriter.serialize(file).utf8)), file)

        let nonUniform = try LUTDomain(min: RGB64(0, -1, 0), max: RGB64(1, 2, 1))
        let incompatible = try CubeLUT(dimension: .one, size: 2, domain: nonUniform,
                                       samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)])
        XCTAssertThrowsError(try SPI1DFile(lut: incompatible, components: 3)) {
            XCTAssertEqual(($0 as? SPI1DFailure)?.category, .lossyRepresentation)
        }
        let titled = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                                 samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)], title: "keep me")
        XCTAssertThrowsError(try SPI1DFile(lut: titled, components: 3)) {
            XCTAssertEqual(($0 as? SPI1DFailure)?.category, .lossyRepresentation)
        }
    }

    func testMalformedHeadersRowsAndTrailingDataAreRejected() throws {
        let cases: [(String, SPI1DFailureCategory)] = [
            ("Version 2\nLength 2\nComponents 1\n{\n0\n1\n}\n", .unsupported),
            ("Version 1\nVersion 1\nLength 2\nComponents 1\n{\n0\n1\n}\n", .malformedHeader),
            ("Version 1\nFrom 1 1\nLength 2\nComponents 1\n{\n0\n1\n}\n", .invalidDomain),
            ("Version 1\nLength 1\nComponents 1\n{\n0\n}\n", .invalidDimension),
            ("Version 1\nLength 2\nComponents 4\n{\n0\n1\n}\n", .invalidComponents),
            ("Version 1\nLength 2\nComponents 1\n{\n0\n}\n", .rowCountMismatch),
            ("Version 1\nLength 2\nComponents 1\n{\n0\n1\n2\n}\n", .rowCountMismatch),
            ("Version 1\nLength 2\nComponents 3\n{\n0 0 0\n1 1\n}\n", .invalidNumber),
            ("Version 1\nLength 2\nComponents 1\n{\n0\nNaN\n}\n", .nonFiniteValue),
            ("Version 1\nLength 2\nComponents 1\n{\n0\n1\n}\nextra\n", .malformedHeader),
        ]
        for (source, category) in cases {
            XCTAssertThrowsError(try SPI1DParser.parse(Data(source.utf8)), source) {
                XCTAssertEqual(($0 as? SPI1DFailure)?.category, category, source)
            }
        }
    }

    func testOversizedLengthRejectedBeforeAllocation() throws {
        let source = "Version 1\nLength 999999999999\nComponents 1\n{\n}\n"
        XCTAssertThrowsError(try SPI1DParser.parse(Data(source.utf8))) {
            XCTAssertEqual(($0 as? SPI1DFailure)?.category, .resourceLimit)
        }
    }
}
