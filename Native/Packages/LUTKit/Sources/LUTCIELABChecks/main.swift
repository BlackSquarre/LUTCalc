import Foundation
import LUTCore

struct Fixture: Decodable {
    let white: CIELABWhitePoint
    let samples: [Sample]
}

struct Sample: Decodable {
    let xyz: [Double]
    let lab: [Double]
}

enum CheckFailure: Error, CustomStringConvertible {
    case invalidInput
    case mismatch(index: Int, actual: [Double], expected: [Double], error: Double)

    var description: String {
        switch self {
        case .invalidInput: "invalid fixture"
        case let .mismatch(index, actual, expected, error):
            "mismatch index=\(index) actual=\(actual) expected=\(expected) maxError=\(error)"
        }
    }
}

let args = CommandLine.arguments
guard args.count == 2, let data = FileManager.default.contents(atPath: args[1]) else {
    fputs("usage: LUTCIELABChecks fixture.json\n", stderr)
    exit(2)
}

do {
    let fixture = try JSONDecoder().decode(Fixture.self, from: data)
    var maximum = 0.0
    for (index, sample) in fixture.samples.enumerated() {
        guard sample.xyz.count == 3, sample.lab.count == 3 else { throw CheckFailure.invalidInput }
        let value = try CIELABColorSpace.fromXYZ(
            try XYZ64(sample.xyz[0], sample.xyz[1], sample.xyz[2]), white: fixture.white
        )
        let actual = [value.lStar, value.aStar, value.bStar]
        let error = zip(actual, sample.lab).map { abs($0 - $1) }.max() ?? 0
        maximum = max(maximum, error)
        guard error <= 2e-13 else {
            throw CheckFailure.mismatch(index: index, actual: actual, expected: sample.lab, error: error)
        }
    }
    print("samples=\(fixture.samples.count) maxError=\(maximum)")
} catch {
    fputs("LUTCIELABChecks: \(error)\n", stderr)
    exit(1)
}
