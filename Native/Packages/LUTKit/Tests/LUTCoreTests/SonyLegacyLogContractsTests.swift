import XCTest
@testable import LUTCore
import LUTCatalog

final class SonyLegacyLogContractsTests: XCTestCase {
    private struct Point: Decodable { let input: Double; let output: String }
    private struct Variant: Decodable { let id: String; let encode: [Point]; let decode: [Point] }
    private struct LegacyReference: Decodable { let precision: Int; let variants: [Variant] }

    func testPublishedSLogAndSLog2ReflectionFormulas() throws {
        XCTAssertEqual(try SonyLegacyLogTransfer.encodeSLogToData(0.18), 0.3849708167170378, accuracy: 2e-15)
        XCTAssertEqual(try SonyLegacyLogTransfer.encodeSLog2ToData(0.18), 0.3395325247957023, accuracy: 2e-15)
        XCTAssertEqual(try SonyLegacyLogTransfer.decodeDataToSLog(0.3849708167170378), 0.18, accuracy: 2e-14)
        XCTAssertEqual(try SonyLegacyLogTransfer.decodeDataToSLog2(0.3395325247957023), 0.18, accuracy: 2e-14)
        XCTAssertThrowsError(try SonyLegacyLogTransfer.encodeSLogToData(.nan))
        XCTAssertThrowsError(try SonyLegacyLogTransfer.decodeDataToSLog2(.infinity))
    }

    func testLegacyDomainIsSeparateAndPlansUseOneScaleBoundary() throws {
        XCTAssertEqual(try SonyLegacyLogTransfer.encodeSLogLegacyToData(0.2), 0.38497081671703787, accuracy: 2e-15)
        XCTAssertEqual(try SonyLegacyLogTransfer.encodeSLog2LegacyToData(0.2), 0.3395325247957023, accuracy: 2e-15)
        let official = TransformSettings(inputTransfer: .sonySLog2, outputTransfer: .linearScene,
            inputSpace: .sonySGamut, outputSpace: .sonySGamut,
            inputRange: .data, outputRange: .data, exposureStops: 0)
        let legacy = official.withInput(transfer: .sonySLog2LUTCalcLegacy, space: .sonySGamut)
        XCTAssertEqual(try TransformPlan(settings: official).evaluate(RGB64(0.3395325247957023, 0.3395325247957023, 0.3395325247957023)).r,
                       0.18, accuracy: 2e-14)
        XCTAssertEqual(try TransformPlan(settings: legacy).evaluate(RGB64(0.3395325247957023, 0.3395325247957023, 0.3395325247957023)).r,
                       0.18, accuracy: 2e-14)
    }

    func testCatalogAndCameraRoutesExposeSLog2AndSLog() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "S-Log2")?.id, .sonySLog2)
        XCTAssertEqual(catalog.transfer(named: "S-Log")?.id, .sonySLog)
        XCTAssertEqual(catalog.colorSpace(named: "S-Gamut")?.id, .sonySGamut)
        let base = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data, exposureStops: 0)
        for id in ["camera.sony.nex-fs700.v1", "camera.sony.a7s.v1", "camera.sony.pmw-f3.v1"] {
            let state = try CameraExposureSettings.selecting(profileID: id, inputPolicy: .publishedAvailableDefaults)
            let settings = try CameraPresetResolver.applying(state, to: base)
            XCTAssertTrue([.sonySLog2, .sonySLog].contains(settings.inputTransfer))
            XCTAssertEqual(settings.inputSpace, .sonySGamut)
        }
    }

    func testLegacyMethodsMatchActualFrozenJavaScriptExecution() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        let data = try Data(contentsOf: root.appendingPathComponent("tests/fixtures/native-contracts/sony-log-legacy-reference.json"))
        let fixture = try JSONDecoder().decode(LegacyReference.self, from: data)
        XCTAssertEqual(fixture.precision, 64)
        for item in fixture.variants {
            let id: TransferID = item.id.contains("slog2") ? .sonySLog2LUTCalcLegacy : .sonySLogLUTCalcLegacy
            for point in item.encode {
                let actual = id == .sonySLog2LUTCalcLegacy
                    ? try SonyLegacyLogTransfer.encodeSLog2LegacyToData(point.input)
                    : try SonyLegacyLogTransfer.encodeSLogLegacyToData(point.input)
                XCTAssertEqual(actual, try XCTUnwrap(Double(point.output)), accuracy: 2e-12)
            }
            for point in item.decode {
                let actual = id == .sonySLog2LUTCalcLegacy
                    ? try SonyLegacyLogTransfer.decodeDataToSLog2Legacy(point.input)
                    : try SonyLegacyLogTransfer.decodeDataToSLogLegacy(point.input)
                XCTAssertEqual(actual, try XCTUnwrap(Double(point.output)), accuracy: 2e-12)
            }
        }
    }
}
