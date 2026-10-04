import Foundation
import LUTCore
import LUTCatalog

private struct ScalarPoint: Decodable {
    let input: Double
    let expected: Double
}

private struct RGBPoint: Decodable {
    let input: [Double]
    let expected: [Double]
}

private struct FullCode: Decodable {
    let bits: Int
    let decoded: [Double]
}

private struct Fixture: Decodable {
    let algorithmVersion: String
    let scaledTolerance: Double?
    let encode: [ScalarPoint]
    let decode: [ScalarPoint]
    let fullCodeData: [FullCode]
    let planExposureOne: [RGBPoint]
}

private struct CrossCase: Decodable {
    let input: [Double]
    let outputLinearAP0: [Double]
}

private struct CrossFixture: Decodable {
    let sourceTransformID: String
    let matrixColumnRowMajor: [Double]
    let scaledTolerance: Double
    let cases: [CrossCase]
}

private enum Failure: Error { case mismatch(String) }

@main
struct LUTSLog3Checks {
    static func main() {
        do {
            guard CommandLine.arguments.count == 5 else {
                throw Failure.mismatch("expected Sony, legacy, Cine and S-Gamut3 AP0 fixture paths")
            }
            let sony = try JSONDecoder().decode(Fixture.self,
                from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
            let legacy = try JSONDecoder().decode(Fixture.self,
                from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
            let cross = try JSONDecoder().decode(CrossFixture.self,
                from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[3])))
            let gamut3 = try JSONDecoder().decode(CrossFixture.self,
                from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[4])))
            guard sony.algorithmVersion == "sony.slog3.technical-summary-v1.0",
                  legacy.algorithmVersion == "slog3.lutcalc-legacy.v1",
                  sony.scaledTolerance == 2e-12 else {
                throw Failure.mismatch("fixture version or frozen threshold")
            }
            let officialError = try checkScalar(sony,
                encode: SLog3Transfer.encodeSonySceneToData,
                decode: SLog3Transfer.decodeSonyDataToScene, tolerance: 2e-12)
            let legacyError = try checkScalar(legacy,
                encode: { try SLog3Transfer.encodeLegacyToData(LinearScale.sceneToLegacy($0)) },
                decode: { try LinearScale.legacyToScene(SLog3Transfer.decodeLegacyDataToLegacy($0)) },
                tolerance: 2e-12)
            let officialPlanError = try checkPlan(sony, transfer: .sonySLog3)
            let legacyPlanError = try checkPlan(legacy, transfer: .sonySLog3LUTCalcLegacy)
            let crossErrors = try checkCross(cross, sourceSpace: .sonySGamut3Cine,
                sourcePrimaries: .sonySGamut3Cine,
                sourceTransform: "SGamut3Cine")
            let gamut3Errors = try checkCross(gamut3, sourceSpace: .sonySGamut3,
                sourcePrimaries: .sonySGamut3,
                sourceTransform: "SGamut3")
            let catalog = try AlgorithmCatalog.builtIn()
            guard catalog.transfer(named: "S-Log3")?.id == .sonySLog3,
                  catalog.transfer(named: "S-Log3 (LUTCalc legacy)")?.id == .sonySLog3LUTCalcLegacy,
                  catalog.colorSpace(named: "S-Gamut3.Cine")?.id == .sonySGamut3Cine,
                  catalog.colorSpace(named: "S-Gamut3")?.id == .sonySGamut3,
                  catalog.preset(named: "sony.slog3-exposure-one.v1")?.settings.inputTransfer == .sonySLog3,
                  catalog.preset(named: "sony.slog3-legacy-exposure-one.v1")?.settings.inputTransfer == .sonySLog3LUTCalcLegacy,
                  catalog.preset(named: "sony.slog3-to-linear-ap0.v1")?.settings.outputSpace == .acesAP0,
                  catalog.preset(named: "sony.slog3-sgamut3-to-linear-ap0.v1")?.settings.inputSpace == .sonySGamut3 else {
                throw Failure.mismatch("catalog source or identity")
            }
            do {
                _ = try SLog3Transfer.encodeSonySceneToData(.infinity)
                throw Failure.mismatch("nonfinite Sony input accepted")
            } catch NumericError.nonFinite {}
            do {
                _ = try SLog3Transfer.decodeLegacyDataToLegacy(.nan)
                throw Failure.mismatch("nonfinite legacy input accepted")
            } catch NumericError.nonFinite {}
            print("H11 Sony S-Log3 官方标量与 10/12-bit 全码通过：最大尺度化误差 \(officialError)")
            print("H11 S-Log3 旧兼容标量与全码通过：最大尺度化误差 \(legacyError)")
            print("H11 S-Log3 双版本同色域曝光计划通过：官方 \(officialPlanError)，旧版 \(legacyPlanError)")
            print("H11 S-Log3 → AP0 独立 CTL 契约通过：矩阵 \(crossErrors.0)，10 点计划 \(crossErrors.1)")
            print("H11 S-Gamut3 → AP0 独立 CTL 契约通过：矩阵 \(gamut3Errors.0)，10 点计划 \(gamut3Errors.1)")
        } catch {
            fputs("LUTSLog3Checks: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func scaled(_ value: Double, _ expected: Double) -> Double {
        abs(value - expected) / max(1, abs(expected))
    }

    private static func checkScalar(_ fixture: Fixture,
                                    encode: (Double) throws -> Double,
                                    decode: (Double) throws -> Double,
                                    tolerance: Double) throws -> Double {
        guard fixture.encode.count >= 12, fixture.decode.count >= 10,
              fixture.fullCodeData.map(\.bits) == [10, 12] else {
            throw Failure.mismatch("scalar coverage missing")
        }
        var maximum = 0.0
        for point in fixture.encode {
            maximum = max(maximum, scaled(try encode(point.input), point.expected))
        }
        for point in fixture.decode {
            maximum = max(maximum, scaled(try decode(point.input), point.expected))
        }
        for codes in fixture.fullCodeData {
            let maxCode = (1 << codes.bits) - 1
            guard codes.decoded.count == maxCode + 1 else {
                throw Failure.mismatch("full-code coverage missing")
            }
            for code in 0...maxCode {
                maximum = max(maximum,
                    scaled(try decode(Double(code) / Double(maxCode)), codes.decoded[code]))
            }
        }
        guard maximum <= tolerance else {
            throw Failure.mismatch("scalar error \(maximum) > \(tolerance)")
        }
        return maximum
    }

    private static func checkPlan(_ fixture: Fixture, transfer: TransferID) throws -> Double {
        guard fixture.planExposureOne.count == 8 else { throw Failure.mismatch("plan coverage") }
        let plan = try TransformPlan(settings: TransformSettings(
            inputTransfer: transfer, outputTransfer: transfer,
            inputSpace: .sonySGamut3Cine, outputSpace: .sonySGamut3Cine,
            inputRange: .data, outputRange: .data, exposureStops: 1))
        var maximum = 0.0
        for (index, point) in fixture.planExposureOne.enumerated() {
            guard point.input.count == 3, point.expected.count == 3 else {
                throw Failure.mismatch("plan RGB shape")
            }
            let input = try RGB64(point.input[0], point.input[1], point.input[2])
            let trace = try plan.trace(input, sampleIndex: index)
            guard trace.stages.map(\.id) == [1, 2, 3, 4, 10, 13, 19] else {
                throw Failure.mismatch("plan stage order")
            }
            for (value, expected) in zip([trace.output.r, trace.output.g, trace.output.b], point.expected) {
                maximum = max(maximum, scaled(value, expected))
            }
        }
        guard maximum <= 2e-12 else { throw Failure.mismatch("plan error \(maximum)") }
        return maximum
    }

    private static func checkCross(_ fixture: CrossFixture, sourceSpace: ColorSpaceID,
                                   sourcePrimaries: ColorPrimaries,
                                   sourceTransform: String) throws -> (Double, Double) {
        guard fixture.sourceTransformID ==
                "urn:ampas:aces:transformId:v2.0:CSC.Sony.SLog3_\(sourceTransform)_to_ACES.a2.v1",
              fixture.matrixColumnRowMajor.count == 9,
              fixture.cases.count == 10,
              fixture.scaledTolerance == 2e-12 else {
            throw Failure.mismatch("cross-space fixture coverage or threshold")
        }
        let matrix = try ColorPrimaries.conversion(
            from: sourcePrimaries, to: .acesAP0, adaptation: .cieCAT02)
        let matrixError = zip(matrix.rowMajor, fixture.matrixColumnRowMajor)
            .map { scaled($0.0, $0.1) }.max()!
        let plan = try TransformPlan(settings: TransformSettings(
            inputTransfer: .sonySLog3, outputTransfer: .linearScene,
            inputSpace: sourceSpace, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1))
        var planError = 0.0
        for (index, point) in fixture.cases.enumerated() {
            guard point.input.count == 3, point.outputLinearAP0.count == 3 else {
                throw Failure.mismatch("cross-space RGB shape")
            }
            let output = try plan.evaluate(
                RGB64(point.input[0], point.input[1], point.input[2]), sampleIndex: index)
            for (actual, expected) in zip([output.r, output.g, output.b], point.outputLinearAP0) {
                planError = max(planError, scaled(actual, expected))
            }
        }
        guard matrixError <= 2e-12, planError <= 2e-12 else {
            throw Failure.mismatch("cross-space matrix \(matrixError), plan \(planError)")
        }
        return (matrixError, planError)
    }
}
