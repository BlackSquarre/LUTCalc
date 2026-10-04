import Foundation
import LUTCore
import LUTFormats

private struct BenchmarkResult: Codable {
    let toolchain: String
    let host: String
    let planVersion: String
    let results: [SizeResult]
}

private struct SizeResult: Codable {
    let size: Int
    let nodes: Int
    let seconds: Double
    let nodesPerSecond: Double
    let checksum: UInt64
}

@main
struct LUTPerformanceChecks {
    static func main() throws {
        let arguments = Set(CommandLine.arguments.dropFirst())
        let sizes = arguments.contains("--quick") ? [17, 33] : [17, 33, 65]
        let plan = try TransformPlan(settings: TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1))
        var measurements: [SizeResult] = []
        for size in sizes {
            let start = ContinuousClock.now
            let lut = try CubeGenerator.generate3D(plan: plan, size: size, domain: .unit)
            let elapsed = start.duration(to: ContinuousClock.now)
            let seconds = elapsed.components.attoseconds == 0
                ? Double(elapsed.components.seconds)
                : Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            let nodes = lut.samples.count
            var checksum: UInt64 = 1469598103934665603
            for sample in lut.samples {
                checksum ^= sample.r.bitPattern
                checksum &*= 1099511628211
                checksum ^= sample.g.bitPattern
                checksum &*= 1099511628211
                checksum ^= sample.b.bitPattern
                checksum &*= 1099511628211
            }
            measurements.append(SizeResult(
                size: size, nodes: nodes, seconds: seconds,
                nodesPerSecond: Double(nodes) / max(seconds, .leastNonzeroMagnitude),
                checksum: checksum))
        }
        let result = BenchmarkResult(
            toolchain: ProcessInfo.processInfo.environment["SWIFT_VERSION"] ?? "swift-runtime",
            host: ProcessInfo.processInfo.hostName,
            planVersion: plan.planVersion,
            results: measurements)
        let data = try JSONEncoder().encode(result)
        print(String(decoding: data, as: UTF8.self))
    }
}
