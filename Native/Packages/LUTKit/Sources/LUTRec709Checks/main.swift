import Foundation
import LUTCore
import LUTCatalog

private enum CheckFailure: Error {
    case malformed(String)
    case mismatch(String, Double)
}

private func object(_ value: Any?, _ name: String) throws -> [String: Any] {
    guard let value = value as? [String: Any] else { throw CheckFailure.malformed(name) }
    return value
}

private func array(_ value: Any?, _ name: String) throws -> [Any] {
    guard let value = value as? [Any] else { throw CheckFailure.malformed(name) }
    return value
}

private func number(_ value: Any?, _ name: String) throws -> Double {
    guard let value = value as? Double, value.isFinite else { throw CheckFailure.malformed(name) }
    return value
}

private func compare(_ actual: Double, _ expected: Double, _ label: String,
                     tolerance: Double, worst: inout Double) throws {
    let error = abs(actual - expected)
    worst = max(worst, error)
    guard error <= tolerance else { throw CheckFailure.mismatch(label, error) }
}

do {
    guard CommandLine.arguments.count == 3 else {
        throw CheckFailure.malformed("expected ITU and old-engine fixture paths")
    }
    let official = try object(JSONSerialization.jsonObject(
        with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))), "ITU fixture")
    let old = try object(JSONSerialization.jsonObject(
        with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))), "old fixture")
    guard official["algorithmVersion"] as? String == "rec709.itu-oetf-2015",
          old["algorithmVersion"] as? String == "rec709.lutcalc-legacy.v1" else {
        throw CheckFailure.malformed("algorithm versions")
    }
    var worstOfficial = 0.0
    for (index, raw) in try array(official["encode"], "ITU encode").enumerated() {
        let item = try object(raw, "ITU case")
        let input = try number(item["input"], "ITU input")
        let expected = try number(item["expected"], "ITU expected")
        let actual = try Rec709Transfer.encodeLegacy(input)
        try compare(actual, expected, "ITU encode \(index)", tolerance: 5e-15, worst: &worstOfficial)
    }
    var worstLegacy = 0.0
    for direction in ["encode", "decode"] {
        for (index, raw) in try array(old[direction], "old \(direction)").enumerated() {
            let item = try object(raw, "old case")
            let input = try number(item["input"], "old input")
            let expected = try number(item["expected"], "old expected")
            let actual = try direction == "encode" ? Rec709Transfer.encodeLegacy(input)
                : Rec709Transfer.decodeLegacy(input)
            try compare(actual, expected, "old \(direction) \(index)",
                        tolerance: 5e-15, worst: &worstLegacy)
        }
    }
    var checkedCodes = 0
    for raw in try array(old["fullCodeData"], "all codes") {
        let group = try object(raw, "code group")
        guard let bits = group["bits"] as? Int, [10, 12].contains(bits) else {
            throw CheckFailure.malformed("bit depth")
        }
        let values = try array(group["decoded"], "decoded codes")
        guard values.count == 1 << bits else { throw CheckFailure.malformed("code count") }
        for (code, rawExpected) in values.enumerated() {
            let expected = try number(rawExpected, "code result")
            let input = Double(code) / Double((1 << bits) - 1)
            let actual = try Rec709Transfer.decodeLegacy(input)
            try compare(actual, expected, "\(bits)-bit code \(code)",
                        tolerance: 5e-15, worst: &worstLegacy)
            checkedCodes += 1
        }
    }
    for value in [Double.nan, .infinity, -.infinity] {
        do {
            _ = try Rec709Transfer.encodeLegacy(value)
            throw CheckFailure.malformed("nonfinite encode accepted")
        } catch NumericError.nonFinite {}
        do {
            _ = try Rec709Transfer.decodeLegacy(value)
            throw CheckFailure.malformed("nonfinite decode accepted")
        } catch NumericError.nonFinite {}
    }
    let catalog = try AlgorithmCatalog.builtIn()
    guard catalog.transfer(named: "Rec.709 (LUTCalc legacy)")?.id == .rec709LUTCalcLegacy,
          catalog.transfer(named: TransferID.rec709LUTCalcLegacy.rawValue)?.linearReference == .legacyGrey02,
          catalog.preset(named: "rec709.legacy-exposure-one.v1")?.settings.inputTransfer == .rec709LUTCalcLegacy else {
        throw CheckFailure.malformed("catalog mapping")
    }
    let settings = TransformSettings(
        inputTransfer: .rec709LUTCalcLegacy, outputTransfer: .rec709LUTCalcLegacy,
        inputSpace: .srgb, outputSpace: .srgb,
        inputRange: .data, outputRange: .data,
        exposureStops: 1
    )
    let plan = try TransformPlan(settings: settings)
    var worstPlan = 0.0
    for (index, raw) in try array(official["legacySameSpaceExposurePlusOne"], "plan cases").enumerated() {
        let item = try object(raw, "plan case")
        let input = try number(item["input"], "plan input")
        let expected = try number(item["expected"], "plan expected")
        let actual = try plan.evaluate(RGB64(input, input, input))
        for channel in [actual.r, actual.g, actual.b] {
            try compare(channel, expected, "plan \(index)", tolerance: 2e-12, worst: &worstPlan)
        }
    }
    print("H11 Rec.709 旧兼容曲线通过：ITU 定义域前向最大误差 \(worstOfficial)，旧 JS 标量与 \(checkedCodes) 个全码解码最大误差 \(worstLegacy)，曝光计划最大误差 \(worstPlan)")
} catch {
    fputs("LUTRec709Checks: \(error)\n", stderr)
    exit(1)
}
