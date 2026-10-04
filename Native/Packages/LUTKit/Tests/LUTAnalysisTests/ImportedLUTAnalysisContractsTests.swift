import XCTest
import LUTCore
import LUTFormats
@testable import LUTAnalysis

final class ImportedLUTAnalysisContractsTests: XCTestCase {
    func testIndependent1DChannelsReportStrictFlatAndReversalWithoutChangingSamples() throws {
        let samples = try [
            RGB64(0, 0, 0), RGB64(0.25, 0.5, 0.8),
            RGB64(0.5, 0.5, 0.3), RGB64(1, 1, 1),
        ]
        let lut = try CubeLUT(dimension: .one, size: 4, domain: .unit, samples: samples)
        let report = try ImportedLUTAnalyzer.analyze(lut: lut, analysisFile: nil)
        let channels = try XCTUnwrap(report.transfer)
        XCTAssertEqual(channels.red.direction, .increasing)
        XCTAssertTrue(channels.red.isInvertibleBySingleValue)
        XCTAssertEqual(channels.green.flatSegmentIndices, [1])
        XCTAssertFalse(channels.green.isInvertibleBySingleValue)
        XCTAssertEqual(channels.blue.direction, .nonMonotonic)
        XCTAssertEqual(channels.blue.reversalIndices, [2, 3])
        XCTAssertFalse(channels.blue.isInvertibleBySingleValue)
        XCTAssertFalse(channels.isInvertibleBySingleValue)
        XCTAssertFalse(report.hasColourLUT)
        XCTAssertEqual(lut.samples, samples)
    }

