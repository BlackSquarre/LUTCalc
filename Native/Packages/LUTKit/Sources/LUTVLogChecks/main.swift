import Foundation
import LUTCore
import LUTCatalog

private struct ScalarPoint: Decodable { let input: Double; let expected: Double }
private struct FullCode: Decodable { let bits: Int; let decoded: [Double] }
private struct RGBPoint: Decodable { let input: [Double]; let outputLinearAP0: [Double] }
private struct Fixture: Decodable {
    let sourceTransformID: String
    let scaledTolerance: Double
    let matrixVGamutToAP0Bradford: [Double]
    let manualPublishedMatrix: [Double]
    let encode: [ScalarPoint]
    let decode: [ScalarPoint]
    let fullCodeData: [FullCode]
    let planExposureOne: [RGBPoint]
}
private enum Failure: Error { case mismatch(String) }

@main
struct LUTVLogChecks {
    static func main() {
        do {
            guard CommandLine.arguments.count == 2 else { throw Failure.mismatch("fixture path") }
            let fixture = try JSONDecoder().decode(Fixture.self,
                from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
            guard fixture.sourceTransformID ==
                "urn:ampas:aces:transformId:v2.0:CSC.Panasonic.VLog_VGamut_to_ACES.a2.v1",
                fixture.scaledTolerance == 2e-12,
                fixture.encode.count >= 10,
                fixture.decode.count >= 8,
                fixture.fullCodeData.map(\.bits) == [10, 12],
                fixture.matrixVGamutToAP0Bradford.count == 9,
                fixture.planExposureOne.count == 10 else {
                throw Failure.mismatch("version, coverage or frozen threshold")
            }
            var scalarError = 0.0
            for point in fixture.encode {
                scalarError = max(scalarError,
                    scaled(try VLogTransfer.encodeSceneToData(point.input), point.expected))
            }
            for point in fixture.decode {
                scalarError = max(scalarError,
                    scaled(try VLogTransfer.decodeDataToScene(point.input), point.expected))
            }
            for codes in fixture.fullCodeData {
                let highest = (1 << codes.bits) - 1
                guard codes.decoded.count == highest + 1 else {
                    throw Failure.mismatch("full code coverage")
                }
                for code in 0...highest {
                    scalarError = max(scalarError, scaled(
                        try VLogTransfer.decodeDataToScene(Double(code) / Double(highest)),
                        codes.decoded[code]))
                }
            }
            guard scalarError <= fixture.scaledTolerance else {
                throw Failure.mismatch("scalar error \(scalarError)")
            }
            let matrix = try ColorPrimaries.conversion(from: .panasonicVGamut,
                to: .acesAP0, adaptation: .bradford)
            let matrixError = zip(matrix.rowMajor, fixture.matrixVGamutToAP0Bradford)
                .map { scaled($0.0, $0.1) }.max()!
            let publishedDelta = zip(matrix.rowMajor, fixture.manualPublishedMatrix)
                .map { abs($0.0 - $0.1) }.max()!
            guard publishedDelta > 1e-4, publishedDelta < 3e-4 else {
                throw Failure.mismatch("manual rounded matrix discrepancy changed \(publishedDelta)")
            }
            let plan = try TransformPlan(settings: TransformSettings(
                inputTransfer: .panasonicVLog, outputTransfer: .linearScene,
                inputSpace: .panasonicVGamut, outputSpace: .acesAP0,
                inputRange: .data, outputRange: .data, exposureStops: 1,
                adaptation: .bradford))
            let encodedSettings = try JSONEncoder().encode(plan.settings)
            guard String(decoding: encodedSettings, as: UTF8.self).contains("\"adaptation\":\"bradford\""),
                  try JSONDecoder().decode(TransformSettings.self, from: encodedSettings) == plan.settings else {
                throw Failure.mismatch("Bradford setting serialization")
            }
            let defaultSettings = TransformSettings(
                inputTransfer: .linearScene, outputTransfer: .linearScene,
                inputSpace: .srgb, outputSpace: .srgb,
                inputRange: .data, outputRange: .data, exposureStops: 0)
            let defaultBytes = try JSONEncoder().encode(defaultSettings)
            guard !String(decoding: defaultBytes, as: UTF8.self).contains("adaptation"),
                  try JSONDecoder().decode(TransformSettings.self, from: defaultBytes) == defaultSettings else {
                throw Failure.mismatch("legacy CAT02 setting serialization")
            }
            var planError = 0.0
            for (index, point) in fixture.planExposureOne.enumerated() {
                guard point.input.count == 3, point.outputLinearAP0.count == 3 else {
                    throw Failure.mismatch("RGB shape")
                }
                let output = try plan.evaluate(
                    RGB64(point.input[0], point.input[1], point.input[2]), sampleIndex: index)
                for (actual, expected) in zip([output.r, output.g, output.b], point.outputLinearAP0) {
                    planError = max(planError, scaled(actual, expected))
                }
            }
            guard matrixError <= fixture.scaledTolerance,
                  planError <= fixture.scaledTolerance else {
                throw Failure.mismatch("matrix \(matrixError), plan \(planError)")
            }
            let catalog = try AlgorithmCatalog.builtIn()
            guard catalog.transfer(named: "V-Log")?.id == .panasonicVLog,
                  catalog.colorSpace(named: "V-Gamut")?.id == .panasonicVGamut,
                  catalog.preset(named: "panasonic.vlog-to-linear-ap0.v1")?.settings.adaptation == .bradford else {
                throw Failure.mismatch("catalog identity")
            }
            do {
                _ = try VLogTransfer.decodeDataToScene(.infinity)
                throw Failure.mismatch("nonfinite accepted")
            } catch NumericError.nonFinite {}
            print("H11 Panasonic V-Log 标量/10,12-bit 全码通过：最大尺度化误差 \(scalarError)")
            print("H11 V-Gamut→AP0 Bradford 矩阵通过：最大尺度化误差 \(matrixError)，手册公布矩阵差 \(publishedDelta)")
            print("H11 V-Log→线性 AP0 曝光 +1 计划 10 点通过：最大尺度化误差 \(planError)")
        } catch {
            fputs("LUTVLogChecks: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func scaled(_ actual: Double, _ expected: Double) -> Double {
        abs(actual - expected) / max(1, abs(expected))
    }
}
