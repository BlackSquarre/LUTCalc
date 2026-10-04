import Foundation
import XCTest
import LUTCore
import LUTFormats

final class ThreeDLContractsTests: XCTestCase {
    func testFlameParserReadsShaperAndRFastRows() throws {
        let source = """
        # NUMBER OF NODES: 2
        # INPUT RANGE: 2
        # OUTPUT RANGE: 2
        0 3
        0 0 0
        0 0 1
        0 1 0
        0 1 1
        1 0 0
        1 0 1
        1 1 0
        1 1 1
        """
        let lut = try ThreeDLParser.parse(Data(source.utf8), flavor: .flame)
        XCTAssertEqual(lut.size, 2)
        XCTAssertEqual(lut.samples[1], try RGB64(1.0 / 3.0, 0, 0))
        XCTAssertEqual(lut.samples[2], try RGB64(0, 1.0 / 3.0, 0))
        XCTAssertEqual(lut.samples[4], try RGB64(0, 0, 1.0 / 3.0))
        XCTAssertNil(lut.shaper)
    }

    func testFlameParserRetainsMonotonicNonlinearShaper() throws {
        var source = """
        # NUMBER OF NODES: 3
        # INPUT RANGE: 2
        # OUTPUT RANGE: 2
        0 1 3
        """
        source += "\n"
        for index in 0..<27 {
            let red = index / 9
            let green = (index / 3) % 3
            let blue = index % 3
            source += "\(red) \(green) \(blue)\n"
        }
        let lut = try ThreeDLParser.parse(Data(source.utf8), flavor: .flame)
        let shaper = try XCTUnwrap(lut.shaper)
        XCTAssertEqual(shaper.size, 3)
        XCTAssertEqual(shaper.domain, .unit)
        XCTAssertEqual(shaper.samples, [try RGB64(0, 0, 0), try RGB64(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0), try RGB64(1, 1, 1)])
    }

    func testFlameWriterQuantizesWithExplicitHalfUpRuleAndRoundTrips() throws {
        let samples = try (0..<8).map { index in
            let value = Double(index) / 7.0
            return try RGB64(value, 0.5, 1)
        }
        let lut = try CubeLUT(dimension: .three, size: 2, domain: .unit, samples: samples)
        let text = try ThreeDLWriter.serialize(lut, inputBits: 2, outputBits: 4, flavor: .flame)
        XCTAssertTrue(text.contains("0 3"))
        let lines = text.split(separator: "\n").filter { !$0.hasPrefix("#") }
        XCTAssertEqual(lines[1], "0 8 15")
        XCTAssertEqual(lines[2], "9 8 15")
        let parsed = try ThreeDLParser.parse(Data(text.utf8), flavor: .flame)
        XCTAssertEqual(parsed.samples[0], try RGB64(0, 8.0 / 15.0, 1))
        XCTAssertEqual(parsed.samples[7], try RGB64(1, 8.0 / 15.0, 1))
    }

    func testRejectsMalformedRowsNonFiniteAndUnsupportedShaper() throws {
        let base = "# NUMBER OF NODES: 2\n# INPUT RANGE: 2\n# OUTPUT RANGE: 2\n"
        let malformed = base + "0 3\n0 0 0\n"
        XCTAssertThrowsError(try ThreeDLParser.parse(Data(malformed.utf8), flavor: .flame)) { error in
            XCTAssertEqual((error as? ThreeDLFailure)?.category, .rowCountMismatch)
        }
        let nonFinite = base + "0 3\n0 0 NaN\n"
        XCTAssertThrowsError(try ThreeDLParser.parse(Data(nonFinite.utf8), flavor: .flame)) { error in
            XCTAssertEqual((error as? ThreeDLFailure)?.category, .nonFiniteValue)
        }
        let nonMonotonic = base + "2 0\n0 0 0\n"
        XCTAssertThrowsError(try ThreeDLParser.parse(Data(nonMonotonic.utf8), flavor: .flame)) { error in
            XCTAssertEqual((error as? ThreeDLFailure)?.category, .unsupportedShaper)
        }
        let excess = base + "0 3\n" + Array(repeating: "0 0 0", count: 9).joined(separator: "\n")
        XCTAssertThrowsError(try ThreeDLParser.parse(Data(excess.utf8), flavor: .flame)) { error in
            XCTAssertEqual((error as? ThreeDLFailure)?.category, .rowCountMismatch)
        }
        let invalidCode = base + "0 3\n0 0 4\n"
        XCTAssertThrowsError(try ThreeDLParser.parse(Data(invalidCode.utf8), flavor: .flame)) { error in
            XCTAssertEqual((error as? ThreeDLFailure)?.category, .invalidCodeValue)
        }
        let mesh = "3DMESH\nMesh 1 2\n" + base
        XCTAssertThrowsError(try ThreeDLParser.parse(Data(mesh.utf8), flavor: .flame)) { error in
            XCTAssertEqual((error as? ThreeDLFailure)?.category, .unsupported)
        }
        let wrongRows = "# NUMBER OF ROWS: 9\n" + base + "0 3\n" + Array(repeating: "0 0 0", count: 8).joined(separator: "\n")
        XCTAssertThrowsError(try ThreeDLParser.parse(Data(wrongRows.utf8), flavor: .flame)) { error in
            XCTAssertEqual((error as? ThreeDLFailure)?.category, .malformedHeader)
        }
    }

    func testWriterRejectsUnrepresentableSamples() throws {
        let samples = try (0..<8).map { index in try RGB64(index == 0 ? -0.1 : 0, 0, 0) }
        let lut = try CubeLUT(dimension: .three, size: 2, domain: .unit, samples: samples)
        XCTAssertThrowsError(try ThreeDLWriter.serialize(lut, inputBits: 10, outputBits: 12, flavor: .flame)) {
            XCTAssertEqual(($0 as? ThreeDLFailure)?.category, .lossyRepresentation)
        }
    }