    func testAnalysisFileKeepsTransferAndColourSectionsDistinct() throws {
        let transfer = try CubeLUT(dimension: .one, size: 4, domain: .unit,
                                   samples: [RGB64(0, 0, 0), RGB64(0.25, 0.25, 0.25),
                                             RGB64(0.75, 0.75, 0.75), RGB64(1, 1, 1)])
        let colour = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                                 samples: (0..<8).map { _ in try RGB64(0.5, 0.5, 0.5) })
        let metadata = LUTAnalysisSectionMetadata(inputRange: "109",
                                                   inputMinimum: -0.25,
                                                   inputMaximum: 1.25,
                                                   interpolation: "tetrahedral")
        let file = LUTAnalysisFile(title: nil, transferLUT: transfer, colourLUT: colour,
                                   transferMetadata: metadata, colourMetadata: metadata, sourceFormat: "lacube")
        let report = try ImportedLUTAnalyzer.analyze(lut: transfer, analysisFile: file)
        XCTAssertNotNil(report.transfer)
        XCTAssertTrue(report.hasColourLUT)
        XCTAssertEqual(report.colourInverse, .requiresExplicitModel)
        let reportMetadata = try XCTUnwrap(report.metadata)
        XCTAssertEqual(reportMetadata.transfer.inputRange, .extended)
        XCTAssertEqual(reportMetadata.transfer.inputBounds, -0.25...1.25)
        XCTAssertEqual(reportMetadata.transfer.interpolation, .tetrahedral)
        XCTAssertEqual(try XCTUnwrap(reportMetadata.colour).inputRange, .extended)
        XCTAssertEqual(reportMetadata.quantization, .textualDouble)
    }

    func testAnalysisRejectsInvalidMetadataBeforeProducingAReport() throws {
        let transfer = try CubeLUT(dimension: .one, size: 4, domain: .unit,
                                   samples: [RGB64(0, 0, 0), RGB64(0.25, 0.25, 0.25),
                                             RGB64(0.75, 0.75, 0.75), RGB64(1, 1, 1)])
        let file = LUTAnalysisFile(title: nil, transferLUT: transfer, colourLUT: nil,
                                   transferMetadata: LUTAnalysisSectionMetadata(inputMinimum: 1,
                                                                                 inputMaximum: 0),
                                   colourMetadata: nil, sourceFormat: "lacube")
        XCTAssertThrowsError(try ImportedLUTAnalyzer.analyze(lut: transfer, analysisFile: file)) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError,
                           .invalidMetadata(.invalidBounds))
        }
    }

    func testInversePlanCarriesAnalysisSemanticsIntoStableIdentity() throws {
        let transfer = try CubeLUT(dimension: .one, size: 4, domain: .unit,
                                   samples: [RGB64(0, 0, 0), RGB64(0.25, 0.25, 0.25),
                                             RGB64(0.75, 0.75, 0.75), RGB64(1, 1, 1)])
        let base = LUTAnalysisFile(title: nil, transferLUT: transfer, colourLUT: nil,
            transferMetadata: LUTAnalysisSectionMetadata(inputRange: "100",
                                                          inputMinimum: 0,
                                                          inputMaximum: 1,
                                                          interpolation: "trilinear"),
            colourMetadata: nil, sourceFormat: "lacube")
        let changed = LUTAnalysisFile(title: nil, transferLUT: transfer, colourLUT: nil,
            transferMetadata: LUTAnalysisSectionMetadata(inputRange: "109",
                                                          inputMinimum: -0.25,
                                                          inputMaximum: 1.25,
                                                          interpolation: "tetrahedral"),
            colourMetadata: nil, sourceFormat: "labin")
        let first = try ImportedLUTInversePlan(lut: transfer, analysisFile: base,
                                               interpolation: .tricubicLegacyV1)
        let second = try ImportedLUTInversePlan(lut: transfer, analysisFile: changed,
                                                interpolation: .tricubicLegacyV1)
        XCTAssertEqual(first.metadata?.transfer.inputRange, .data)
        XCTAssertEqual(first.metadata?.quantization, .textualDouble)
        XCTAssertNotEqual(first.contentFingerprint, second.contentFingerprint)
    }

    func testInversePlanRejectsInvalidAnalysisMetadata() throws {
        let transfer = try CubeLUT(dimension: .one, size: 2, domain: .unit,
                                   samples: [RGB64(0, 0, 0), RGB64(1, 1, 1)])
        let file = LUTAnalysisFile(title: nil, transferLUT: transfer, colourLUT: nil,
            transferMetadata: LUTAnalysisSectionMetadata(inputMinimum: 1, inputMaximum: 0),
            colourMetadata: nil, sourceFormat: "lacube")
        XCTAssertThrowsError(try ImportedLUTInversePlan(lut: transfer, analysisFile: file,
                                                        interpolation: .tricubicLegacyV1)) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError,
                           .invalidMetadata(.invalidBounds))
        }
    }

    func testExplicitTransferColourReconstructionReportsResiduals() throws {
        let transfer = try CubeLUT(dimension: .one, size: 4, domain: .unit,
                                   samples: [RGB64(0, 0, 0), RGB64(1.0 / 3, 1.0 / 3, 1.0 / 3),
                                             RGB64(2.0 / 3, 2.0 / 3, 2.0 / 3), RGB64(1, 1, 1)])
        let colourSamples = try (0..<8).map { index in
            let r = Double(index & 1)
            let g = Double((index >> 1) & 1)
            let b = Double((index >> 2) & 1)
            return try RGB64(r, g, b)
        }
        let colour = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                                 samples: colourSamples)
        let file = LUTAnalysisFile(title: nil, transferLUT: transfer, colourLUT: colour,
                                   transferMetadata: .init(), colourMetadata: .init(),
                                   sourceFormat: "lacube")
        let inputs = try [RGB64(0.1, 0.2, 0.3), RGB64(0.25, 0.5, 0.75), RGB64(0.9, 0.8, 0.7)]
        let report = try ImportedLUTAnalyzer.reconstructionReport(
            lut: transfer, analysisFile: file, inputs: inputs, expectedOutputs: inputs,
            transferInterpolation: .trilinear, colourInterpolation: .trilinear)
        XCTAssertEqual(report.sampleCount, 3)
        XCTAssertEqual(report.maximumAbsoluteResidual, 0, accuracy: 1e-15)
        XCTAssertEqual(report.rmsAbsoluteResidual, 0, accuracy: 1e-15)
        XCTAssertEqual(report.p99AbsoluteResidual, 0, accuracy: 1e-15)

        var changed = inputs
        changed[1] = try RGB64(0.25, 0.5, 0.70)
        let nonZero = try ImportedLUTAnalyzer.reconstructionReport(
            lut: transfer, analysisFile: file, inputs: inputs, expectedOutputs: changed,
            transferInterpolation: .trilinear, colourInterpolation: .trilinear)
        XCTAssertEqual(nonZero.maximumAbsoluteResidual, 0.05, accuracy: 1e-15)
        XCTAssertEqual(nonZero.p99AbsoluteResidual, 0.05, accuracy: 1e-15)
    }

    func testReconstructionRejectsMissingSectionMismatchedAndNonFiniteReferences() throws {
        let transfer = try CubeLUT(dimension: .one, size: 4, domain: .unit,
                                   samples: [RGB64(0, 0, 0), RGB64(1.0 / 3, 1.0 / 3, 1.0 / 3),
                                             RGB64(2.0 / 3, 2.0 / 3, 2.0 / 3), RGB64(1, 1, 1)])
        let noColour = LUTAnalysisFile(title: nil, transferLUT: transfer, colourLUT: nil,
                                       transferMetadata: .init(), colourMetadata: nil,
                                       sourceFormat: "lacube")
        XCTAssertThrowsError(try ImportedLUTAnalyzer.reconstructionReport(
            lut: transfer, analysisFile: noColour, inputs: [RGB64(0, 0, 0)],
            expectedOutputs: [RGB64(0, 0, 0)], transferInterpolation: .trilinear,
            colourInterpolation: .trilinear)) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .reconstructionRequiresColourLUT)
        }
        let colour = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                                 samples: Array(repeating: RGB64(0, 0, 0), count: 8))
        let file = LUTAnalysisFile(title: nil, transferLUT: transfer, colourLUT: colour,
                                   transferMetadata: .init(), colourMetadata: .init(),
                                   sourceFormat: "lacube")
        XCTAssertThrowsError(try ImportedLUTAnalyzer.reconstructionReport(
            lut: transfer, analysisFile: file, inputs: [RGB64(0, 0, 0)],
            expectedOutputs: [], transferInterpolation: .trilinear,
            colourInterpolation: .trilinear)) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .reconstructionCountMismatch)
        }
        XCTAssertThrowsError(try ImportedLUTAnalyzer.reconstructionReport(
            lut: transfer, analysisFile: file, inputs: [], expectedOutputs: [],
            transferInterpolation: .trilinear, colourInterpolation: .trilinear)) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .reconstructionEmptyReference)
        }
        XCTAssertThrowsError(try ImportedLUTAnalyzer.reconstructionReport(
            lut: transfer, analysisFile: file, inputs: [RGB64(1.1, 0, 0)],
            expectedOutputs: [RGB64(0, 0, 0)], transferInterpolation: .trilinear,
            colourInterpolation: .trilinear)) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .reconstructionOutsideDomain)
        }

        let invalidMetadata = LUTAnalysisFile(
            title: nil, transferLUT: transfer, colourLUT: colour,
            transferMetadata: LUTAnalysisSectionMetadata(inputMinimum: 1, inputMaximum: 0),
            colourMetadata: .init(), sourceFormat: "lacube")
        XCTAssertThrowsError(try ImportedLUTAnalyzer.reconstructionReport(
            lut: transfer, analysisFile: invalidMetadata,
            inputs: [RGB64(0.25, 0.25, 0.25)],
            expectedOutputs: [RGB64(0.25, 0.25, 0.25)],
            transferInterpolation: .trilinear, colourInterpolation: .trilinear)) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError,
                           .invalidMetadata(.invalidBounds))
        }
    }

    func testArbitraryThreeDimensionalLUTIsNeverInferredInvertible() throws {
        let samples = try (0..<8).map { _ in try RGB64(0.5, 0.5, 0.5) }
        let lut = try CubeLUT(dimension: .three, size: 2, domain: .unit, samples: samples)
        let report = try ImportedLUTAnalyzer.analyze(lut: lut, analysisFile: nil)
        XCTAssertNil(report.transfer)
        XCTAssertTrue(report.hasColourLUT)
        XCTAssertEqual(report.colourInverse, .requiresExplicitModel)
        XCTAssertThrowsError(try report.inverseColourLUT(RGB64(0.5, 0.5, 0.5))) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .arbitrary3DInverseUnsupported)
        }
    }

    func testColourInverseAcceptsOnlyCallerSuppliedKnownAffineModel() throws {
        let samples = try (0..<8).map { _ in try RGB64(0.5, 0.5, 0.5) }
        let lut = try CubeLUT(dimension: .three, size: 2, domain: .unit, samples: samples)
        let report = try ImportedLUTAnalyzer.analyze(lut: lut, analysisFile: nil)
        let matrix = try Matrix3x3(rowMajor: [1.1, 0.1, 0.0,
                                               0.0, 0.9, 0.05,
                                               0.02, 0.0, 1.2])
        let model = try KnownAffine3DTransform(matrix: matrix,
                                                offset: try RGB64(0.05, -0.02, 0.03))
        let input = try RGB64(0.2, 0.4, 0.6)
        let output = try model.applying(to: input)
        let recovered = try report.inverseColourLUT(output, using: model,
                                                    inputDomain: .unit)
        XCTAssertEqual(recovered.r, input.r, accuracy: 2e-14)
        XCTAssertEqual(recovered.g, input.g, accuracy: 2e-14)
        XCTAssertEqual(recovered.b, input.b, accuracy: 2e-14)
    }

    func testStrictIndependentTransferInverseRoundtripAndFailures() throws {
        let samples = try [RGB64(0, 1, -1), RGB64(0.2, 0.6, 0),
                           RGB64(0.65, 0.3, 1), RGB64(1, 0, 2)]
        let lut = try CubeLUT(dimension: .one, size: 4, domain: .unit, samples: samples)
        let input = try RGB64(0.13, 0.46, 0.82)
        let output = try lut.sample(input, interpolation: .trilinear, outside: .reject)
        let recovered = try ImportedLUTAnalyzer.inverseTransfer(lut: lut, analysisFile: nil,
                                                                 output: output)
        XCTAssertEqual(recovered.r, input.r, accuracy: 2e-12)
        XCTAssertEqual(recovered.g, input.g, accuracy: 2e-12)
        XCTAssertEqual(recovered.b, input.b, accuracy: 2e-12)
        XCTAssertThrowsError(try ImportedLUTAnalyzer.inverseTransfer(
            lut: lut, analysisFile: nil, output: RGB64(2, 0.5, 0))) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .outsideTransferRange)
        }
        let flat = try CubeLUT(dimension: .one, size: 3, domain: .unit,
                               samples: [RGB64(0, 0, 0), RGB64(0.5, 0.5, 0.5), RGB64(1, 0.5, 1)])
        XCTAssertThrowsError(try ImportedLUTAnalyzer.inverseTransfer(
            lut: flat, analysisFile: nil, output: RGB64(0.5, 0.5, 0.5))) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .nonUniqueTransfer)
        }
        let reversed = try CubeLUT(dimension: .one, size: 3, domain: .unit,
                                   samples: [RGB64(0, 0, 0), RGB64(0.5, 0.5, 0.5), RGB64(0.25, 1, 1)])
        XCTAssertThrowsError(try ImportedLUTAnalyzer.inverseTransfer(
            lut: reversed, analysisFile: nil, output: RGB64(0.4, 0.5, 0.5))) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .nonUniqueTransfer)
        }
    }

    func testLegacyCubicTransferInverseUsesIndependentHermiteReference() throws {
        let lut = try CubeLUT(dimension: .one, size: 4, domain: .unit,
                              samples: [RGB64(0, 0, 0), RGB64(0.25, 0.25, 0.25),
                                        RGB64(0.75, 0.75, 0.75), RGB64(1, 1, 1)])
        let output = try RGB64(0.42742425, 0.42742425, 0.42742425)
        let recovered = try ImportedLUTAnalyzer.inverseTransfer(
            lut: lut, analysisFile: nil, output: output,
            interpolation: .tricubicLegacyV1)
        XCTAssertEqual(recovered.r, 1.37 / 3, accuracy: 2e-12)
        XCTAssertEqual(recovered.g, 1.37 / 3, accuracy: 2e-12)
        XCTAssertEqual(recovered.b, 1.37 / 3, accuracy: 2e-12)

        let hump = try CubeLUT(dimension: .one, size: 4, domain: .unit,
                               samples: [RGB64(0, 0, 0), RGB64(1, 1, 1),
                                         RGB64(1, 1, 1), RGB64(0, 0, 0)])
        XCTAssertThrowsError(try ImportedLUTAnalyzer.inverseTransfer(
            lut: hump, analysisFile: nil,
            output: RGB64(1.125, 1.125, 1.125),
            interpolation: .tricubicLegacyV1)) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .nonUniqueTransfer)
        }
    }

    func testCombinedShaperCubicInverseUsesIndependentHermiteReference() throws {
        let shaper = try CubeShaper(
            size: 4,
            domain: .unit,
            samples: [RGB64(0, 0, 0), RGB64(0.25, 0.25, 0.25),
                      RGB64(0.75, 0.75, 0.75), RGB64(1, 1, 1)]
        )
        let volume = try CubeLUT(dimension: .three, size: 4, domain: .unit,
                                 samples: (0..<64).map { _ in try RGB64(0, 0, 0) },
                                 shaper: shaper)
        let recovered = try ImportedLUTAnalyzer.inverseShaper(
            lut: volume,
            output: RGB64(0.42742425, 0.42742425, 0.42742425),
            interpolation: .tricubicLegacyV1
        )
        XCTAssertEqual(recovered.r, 1.37 / 3, accuracy: 2e-12)
        XCTAssertEqual(recovered.g, 1.37 / 3, accuracy: 2e-12)
        XCTAssertEqual(recovered.b, 1.37 / 3, accuracy: 2e-12)
    }

    func testCombinedShaperInverseRejectsFlatAndMissingShaper() throws {
        let zero = try RGB64(0, 0, 0)
        let identity = try RGB64(1, 1, 1)
        let volume = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                                 samples: Array(repeating: zero, count: 8))
        XCTAssertThrowsError(try ImportedLUTAnalyzer.inverseShaper(
            lut: volume, output: zero
        )) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .noShaperLUT)
        }
        let flatShaper = try CubeShaper(size: 3, domain: .unit,
                                        samples: [zero, zero, identity])
        let flatVolume = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                                     samples: Array(repeating: zero, count: 8),
                                     shaper: flatShaper)
        XCTAssertThrowsError(try ImportedLUTAnalyzer.inverseShaper(
            lut: flatVolume, output: zero
        )) {
            XCTAssertEqual($0 as? ImportedLUTAnalysisError, .nonUniqueTransfer)
        }
    }

    func testTransferInverseDiagnosticPreservesPerChannelFailureAndSuccess() throws {
        let lut = try CubeLUT(dimension: .one, size: 3, domain: .unit,
                              samples: [RGB64(0, 0, 0), RGB64(0.5, 0.5, 0.5), RGB64(1, 0.5, 1)])
        let diagnostic = try ImportedLUTAnalyzer.diagnoseTransferInverse(
            lut: lut, analysisFile: nil, output: RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(diagnostic.channels.count, 3)
        XCTAssertEqual(diagnostic.channels[0].status, .converged)
        XCTAssertEqual(diagnostic.channels[1].status, .nonUnique)
        XCTAssertEqual(diagnostic.channels[2].status, .converged)
        XCTAssertEqual(diagnostic.channels[0].value!, 0.25, accuracy: 1e-12)
        XCTAssertNil(diagnostic.channels[1].value)
        XCTAssertEqual(diagnostic.channels[1].bracket, 0.5...1.0)
    }

    func testTransferInverseDiagnosticReportsOutsideRangeWithoutThrowing() throws {
        let lut = try CubeLUT(dimension: .one, size: 3, domain: .unit,
                              samples: [RGB64(0, 0, 0), RGB64(0.5, 0.5, 0.5), RGB64(1, 1, 1)])
        let diagnostic = try ImportedLUTAnalyzer.diagnoseTransferInverse(
            lut: lut, analysisFile: nil, output: RGB64(2, 0.25, 0.75))
        XCTAssertEqual(diagnostic.channels.map(\.status), [.notBracketed, .converged, .converged])
        XCTAssertEqual(diagnostic.channels[0].bracket, 0.0...1.0)
        XCTAssertNil(diagnostic.channels[0].value)
    }

    func testShaperInverseDiagnosticPreservesPerChannelFailureAndSuccess() throws {
        let zero = try RGB64(0, 0, 0)
        let shaper = try CubeShaper(size: 3, domain: .unit,
                                    samples: [zero, try RGB64(0.5, 0.5, 0.5),
                                              try RGB64(1, 0.5, 1)])
        let lut = try CubeLUT(dimension: .three, size: 2, domain: .unit,
                              samples: Array(repeating: zero, count: 8), shaper: shaper)
        let diagnostic = try ImportedLUTAnalyzer.diagnoseShaperInverse(
            lut: lut, output: RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(diagnostic.channels.map(\.status), [.converged, .nonUnique, .converged])
        XCTAssertEqual(diagnostic.channels[0].value!, 0.25, accuracy: 1e-12)
        XCTAssertEqual(diagnostic.channels[1].bracket, 0.5...1.0)
        XCTAssertNil(diagnostic.channels[1].value)
    }

    func testTransferInverseRootsReportEveryCubicRootPerChannel() throws {
        let hump = try CubeLUT(dimension: .one, size: 4, domain: .unit,
                               samples: [RGB64(0, 0, 0), RGB64(1, 1, 1),
                                         RGB64(1, 1, 1), RGB64(0, 0, 0)])
        let report = try ImportedLUTAnalyzer.diagnoseTransferInverseRoots(
            lut: hump, analysisFile: nil, output: RGB64(0.5, 0.5, 0.5))
        XCTAssertEqual(report.channels.map(\.status), [.nonUnique, .nonUnique, .nonUnique])
        XCTAssertEqual(report.channels.map { $0.roots.count }, [2, 2, 2])
        XCTAssertEqual(report.channels[0].roots[0].value!, 0.12732200375003508, accuracy: 2e-12)
        XCTAssertEqual(report.channels[0].roots[1].value!, 0.8182043533932605, accuracy: 2e-12)
        XCTAssertTrue(report.channels.allSatisfy { $0.roots.allSatisfy { ($0.residual ?? 1) <= 2e-12 } })
    }

    func testTransferInverseRootsKeepOutsideAndNonFiniteStatesExplicit() throws {
        let lut = try CubeLUT(dimension: .one, size: 3, domain: .unit,
                              samples: [RGB64(0, 0, 0), RGB64(0.5, 0.5, 0.5), RGB64(1, 1, 1)])
        let outside = try ImportedLUTAnalyzer.diagnoseTransferInverseRoots(
            lut: lut, analysisFile: nil, output: RGB64(2, 0.25, 0.75))
        XCTAssertEqual(outside.channels.map(\.status), [.notBracketed, .converged, .converged])
        XCTAssertTrue(outside.channels[0].roots.isEmpty)
    }

    func testTransferInverseRootsExposeConstantPlateauAsNonUniqueInterval() throws {
        let flat = try CubeLUT(dimension: .one, size: 6, domain: .unit,
                               samples: [RGB64(0, 0, 0), RGB64(0.5, 0.5, 0.5),
                                         RGB64(0.5, 0.5, 0.5), RGB64(0.5, 0.5, 0.5),
                                         RGB64(0.5, 0.5, 0.5), RGB64(1, 1, 1)])
        let report = try ImportedLUTAnalyzer.diagnoseTransferInverseRoots(
            lut: flat, analysisFile: nil, output: RGB64(0.5, 0.5, 0.5))
        XCTAssertEqual(report.channels.map(\.status), [.nonUnique, .nonUnique, .nonUnique])
        XCTAssertTrue(report.channels.allSatisfy { $0.roots.count == 2 })
        XCTAssertTrue(report.channels.allSatisfy { channel in
            channel.roots.allSatisfy { !(0.4...0.6).contains($0.value!) }
        })
        XCTAssertEqual(report.channels[0].nonUniqueBrackets, [0.4...0.6])
    }
}
