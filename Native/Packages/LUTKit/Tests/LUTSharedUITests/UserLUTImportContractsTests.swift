import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTAnalysis
import LUTSharedUI

@MainActor
final class UserLUTImportContractsTests: XCTestCase {
    func testCubicSampleReportsActualSlopeChangesAndDiscardsStaleReports() throws {
        let lut = try CubeLUT(dimension: .one, size: 3, domain: .unit,
            samples: [RGB64(0,0,1), RGB64(0.25,0.5,0.5), RGB64(1,1,0)])
        let imported = ImportedUserLUT(url: URL(fileURLWithPath: "/tmp/cubic-report.cube"), format: .cube, lut: lut)
        let session = UserLUTImportSession()
        session.showStored(imported)
        _ = try session.sample(RGB64(0.25,0.25,0.25), interpolation: .tricubicLegacyV1, outside: .reject)
        XCTAssertEqual(session.cubicEndpointSlopes.count, 3)
        XCTAssertTrue(session.cubicEndpointSlopes[0].lower.modified)
        XCTAssertFalse(session.cubicEndpointSlopes[1].lower.modified)
        XCTAssertFalse(session.cubicEndpointSlopes[2].lower.modified)
        XCTAssertThrowsError(try session.sample(RGB64(-0.1,0.25,0.25), interpolation: .tricubicLegacyV1, outside: .reject))
        XCTAssertTrue(session.cubicEndpointSlopes.isEmpty)
        XCTAssertNil(session.sampleOutput)
        _ = try session.sample(RGB64(0.25,0.25,0.25), interpolation: .tricubicLegacyV1, outside: .reject)
        _ = try session.sample(RGB64(0.25,0.25,0.25), interpolation: .tetrahedral, outside: .reject)
        XCTAssertTrue(session.cubicEndpointSlopes.isEmpty)
        _ = try session.sample(RGB64(0.25,0.25,0.25), interpolation: .tricubicLegacyV1, outside: .reject)
        session.showStored(imported)
        XCTAssertTrue(session.cubicEndpointSlopes.isEmpty)
        _ = try session.sample(RGB64(0.25,0.25,0.25), interpolation: .tricubicLegacyV1, outside: .reject)
        session.clear()
        XCTAssertTrue(session.cubicEndpointSlopes.isEmpty)
    }

