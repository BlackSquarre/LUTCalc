import Foundation
import LUTCore

private struct Failure: Error, CustomStringConvertible {
    let size: Int
    let index: Int
    let channel: Int
    let actual: Double
    let expected: Double
    var description: String {
        "size=\(size) node=\(index) channel=\(channel): actual=\(actual), expected=\(expected)"
    }
}

private func independentDecode(_ data: Double, m: Double) -> Double {
    let scale = 0.85630498533724
    let offset = 0.06256109481916
    let y = (data - offset) / scale
    let root = Foundation.sqrt(m)
    let n = root / 2
    let r = root * (1 - Foundation.log(root))
    return y > root ? Foundation.exp((y - r) / n) : Foundation.pow(y, 2)
}

private func independentEncode(_ legacy: Double, m: Double) -> Double {
    let scale = 0.85630498533724
    let offset = 0.06256109481916
    let root = Foundation.sqrt(m)
    let n = root / 2
    let r = root * (1 - Foundation.log(root))
    let y: Double
    if legacy > m {
        y = n * Foundation.log(legacy) + r
    } else if legacy > 0 {
        y = Foundation.sqrt(legacy)
    } else {
        y = 0
    }
    return y * scale + offset
}

private func run(size: Int, m: Double) throws -> Double {
    let grid = try Grid3D(size: size, domain: .unit)
    let settings = TransformSettings(
        inputTransfer: m == BBCWHP283Transfer.percent400.m ? .bbcWHP283400 : .bbcWHP283800,
        outputTransfer: m == BBCWHP283Transfer.percent400.m ? .bbcWHP283400 : .bbcWHP283800,
        inputSpace: .srgb, outputSpace: .srgb,
        inputRange: .data, outputRange: .data, exposureStops: 1
    )
    let plan = try TransformPlan(settings: settings)
    var maximum = 0.0
    for index in 0..<grid.nodeCount {
        let input = try grid.coordinate(at: index)
        let channels = [input.r, input.g, input.b]
        for channel in 0..<3 {
            let decoded = independentDecode(channels[channel], m: m)
            let expected = independentEncode(decoded * 2, m: m)
            let actual = try plan.evaluate(input)[channel]
            let error = abs(actual - expected) / max(1, abs(expected))
            maximum = max(maximum, error)
            guard error <= 2e-12 else {
                throw Failure(size: size, index: index, channel: channel, actual: actual, expected: expected)
            }
        }
    }
    return maximum
}

do {
    for (label, m) in [("400%", BBCWHP283Transfer.percent400.m), ("800%", BBCWHP283Transfer.percent800.m)] {
        for size in [33, 65] {
            let maximum = try run(size: size, m: m)
            print("BBC WHP283 \(label) \(size)³ 独立公式读回通过：最大尺度化误差 \(maximum)")
        }
    }
} catch {
    fputs("LUTBBCWHP283Checks: \(error)\n", stderr)
    exit(1)
}
