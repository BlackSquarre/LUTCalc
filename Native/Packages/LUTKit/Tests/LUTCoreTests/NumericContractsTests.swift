import XCTest
import LUTCore

final class NumericContractsTests: XCTestCase {
    func testRangeEndpointsAndExtendedValues() throws {
        for bits in [8, 10, 12] {
            let range = try CodeRange.videoRGB(bitDepth: bits)
            XCTAssertEqual(try range.dataToVideo(Double(range.blackCode) / Double(range.maxCode)), 0, accuracy: 2e-12)
            XCTAssertEqual(try range.dataToVideo(Double(range.whiteCode) / Double(range.maxCode)), 1, accuracy: 2e-12)
            XCTAssertLessThan(try range.dataToVideo(0), 0)
            XCTAssertGreaterThan(try range.dataToVideo(1), 1)
        }
    }

    func testGridEndpointsAndOverflow() throws {
        let grid = try Grid3D(size: 3, domain: .unit)
        XCTAssertEqual(grid.nodeCount, 27)
        XCTAssertEqual(try grid.coordinate(at: 0), try RGB64(0, 0, 0))
        XCTAssertEqual(try grid.coordinate(at: 26), try RGB64(1, 1, 1))
        XCTAssertThrowsError(try Grid3D(size: Int.max, domain: .unit))
    }

    func testExplicitLegacyScale() throws {
        XCTAssertEqual(try LinearScale.legacyToScene(0.2), 0.18, accuracy: 2e-12)
        XCTAssertEqual(try LinearScale.legacyToScene(-0.2), -0.18, accuracy: 2e-12)
    }

    func testAsymmetricMatrixAndIllConditionedFailure() throws {
        let matrix = try Matrix3x3(rowMajor: [1, 2, 3, 0, 1, 4, 5, 6, 0])
        XCTAssertEqual(try matrix.applying(to: RGB64(0.25, -0.5, 2)), try RGB64(5.25, 7.5, -1.75))
        let inverse = try matrix.inverted()
        XCTAssertEqual(inverse.rowMajor, [-24, 18, 5, 20, -15, -4, -5, 4, 1])
        let singular = try Matrix3x3(rowMajor: [1, 2, 3, 2, 4, 6, 1, 1, 1])
        XCTAssertThrowsError(try singular.inverted())
    }

    func testDLog2LegalAndDataRoundTrip() throws {
        let range = try CodeRange.videoRGB(bitDepth: 10)
        for code in 0...range.maxCode {
            let data = Double(code) / Double(range.maxCode)
            let scene = try DLog2.decodeDataToScene(data)
            XCTAssertEqual(try DLog2.encodeSceneToData(scene), data, accuracy: 2e-12)
            let video = try range.dataToVideo(data)
            XCTAssertEqual(try DLog2.decodeVideoToScene(video, codeRange: range), scene, accuracy: 2e-12)
        }
    }

