import XCTest
import LUTCore
import LUTFormats
import LUTAnalysis
import LUTSharedUI
@testable import LUTJobs

final class UserLUTInverseExportContractsTests: XCTestCase {
    private func plan() throws -> TransformPlan {
        try TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .acesAP0, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 0))
    }

    private func inverse() throws -> ImportedLUTInversePlan {
        let lut = try CubeLUT(dimension: .one, size: 4, domain: .unit,
                              samples: [RGB64(0, 0, 0), RGB64(0.25, 0.25, 0.25),
                                        RGB64(0.75, 0.75, 0.75), RGB64(1, 1, 1)])
        return try ImportedLUTInversePlan(lut: lut, analysisFile: nil,
                                          interpolation: .tricubicLegacyV1)
    }

    func testExposureBatchCarriesInputInverseIntoEveryItemAndFingerprint() throws {
        let base = try LUTGenerationRequest(plan: plan(), size: 3, domain: .unit,
                                            workerCount: 1, inputTransferInverse: inverse())
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-inverse-batch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = try ExposureBatchSettings(minimumStops: 0, maximumStops: 1, subdivisions: 1)
        let request = try ExposureBatchRequest(base: base, settings: settings,
                                               directory: directory, basename: "inverse", format: .cube)
        XCTAssertEqual(request.items.count, 2)
        XCTAssertTrue(request.items.allSatisfy { $0.request.inputTransferInverse != nil })
        let plain = try ExposureBatchRequest(
            base: LUTGenerationRequest(plan: plan(), size: 3, domain: .unit, workerCount: 1),
            settings: settings, directory: directory, basename: "inverse", format: .cube)
        XCTAssertNotEqual(request.fingerprint, plain.fingerprint)
    }

    func testOneDimensionalExportRejectsInputInverseInsteadOfDroppingIt() async throws {
        let request = try LUTGenerationRequest(plan: plan(), size: 3, domain: .unit,
                                                workerCount: 1, inputTransferInverse: inverse())
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-inverse-reject-\(UUID().uuidString).spi1d")
        defer { try? FileManager.default.removeItem(at: output) }
        do {
            _ = try await NativeExportService().generate(request, to: output)
            XCTFail("一维导出不得静默丢弃输入反求")
        } catch let error as SPI1DFailure {
            XCTAssertEqual(error.category, .lossyRepresentation)
        }
    }

    func testLabinDirectionAndQuantizedSamplesReachThreeDimensionalCubeExport() async throws {
        let transfer = try CubeLUT(dimension: .one, size: 4, domain: .unit,
                                   samples: [RGB64(1, 1, 1), RGB64(0.75, 0.75, 0.75),
                                             RGB64(0.25, 0.25, 0.25), RGB64(0, 0, 0)])
        let metadata = LUTAnalysisSectionMetadata(inputTransferFunction: "descending-test",
                                                   inputRange: "109", inputMinimum: 0,
                                                   inputMaximum: 1, interpolation: "tricubic")
        let source = LUTAnalysisFile(title: nil, transferLUT: transfer, colourLUT: nil,
                                     transferMetadata: metadata, colourMetadata: nil,
                                     sourceFormat: "labin")
        let decoded = try LABinParser.parse(LABinWriter.serialize(source))
        XCTAssertEqual(decoded.quantizationSemantics.kind, .legacyLABin)
        XCTAssertEqual(try decoded.transferMetadata.semantics().inputRange, .extended)

        let inversePlan = try ImportedLUTInversePlan(lut: decoded.transferLUT,
                                                      analysisFile: decoded,
                                                      interpolation: .tricubicLegacyV1)
        XCTAssertEqual(inversePlan.metadata?.transfer.inputRange, .extended)
        XCTAssertEqual(inversePlan.metadata?.transfer.interpolation, .tricubic)
        XCTAssertEqual(inversePlan.metadata?.quantization.kind, .legacyLABin)

        let request = try LUTGenerationRequest(plan: plan(), size: 3, domain: .unit,
                                              workerCount: 1,
                                              inputTransferInverse: inversePlan)
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-labin-inverse-\(UUID().uuidString).cube")
        defer { try? FileManager.default.removeItem(at: output) }
        _ = try await NativeExportService().generate(request, to: output)

        let exported = try CubeParser.parse(Data(contentsOf: output))
        XCTAssertEqual(exported.dimension, .three)
        XCTAssertEqual(exported.size, 3)
        let grid = try Grid3D(size: 3, domain: .unit)
        var maximumAbsoluteError = 0.0
        for index in 0..<grid.nodeCount {
            let coordinate = try grid.coordinate(at: index)
            let sample = exported.samples[index]
            for channel in 0..<3 {
                let error = abs(sample[channel] - (1 - coordinate[channel]))
                maximumAbsoluteError = max(maximumAbsoluteError, error)
                XCTAssertLessThanOrEqual(error, 2e-12)
            }
        }
        print("LABin 量化下降 transfer 到 3D CUBE 反求最大绝对误差：\(maximumAbsoluteError)")
    }
}
