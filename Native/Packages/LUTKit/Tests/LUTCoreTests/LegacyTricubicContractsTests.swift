import Foundation
import XCTest
import LUTCore

final class LegacyTricubicContractsTests: XCTestCase {
    private struct Reference: Decodable {
        let cases: [Case]
        struct Case: Decodable {
            let size: Int
            let field: String
            let samples: [[Double]]
            let probes: [Probe]
        }
        struct Probe: Decodable { let input: [Double]; let output: [Double] }
    }

    func testFrozenLegacyInteriorFacesEdgesAndCorners() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        let data = try Data(contentsOf: root.appendingPathComponent(
            "tests/fixtures/native-contracts/tricubic-legacy-reference.json"))
        let reference = try JSONDecoder().decode(Reference.self, from: data)
        var maximum = 0.0
        var count = 0
        for item in reference.cases {
            let samples = try item.samples.map { try RGB64($0[0], $0[1], $0[2]) }
            let volume = try LegacyTricubicVolume3D(size: item.size, domain: .unit, samples: samples)
            for probe in item.probes {
                let input = try RGB64(probe.input[0], probe.input[1], probe.input[2])
                let output = try volume.sample(input, outside: .reject)
                for channel in 0..<3 {
                    let expected = probe.output[channel]
                    let error = abs(output[channel] - expected) / max(1, abs(expected))
                    maximum = max(maximum, error)
                    XCTAssertLessThanOrEqual(error, 2e-12,
                        "\(item.size) \(item.field) \(probe.input) channel \(channel)")
                }
                count += 1
            }
        }
        print("旧 tricubic 冻结参照：\(count) 点，最大尺度化误差 \(maximum)")
    }

    func testIndependentAffineDomainAndGridNodes() throws {
        let domain = try LUTDomain(min: RGB64(-2, 1, -3), max: RGB64(2, 5, 1))
        let grid = try Grid3D(size: 5, domain: domain)
        func affine(_ p: RGB64) throws -> RGB64 {
            try RGB64(0.5 * p.r + 0.25 * p.g - p.b,
                      -p.r + 2 * p.g + 0.5 * p.b, p.r - p.g + 3 * p.b)
        }
        let samples = try (0..<grid.nodeCount).map { try affine(grid.coordinate(at: $0)) }
        let volume = try LegacyTricubicVolume3D(size: grid.size, domain: domain, samples: samples)
        for index in 0..<grid.nodeCount {
            XCTAssertEqual(try volume.sample(grid.coordinate(at: index), outside: .reject), samples[index])
        }
        for p in [try RGB64(-1.7, 1.3, -2.2), try RGB64(0.1, 4.8, -0.4)] {
            let actual = try volume.sample(p, outside: .reject)
            let expected = try affine(p)
            for c in 0..<3 { XCTAssertEqual(actual[c], expected[c], accuracy: 2e-12) }
        }
    }

    func testCellBernsteinCoefficientsReconstructProductionSamplerAndEncloseCell() throws {
        let size = 5
        let grid = try Grid3D(size: size, domain: .unit)
        let samples = try (0..<grid.nodeCount).map { index -> RGB64 in
            let p = try grid.coordinate(at: index)
            return try RGB64(p.r * p.r + 0.2 * p.g * p.b,
                             p.g * p.g * p.g - 0.1 * p.r,
                             sin(p.r + 2 * p.g - p.b))
        }
        let volume = try LegacyTricubicVolume3D(size: size, domain: .unit, samples: samples)
        let cell = [1, 2, 0]
        let coefficients = try volume.cellBernsteinCoefficients(cell)
        XCTAssertEqual(coefficients.count, 64)

        func choose3(_ i: Int) -> Double {
            switch i {
            case 0, 3: 1
            case 1, 2: 3
            default: 0
            }
        }
        for iz in 0...4 {
            for iy in 0...4 {
                for ix in 0...4 {
                    let u = Double(ix) / 4, v = Double(iy) / 4, w = Double(iz) / 4
                    let bernstein: (Int, Double) -> Double = { i, t in
                        choose3(i) * pow(t, Double(i)) * pow(1 - t, Double(3 - i))
                    }
                    var rebuilt = [Double](repeating: 0, count: 3)
                    for z in 0..<4 {
                        for y in 0..<4 {
                            for x in 0..<4 {
                                let weight = bernstein(x, u) * bernstein(y, v) * bernstein(z, w)
                                let coefficient = coefficients[x + 4 * (y + 4 * z)]
                                for channel in 0..<3 { rebuilt[channel] += coefficient[channel] * weight }
                            }
                        }
                    }
                    let input = try RGB64((Double(cell[0]) + u) / Double(size - 1),
                                          (Double(cell[1]) + v) / Double(size - 1),
                                          (Double(cell[2]) + w) / Double(size - 1))
                    let sampled = try volume.sample(input, outside: .reject)
                    for channel in 0..<3 {
                        XCTAssertEqual(rebuilt[channel], sampled[channel], accuracy: 2e-12)
                    }
                }
            }
        }
    }

    func testCellBernsteinCoefficientsMatchIndependentAffineReference() throws {
        let size = 5
        let grid = try Grid3D(size: size, domain: .unit)
        func affine(_ p: RGB64) throws -> RGB64 {
            try RGB64(0.25 + 0.7 * p.r - 0.2 * p.g + 0.4 * p.b,
                      -0.1 + 0.3 * p.r + 0.8 * p.g - 0.5 * p.b,
                      0.6 - 0.4 * p.r + 0.1 * p.g + 0.9 * p.b)
        }
        let samples = try (0..<grid.nodeCount).map { try affine(grid.coordinate(at: $0)) }
        let volume = try LegacyTricubicVolume3D(size: size, domain: .unit, samples: samples)
        let cell = [1, 2, 0]
        let coefficients = try volume.cellBernsteinCoefficients(cell)
        for z in 0..<4 {
            for y in 0..<4 {
                for x in 0..<4 {
                    let point = try RGB64((Double(cell[0]) + Double(x) / 3) / Double(size - 1),
                                          (Double(cell[1]) + Double(y) / 3) / Double(size - 1),
                                          (Double(cell[2]) + Double(z) / 3) / Double(size - 1))
                    let expected = try affine(point)
                    let actual = coefficients[x + 4 * (y + 4 * z)]
                    for channel in 0..<3 { XCTAssertEqual(actual[channel], expected[channel], accuracy: 2e-12) }
                }
            }
        }
    }

    func testOvershootIsPreservedAndOutsidePoliciesStayExplicit() throws {
        var samples: [RGB64] = []
        for _ in 0..<16 {
            for r in [0.0, 1.0, 1.0, 0.0] { samples.append(try RGB64(r, r, r)) }
        }
        let volume = try LegacyTricubicVolume3D(size: 4, domain: .unit, samples: samples)
        let middle = try volume.sample(RGB64(0.5, 0.5, 0.5), outside: .reject)
        XCTAssertEqual(middle.r, 1.125, accuracy: 2e-12)
        XCTAssertThrowsError(try volume.sample(RGB64(-0.1, 0.5, 0.5), outside: .reject))
        XCTAssertEqual(try volume.sample(RGB64(-0.1, 0.5, 0.5), outside: .clampToDomain),
                       try volume.sample(RGB64(0, 0.5, 0.5), outside: .reject))
    }

    func testInvalidStencilCountAndResourceBudgetAreRejected() throws {
        let zero = try RGB64(0, 0, 0)
        XCTAssertThrowsError(try LegacyTricubicVolume3D(size: 3, domain: .unit,
            samples: Array(repeating: zero, count: 27)))
        XCTAssertThrowsError(try LegacyTricubicVolume3D(size: 4, domain: .unit, samples: [zero]))
        XCTAssertThrowsError(try LegacyTricubicVolume3D(size: Int.max, domain: .unit, samples: []))
        XCTAssertThrowsError(try LegacyTricubicVolume3D(size: 513, domain: .unit, samples: [])) { error in
            XCTAssertEqual(error as? LegacyTricubicError, .resourceLimit)
        }
        let extreme = try LUTDomain(min: RGB64(-Double.greatestFiniteMagnitude, 0, 0),
                                    max: RGB64(Double.greatestFiniteMagnitude, 1, 1))
        XCTAssertThrowsError(try LegacyTricubicVolume3D(size: 4, domain: extreme,
            samples: Array(repeating: zero, count: 64))) { error in
                XCTAssertEqual(error as? NumericError, .invalidDomain)
            }

        let validSamples = Array(repeating: zero, count: 4 * 4 * 4)
        let volume = try LegacyTricubicVolume3D(size: 4, domain: .unit, samples: validSamples)
        for invalidCell in [[], [0, 0], [-1, 0, 0], [3, 0, 0], [0, 4, 0], [0, 0, 4]] {
            XCTAssertThrowsError(try volume.cellBernsteinCoefficients(invalidCell), "cell \(invalidCell)") { error in
                XCTAssertEqual(error as? VolumeError, .outsideDomain)
            }
        }
    }
}
