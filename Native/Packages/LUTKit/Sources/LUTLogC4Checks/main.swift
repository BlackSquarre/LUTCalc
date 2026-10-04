import Foundation
import LUTCore
import LUTCatalog

private struct ScalarPoint: Decodable {
    let input: Double
    let expected: Double
}

private struct FullCode: Decodable {
    let bits: Int
    let decoded: [Double]
}

private struct RGBPoint: Decodable {
    let input: [Double]
    let outputLinearAP0: [Double]
}

private struct Fixture: Decodable {
    let sourceTransformID: String
    let scaledTolerance: Double
    let thresholdScene: Double
    let matrixAWG4ToAP0: [Double]
    let encode: [ScalarPoint]
    let decode: [ScalarPoint]
    let fullCodeData: [FullCode]
    let planExposureOne: [RGBPoint]
}

private enum Failure: Error { case mismatch(String) }

@main
struct LUTLogC4Checks {
    static func main() {
        do {
            guard CommandLine.arguments.count == 2 else { throw Failure.mismatch("fixture path") }
            let fixture = try JSONDecoder().decode(Fixture.self,
                from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
            guard fixture.sourceTransformID ==
                "urn:ampas:aces:transformId:v2.0:CSC.Arri.LogC4_to_ACES.a2.v1",
                fixture.scaledTolerance == 2e-12,
                fixture.encode.count >= 13,
                fixture.decode.count >= 11,
                fixture.fullCodeData.map(\.bits) == [10, 12],
                fixture.matrixAWG4ToAP0.count == 9,
                fixture.planExposureOne.count == 10 else {
                throw Failure.mismatch("version, coverage or frozen threshold")
            }
            var scalarError = 0.0
            for point in fixture.encode {
                scalarError = max(scalarError,
                    scaled(try LogC4Transfer.encodeSceneToData(point.input), point.expected))
            }
            for point in fixture.decode {
                scalarError = max(scalarError,
                    scaled(try LogC4Transfer.decodeDataToScene(point.input), point.expected))
            }
            for codes in fixture.fullCodeData {
                let maxCode = (1 << codes.bits) - 1
                guard codes.decoded.count == maxCode + 1 else {
                    throw Failure.mismatch("full code coverage")
                }
                for code in 0...maxCode {
                    scalarError = max(scalarError,
                        scaled(try LogC4Transfer.decodeDataToScene(Double(code) / Double(maxCode)),
                               codes.decoded[code]))
                }
            }
            guard scalarError <= fixture.scaledTolerance else {
                throw Failure.mismatch("scalar error \(scalarError)")
            }
            let matrix = try ColorPrimaries.conversion(from: .arriWideGamut4,
                to: .acesAP0, adaptation: .cieCAT02)
            let matrixError = zip(matrix.rowMajor, fixture.matrixAWG4ToAP0)
                .map { scaled($0.0, $0.1) }.max()!
            let plan = try TransformPlan(settings: TransformSettings(
                inputTransfer: .arriLogC4, outputTransfer: .linearScene,
                inputSpace: .arriWideGamut4, outputSpace: .acesAP0,
                inputRange: .data, outputRange: .data, exposureStops: 1))
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
            guard catalog.transfer(named: "LogC4")?.id == .arriLogC4,
                  catalog.colorSpace(named: "ARRI Wide Gamut 4")?.id == .arriWideGamut4,
                  catalog.preset(named: "arri.logc4-to-linear-ap0.v1")?.settings.inputTransfer == .arriLogC4 else {
                throw Failure.mismatch("catalog identity")
            }
            do {
                _ = try LogC4Transfer.decodeDataToScene(.infinity)
                throw Failure.mismatch("nonfinite accepted")
            } catch NumericError.nonFinite {}
            print("H11 ARRI LogC4 标量/10,12-bit 全码通过：最大尺度化误差 \(scalarError)")
            print("H11 AWG4→AP0 官方矩阵通过：最大尺度化误差 \(matrixError)")
            print("H11 LogC4→线性 AP0 曝光 +1 计划 10 点通过：最大尺度化误差 \(planError)")
        } catch {
            fputs("LUTLogC4Checks: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func scaled(_ actual: Double, _ expected: Double) -> Double {
        abs(actual - expected) / max(1, abs(expected))
    }
}
