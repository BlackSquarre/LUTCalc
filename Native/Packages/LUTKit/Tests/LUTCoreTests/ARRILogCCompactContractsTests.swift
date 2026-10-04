import Foundation
import XCTest
import LUTCore

final class ARRILogCCompactContractsTests: XCTestCase {
    private func fixture() throws -> [String: Any] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent(
            "tests/fixtures/native-contracts/arri-logc-compact-independent.json"))) as! [String: Any]
    }
    private func kernel(_ item: [String: Any]) throws -> ARRILogCCompact {
        try ARRILogCCompact(firmware: ARRILogCCompact.Firmware(rawValue: item["firmware"] as! String)!,
            domain: ARRILogCCompact.LinearDomain(rawValue: item["domain"] as! String)!,
            exposureIndex: item["exposureIndex"] as! Int)
    }
    func testAllPublishedParametersBoundariesAndTenTwelveBitCodesAgainstDecimal() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("tests/fixtures/native-contracts/arri-logc-compact-decode.f64"))
        let cases = try fixture()["cases"] as! [[String: Any]]
        XCTAssertEqual(cases.count, 44)
        var errors: [Double] = [], cursor = 0
        func check(_ actual: Double, _ expected: Double) {
            let error = abs(actual - expected) / max(1, abs(expected))
            errors.append(error); XCTAssertLessThanOrEqual(error, 2e-12)
        }
        for item in cases {
            let transform = try kernel(item)
            let p = item["parameters"] as! [String: String]
            let values = transform.parameters
            for (name, actual) in [("cut",values.cut),("a",values.a),("b",values.b),("c",values.c),
                                  ("d",values.d),("e",values.e),("f",values.f)] {
                XCTAssertEqual(actual, Double(p[name]!))
            }
            XCTAssertEqual(values.encodedCut, values.e * values.cut + values.f)
            for probe in item["probes"] as! [[String: Any]] {
                let x = Double(probe["input"] as! String)!, expected = Double(probe["output"] as! String)!
                check(try probe["direction"] as! String == "encode" ? transform.encode(x) : transform.decode(x), expected)
            }
            for depth in [10,12] { for code in 0..<(1 << depth) {
                let word = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: cursor, as: UInt64.self) }
                cursor += 8
                let expected = Double(bitPattern: UInt64(littleEndian: word))
                check(try transform.decode(Double(code) / Double((1 << depth)-1)), expected)
            }}
        }
        XCTAssertEqual(cursor, data.count)
        report("Log C compact Decimal probes/full codes", errors)
    }
    func testIndependentComplete33And65GridsPreserveNegativeAndSuperwhite() throws {
        var errors: [Double] = []
        for item in try fixture()["grids"] as! [[String: Any]] {
            let transform = try kernel(item), size = item["size"] as! Int
            let lower = Double(item["minimum"] as! String)!, upper = Double(item["maximum"] as! String)!
            let expected = (item["outputs"] as! [String]).map { Double($0)! }
            let grid = try Grid3D(size: size, domain: LUTDomain(min: RGB64(lower,lower,lower), max: RGB64(upper,upper,upper)))
            for i in 0..<grid.nodeCount {
                let point = try grid.coordinate(at: i), axes = [i % size, (i / size) % size, i / (size*size)]
                for c in 0..<3 {
                    let actual = try item["direction"] as! String == "encode" ? transform.encode(point[c]) : transform.decode(point[c])
                    let error = abs(actual - expected[axes[c]]) / max(1,abs(expected[axes[c]]))
                    errors.append(error); XCTAssertLessThanOrEqual(error,2e-12)
                }
            }
        }
        report("Log C compact independent complete grids",errors)
        let curve = try ARRILogCCompact(firmware: .sup3, domain: .sceneExposure, exposureIndex: 1600)
        XCTAssertLessThan(try curve.decode(0),0)
        XCTAssertGreaterThan(try curve.encode(100),1)
    }
    func testUnsupportedExposureIndicesNonfiniteAndDocumentedJunctionMismatch() throws {
        for firmware in ARRILogCCompact.Firmware.allCases { for domain in ARRILogCCompact.LinearDomain.allCases {
            for ei in [0,-1,159,161,1501,1601,2000,2560,3200,Int.max] {
                XCTAssertThrowsError(try ARRILogCCompact(firmware:firmware,domain:domain,exposureIndex:ei)) {
                    XCTAssertEqual($0 as? ARRILogCCompact.Failure,.unsupportedExposureIndex(ei))
                }
            }
            for ei in ARRILogCCompact.supportedExposureIndices {
                let curve = try ARRILogCCompact(firmware:firmware,domain:domain,exposureIndex:ei)
                for operation in [{ try curve.decode(100) }, { try curve.encode(Double.greatestFiniteMagnitude) }] {
                    XCTAssertThrowsError(try operation()) {
                        XCTAssertEqual($0 as? NumericError,.nonFinite)
                    }
                }
            }
        }}
        let curve = try ARRILogCCompact(firmware:.sup3,domain:.sceneExposure,exposureIndex:800)
        for x in [Double.nan,Double.infinity,-Double.infinity] {
            XCTAssertThrowsError(try curve.encode(x)); XCTAssertThrowsError(try curve.decode(x))
        }
        XCTAssertThrowsError(try curve.decode(Double.greatestFiniteMagnitude))
        let cut = curve.parameters.cut
        let left = try curve.encode(cut), right = try curve.encode(cut.nextUp)
        XCTAssertGreaterThan(abs(right-left),2e-12)
        XCTAssertEqual(left,curve.parameters.encodedCut)
        XCTAssertNotEqual(try curve.decode(right),cut)
        XCTAssertEqual(curve.algorithm,"arri.logc-sup3-compact-published.v1")
    }
    private func report(_ name: String, _ errors: [Double]) {
        let sorted = errors.sorted(), n = Double(errors.count)
        print("\(name): count=\(errors.count), max=\(sorted.last!), RMS=\(sqrt(errors.reduce(0){$0+$1*$1}/n)), P99=\(sorted[Int(ceil(n*0.99))-1])")
    }
}