    func testWriterRoundTripsNonlinearShaper() throws {
        let samples = try (0..<27).map { index in
            let value = Double(index) / 26.0
            return try RGB64(value, 0.5, 1)
        }
        let shaper = try CubeShaper(
            size: 3,
            domain: .unit,
            samples: [try RGB64(0, 0, 0), try RGB64(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0), try RGB64(1, 1, 1)]
        )
        let lut = try CubeLUT(dimension: .three, size: 3, domain: .unit,
                              samples: samples, shaper: shaper)
        let text = try ThreeDLWriter.serialize(lut, inputBits: 2, outputBits: 4, flavor: .flame)
        XCTAssertTrue(text.contains("0 1 3\n"))
        let parsed = try ThreeDLParser.parse(Data(text.utf8), flavor: .flame)
        XCTAssertEqual(parsed.shaper, shaper)
        XCTAssertEqual(parsed.samples.count, 27)
    }

    func testRejectsConflictingOrLateNumericMetadata() throws {
        let header = "# NUMBER OF NODES: 2\n# INPUT RANGE: 2\n# OUTPUT RANGE: 2\n"
        let shape = "0 3\n"
        let rows = Array(repeating: "0 0 0", count: 8).joined(separator: "\n") + "\n"
        let cases = [
            header + "# INPUT RANGE: 3\n" + shape + rows,
            header + "# OUTPUT RANGE: 3\n" + shape + rows,
            header + "# NUMBER OF ROWS: 8\n# NUMBER OF ROWS: 9\n" + shape + rows,
            header + shape + "# OUTPUT RANGE: 3\n" + rows,
            header + shape + rows + "# NUMBER OF NODES: 3\n",
        ]
        for source in cases {
            XCTAssertThrowsError(try ThreeDLParser.parse(Data(source.utf8), flavor: .flame)) {
                XCTAssertEqual(($0 as? ThreeDLFailure)?.category, .malformedHeader)
            }
        }
    }

    func testLustreWriterAndParserUseMeshHeaderAndFooter() throws {
        let samples = try (0..<8).map { index in
            let value = Double(index) / 7.0
            return try RGB64(value, 0.5, 1)
        }
        let lut = try CubeLUT(dimension: .three, size: 2, domain: .unit, samples: samples)
        XCTAssertThrowsError(try ThreeDLWriter.serialize(lut, inputBits: 2, outputBits: 4, flavor: .lustre)) {
            XCTAssertEqual(($0 as? ThreeDLFailure)?.category, .invalidDimension)
        }

        let size = 9
        let full = try (0..<(size * size * size)).map { index in
            let value = Double(index) / Double(size * size * size - 1)
            return try RGB64(value, 0.5, 1)
        }
        let cube = try CubeLUT(dimension: .three, size: size, domain: .unit, samples: full)
        let text = try ThreeDLWriter.serialize(cube, inputBits: 4, outputBits: 8, flavor: .lustre)
        XCTAssertTrue(text.contains("3DMESH\nMesh 3 8\n"))
        XCTAssertTrue(text.hasSuffix("LUT8\ngamma 1.0\n"))
        let parsed = try ThreeDLParser.parse(Data(text.utf8), flavor: .lustre)
        XCTAssertEqual(parsed.samples, cube.samples.map { try! RGB64((($0.r * 255).rounded(.toNearestOrAwayFromZero)) / 255,
                                                                      (($0.g * 255).rounded(.toNearestOrAwayFromZero)) / 255,
                                                                      (($0.b * 255).rounded(.toNearestOrAwayFromZero)) / 255) })
    }

    func testKodakUsesPlainThreeDLRowsAndRejectsLustreMarkers() throws {
        let samples = try (0..<8).map { index in
            let value = Double(index) / 7.0
            return try RGB64(value, 0.5, 1)
        }
        let lut = try CubeLUT(dimension: .three, size: 2, domain: .unit, samples: samples)
        let text = try ThreeDLWriter.serialize(lut, inputBits: 2, outputBits: 4, flavor: .kodak)
        XCTAssertFalse(text.contains("3DMESH"))
        XCTAssertFalse(text.contains("LUT8"))
        XCTAssertEqual(try ThreeDLParser.parse(Data(text.utf8), flavor: .kodak).samples.count, 8)

        let lustre = text.replacingOccurrences(of: "0 3\n", with: "3DMESH\nMesh 1 4\n0 3\n") + "LUT8\ngamma 1.0\n"
        XCTAssertThrowsError(try ThreeDLParser.parse(Data(lustre.utf8), flavor: .kodak)) {
            XCTAssertEqual(($0 as? ThreeDLFailure)?.category, .unsupported)
        }
    }

    func testAutoParserSelectsLustreOnlyFromExplicitMeshMarker() throws {
        let samples = try (0..<729).map { index in
            try RGB64(Double(index) / 728, 0, 1)
        }
        let cube = try CubeLUT(dimension: .three, size: 9, domain: .unit, samples: samples)
        let lustre = try ThreeDLWriter.serialize(cube, inputBits: 10, outputBits: 12, flavor: .lustre)
        XCTAssertEqual(try ThreeDLParser.parseAuto(Data(lustre.utf8)).size, 9)
        let plain = try ThreeDLWriter.serialize(cube, inputBits: 10, outputBits: 12, flavor: .kodak)
        XCTAssertEqual(try ThreeDLParser.parseAuto(Data(plain.utf8)).size, 9)
    }
}
