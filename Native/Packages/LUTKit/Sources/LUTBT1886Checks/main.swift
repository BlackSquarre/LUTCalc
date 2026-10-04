import Foundation
import LUTCore

private struct Failure: Error, CustomStringConvertible {
    let size: Int; let index: Int; let actual: Double; let expected: Double
    var description: String { "size=\(size) node=\(index): actual=\(actual), expected=\(expected)" }
}

private func reference(_ signal: Double, black: Double, white: Double, gamma: Double) -> Double {
    let br = pow(black, 1 / gamma)
    let wr = pow(white, 1 / gamma)
    return pow((wr - br) * signal + br, gamma)
}

private func run(size: Int) throws -> (Int, Double) {
    let grid = try Grid3D(size: size, domain: .unit)
    let transfer = try BT1886Transfer(blackLevel: 0.01, whiteLevel: 1, gamma: 2.4)
    var maximum = 0.0
    for index in 0..<grid.nodeCount {
        let input = try grid.coordinate(at: index)
        let values = [input.r, input.g, input.b]
        for value in values {
            let expected = reference(value, black: 0.01, white: 1, gamma: 2.4)
            let actual = try transfer.encodeDisplayToLuminance(value)
            let error = abs(actual - expected)
            maximum = max(maximum, error)
            guard error <= 2e-12 else { throw Failure(size: size, index: index, actual: actual, expected: expected) }
            let decoded = try transfer.decodeLuminanceToDisplay(actual)
            guard abs(decoded - value) <= 2e-12 else { throw Failure(size: size, index: index, actual: decoded, expected: value) }
        }
    }
    return (grid.nodeCount, maximum)
}

do {
    for size in [33, 65] {
        let result = try run(size: size)
        print("H11 BT.1886 \(size)³ 独立公式与逆函数全节点通过：\(result.0) 节点，最大绝对误差 \(result.1)")
    }
} catch {
    fputs("LUTBT1886Checks: \(error)\n", stderr)
    exit(1)
}
