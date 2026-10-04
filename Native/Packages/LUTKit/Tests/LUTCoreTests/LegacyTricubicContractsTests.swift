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
    }
}
