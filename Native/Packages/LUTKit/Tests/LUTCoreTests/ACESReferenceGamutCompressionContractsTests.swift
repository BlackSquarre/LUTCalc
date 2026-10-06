import Foundation
import XCTest
@testable import LUTCore

final class ACESReferenceGamutCompressionContractsTests: XCTestCase {
    private struct ReferenceSample: Decodable {
        let input: [String]
        let output: [String]
    }

    private struct Reference: Decodable {
        let algorithm: String
        let precision: Int
        let sampleCount: Int
        let samples: [ReferenceSample]
        let inverseSamples: [ReferenceSample]
    }

    func testInGamutAndAchromaticValuesRemainUnchangedWithinDoubleTolerance() throws {
        let operatorUnderTest = ACESReferenceGamutCompression()
        for value in [
            try RGB64(0.0, 0.0, 0.0),
            try RGB64(0.18, 0.18, 0.18),
            try RGB64(0.5, 0.25, 0.1),
        ] {
            let actual = try operatorUnderTest.compress(value)
            XCTAssertEqual(actual.r, value.r, accuracy: 3e-10)
            XCTAssertEqual(actual.g, value.g, accuracy: 3e-10)
            XCTAssertEqual(actual.b, value.b, accuracy: 3e-10)
        }
    }

    func testPublishedOutOfGamutReferenceValueMatchesIndependentExpectedResult() throws {
        let references: [(RGB64, RGB64)] = [
            (
                try RGB64(1.2, -0.1, 0.05),
                try RGB64(1.2442924393243279, 0.1304655980052361, 0.09550440688161017)
            ),
            (
                try RGB64(-1.0, 0.0, 1.0),
                try RGB64(0.09306531162813847, 0.13849769078127972, 0.9917264929104379)
            ),
            (
                try RGB64(2.0, -0.5, 0.25),
                try RGB64(2.1096757267951734, 0.16182037839518374, 0.2623763434809616)
            ),
        ]
        for (input, expected) in references {
            let output = try ACESReferenceGamutCompression().compress(input)
            XCTAssertEqual(output.r, expected.r, accuracy: 3e-12)
            XCTAssertEqual(output.g, expected.g, accuracy: 3e-12)
            XCTAssertEqual(output.b, expected.b, accuracy: 3e-12)
        }
    }

    func testClosedFormDecompressionRecoversFiniteCompressionInputs() throws {
        let operatorUnderTest = ACESReferenceGamutCompression()
        let values = [
            try RGB64(1.2, -0.1, 0.05),
            try RGB64(-1.0, 0.0, 1.0),
            try RGB64(2.0, -0.5, 0.25),
            try RGB64(0.18, 0.18, 0.18),
        ]
        for value in values {
            let compressed = try operatorUnderTest.compress(value)
            let recovered = try operatorUnderTest.decompress(compressed)
            XCTAssertEqual(recovered.r, value.r, accuracy: 2e-9)
            XCTAssertEqual(recovered.g, value.g, accuracy: 2e-9)
            XCTAssertEqual(recovered.b, value.b, accuracy: 2e-9)
        }
    }

    func testClosedFormDecompressionPassesThroughValuesBeyondItsSingularity() throws {
        let threshold = ACESReferenceGamutCompression.thresholds.r
        let limit = ACESReferenceGamutCompression.limits.r
        let p = ACESReferenceGamutCompression.exponent
        let scale = (limit - threshold) / pow(
            pow((1 - threshold) / (limit - threshold), -p) - 1,
            1 / p
        )
        let achromatic = 1.0
        let distance = threshold + scale + 0.01
        let ap1 = try RGB64(achromatic - distance * achromatic, achromatic, achromatic)
        let input = try ACESReferenceGamutCompression.ap1ToAp0.applying(to: ap1)
        let output = try ACESReferenceGamutCompression().decompress(input)
        XCTAssertEqual(output.r, input.r, accuracy: 2e-9)
        XCTAssertEqual(output.g, input.g, accuracy: 2e-9)
        XCTAssertEqual(output.b, input.b, accuracy: 2e-9)
    }

    func testBoundaryAndNegativeValuesRemainFinite() throws {
        let operatorUnderTest = ACESReferenceGamutCompression()
        for value in [
            try RGB64(-1.0, 0.0, 1.0),
            try RGB64(2.0, -0.5, 0.25),
            try RGB64(0.815, 0.803, 0.880),
        ] {
            let output = try operatorUnderTest.compress(value)
            XCTAssertTrue(output.r.isFinite && output.g.isFinite && output.b.isFinite)
        }
        XCTAssertThrowsError(try RGB64(.infinity, 0, 0))
    }

