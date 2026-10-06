import Foundation
import XCTest
@testable import LUTCore
import LUTCatalog

final class CameraTransferIndependentContractsTests: XCTestCase {
    private struct Point: Decodable { let input: Double; let output: String? }
    private struct Variant: Decodable { let id: TransferID; let encode: [Point]; let decode: [Point] }
    private struct Reference: Decodable { let precision: Int; let threshold: Double; let variants: [Variant] }
    private let ids: [TransferID] = [.nikonNLog, .nikonNLogLUTCalcLegacy, .cineon, .cineonLUTCalcLegacy]

    private func encode(_ x: Double, id: TransferID) throws -> Double {
        switch id {
        case .nikonNLog: try NikonNLogTransfer.encodeSceneToData(x)
        case .nikonNLogLUTCalcLegacy: try NikonNLogTransfer.encodeLegacyToData(x)
        case .cineon: try CineonTransfer.encodeSceneToData(x)
        case .cineonLUTCalcLegacy: try CineonTransfer.encodeLegacyToData(x)
        default: throw NumericError.invalidDomain
        }
    }
    private func decode(_ x: Double, id: TransferID) throws -> Double {
        switch id {
        case .nikonNLog: try NikonNLogTransfer.decodeDataToScene(x)
        case .nikonNLogLUTCalcLegacy: try NikonNLogTransfer.decodeDataToLegacy(x)
        case .cineon: try CineonTransfer.decodeDataToScene(x)
        case .cineonLUTCalcLegacy: try CineonTransfer.decodeDataToLegacy(x)
        default: throw NumericError.invalidDomain
        }
    }
    func testNinetyDigitIndependentFullCodesAndBranchNeighbours() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        let ref = try JSONDecoder().decode(Reference.self, from: Data(contentsOf:
            root.appendingPathComponent("tests/fixtures/native-contracts/camera-transfer-decimal.json")))
        XCTAssertEqual(ref.precision, 90); XCTAssertEqual(ref.threshold, 2e-12)
        XCTAssertEqual(ref.variants.map(\.id), ids)
        var reports: [[String: Any]] = []
        for variant in ref.variants {
            var errors: [Double] = []
            for point in variant.encode {
                if let text = point.output {
                    let expected = try XCTUnwrap(Double(text))
                    errors.append(abs(try encode(point.input, id: variant.id) - expected) / max(1, abs(expected)))
                } else {
                    XCTAssertThrowsError(try encode(point.input, id: variant.id))
                }
            }
            for point in variant.decode {
                let expected = try XCTUnwrap(Double(try XCTUnwrap(point.output)))
                errors.append(abs(try decode(point.input, id: variant.id) - expected) / max(1, abs(expected)))
            }
            errors.sort()
            let maximum = try XCTUnwrap(errors.last)
            XCTAssertLessThanOrEqual(maximum, ref.threshold, variant.id.rawValue)
            let report: [String: Any] = ["id": variant.id.rawValue, "count": errors.count,
                "maxScaled": maximum, "rmsScaled": sqrt(errors.reduce(0) { $0 + $1 * $1 } / Double(errors.count)),
                "p99Scaled": errors[Int(ceil(Double(errors.count) * 0.99)) - 1], "threshold": ref.threshold]
            reports.append(report)
            print("Camera transfer Decimal: \(report)")
        }
        if let directory = ProcessInfo.processInfo.environment["LUTCALC_CAMERA_TRANSFER_ARTIFACT_DIR"] {
            let url = URL(fileURLWithPath: directory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: reports, options: [.prettyPrinted, .sortedKeys])
                .write(to: url.appendingPathComponent("scalar-decimal.json"))
        }
    }
    func testPlanAdaptsLegacyLinearScaleOnceAndCodeUnitsExplicitly() throws {
        for id in ids {
            let legacy = id == .nikonNLogLUTCalcLegacy || id == .cineonLUTCalcLegacy
            let encoded = try encode(legacy ? 0.2 : 0.18, id: id)
            let settings = TransformSettings(inputTransfer: id, outputTransfer: .linearScene,
                inputSpace: .rec2020, outputSpace: .rec2020,
                inputRange: .data, outputRange: .data, exposureStops: 1)
            let plan = try TransformPlan(settings: settings)
            XCTAssertTrue(plan.planVersion.contains(id.rawValue))
            let rgb = try RGB64(encoded, encoded, encoded)
            XCTAssertEqual(try plan.evaluate(rgb).r, 0.36, accuracy: 2e-14)
            let reverse = settings.withInput(transfer: .linearScene, space: .rec2020)
                .withOutput(transfer: id, space: .rec2020).withExposureStops(0)
            XCTAssertEqual(try TransformPlan(settings: reverse).evaluate(RGB64(0.18, 0.18, 0.18)).r,
                           encoded, accuracy: 2e-14)
            let video = reverse.withOutputRange(.video)
            XCTAssertEqual(try TransformPlan(settings: video).evaluate(RGB64(0.18, 0.18, 0.18)).r,
                           (encoded * 1023 - 64) / 876, accuracy: 2e-14)
        }
        // Nikon's published rounded split is intentionally not a perfect
        // inverse near 0.328. Preserve the two equations without smoothing.
        let shoulder = try NikonNLogTransfer.encodeSceneToData(0.328)
        XCTAssertLessThan(shoulder, 452.0 / 1023)
        XCTAssertGreaterThan(abs(try NikonNLogTransfer.decodeDataToScene(shoulder) - 0.328), 1e-4)
        XCTAssertThrowsError(try CineonTransfer.encodeSceneToData(-0.1))
        XCTAssertTrue(try CineonTransfer.encodeLegacyToData(-0.1).isFinite)
    }

    func testCameraTransferPlanIdentityIncludesDirectionAndBothColorSpaces() throws {
        for id in ids {
            let decode = try TransformPlan(settings: TransformSettings(
                inputTransfer: id, outputTransfer: .linearScene,
                inputSpace: .rec2020, outputSpace: .srgb,
                inputRange: .data, outputRange: .data, exposureStops: 0))
            let encode = try TransformPlan(settings: TransformSettings(
                inputTransfer: .linearScene, outputTransfer: id,
                inputSpace: .srgb, outputSpace: .rec2020,
                inputRange: .data, outputRange: .data, exposureStops: 0))
            let alternate = try TransformPlan(settings: TransformSettings(
                inputTransfer: id, outputTransfer: .linearScene,
                inputSpace: .displayP3, outputSpace: .srgb,
                inputRange: .data, outputRange: .data, exposureStops: 0))
            XCTAssertNotEqual(decode.planVersion, encode.planVersion, id.rawValue)
            XCTAssertNotEqual(decode.planVersion, alternate.planVersion, id.rawValue)
        }
    }

    func testLegacyMethodsAgainstActualFrozenJavaScriptExecution() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        let data = try Data(contentsOf: root.appendingPathComponent("tests/fixtures/native-contracts/camera-transfer-legacy.json"))
        let ref = try JSONDecoder().decode(Reference.self, from: data)
        XCTAssertEqual(ref.precision, 64); XCTAssertEqual(ref.threshold, 2e-12)
        XCTAssertEqual(ref.variants.map(\.id), [.nikonNLogLUTCalcLegacy, .cineonLUTCalcLegacy])
        var reports: [[String: Any]] = []
        for variant in ref.variants {
            var maximum = 0.0
            for (points, isEncode) in [(variant.encode, true), (variant.decode, false)] {
                for point in points {
                    let expected = try XCTUnwrap(Double(try XCTUnwrap(point.output)))
                    let actual = try isEncode ? encode(point.input, id: variant.id) : decode(point.input, id: variant.id)
                    maximum = max(maximum, abs(actual - expected) / max(1, abs(expected)))
                }
            }
            XCTAssertLessThanOrEqual(maximum, ref.threshold)
            reports.append(["id": variant.id.rawValue, "maxScaled": maximum,
                "count": variant.encode.count + variant.decode.count, "threshold": ref.threshold])
        }
        if let directory = ProcessInfo.processInfo.environment["LUTCALC_CAMERA_TRANSFER_ARTIFACT_DIR"] {
            let url = URL(fileURLWithPath: directory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: reports, options: [.prettyPrinted, .sortedKeys])
                .write(to: url.appendingPathComponent("scalar-legacy-js.json"))
        }
    }
}
