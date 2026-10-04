import XCTest
import LUTCore
import LUTAnalysis

final class GrayAxisContractsTests: XCTestCase {
    func testBatchedAffineGrayAxesHaveSmallReconstructionResidual() throws {
        let cases: [(Double, Double)] = [(1, 0), (0.5, 0.25), (-1, 1)]
        for (slope, offset) in cases {
            let volume = try makeVolume(size: 5) { r, g, b in
                try RGB64(slope * r + offset, slope * g + offset, slope * b + offset)
            }
            let report = try GrayAxisAnalyzer.extract(volume, interpolation: .tetrahedral)
            XCTAssertEqual(report.method, .normalizedDomainDiagonal)
            XCTAssertEqual(report.interpolation, .tetrahedral)
            XCTAssertEqual(report.samples.count, 5)
            XCTAssertEqual(report.midpointProbeCount, 4)
            XCTAssertLessThan(report.maximumMidpointResidual, 1e-12)
            XCTAssertEqual(report.samples.first?.input, try RGB64(0, 0, 0))
            XCTAssertEqual(report.samples.last?.input, try RGB64(1, 1, 1))
        }
    }

    func testNonlinearGrayAxisReportsActualMidpointResidual() throws {
        let volume = try makeVolume(size: 3) { r, g, b in
            try RGB64(r * g, g * b, b * r)
        }
        let report = try GrayAxisAnalyzer.extract(volume, interpolation: .trilinear)
        XCTAssertEqual(report.samples[1].output, try RGB64(0.25, 0.25, 0.25))
        XCTAssertEqual(report.midpointProbeCount, 2)
        XCTAssertEqual(report.maximumMidpointResidual, 0.0625, accuracy: 1e-12)
    }

    func testUnequalInputDomainUsesNormalizedDiagonal() throws {
        let domain = try LUTDomain(min: RGB64(-1, 0, 2), max: RGB64(1, 2, 6))
        let volume = try LUTVolume3D(size: 2, domain: domain, samples: [
            RGB64(-1, 0, 2), RGB64(1, 0, 2), RGB64(-1, 2, 2), RGB64(1, 2, 2),
            RGB64(-1, 0, 6), RGB64(1, 0, 6), RGB64(-1, 2, 6), RGB64(1, 2, 6)
        ])
        let report = try GrayAxisAnalyzer.extract(volume, interpolation: .tetrahedral)
        XCTAssertEqual(report.samples[0].input, domain.min)
        XCTAssertEqual(report.samples[1].input, domain.max)
        XCTAssertLessThan(report.maximumMidpointResidual, 1e-12)
    }

    private func makeVolume(size: Int, transform: (Double, Double, Double) throws -> RGB64) throws -> LUTVolume3D {
        let step = Double(size - 1)
        let samples = try (0..<size).flatMap { b in
            try (0..<size).flatMap { g in
                try (0..<size).map { r in
                    try transform(Double(r) / step, Double(g) / step, Double(b) / step)
                }
            }
        }
        return try LUTVolume3D(size: size, domain: .unit, samples: samples)
    }
}