    func testNinetyDigitIndependentReferenceGrid() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        let referenceURL = root.appendingPathComponent(
            "docs/native-validation/artifacts/2026-10-05-aces-rgc/decimal-reference.json"
        )
        let reference = try JSONDecoder().decode(
            Reference.self, from: Data(contentsOf: referenceURL)
        )
        XCTAssertEqual(reference.algorithm, ACESReferenceGamutCompression.algorithm)
        XCTAssertEqual(
            ACESReferenceGamutCompression.transformID,
            "urn:ampas:aces:transformId:v1.5:LMT.Academy.GamutCompress.a1.3.0"
        )
        XCTAssertEqual(reference.precision, 90)
        XCTAssertEqual(reference.sampleCount, reference.samples.count)
        XCTAssertEqual(reference.sampleCount, reference.inverseSamples.count)

        var errors: [Double] = []
        errors.reserveCapacity(reference.samples.count * 3)
        for sample in reference.samples {
            let input = try RGB64(
                Double(sample.input[0])!, Double(sample.input[1])!, Double(sample.input[2])!
            )
            let expected = [
                Double(sample.output[0])!, Double(sample.output[1])!, Double(sample.output[2])!
            ]
            let actual = try ACESReferenceGamutCompression().compress(input)
            let values = [actual.r, actual.g, actual.b]
            for index in 0..<3 {
                let error = abs(values[index] - expected[index]) / max(1, abs(expected[index]))
                XCTAssertTrue(error.isFinite)
                errors.append(error)
            }
        }

        errors.sort()
        let maximum = try XCTUnwrap(errors.last)
        let rms = sqrt(errors.reduce(0) { $0 + $1 * $1 } / Double(errors.count))
        let p99 = errors[Int(ceil(Double(errors.count) * 0.99)) - 1]
        XCTAssertLessThanOrEqual(maximum, 2e-14)
        let report: [String: Any] = [
            "algorithm": reference.algorithm,
            "sampleCount": reference.sampleCount,
            "channelCount": errors.count,
            "maximumScaledError": maximum,
            "rmsScaledError": rms,
            "p99ScaledError": p99,
            "threshold": 2e-14,
        ]
        if let directory = ProcessInfo.processInfo.environment["LUTCALC_ACES_RGC_ARTIFACT_DIR"] {
            let url = URL(fileURLWithPath: directory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: url.appendingPathComponent("decimal-error-report.json"))
        }
        print("ACES RGC Decimal: \(report)")
    }

    func testNinetyDigitIndependentInverseReferenceGrid() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        let referenceURL = root.appendingPathComponent(
            "docs/native-validation/artifacts/2026-10-05-aces-rgc/decimal-reference.json"
        )
        let reference = try JSONDecoder().decode(
            Reference.self, from: Data(contentsOf: referenceURL)
        )
        var errors: [Double] = []
        errors.reserveCapacity(reference.inverseSamples.count * 3)
        for sample in reference.inverseSamples {
            let input = try RGB64(
                Double(sample.input[0])!, Double(sample.input[1])!, Double(sample.input[2])!
            )
            let expected = [
                Double(sample.output[0])!, Double(sample.output[1])!, Double(sample.output[2])!
            ]
            let actual = try ACESReferenceGamutCompression().decompress(input)
            let values = [actual.r, actual.g, actual.b]
            for index in 0..<3 {
                let error = abs(values[index] - expected[index]) / max(1, abs(expected[index]))
                XCTAssertTrue(error.isFinite)
                errors.append(error)
            }
        }
        errors.sort()
        let maximum = try XCTUnwrap(errors.last)
        let rms = sqrt(errors.reduce(0) { $0 + $1 * $1 } / Double(errors.count))
        let p99 = errors[Int(ceil(Double(errors.count) * 0.99)) - 1]
        XCTAssertLessThanOrEqual(maximum, 3e-9)
        let report: [String: Any] = [
            "algorithm": reference.algorithm,
            "sampleCount": reference.sampleCount,
            "channelCount": errors.count,
            "maximumScaledError": maximum,
            "rmsScaledError": rms,
            "p99ScaledError": p99,
            "threshold": 3e-9,
        ]
        if let directory = ProcessInfo.processInfo.environment["LUTCALC_ACES_RGC_ARTIFACT_DIR"] {
            let url = URL(fileURLWithPath: directory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: url.appendingPathComponent("decimal-inverse-error-report.json"))
        }
        print("ACES RGC inverse Decimal: \(report)")
    }
}
