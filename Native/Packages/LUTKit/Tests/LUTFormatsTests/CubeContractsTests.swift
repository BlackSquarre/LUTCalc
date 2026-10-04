import Foundation
import XCTest
import LUTCore
import LUTFormats

final class CubeContractsTests: XCTestCase {
    func testRoundTripPreservesExtendedDoubleValues() throws {
        let domain = try LUTDomain(min: RGB64(-1, -2, -3), max: RGB64(2, 3, 4))
        let original = try CubeLUT(dimension: .one, size: 2, domain: domain, samples: [
            RGB64(-0.001, 0.5, 0.25), RGB64(2, 3, 4),
        ], title: "扩展域")
        let text = try CubeWriter.serialize(original)
        let decoded = try CubeParser.parse(Data(text.utf8))
        XCTAssertEqual(decoded, original)
    }

    func testMissingRowIsRejected() throws {
        let input = Data("LUT_1D_SIZE 2\n0 0 0\n".utf8)
        XCTAssertThrowsError(try CubeParser.parse(input)) { error in
            XCTAssertEqual((error as? CubeFailure)?.category, .rowCountMismatch)
        }
    }

    func testNonFiniteIsRejected() throws {
        let input = Data("LUT_1D_SIZE 2\n0 Infinity 0\n1 1 1\n".utf8)
        XCTAssertThrowsError(try CubeParser.parse(input)) { error in
            XCTAssertEqual((error as? CubeFailure)?.category, .nonFiniteValue)
        }
    }

    func testNonFiniteFirstChannelIsReportedAsSampleError() throws {
        for token in ["NaN", "Infinity", "-inf"] {
            let input = Data("LUT_1D_SIZE 2\n\(token) 0 0\n1 1 1\n".utf8)
            XCTAssertThrowsError(try CubeParser.parse(input), token) { error in
                XCTAssertEqual((error as? CubeFailure)?.category, .nonFiniteValue)
                XCTAssertEqual((error as? CubeFailure)?.line, 2)
            }
        }
    }

    func testNonIdentityCubeGeneration() throws {
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1
        )
        let plan = try TransformPlan(settings: settings)
        let cube = try CubeGenerator.generate3D(plan: plan, size: 17, domain: .unit)
        XCTAssertEqual(cube.samples.count, 4913)
        XCTAssertNotEqual(cube.samples[0], try RGB64(0, 0, 0))
        XCTAssertEqual(try CubeParser.parse(Data(CubeWriter.serialize(cube).utf8)), cube)
    }

    func testThreeDialectsPreserveOrRejectInputDomain() throws {
        let uniform = try LUTDomain(min: RGB64(-0.1, -0.1, -0.1), max: RGB64(1.5, 1.5, 1.5))
        let source = try CubeLUT(dimension: .one, size: 2, domain: uniform,
                                 samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)])
        let resolve = try CubeWriter.serialize(source, dialect: .resolveInputRange)
        XCTAssertTrue(resolve.contains("LUT_1D_INPUT_RANGE -0.1 1.5"))
        XCTAssertEqual(try CubeParser.parse(Data(resolve.utf8)), source)
        XCTAssertThrowsError(try CubeWriter.serialize(source, dialect: .general)) {
            XCTAssertEqual(($0 as? CubeFailure)?.category, .unsupported)
        }
        let domain = try CubeWriter.serialize(source, dialect: .domain)
        XCTAssertTrue(domain.contains("DOMAIN_MIN -0.1 -0.1 -0.1"))
    }

    func testCombinedShaperPrecedesThreeDimensionalLUT() throws {
        let inputDomain = try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(1, 1, 1))
        let volumeDomain = try LUTDomain(min: RGB64(0, 0, 0), max: RGB64(2, 2, 2))
        let shaper = try CubeShaper(size: 2, domain: inputDomain,
                                    samples: [RGB64(0, 0, 0), RGB64(2, 1, 0.5)])
        var nodes: [RGB64] = []
        nodes.reserveCapacity(8)
        for index in 0..<8 {
            let red = Double(index % 2)
            let green = Double((index / 2) % 2)
            let blue = Double(index / 4)
            try nodes.append(RGB64(red, green, blue))
        }
        let source = try CubeLUT(dimension: .three, size: 2, domain: volumeDomain,
                                 samples: nodes, title: "shaper 组合", shaper: shaper)
        let text = try CubeWriter.serialize(source, dialect: .resolveInputRange)
        XCTAssertEqual(try CubeParser.parse(Data(text.utf8)), source)
        let output = try source.sample(RGB64(0, 0.5, 1), interpolation: .tetrahedral, outside: .reject)
        XCTAssertEqual(output.r, 0.5, accuracy: 1e-15)
        XCTAssertEqual(output.g, 0.375, accuracy: 1e-15)
        XCTAssertEqual(output.b, 0.25, accuracy: 1e-15)
        XCTAssertThrowsError(try CubeWriter.serialize(source, dialect: .domain)) {
            XCTAssertEqual(($0 as? CubeFailure)?.category, .unsupported)
        }
        let ambiguousDomain = text.replacingOccurrences(of: "LUT_3D_INPUT_RANGE 0 2.0\n",
                                                         with: "LUT_3D_INPUT_RANGE 0 2.0\nDOMAIN_MIN 0 0 0\n")
        XCTAssertThrowsError(try CubeParser.parse(Data(ambiguousDomain.utf8))) {
            XCTAssertEqual(($0 as? CubeFailure)?.category, .invalidDomain)
        }
    }
}