    func testPlanKeepsSettingsSnapshotAndStageOrder() throws {
        let settings = TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1
        )
        let plan = try TransformPlan(settings: settings)
        let result = try plan.trace(try RGB64(0.1, 0.2, 0.3))
        XCTAssertEqual(result.stages.map(\.id), [1, 2, 3, 4, 10, 13, 19])
        XCTAssertEqual(result.output.r, 0.06664835281530862, accuracy: 2e-12)
        XCTAssertEqual(result.output.g, 0.08911463491640885, accuracy: 2e-12)
        XCTAssertEqual(result.output.b, 0.34003804189511755, accuracy: 2e-12)
    }

    func testTetrahedralDiffersFromTrilinearAndRejectsOutside() throws {
        let vertices = try [
            RGB64(0, 0, 0), RGB64(1, 3, -1), RGB64(2, -1, 1), RGB64(4, 2, 0),
            RGB64(4, 2, 2), RGB64(5, 5, 2), RGB64(6, 2, 3), RGB64(8, 5, 3),
        ]
        let volume = try LUTVolume3D(size: 2, domain: .unit, samples: vertices)
        let point = try RGB64(0.8, 0.5, 0.2)
        let tetra = try volume.sample(point, interpolation: .tetrahedral, outside: .reject)
        let trilinear = try volume.sample(point, interpolation: .trilinear, outside: .reject)
        XCTAssertEqual(tetra.r, 3.1, accuracy: 2e-12)
        XCTAssertEqual(trilinear.r, 3, accuracy: 2e-12)
        XCTAssertThrowsError(try volume.sample(RGB64(-0.1, 0.5, 0.5), interpolation: .tetrahedral, outside: .reject))
    }

    func testSRGBVersionedDecodingAtLegacyDifference() throws {
        let code = 0.0403
        let standard = try SRGBTransfer.decode(code, variant: .w3cExtended)
        let legacy = try SRGBTransfer.decode(code, variant: .lutcalcLegacy)
        XCTAssertEqual(standard, code / 12.92, accuracy: 2e-12)
        XCTAssertNotEqual(standard, legacy)
        XCTAssertEqual(try SRGBTransfer.decode(-0.1, variant: .lutcalcLegacy), -0.1 / 12.92, accuracy: 2e-12)
    }

    func testSRGBPlanKeepsScaleAndRangeVersionsSeparate() throws {
        let standard = try TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .srgbW3CExtended,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .video, exposureStops: 0, rangeBitDepth: 12
        ))
        let legacy = try TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .srgbLUTCalcLegacy,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0
        ))
        let sample = try RGB64(0.18, -0.01, 1.5)
        let standardTrace = try standard.trace(sample)
        XCTAssertEqual(standardTrace.stages.map(\.id), [1, 2, 3, 4, 10, 13, 19])
        let range = try CodeRange.videoRGB(bitDepth: 12)
        for channel in 0..<3 {
            let encoded = try SRGBTransfer.encode(sample[channel], variant: .w3cExtended)
            XCTAssertEqual(standardTrace.output[channel], try range.dataToVideo(encoded), accuracy: 2e-12)
            let oldEncoded = try SRGBTransfer.encode(sample[channel] / 0.9, variant: .lutcalcLegacy)
            XCTAssertEqual(try legacy.evaluate(sample)[channel], oldEncoded, accuracy: 2e-12)
        }
    }

    func testRec2100HLGStandardScalarContract() throws {
        XCTAssertEqual(HLGTransfer.a, 0.17883277, accuracy: 1e-15)
        XCTAssertEqual(HLGTransfer.b, 0.28466892, accuracy: 1e-15)
        XCTAssertEqual(HLGTransfer.c, 0.5 - HLGTransfer.a * log(4.0 * HLGTransfer.a), accuracy: 2e-16)
        XCTAssertEqual(try HLGTransfer.encodeSceneToData(0), 0, accuracy: 2e-12)
        XCTAssertEqual(try HLGTransfer.encodeSceneToData(1.0 / 12.0), 0.5, accuracy: 2e-12)
        XCTAssertEqual(try HLGTransfer.decodeDataToScene(0.5), 1.0 / 12.0, accuracy: 2e-12)
        XCTAssertThrowsError(try HLGTransfer.encodeSceneToData(-0.25)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }
        XCTAssertThrowsError(try HLGTransfer.decodeDataToScene(-0.25)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }
        XCTAssertEqual(try HLGTransfer.encodeSceneToData(0.01), 0.17320508075688773, accuracy: 2e-12)
        XCTAssertEqual(try HLGTransfer.encodeSceneToData(0.18), 0.6723581321276545, accuracy: 2e-12)
        XCTAssertEqual(try HLGTransfer.decodeDataToScene(0.75), 0.2649625604210072, accuracy: 2e-12)
        XCTAssertEqual(try HLGTransfer.decodeDataToScene(1.2), 3.010977610099849, accuracy: 2e-12)
        let knee = 1.0 / 12.0
        XCTAssertEqual(try HLGTransfer.encodeSceneToData(knee.nextDown), 0.5, accuracy: 2e-12)
        XCTAssertEqual(try HLGTransfer.encodeSceneToData(knee.nextUp), 0.5, accuracy: 2e-12)
        for value in [0.0, knee.nextDown, knee, knee.nextUp, 0.18, 1.0, 4.0] {
            let encoded = try HLGTransfer.encodeSceneToData(value)
            XCTAssertEqual(try HLGTransfer.decodeDataToScene(encoded), value, accuracy: 2e-12)
        }
        for bits in [10, 12] {
            let maximum = Double((1 << bits) - 1)
            for code in 0...Int(maximum) {
                let encoded = Double(code) / maximum
                let scene = try HLGTransfer.decodeDataToScene(encoded)
                XCTAssertEqual(try HLGTransfer.encodeSceneToData(scene), encoded, accuracy: 2e-12)
            }
        }
        XCTAssertThrowsError(try HLGTransfer.encodeSceneToData(.infinity)) {
            XCTAssertEqual($0 as? NumericError, .nonFinite)
        }
        XCTAssertThrowsError(try HLGTransfer.decodeDataToScene(.nan)) {
            XCTAssertEqual($0 as? NumericError, .nonFinite)
        }
        XCTAssertThrowsError(try HLGTransfer.decodeDataToScene(Double.greatestFiniteMagnitude)) {
            XCTAssertEqual($0 as? NumericError, .nonFinite)
        }
    }

    func testRec2100HLGSameSpacePlanPreservesBlackChannels() throws {
        let plan = try TransformPlan(settings: TransformSettings(
            inputTransfer: .rec2100HLG, outputTransfer: .rec2100HLG,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 1
        ))
        let trace = try plan.trace(RGB64(1.0 / 32.0, 0, 0))
        XCTAssertEqual(trace.stages.map(\.id), [1, 2, 3, 4, 10, 13, 19])
        XCTAssertEqual(trace.output.g, 0)
        XCTAssertEqual(trace.output.b, 0)
    }

    func testRec2100PQStandardScalarContract() throws {
        XCTAssertEqual(try PQTransfer.encodeNormalizedLuminanceToData(0), 0, accuracy: 2e-12)
        XCTAssertEqual(try PQTransfer.decodeDataToNormalizedLuminance(0), 0, accuracy: 2e-12)
        XCTAssertEqual(try PQTransfer.encodeNormalizedLuminanceToData(0.0001),
                       0.1499457321001802, accuracy: 2e-12)
        XCTAssertEqual(try PQTransfer.decodeDataToNormalizedLuminance(0.1499457321001802),
                       0.0001, accuracy: 2e-12)
        XCTAssertEqual(try PQTransfer.encodeNormalizedLuminanceToData(0.01), 0.508078421517399, accuracy: 2e-12)
        XCTAssertEqual(try PQTransfer.decodeDataToNormalizedLuminance(0.508078421517399), 0.01, accuracy: 2e-12)
        XCTAssertEqual(try PQTransfer.encodeNormalizedLuminanceToData(1), 1, accuracy: 2e-12)
        XCTAssertEqual(try PQTransfer.decodeDataToNormalizedLuminance(1), 1, accuracy: 2e-12)
        for bits in [10, 12] {
            let maximum = Double((1 << bits) - 1)
            for code in stride(from: 0, through: Int(maximum), by: max(1, Int(maximum) / 257)) {
                let encoded = Double(code) / maximum
                let scene = try PQTransfer.decodeDataToNormalizedLuminance(encoded)
                XCTAssertEqual(try PQTransfer.encodeNormalizedLuminanceToData(scene), encoded, accuracy: 2e-12)
            }
        }
        XCTAssertThrowsError(try PQTransfer.encodeNormalizedLuminanceToData(-0.1)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }
        XCTAssertThrowsError(try PQTransfer.decodeDataToNormalizedLuminance(1.1)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }
        XCTAssertThrowsError(try PQTransfer.encodeNormalizedLuminanceToData(.nan)) {
            XCTAssertEqual($0 as? NumericError, .nonFinite)
        }
    }

    func testRec2100PQExplicitNitsContractUsesTenThousandCdPerSquareMeterReference() throws {
        XCTAssertEqual(PQTransfer.referencePeakNits, 10_000.0, accuracy: 0.0)
        XCTAssertEqual(try PQTransfer.encodeAbsoluteLuminanceToData(0), 0, accuracy: 2e-12)
        XCTAssertEqual(try PQTransfer.encodeAbsoluteLuminanceToData(100),
                       try PQTransfer.encodeNormalizedLuminanceToData(0.01), accuracy: 2e-15)
        XCTAssertEqual(try PQTransfer.decodeDataToAbsoluteLuminance(0.508078421517399), 100,
                       accuracy: 2e-10)
        XCTAssertThrowsError(try PQTransfer.encodeAbsoluteLuminanceToData(-0.1)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }
        XCTAssertThrowsError(try PQTransfer.encodeAbsoluteLuminanceToData(10_000.0001)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }
        XCTAssertThrowsError(try PQTransfer.decodeDataToAbsoluteLuminance(1.0001)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }
    }

    func testRec2100PQAbsoluteNitsRoundTripEvery16BitCode() throws {
        var maximum = 0.0
        var previous = -1.0
        for code in 0...65_535 {
            let encoded = Double(code) / 65_535.0
            let nits = try PQTransfer.decodeDataToAbsoluteLuminance(encoded)
            XCTAssertGreaterThanOrEqual(nits, previous)
            XCTAssertLessThanOrEqual(nits, 10_000)
            let roundTrip = try PQTransfer.encodeAbsoluteLuminanceToData(nits)
            maximum = max(maximum, abs(roundTrip - encoded))
            previous = nits
        }
        print("PQ absolute nits 16-bit round-trip max encoded error: \(maximum)")
        XCTAssertLessThanOrEqual(maximum, 4e-14)
    }

    func testBT1886ReferenceDisplayEOTFContract() throws {
        XCTAssertEqual(BT1886Transfer.gamma, 2.4, accuracy: 1e-15)
        let white = 100.0
        let black = 0.1
        XCTAssertEqual(try BT1886Transfer.encodeSignalToLuminance(0, whiteLuminance: white, blackLuminance: black), black, accuracy: 2e-12)
        XCTAssertEqual(try BT1886Transfer.encodeSignalToLuminance(1, whiteLuminance: white, blackLuminance: black), white, accuracy: 2e-12)
        XCTAssertEqual(try BT1886Transfer.encodeSignalToLuminance(0.5, whiteLuminance: white, blackLuminance: black), 21.60491116738936, accuracy: 2e-12)
        for signal in [0.0, 0.0183, 0.5, 1.0] {
            let luminance = try BT1886Transfer.encodeSignalToLuminance(signal, whiteLuminance: white, blackLuminance: black)
            XCTAssertEqual(try BT1886Transfer.decodeLuminanceToSignal(luminance, whiteLuminance: white, blackLuminance: black), signal, accuracy: 2e-12)
        }
        XCTAssertThrowsError(try BT1886Transfer.encodeSignalToLuminance(-0.1, whiteLuminance: white, blackLuminance: black)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }
        XCTAssertThrowsError(try BT1886Transfer.decodeLuminanceToSignal(0, whiteLuminance: white, blackLuminance: black)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }
        XCTAssertThrowsError(try BT1886Transfer.encodeSignalToLuminance(.nan, whiteLuminance: white, blackLuminance: black)) {
            XCTAssertEqual($0 as? NumericError, .nonFinite)
        }
        XCTAssertThrowsError(try BT1886Transfer.encodeSignalToLuminance(0.5, whiteLuminance: black, blackLuminance: white)) {
            XCTAssertEqual($0 as? NumericError, .invalidDomain)
        }
    }

}
