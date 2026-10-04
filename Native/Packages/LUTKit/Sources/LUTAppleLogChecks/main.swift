import Foundation
import LUTCore
import LUTCatalog

private struct ScalarPoint: Decodable { let input: Double; let expected: Double }
private struct FullCode: Decodable { let bits: Int; let decoded: [Double] }
private struct RGBPoint: Decodable { let input: [Double]; let outputLinearAP0: [Double] }
private struct Variant: Decodable {
    let sourceTransformID: String
    let matrixToAP0Bradford: [Double]
    let planExposureOne: [RGBPoint]
}
private struct Fixture: Decodable {
    let scaledTolerance: Double
    let encode: [ScalarPoint]
    let decode: [ScalarPoint]
    let fullCodeData: [FullCode]
    let variants: [String: Variant]
}
private enum Failure: Error { case mismatch(String) }

@main
struct LUTAppleLogChecks {
    static func main() {
        do {
            guard CommandLine.arguments.count == 2 else { throw Failure.mismatch("fixture path") }
            let fixture = try JSONDecoder().decode(Fixture.self,
                from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
            guard fixture.scaledTolerance == 2e-12,
                  fixture.encode.count >= 10, fixture.decode.count >= 7,
                  fixture.fullCodeData.map(\.bits) == [10, 12],
                  Set(fixture.variants.keys) == ["original", "log2"] else {
                throw Failure.mismatch("coverage or frozen threshold")
            }
            var scalarError = 0.0
            for point in fixture.encode {
                scalarError = max(scalarError,
                    scaled(try AppleLogTransfer.encodeSceneToData(point.input), point.expected))
            }
            for point in fixture.decode {
                scalarError = max(scalarError,
                    scaled(try AppleLogTransfer.decodeDataToScene(point.input), point.expected))
            }
            for codes in fixture.fullCodeData {
                let highest = (1 << codes.bits) - 1
                guard codes.decoded.count == highest + 1 else {
                    throw Failure.mismatch("full code coverage")
                }
                for code in 0...highest {
                    scalarError = max(scalarError, scaled(
                        try AppleLogTransfer.decodeDataToScene(Double(code) / Double(highest)),
                        codes.decoded[code]))
                }
            }
            guard scalarError <= fixture.scaledTolerance else {
                throw Failure.mismatch("scalar error \(scalarError)")
            }
            for name in ["original", "log2"] {
                let variant = fixture.variants[name]!
                let transfer: TransferID = name == "original" ? .appleLogOriginal : .appleLog2
                let space: ColorSpaceID = name == "original" ? .rec2020 : .appleWideGamut
                let expectedID = "urn:ampas:aces:transformId:v2.0:CSC.Apple.\(name == "original" ? "AppleLog" : "AppleLog2")_to_ACES.a2.v1"
                guard variant.sourceTransformID == expectedID,
                      variant.matrixToAP0Bradford.count == 9,
                      variant.planExposureOne.count == 10 else {
                    throw Failure.mismatch("variant source or coverage \(name)")
                }
                let matrix = try ColorPrimaries.conversion(
                    from: name == "original" ? .rec2020 : .appleWideGamut,
                    to: .acesAP0, adaptation: .bradford)
                let matrixError = zip(matrix.rowMajor, variant.matrixToAP0Bradford)
                    .map { scaled($0.0, $0.1) }.max()!
                let plan = try TransformPlan(settings: TransformSettings(
                    inputTransfer: transfer, outputTransfer: .linearScene,
                    inputSpace: space, outputSpace: .acesAP0,
                    inputRange: .data, outputRange: .data, exposureStops: 1,
                    adaptation: .bradford))
                var planError = 0.0
                for (index, point) in variant.planExposureOne.enumerated() {
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
                    throw Failure.mismatch("\(name) matrix \(matrixError), plan \(planError)")
                }
                print("H11 Apple \(name) Bradford 矩阵最大尺度化误差 \(matrixError)，10 点计划 \(planError)")
            }
            let catalog = try AlgorithmCatalog.builtIn()
            guard catalog.transfer(named: "Apple Log")?.id == .appleLogOriginal,
                  catalog.transfer(named: "Apple Log 2")?.id == .appleLog2,
                  catalog.colorSpace(named: "Rec.2020")?.id == .rec2020,
                  catalog.colorSpace(named: "Apple Wide Gamut")?.id == .appleWideGamut,
                  catalog.preset(named: "apple.log2-to-linear-ap0.v1")?.settings.adaptation == .bradford else {
                throw Failure.mismatch("catalog identity")
            }
            do {
                _ = try AppleLogTransfer.decodeDataToScene(.nan)
                throw Failure.mismatch("nonfinite accepted")
            } catch NumericError.nonFinite {}
            print("H11 Apple Log/Log 2 共用官方标量与 10/12-bit 全码通过：最大尺度化误差 \(scalarError)")
        } catch {
            fputs("LUTAppleLogChecks: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func scaled(_ actual: Double, _ expected: Double) -> Double {
        abs(actual - expected) / max(1, abs(expected))
    }
}
