import Foundation
import XCTest
import LUTCore
import LUTCatalog
import LUTProject
import LUTJobs
import LUTFormats
import LUTSharedUI

@MainActor final class CanonCLog2DocumentContractsTests: XCTestCase {
    private let tolerance = 2e-12
    private let matrix = [
        0.76306445477573395, 0.14902116113706039, 0.08791438408720566,
        0.003657456705123844, 1.106960380376215, -0.11061783708133881,
        -0.009407794045718891, -0.21838330498998712, 1.227791099035706,
    ]

    func testPublishedAndLegacy33And65CubeFilesAgainstIndependentFormula() async throws {
        let artifactFolder = ProcessInfo.processInfo.environment["LUTCALC_CANON_CLOG2_ARTIFACT_DIR"].map(URL.init(fileURLWithPath:))
        let folder = artifactFolder?.appendingPathComponent("cubes-" + UUID().uuidString, isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("canon-clog2-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer {
            if artifactFolder == nil { try? FileManager.default.removeItem(at: folder) }
        }
        let catalog = try AlgorithmCatalog.builtIn()
        var maximum = 0.0
        var channels = 0
        for (index, transfer) in [TransferID.canonCLog2, .canonCLog2LUTCalcLegacy].enumerated() {
            let settings = TransformSettings(inputTransfer: transfer, outputTransfer: .linearScene,
                                             inputSpace: .canonCinemaGamut, outputSpace: .acesAP0,
                                             inputRange: .data, outputRange: .data, exposureStops: 0)
            let document = try LUTProjectDocument(new: ProjectManifest(settings: settings, cubeSize: 33, domain: .unit))
            XCTAssertEqual(try ProjectCodec.decode(try ProjectCodec.encode(document.manifest, catalog: catalog), catalog: catalog), document.manifest)
            for size in [33, 65] {
                let output = folder.appendingPathComponent("case-\(index)-\(size).cube")
                let grid = try Grid3D(size: size, domain: .unit)
                let request = try LUTGenerationRequest(plan: TransformPlan(settings: settings), size: size,
                                                        domain: .unit, blockNodes: 4096, workerCount: 4)
                _ = try await NativeExportService().generate(request, to: output)
                let lut = try CubeParser.parse(Data(contentsOf: output))
                XCTAssertEqual(lut.samples.count, size * size * size)
                for (sampleIndex, actual) in lut.samples.enumerated() {
                    let coordinate = try grid.coordinate(at: sampleIndex)
                    let expected = try expectedSample(coordinate, transfer: transfer)
                    for channel in 0..<3 {
                        let error = abs(actual[channel] - expected[channel]) / max(1, abs(expected[channel]))
                        maximum = max(maximum, error); channels += 1
                        XCTAssertLessThanOrEqual(error, tolerance)
                    }
                }
            }
        }
        let result: [String: Any] = ["channels": channels, "maximumRelativeError": maximum, "threshold": tolerance]
        if let artifact = ProcessInfo.processInfo.environment["LUTCALC_CANON_CLOG2_ARTIFACT_DIR"] {
            let directory = URL(fileURLWithPath: artifact)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
            try data.write(to: directory.appendingPathComponent("cube-results.json"))
            try folder.path.data(using: .utf8)?.write(to: directory.appendingPathComponent("cube-directory.txt"))
        }
        print("Canon C-Log2 cubes: \(result)")
    }

    private func expectedSample(_ input: RGB64, transfer: TransferID) throws -> RGB64 {
        func decode(_ value: Double) -> Double {
            if transfer == .canonCLog2 {
                let linear = value < 0.092864125
                    ? -(pow(10, (0.092864125 - value) / 0.24136077) - 1) / 87.099375
                    : (pow(10, (value - 0.092864125) / 0.24136077) - 1) / 87.099375
                return 0.9 * linear
            }
            if value == 0 { return 0 }
            return value >= 0
                ? (pow(10, (value - 0.092864125) / 0.24136077) - 1) / 87.09937546 * 0.9
                : (0.045164984 * value - 0.006747091156) * 0.9
        }
        let scene = [decode(input.r), decode(input.g), decode(input.b)]
        return try RGB64(
            matrix[0] * scene[0] + matrix[1] * scene[1] + matrix[2] * scene[2],
            matrix[3] * scene[0] + matrix[4] * scene[1] + matrix[5] * scene[2],
            matrix[6] * scene[0] + matrix[7] * scene[1] + matrix[8] * scene[2]
        )
    }
}
