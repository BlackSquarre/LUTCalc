import Foundation
import XCTest
import LUTCore
import LUTFormats

final class LUTAnalysisFileContractsTests: XCTestCase {
    private func sampleFile() throws -> LUTAnalysisFile {
        let transfer = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                                   samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)], title: "分析")
        var colourSamples: [RGB64] = []
        for index in 0..<8 {
            let red = Double(index % 2)
            let green = Double((index / 2) % 2)
            let blue = Double(index / 4)
            colourSamples.append(try RGB64(red, green, blue))
        }
        let colour = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                                 samples: colourSamples, title: "分析")
        let metadata = LUTAnalysisSectionMetadata(inputTransferFunction: "S-Log3",
                                                   systemColourspace: "Sony S-Gamut3.cine",
                                                   inputColourspace: "Sony S-Gamut3.cine",
                                                   inputRange: "109", inputMinimum: 0,
                                                   inputMaximum: 1, interpolation: "tetrahedral",
                                                   baseISO: 800,
                                                   inputMatrix: try Matrix3x3(rowMajor: [1, 0.1, 0, 0, 1, 0, 0, 0.9, 0.1]))
        return LUTAnalysisFile(title: "分析", transferLUT: transfer, colourLUT: colour,
                               transferMetadata: metadata, colourMetadata: metadata,
                               sourceFormat: "lacube")
    }

    func testLACubeRoundTripPreservesSectionsAndMetadata() throws {
        let original = try sampleFile()
        let text = try LACubeWriter.serialize(original)
        let decoded = try LACubeParser.parse(Data(text.utf8))
        XCTAssertEqual(decoded.transferLUT.samples, original.transferLUT.samples)
        XCTAssertEqual(decoded.colourLUT?.samples, original.colourLUT?.samples)
        XCTAssertEqual(decoded.transferMetadata.inputTransferFunction, "S-Log3")
        XCTAssertEqual(decoded.transferMetadata.inputMatrix, original.transferMetadata.inputMatrix)
        XCTAssertEqual(decoded.colourMetadata?.interpolation, "tetrahedral")
    }

    func testLACubeRequiresOneDimensionalFirstSection() throws {
        let text = "LUT_3D_SIZE 2\n" + (0..<8).map { _ in "0 0 0" }.joined(separator: "\n") + "\n"
        XCTAssertThrowsError(try LACubeParser.parse(Data(text.utf8))) { error in
            XCTAssertEqual((error as? LUTAnalysisFailure)?.category, .invalidDimension)
        }
    }

    func testLABinRoundTripUsesLittleEndianAndRejectsLossySentinel() throws {
        let original = try sampleFile()
        let bytes = try LABinWriter.serialize(original)
        let decoded = try LABinParser.parse(bytes)
        XCTAssertEqual(decoded.transferLUT.size, 2)
        XCTAssertEqual(decoded.colourLUT?.size, 2)
        XCTAssertEqual(decoded.transferLUT.samples[1].r, 1, accuracy: 1e-9)
        let decodedMatrix = try XCTUnwrap(decoded.colourMetadata?.inputMatrix)
        let originalMatrix = try XCTUnwrap(original.colourMetadata?.inputMatrix)
        for index in 0..<9 { XCTAssertEqual(decodedMatrix.rowMajor[index], originalMatrix.rowMajor[index], accuracy: 2e-8) }

        var damaged = bytes
        damaged[8] = 0xF6; damaged[9] = 0x28; damaged[10] = 0x5C; damaged[11] = 0x7F
        XCTAssertThrowsError(try LABinParser.parse(damaged)) { error in
            XCTAssertEqual((error as? LUTAnalysisFailure)?.category, .lossyRepresentation)
        }
    }

    func testLABinRoundTripPreservesDistinctTransferAndColourMetadata() throws {
        let transfer = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                                   samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)])
        let colour = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                                 samples: (0..<8).map { _ in try RGB64(0.5, 0.5, 0.5) })
        let transferMetadata = LUTAnalysisSectionMetadata(
            inputTransferFunction: "S-Log3",
            systemColourspace: "Sony S-Gamut3.cine",
            inputRange: "100", inputMinimum: 0, inputMaximum: 1,
            interpolation: "tetrahedral", baseISO: 800)
        let colourMetadata = LUTAnalysisSectionMetadata(
            inputTransferFunction: "C-Log3",
            systemColourspace: "Sony S-Gamut3.cine",
            inputColourspace: "Canon Cinema Gamut",
            inputRange: "109", inputMinimum: -0.2, inputMaximum: 1.2,
            interpolation: "tetrahedral", baseISO: 800)
        let original = LUTAnalysisFile(title: nil, transferLUT: transfer, colourLUT: colour,
                                       transferMetadata: transferMetadata,
                                       colourMetadata: colourMetadata, sourceFormat: "labin")
        let decoded = try LABinParser.parse(try LABinWriter.serialize(original))
        XCTAssertEqual(decoded.transferMetadata.inputTransferFunction, "S-Log3")
        XCTAssertEqual(decoded.transferMetadata.inputRange, "100")
        XCTAssertEqual(decoded.transferMetadata.inputMinimum, 0)
        XCTAssertEqual(decoded.transferMetadata.inputMaximum, 1)
        let decodedColour = try XCTUnwrap(decoded.colourMetadata)
        XCTAssertEqual(decodedColour.inputTransferFunction, "C-Log3")
        XCTAssertEqual(decodedColour.inputColourspace, "Canon Cinema Gamut")
        XCTAssertEqual(decodedColour.inputRange, "109")
        XCTAssertEqual(decodedColour.inputMinimum, -0.2)
        XCTAssertEqual(decodedColour.inputMaximum, 1.2)
    }

    func testLABinRejectsTruncationAndMalformedMetadata() throws {
        XCTAssertThrowsError(try LABinParser.parse(Data([2, 0, 0, 0, 0, 0, 0]))) { error in
            XCTAssertEqual((error as? LUTAnalysisFailure)?.category, .truncated)
        }
        let lut = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                              samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)])
        let file = LUTAnalysisFile(title: nil, transferLUT: lut, colourLUT: nil,
                                   transferMetadata: LUTAnalysisSectionMetadata(),
                                   colourMetadata: nil, sourceFormat: "labin")
        var bytes = try LABinWriter.serialize(file)
        bytes.append(contentsOf: Array("A|B|C".utf8))
        XCTAssertThrowsError(try LABinParser.parse(bytes)) { error in
            XCTAssertEqual((error as? LUTAnalysisFailure)?.category, .invalidMetadata)
        }
    }

    func testAnalysisMetadataSemanticsPreserveRangeInterpolationAndBounds() throws {
        let metadata = LUTAnalysisSectionMetadata(inputRange: "109",
                                                   inputMinimum: -0.25,
                                                   inputMaximum: 1.25,
                                                   interpolation: "tetrahedral",
                                                   baseISO: 800)
        let semantics = try metadata.semantics()
        XCTAssertEqual(semantics.inputRange, .extended)
        XCTAssertEqual(semantics.interpolation, .tetrahedral)
        XCTAssertEqual(semantics.inputBounds, -0.25...1.25)
        XCTAssertEqual(semantics.baseISO, 800)

        let data = LUTAnalysisSectionMetadata(inputRange: "100")
        XCTAssertEqual(try data.semantics().inputRange, .data)
        XCTAssertEqual(try data.semantics().inputBounds, 0...1)
    }

    func testAnalysisMetadataSemanticsKeepUnknownValuesAndRejectInvalidBounds() throws {
        let unknown = LUTAnalysisSectionMetadata(inputRange: "camera-native",
                                                  interpolation: "unknown-method")
        let semantics = try unknown.semantics()
        XCTAssertEqual(semantics.inputRange, .unknown("camera-native"))
        XCTAssertEqual(semantics.interpolation, .unknown("unknown-method"))

        let reversed = LUTAnalysisSectionMetadata(inputMinimum: 1, inputMaximum: 0)
        XCTAssertThrowsError(try reversed.semantics()) { error in
            XCTAssertEqual(error as? LUTAnalysisMetadataError, .invalidBounds)
        }
        let incomplete = LUTAnalysisSectionMetadata(inputMinimum: .infinity)
        XCTAssertThrowsError(try incomplete.semantics()) { error in
            XCTAssertEqual(error as? LUTAnalysisMetadataError, .nonFiniteBounds)
        }
    }

    func testAnalysisQuantizationSemanticsAreExplicitForTextAndLegacyLABin() throws {
        let original = try sampleFile()
        XCTAssertEqual(original.quantizationSemantics,
                       .textualDouble)

        let bytes = try LABinWriter.serialize(original)
        let decoded = try LABinParser.parse(bytes)
        XCTAssertEqual(decoded.quantizationSemantics.kind, .legacyLABin)
        XCTAssertEqual(decoded.quantizationSemantics.sampleScale, 1_073_741_824.0)
        XCTAssertEqual(decoded.quantizationSemantics.matrixScale, 107_374_182.4)
        XCTAssertEqual(decoded.quantizationSemantics.lossySentinel, 2_136_746_230)
        XCTAssertEqual(decoded.quantizationSemantics.byteOrder, .littleEndian)
        XCTAssertEqual(decoded.quantizationSemantics.rounding, .floorPlusHalf)
    }

    func testAnalysisQuantizationSemanticsDoNotGuessUnknownSourceFormat() throws {
        let lut = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                              samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)])
        let file = LUTAnalysisFile(title: nil, transferLUT: lut, colourLUT: nil,
                                   transferMetadata: LUTAnalysisSectionMetadata(),
                                   colourMetadata: nil, sourceFormat: "vendor-binary")
        XCTAssertEqual(file.quantizationSemantics.kind, .unknown)
        XCTAssertNil(file.quantizationSemantics.sampleScale)
    }

    func testLegacyLABinFixtureIsParsedOrReportsLossyBoundary() throws {
        guard let path = ProcessInfo.processInfo.environment["LUTCALC_LABIN_SAMPLE"] else {
            throw XCTSkip("未提供旧 .labin 研发夹具")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        do {
            let parsed = try LABinParser.parse(data)
            XCTAssertGreaterThanOrEqual(parsed.transferLUT.size, 2)
            XCTAssertNotNil(parsed.transferMetadata.inputTransferFunction)
        } catch let error as LUTAnalysisFailure {
            XCTAssertEqual(error.category, .lossyRepresentation)
        }
    }
}
