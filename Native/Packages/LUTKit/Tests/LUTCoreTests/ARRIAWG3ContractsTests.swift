import Foundation
import XCTest
@testable import LUTCore
import LUTCatalog

final class ARRIAWG3ContractsTests: XCTestCase {
    private func root() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func fixture() throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: root().appendingPathComponent(
            "tests/fixtures/native-contracts/arri-awg3-independent.json"))) as! [String: Any]
    }
    private func report(_ scope: String, _ errors: [Double]) {
        let sorted = errors.sorted()
        print("AWG3 \(scope): count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/Double(errors.count))), P99=\(sorted[Int(ceil(Double(errors.count)*0.99))-1])")
    }
    func testPublishedPrimariesRationalMatricesAndEveryNativeTargetBothCATs() throws {
        let p = ColorPrimaries.arriWideGamut3
        XCTAssertEqual(p.red.x, 0.6840); XCTAssertEqual(p.red.y, 0.3130)
        XCTAssertEqual(p.green.x, 0.2210); XCTAssertEqual(p.green.y, 0.8480)
        XCTAssertEqual(p.blue.x, 0.0861); XCTAssertEqual(p.blue.y, -0.1020)
        XCTAssertEqual(p.white.x, 0.3127); XCTAssertEqual(p.white.y, 0.3290)
        let raw = try fixture(), matrix = try p.rgbToXYZ()
        var errors: [Double] = []
        func check(_ actual: Double, _ expected: Double) {
            let error = abs(actual-expected)/max(1,abs(expected)); errors.append(error)
            XCTAssertLessThanOrEqual(error, 2e-12)
        }
        for (i, word) in (raw["rgbToXYZ"] as! [String]).enumerated() { check(matrix.rowMajor[i], Double(word)!) }
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.colorSpace(named: "ARRI Wide Gamut 3")?.id, .arriWideGamut3)
        let cases = raw["matrices"] as! [[String: Any]]
        XCTAssertEqual(cases.count, 60)
        for item in cases {
            let source = ColorSpaceID(rawValue: item["source"] as! String)!, target = ColorSpaceID(rawValue: item["target"] as! String)!
            let cat = ChromaticAdaptation(rawValue: item["adaptation"] as! String)!
            let actual = try ColorPrimaries.conversion(from: source.primaries, to: target.primaries, adaptation: cat)
            for (i, word) in (item["values"] as! [String]).enumerated() { check(actual.rowMajor[i], Double(word)!) }
            for probe in item["probes"] as! [[String: Any]] {
                let x = (probe["input"] as! [String]).map { Double($0)! }, y = (probe["output"] as! [String]).map { Double($0)! }
                let output = try actual.applying(to: RGB64(x[0],x[1],x[2]))
                for c in 0..<3 { check(output[c], y[c]) }
            }
        }
        report("rational matrices/probes", errors)
        XCTAssertGreaterThan(raw["publishedRoundedXYZMaximumDifference"] as! Double, 2e-12)
    }
    func testAllEIPresetsUseExplicitAWG3AndPlanTraceMatchesActualWorkingSpace() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        for ei in ARRILogCCompact.supportedExposureIndices {
            let preset = try XCTUnwrap(catalog.preset(named: "arri.logc-sup3-ei\(ei)-awg3-to-linear-ap0-published.v1"))
            let s = preset.settings
            XCTAssertEqual(s.inputTransfer, .arriLogCSUP3Scene); XCTAssertEqual(s.inputSpace, .arriWideGamut3)
            XCTAssertEqual(s.inputLogC?.algorithm, .sup3Published); XCTAssertEqual(s.inputLogC?.exposureIndex, ei)
            XCTAssertEqual(s.outputSpace, .acesAP0); XCTAssertEqual(s.exposureStops, 0); XCTAssertNil(s.outputLogC)
            let plan = try TransformPlan(settings: s), trace = try plan.trace(RGB64(0.1,0.4,0.8))
            XCTAssertEqual(trace.stages.first { $0.id == 2 }?.outputSpace, .arriWideGamut3)
            XCTAssertEqual(trace.stages.first { $0.id == 3 }?.outputSpace, .sonySGamut3Cine)
            XCTAssertEqual(trace.stages.first { $0.id == 4 }?.inputSpace, .sonySGamut3Cine)
            XCTAssertEqual(trace.stages.first { $0.id == 10 }?.outputSpace, .acesAP0)
            XCTAssertTrue(plan.planVersion.contains("gamut:arri.awg3.v1"))
        }
        XCTAssertNil(catalog.preset(named: "arri.logc-sup3-ei2000-awg3-to-linear-ap0-published.v1"))
        XCTAssertFalse(catalog.presets.contains { $0.settings.inputTransfer == .arriLogCSUP2Scene && $0.settings.inputSpace == .arriWideGamut3 })
        let s = TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .arriWideGamut3, outputSpace: .arriWideGamut3, inputRange: .data, outputRange: .data, exposureStops: 0)
        let trace = try TransformPlan(settings: s).trace(RGB64(-0.1,0.5,1.2))
        XCTAssertEqual(trace.stages.first { $0.id == 3 }?.outputSpace, .arriWideGamut3)
        XCTAssertEqual(trace.output, try RGB64(-0.1,0.5,1.2))
    }
    func testAllEIPlansAndTenTwelveBitColourCodesAgainstIndependentDecimal() throws {
        let raw = try fixture(), bytes = try Data(contentsOf: root().appendingPathComponent("tests/fixtures/native-contracts/arri-awg3-codes.f64"))
        var errors: [Double] = []
        let cases = raw["codeCases"] as! [[String: Any]]; XCTAssertEqual(cases.count, 44)
        for item in cases {
            let decoding = item["direction"] as! String == "decode"
            let payload = try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: item["exposureIndex"] as! Int)
            let s = TransformSettings(inputTransfer: decoding ? .arriLogCSUP3Scene : .linearScene,
                outputTransfer: decoding ? .linearScene : .arriLogCSUP3Scene,
                inputSpace: decoding ? .arriWideGamut3 : .acesAP0, outputSpace: decoding ? .acesAP0 : .arriWideGamut3,
                inputRange: .data, outputRange: .data, exposureStops: 0,
                adaptation: ChromaticAdaptation(rawValue: item["adaptation"] as! String)!,
                inputLogC: decoding ? payload : nil, outputLogC: decoding ? nil : payload)
            let plan = try TransformPlan(settings: s); var cursor = item["offsetBytes"] as! Int
            for depth in [10,12] { for code in 0..<(1 << depth) {
                let scalar = Double(code)/Double((1 << depth)-1)
                let input = try RGB64(scalar, 0.001+scalar*0.73, 1-scalar*0.83), actual = try plan.evaluate(input)
                for c in 0..<3 {
                    let word = bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: cursor, as: UInt64.self) }; cursor += 8
                    let y = Double(bitPattern: UInt64(littleEndian: word)), error = abs(actual[c]-y)/max(1,abs(y))
                    errors.append(error); XCTAssertLessThanOrEqual(error, 2e-12)
                }
            }}
        }
        XCTAssertEqual(bytes.count, 44*(1024+4096)*3*8)
        report("all EI/colour full codes", errors)
    }
}