    func testSupportedUserFilesAndDirectNumericSample() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-user-lut-import-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cases: [(String, String, UserLUTFormat)] = [
            ("cube", "LUT_1D_SIZE 2\n0 0 0\n1 2 3\n", .cube),
            ("spi1d", "Version 1\nLength 2\nComponents 3\n{\n0 0 0\n1 2 3\n}\n", .spi1d),
            ("spi3d", "SPILUT 1.0\n3 3\n2 2 2\n" + (0..<2).flatMap { red in
                (0..<2).flatMap { green in
                    (0..<2).map { blue in "\(red) \(green) \(blue) \(red) \(green) \(blue)" }
                }
                }.joined(separator: "\n") + "\n", .spi3d),
            ("olut", (0..<4096).map { "\($0),\($0),\($0),\($0),\($0),\($0)" }.joined(separator: "\n") + "\n", .olut),
            ("lut", "LUT: 3 2\n0\n1\n0\n2\n0\n3\n", .assimilate),
        ]
        let loader = NativeUserLUTLoader()
        for (extensionName, contents, format) in cases {
            let url = directory.appendingPathComponent("sample.\(extensionName)")
            try contents.write(to: url, atomically: true, encoding: .utf8)
            let imported = try await loader.load(url)
            XCTAssertEqual(imported.format, format)
            XCTAssertEqual(imported.url, url)
            XCTAssertEqual(imported.lut.size, format == .olut ? 4096 : 2)
            let input = try RGB64(0.5, 0.25, 0.75)
            let output = try imported.sample(input, interpolation: .tetrahedral, outside: .reject)
            if format == .spi3d {
                XCTAssertEqual(output.r, input.r, accuracy: 1e-15)
                XCTAssertEqual(output.g, input.g, accuracy: 1e-15)
                XCTAssertEqual(output.b, input.b, accuracy: 1e-15)
            } else if format == .olut {
                XCTAssertEqual(output.r, 0.5, accuracy: 1e-12)
                XCTAssertEqual(output.g, 0.25, accuracy: 1e-12)
                XCTAssertEqual(output.b, 0.75, accuracy: 1e-12)
            } else if format == .assimilate {
                XCTAssertEqual(output.r, 0.5, accuracy: 1e-15)
                XCTAssertEqual(output.g, 0.5, accuracy: 1e-15)
                XCTAssertEqual(output.b, 2.25, accuracy: 1e-15)
            } else {
                XCTAssertEqual(output.r, 0.5, accuracy: 1e-15)
                XCTAssertEqual(output.g, 0.5, accuracy: 1e-15)
                XCTAssertEqual(output.b, 2.25, accuracy: 1e-15)
            }
        }
        let unknown = directory.appendingPathComponent("sample.bin")
        try Data("SPILUT 1.0".utf8).write(to: unknown)
        await XCTAssertThrowsErrorAsync(try await loader.load(unknown)) { error in
            XCTAssertEqual(error as? UserLUTImportError, .unsupportedExtension)
        }
        let otherLUT = directory.appendingPathComponent("other.lut")
        try Data("3D Mesh\n0 0 0\n".utf8).write(to: otherLUT)
        await XCTAssertThrowsErrorAsync(try await loader.load(otherLUT)) { error in
            XCTAssertEqual((error as? AssimilateLUTFailure)?.category, .malformedHeader)
        }
    }

    func testLatestSelectionOwnsResultAndCloseDiscardsLateReturn() async throws {
        let loader = ControlledLUTLoader()
        let session = UserLUTImportSession(loader: loader)
        let first = URL(fileURLWithPath: "/tmp/lutcalc-first.cube")
        let second = URL(fileURLWithPath: "/tmp/lutcalc-second.cube")
        XCTAssertTrue(session.startLoading(first))
        XCTAssertTrue(session.startLoading(second))
        let lut = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                              samples: [RGB64(0, 0, 0), RGB64(1, 2, 3)])
        await loader.complete(url: second, value: ImportedUserLUT(url: second, format: .cube, lut: lut))
        await session.waitForCurrentLoad()
        XCTAssertEqual(session.imported?.url, second)
        let output = try session.sample(try RGB64(0.5, 0.5, 0.5),
                                        interpolation: .trilinear, outside: .reject)
        XCTAssertEqual(output, try RGB64(0.5, 1, 1.5))
        await loader.complete(url: first, value: ImportedUserLUT(url: first, format: .cube, lut: lut))
        await session.waitForPendingLoads()
        XCTAssertEqual(session.imported?.url, second)
        session.close()
        XCTAssertNil(session.imported)
        XCTAssertEqual(session.loadStatus, .closed)
    }

    func testAdditionalNativeFormatsAreAvailableForReadOnlySampling() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-user-lut-expanded-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let flameSamples: [RGB64] = try (0..<8).map { index in
            let red = Double(index % 2)
            let green = Double((index / 2) % 2)
            let blue = Double(index / 4)
            return try RGB64(red, green, blue)
        }
        let cube3D = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                                 samples: flameSamples)
        let flame = directory.appendingPathComponent("sample.3dl")
        try ThreeDLWriter.serialize(cube3D, inputBits: 10, outputBits: 12, flavor: .flame)
            .write(to: flame, atomically: true, encoding: .utf8)

        let ilut = directory.appendingPathComponent("sample.ilut")
        let ilutText = (0..<ILUTParser.size).map { "\($0),\($0),\($0),0" }.joined(separator: "\n") + "\n"
        try ilutText.write(to: ilut, atomically: true, encoding: .utf8)

        let vlt = directory.appendingPathComponent("sample.vlt")
        let vltSamples = try (0..<(VLTParser.size * VLTParser.size * VLTParser.size)).map { index in
            try RGB64(Double(index % 17) / 16, Double((index / 17) % 17) / 16,
                      Double(index / (17 * 17)) / 16)
        }
        let vltCube = try CubeLUT(dimension: .three, size: VLTParser.size,
                                  domain: .unit, samples: vltSamples)
        try VLTWriter.serialize(vltCube).write(to: vlt, atomically: true, encoding: .utf8)

        let loader = NativeUserLUTLoader()
        let cases: [(URL, UserLUTFormat, CubeDimension, Int)] = [
            (flame, .threeDL, .three, 2),
            (ilut, .ilut, .one, ILUTParser.size),
            (vlt, .vlt, .three, VLTParser.size),
        ]
        for (url, format, dimension, size) in cases {
            let imported = try await loader.load(url)
            XCTAssertEqual(imported.format, format)
            XCTAssertEqual(imported.lut.dimension, dimension)
            XCTAssertEqual(imported.lut.size, size)
            let output = try imported.sample(try RGB64(1, 0, 0),
                                             interpolation: .tetrahedral, outside: .reject)
            XCTAssertEqual(output, try RGB64(1, 0, 0))
        }
    }

    func testLustreThreeDLIsDiscoveredByTheNativeImporter() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-user-lustre-(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let size = 9
        let samples = try (0..<(size * size * size)).map { index in
            try RGB64(Double(index) / Double(size * size * size - 1), 0, 1)
        }
        let cube = try CubeLUT(dimension: .three, size: size, domain: .unit, samples: samples)
        let url = directory.appendingPathComponent("lustre.3dl")
        try ThreeDLWriter.serialize(cube, inputBits: 10, outputBits: 12, flavor: .lustre)
            .write(to: url, atomically: true, encoding: .utf8)
        let imported = try await NativeUserLUTLoader().load(url)
        XCTAssertEqual(imported.format, .threeDL)
        XCTAssertEqual(imported.lut.dimension, .three)
        XCTAssertEqual(imported.lut.size, size)
    }

    func testLUTAnalystFormatsExposeAnalysisPayload() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-analysis-import-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let transfer = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                                   samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)], title: "分析")
        let analysis = LUTAnalysisFile(title: "分析", transferLUT: transfer, colourLUT: nil,
                                       transferMetadata: LUTAnalysisSectionMetadata(inputTransferFunction: "S-Log3"),
                                       colourMetadata: nil, sourceFormat: "lacube")
        let lacubeURL = directory.appendingPathComponent("sample.lacube")
        try LACubeWriter.serialize(analysis).write(to: lacubeURL, atomically: true, encoding: .utf8)
        let labinURL = directory.appendingPathComponent("sample.labin")
        try LABinWriter.serialize(analysis).write(to: labinURL)

        let loader = NativeUserLUTLoader()
        let lacube = try await loader.load(lacubeURL)
        XCTAssertEqual(lacube.format, .lacube)
        XCTAssertEqual(lacube.analysis?.transferMetadata.inputTransferFunction, "S-Log3")
        XCTAssertNil(lacube.analysis?.colourLUT)
        let labin = try await loader.load(labinURL)
        XCTAssertEqual(labin.format, .labin)
        XCTAssertEqual(labin.analysis?.transferLUT.samples.count, 2)
    }

    func testAnalysisSessionReportResetsAcrossStoredSelectionAndClear() throws {
        let one = try CubeLUT(dimension: .one, size: 3, domain: .unit,
                              samples: [RGB64(0, 0, 0), RGB64(0.5, 0.5, 1), RGB64(1, 0.5, 0)])
        let three = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                                samples: (0..<8).map { _ in try RGB64(0.5, 0.5, 0.5) })
        let session = UserLUTImportSession()
        session.showStored(ImportedUserLUT(url: URL(fileURLWithPath: "/tmp/one.cube"),
                                            format: .cube, lut: one))
        let report = try session.inspectStructure()
        XCTAssertEqual(report.transfer?.green.flatSegmentIndices, [1])
        XCTAssertFalse(try XCTUnwrap(report.transfer).isInvertibleBySingleValue)
        XCTAssertNotNil(session.analysisReport)
        session.showStored(ImportedUserLUT(url: URL(fileURLWithPath: "/tmp/three.cube"),
                                            format: .cube, lut: three))
        XCTAssertNil(session.analysisReport)
        XCTAssertEqual(try session.inspectStructure().colourInverse, .requiresExplicitModel)
        session.clear()
        XCTAssertNil(session.analysisReport)
        XCTAssertThrowsError(try session.inspectStructure()) {
            XCTAssertEqual($0 as? UserLUTImportError, .noImportedLUT)
        }
    }

    func testSessionInverseUsesCurrentImportedOneDimensionalLUTOnly() throws {
        let one = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                              samples: [RGB64(0, 0, 0), RGB64(1, 2, 3)])
        let three = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                                samples: (0..<8).map { _ in try RGB64(0.5, 0.5, 0.5) })
        let session = UserLUTImportSession()
        session.showStored(ImportedUserLUT(url: URL(fileURLWithPath: "/tmp/one.cube"),
                                            format: .cube, lut: one))
        XCTAssertEqual(try session.inverseTransfer(RGB64(0.25, 1, 2.25)),
                       try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(session.inverseInput, try RGB64(0.25, 0.5, 0.75))
        session.showStored(ImportedUserLUT(url: URL(fileURLWithPath: "/tmp/three.cube"),
                                            format: .cube, lut: three))
        XCTAssertNil(session.inverseInput)
        XCTAssertThrowsError(try session.inverseTransfer(RGB64(0.5, 0.5, 0.5))) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .noTransferLUT)
        }
        session.close()
        XCTAssertNil(session.inverseOutput)
        XCTAssertThrowsError(try session.inverseTransfer(RGB64(0.5, 0.5, 0.5))) {
            XCTAssertEqual($0 as? UserLUTImportError, .closed)
        }
    }

    func testAnalysisFileColourSectionSamplingIsExplicitAndIndependent() throws {
        let transfer = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                                   samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)])
        let colourSamples: [RGB64] = try (0..<8).map { index in
            let red = Double(index % 2) * 0.5
            let green = Double((index / 2) % 2) * 0.25
            let blue = Double(index / 4) * 0.75
            return try RGB64(red, green, blue)
        }
        let colour = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                                 samples: colourSamples)
        let file = LUTAnalysisFile(title: nil, transferLUT: transfer, colourLUT: colour,
                                   transferMetadata: .init(), colourMetadata: .init(), sourceFormat: "lacube")
        let imported = ImportedUserLUT(url: URL(fileURLWithPath: "/tmp/a.lacube"),
                                        format: .lacube, lut: transfer, analysis: file)
        let input = try RGB64(1, 1, 1)
        XCTAssertEqual(try imported.sample(input, interpolation: .tetrahedral, outside: .reject),
                       try RGB64(1, 1, 1))
        XCTAssertEqual(try imported.sample(input, interpolation: .tetrahedral, outside: .reject,
                                           section: .colour), try RGB64(0.5, 0.25, 0.75))
        let session = UserLUTImportSession()
        session.showStored(imported)
        XCTAssertEqual(try session.sample(input, interpolation: .tetrahedral, outside: .reject,
                                          section: .colour), try RGB64(0.5, 0.25, 0.75))
        XCTAssertEqual(session.sampleSection, .colour)
        session.clear()
        XCTAssertNil(session.sampleSection)
        let plain = ImportedUserLUT(url: URL(fileURLWithPath: "/tmp/plain.cube"),
                                    format: .cube, lut: transfer)
        XCTAssertThrowsError(try plain.sample(input, interpolation: .tetrahedral, outside: .reject,
                                               section: .colour)) {
            XCTAssertEqual($0 as? UserLUTImportError, .noColourSection)
        }
    }
}

private actor ControlledLUTLoader: UserLUTLoading {
    private var waiting: [URL: CheckedContinuation<ImportedUserLUT, Error>] = [:]
    private var ready: [URL: ImportedUserLUT] = [:]

    func load(_ url: URL) async throws -> ImportedUserLUT {
        if let value = ready.removeValue(forKey: url) { return value }
        return try await withCheckedThrowingContinuation { continuation in
            waiting[url] = continuation
        }
    }

    func complete(url: URL, value: ImportedUserLUT) {
        if let continuation = waiting.removeValue(forKey: url) {
            continuation.resume(returning: value)
        } else {
            ready[url] = value
        }
    }
}

@MainActor
private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ handler: (Error) -> Void
) async {
    do { _ = try await expression(); XCTFail("Expected an error") }
    catch { handler(error) }
}
