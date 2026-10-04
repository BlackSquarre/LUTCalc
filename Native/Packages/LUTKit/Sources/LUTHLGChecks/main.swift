import Foundation
import LUTCore

private enum Failure: Error, CustomStringConvertible {
    case mismatch(size: Int, index: Int, channel: Int, actual: Double, expected: Double, scaledError: Double)

    var description: String {
        switch self {
        case let .mismatch(size, index, channel, actual, expected, scaledError):
            return "size=\(size) node=\(index) channel=\(channel): actual=\(actual), expected=\(expected), scaled=\(scaledError)"
        }
    }
}

// Independent BT.2100-3 Table 5 reference. Keep this separate from HLGTransfer
// so the grid check can detect an implementation that shares the same defect.
private enum BT2100Reference {
    static let a = 0.17883277
    static let b = 0.28466892
    static let c = 0.5 - a * log(4.0 * a)

    static func decode(_ encoded: Double) -> Double {
        encoded <= 0.5
            ? (encoded * encoded) / 3.0
            : (exp((encoded - c) / a) + b) / 12.0
    }

    static func encode(_ scene: Double) -> Double {
        scene <= 1.0 / 12.0
            ? sqrt(3.0 * scene)
            : a * log(12.0 * scene - b) + c
    }
}

private func scaledError(_ actual: Double, _ expected: Double) -> Double {
    abs(actual - expected) / max(1.0, abs(expected))
}

private func run(size: Int) throws -> (nodes: Int, maximum: Double, worstIndex: Int, worstChannel: Int) {
    let grid = try Grid3D(size: size, domain: .unit)
    let settings = TransformSettings(
        inputTransfer: .rec2100HLG,
        outputTransfer: .rec2100HLG,
        inputSpace: .rec2020,
        outputSpace: .rec2020,
        inputRange: .data,
        outputRange: .data,
        exposureStops: 1
    )
    let plan = try TransformPlan(settings: settings)
    var maximum = 0.0
    var worstIndex = 0
    var worstChannel = 0
    for index in 0..<grid.nodeCount {
        let input = try grid.coordinate(at: index)
        let expected = try RGB64(
            BT2100Reference.encode(2.0 * BT2100Reference.decode(input.r)),
            BT2100Reference.encode(2.0 * BT2100Reference.decode(input.g)),
            BT2100Reference.encode(2.0 * BT2100Reference.decode(input.b))
        )
        let actual = try plan.evaluate(input, sampleIndex: index)
        for channel in 0..<3 {
            let error = scaledError(actual[channel], expected[channel])
            if error > maximum {
                maximum = error
                worstIndex = index
                worstChannel = channel
            }
            guard error <= 2e-12 else {
                throw Failure.mismatch(size: size, index: index, channel: channel,
                                      actual: actual[channel], expected: expected[channel], scaledError: error)
            }
        }
    }
    return (grid.nodeCount, maximum, worstIndex, worstChannel)
}

do {
    let results = try [33, 65].map(run)
    for (size, result) in zip([33, 65], results) {
        print("H11 Rec.2100 HLG \(size)³ 独立 BT.2100-3 全节点通过：\(result.nodes) 节点，最大尺度化误差 \(result.maximum)，最差节点 \(result.worstIndex)/通道 \(result.worstChannel)")
    }
} catch {
    fputs("LUTHLGChecks: \(error)\n", stderr)
    exit(1)
}
