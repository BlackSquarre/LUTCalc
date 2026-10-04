import Foundation
import XCTest
@testable import LUTCore

final class ARRILogCSceneRoutingContractsTests: XCTestCase {
    private func settings(input: ARRILogCSceneSettings? = nil, output: ARRILogCSceneSettings? = nil,
                          inputID: TransferID = .linearScene, outputID: TransferID = .linearScene) -> TransformSettings {
        TransformSettings(inputTransfer: inputID, outputTransfer: outputID,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data,
            exposureStops: 0, inputLogC: input, outputLogC: output)
    }
    private func root() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    func testExplicitIndependentPayloadsRejectMissingMismatchAndUnsupportedEI() throws {
        let a = try ARRILogCSceneSettings(algorithm: .sup2Published, exposureIndex: 800)
        let b = try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 1600)
        XCTAssertThrowsError(try TransformPlan(settings: settings(inputID: .arriLogCSUP2Scene))) {
            XCTAssertEqual($0 as? TransformSettingsError, .missingInputLogC)
        }
        XCTAssertThrowsError(try TransformPlan(settings: settings(outputID: .arriLogCSUP3Scene))) {
            XCTAssertEqual($0 as? TransformSettingsError, .missingOutputLogC)
        }
        XCTAssertThrowsError(try TransformPlan(settings: settings(input: a))) {
            XCTAssertEqual($0 as? TransformSettingsError, .unexpectedInputLogC)
        }
        XCTAssertThrowsError(try TransformPlan(settings: settings(output: b, outputID: .arriLogCSUP2Scene))) {
            XCTAssertEqual($0 as? TransformSettingsError, .logCAlgorithmMismatch)
        }
        for ei in [0, 159, 161, 1501, 1601, 2000, 3200, Int.max] {
            XCTAssertThrowsError(try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: ei))
        }
        let s = settings(input: a, output: b, inputID: .arriLogCSUP2Scene, outputID: .arriLogCSUP3Scene)
        let plan = try TransformPlan(settings: s)
        let input = try RGB64(0.1, 0.4, 1.1), actual = try plan.evaluate(input)
        for c in 0..<3 { XCTAssertEqual(actual[c], try b.makeTransfer().encode(a.makeTransfer().decode(input[c])), accuracy: 2e-12) }
        XCTAssertTrue(plan.planVersion.contains("input-logc:" + a.algorithm.rawValue + ":EI800"))
        XCTAssertTrue(plan.planVersion.contains("output-logc:" + b.algorithm.rawValue + ":EI1600"))
        XCTAssertNotEqual(plan.planVersion, try TransformPlan(settings: s.withOutputLogC(
            ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 800))).planVersion)
    }
    func testScenePlanStagesAgainstIndependentDecimalProbesAndFullCodes() throws {
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: root().appendingPathComponent(
            "tests/fixtures/native-contracts/arri-logc-compact-independent.json"))) as! [String: Any]
        let bytes = try Data(contentsOf: root().appendingPathComponent("tests/fixtures/native-contracts/arri-logc-compact-decode.f64"))
        var errors: [Double] = []
        func check(_ actual: Double, _ expected: Double) {
            let error = abs(actual - expected) / max(1, abs(expected))
            errors.append(error); XCTAssertLessThanOrEqual(error, 2e-12)
        }
        let cases = (raw["cases"] as! [[String: Any]]).filter { $0["domain"] as! String == "sceneExposure" }
        XCTAssertEqual(cases.count, 22)
        for item in cases {
            let payload = try ARRILogCSceneSettings(algorithm: item["firmware"] as! String == "sup2" ? .sup2Published : .sup3Published,
                exposureIndex: item["exposureIndex"] as! Int)
            let decode = try TransformPlan(settings: settings(input: payload, inputID: payload.algorithm.transferID))
            let encode = try TransformPlan(settings: settings(output: payload, outputID: payload.algorithm.transferID))
            for probe in item["probes"] as! [[String: Any]] {
                let x = Double(probe["input"] as! String)!, expected = Double(probe["output"] as! String)!
                let plan = probe["direction"] as! String == "encode" ? encode : decode
                let trace = try plan.trace(RGB64(x, x, x))
                check(trace.output.r, expected)
                XCTAssertEqual(trace.stages.first(where: { $0.id == 2 })?.outputUnit, .sceneReflectance)
            }
            var cursor = item["decodeBinaryOffsetBytes"] as! Int
            for depth in [10, 12] { for code in 0..<(1 << depth) {
                let word = bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: cursor, as: UInt64.self) }; cursor += 8
                let x = Double(code) / Double((1 << depth) - 1)
                check(try decode.evaluate(RGB64(x,x,x)).r, Double(bitPattern: UInt64(littleEndian: word)))
            }}
        }
        let sorted = errors.sorted()
        print("Log C scene routed Decimal: count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/Double(errors.count))), P99=\(sorted[Int(ceil(Double(errors.count)*0.99))-1])")
    }
    func testOutputAnchorsUsePreparedEIAndHelpersRetainBothPayloads() throws {
        let input = try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 200)
        let output = try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 1600)
        let s = settings(input: input, output: output, inputID: .arriLogCSUP3Scene, outputID: .arriLogCSUP3Scene)
        for copy in [s.withInputRange(.video), s.withOutputRange(.video), s.withRangeBitDepth(12), s.withExposureStops(1),
            s.withAdaptation(.bradford), s.withASCCDL(nil), s.withSDRSaturation(nil), s.withMultitone(nil),
            s.withBlackGamma(nil), s.withBlackHighlight(nil), s.withKnee(nil), s.withHighlightGamut(nil),
            s.withGamutLimiter(nil), s.withOutputCodeUnits(.partialV1), s.withDisplayConversion(nil),
            s.withFalseColour(nil), s.withFinalOutput(nil)] {
            XCTAssertEqual(copy.inputLogC, input); XCTAssertEqual(copy.outputLogC, output)
        }
        XCTAssertNil(s.withInput(transfer: .linearScene, space: .rec2020).inputLogC)
        XCTAssertEqual(s.withInput(transfer: .linearScene, space: .rec2020).outputLogC, output)
        XCTAssertNil(s.withOutput(transfer: .linearScene, space: .rec2020).outputLogC)
        let encoder = try NativeOutputEncoder(settings: s)
        XCTAssertEqual(encoder.legalScale, 876.0/1023); XCTAssertEqual(encoder.legalOffset, 64.0/1023)
        let reference = try JSONSerialization.jsonObject(with: Data(contentsOf: root().appendingPathComponent(
            "tests/fixtures/native-contracts/arri-logc-scene-routing-independent.json"))) as! [String: Any]
        for probe in reference["anchorProbes"] as! [[String: Any]] {
            let x = probe["legacy"] as! Double, expected = Double(probe["legal"] as! String)!
            XCTAssertLessThanOrEqual(abs(try encoder.encodeLegacyToLegal(x) - expected)/max(1,abs(expected)), 2e-12)
        }
        let changed = s.withOutputLogC(try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 400))
        XCTAssertNotEqual(try NativeOutputEncoder(settings: changed).encodeScene(0.9), try encoder.encodeScene(0.9))
        let levels = try BlackHighlightSettings(doBlack: true, doHigh: true, blackLevel: 0.1,
            blackLock: false, highMap: 0.8, highLock: false)
        let rebased = s.withBlackHighlight(levels).withOutputLogC(
            try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 400))
        XCTAssertNil(rebased.blackHighlight?.blackLevel); XCTAssertNil(rebased.blackHighlight?.highMap)
    }
}
