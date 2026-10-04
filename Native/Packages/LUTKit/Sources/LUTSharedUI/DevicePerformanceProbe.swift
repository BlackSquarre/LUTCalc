import Foundation
import LUTCore
import LUTFormats

public struct DevicePerformanceMeasurement: Codable, Equatable, Sendable {
    public let size: Int
    public let nodes: Int
    public let seconds: Double
    public let nodesPerSecond: Double
    public let checksum: UInt64

    public init(size: Int, nodes: Int, seconds: Double, nodesPerSecond: Double,
                checksum: UInt64) {
        self.size = size
        self.nodes = nodes
        self.seconds = seconds
        self.nodesPerSecond = nodesPerSecond
        self.checksum = checksum
    }
}

public struct DevicePerformanceProbeResult: Codable, Equatable, Sendable {
    public static let currentSchema = "native.device-performance.v1"

    public let schema: String
    public let toolchain: String
    public let host: String
    public let planVersion: String
    public let results: [DevicePerformanceMeasurement]

    public init(toolchain: String, host: String, planVersion: String,
                results: [DevicePerformanceMeasurement]) {
        self.schema = Self.currentSchema
        self.toolchain = toolchain
        self.host = host
        self.planVersion = planVersion
        self.results = results
    }
}

public struct DevicePerformanceRepeatedMeasurement: Codable, Equatable, Sendable {
    public let size: Int
    public let nodes: Int
    public let seconds: [Double]
    public let minimumSeconds: Double
    public let medianSeconds: Double
    public let maximumSeconds: Double
    public let checksum: UInt64

    public init(size: Int, nodes: Int, seconds: [Double], minimumSeconds: Double,
                medianSeconds: Double, maximumSeconds: Double, checksum: UInt64) {
        self.size = size
        self.nodes = nodes
        self.seconds = seconds
        self.minimumSeconds = minimumSeconds
        self.medianSeconds = medianSeconds
        self.maximumSeconds = maximumSeconds
        self.checksum = checksum
    }
}

public struct DevicePerformanceRepeatedProbeResult: Codable, Equatable, Sendable {
    public static let currentSchema = "native.device-performance-repeat.v1"

    public let schema: String
    public let toolchain: String
    public let host: String
    public let planVersion: String
    public let warmups: Int
    public let repetitions: Int
    public let measurements: [DevicePerformanceRepeatedMeasurement]

    public init(toolchain: String, host: String, planVersion: String, warmups: Int,
                repetitions: Int, measurements: [DevicePerformanceRepeatedMeasurement]) {
        self.schema = Self.currentSchema
        self.toolchain = toolchain
        self.host = host
        self.planVersion = planVersion
        self.warmups = warmups
        self.repetitions = repetitions
        self.measurements = measurements
    }
}

public enum DevicePerformanceProbeError: Error, Equatable, Sendable {
    case emptySizes
    case invalidSize(Int)
    case duplicateSize(Int)
    case invalidRepetitions(Int)
    case invalidWarmups(Int)
    case cancelled
}

/// Runs a deterministic backend generation workload and reports timing separately
/// from a Double bit-pattern checksum. The checksum is a stability guard, not a
/// numerical reference or a replacement for independent validation.
public enum DevicePerformanceProbe {
    public static let defaultSizes = [17, 33, 65]

    public static func run(sizes: [Int] = defaultSizes) throws -> DevicePerformanceProbeResult {
        guard !sizes.isEmpty else { throw DevicePerformanceProbeError.emptySizes }
        var seen = Set<Int>()
        for size in sizes {
            guard (2...65).contains(size), (try? Grid3D(size: size, domain: .unit)) != nil else {
                throw DevicePerformanceProbeError.invalidSize(size)
            }
            guard seen.insert(size).inserted else {
                throw DevicePerformanceProbeError.duplicateSize(size)
            }
        }

        let plan = try TransformPlan(settings: TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1))
        var measurements: [DevicePerformanceMeasurement] = []
        measurements.reserveCapacity(sizes.count)

        for size in sizes {
            let start = ContinuousClock.now
            let lut = try CubeGenerator.generate3D(plan: plan, size: size, domain: .unit)
            let elapsed = start.duration(to: ContinuousClock.now)
            let seconds = Double(elapsed.components.seconds) +
                Double(elapsed.components.attoseconds) / 1e18
            var checksum: UInt64 = 1_469_598_103_934_665_603
            for sample in lut.samples {
                checksum ^= sample.r.bitPattern
                checksum &*= 1_099_511_628_211
                checksum ^= sample.g.bitPattern
                checksum &*= 1_099_511_628_211
                checksum ^= sample.b.bitPattern
                checksum &*= 1_099_511_628_211
            }
            measurements.append(DevicePerformanceMeasurement(
                size: size,
                nodes: lut.samples.count,
                seconds: seconds,
                nodesPerSecond: Double(lut.samples.count) /
                    max(seconds, .leastNonzeroMagnitude),
                checksum: checksum))
        }

        return DevicePerformanceProbeResult(
            toolchain: ProcessInfo.processInfo.environment["SWIFT_VERSION"] ?? "swift-runtime",
            // Avoid reverse DNS on iOS; ProcessInfo.hostName may block during launch.
            host: "Apple-platform-runtime",
            planVersion: plan.planVersion,
            results: measurements)
    }

    public static func encodedJSON(sizes: [Int] = defaultSizes) throws -> Data {
        try JSONEncoder().encode(run(sizes: sizes))
    }

    public static func runRepeated(
        sizes: [Int] = defaultSizes,
        repetitions: Int = 5,
        warmups: Int = 1,
        shouldCancel: () -> Bool = { false }
    ) throws -> DevicePerformanceRepeatedProbeResult {
        guard repetitions > 0 else { throw DevicePerformanceProbeError.invalidRepetitions(repetitions) }
        guard warmups >= 0 else { throw DevicePerformanceProbeError.invalidWarmups(warmups) }
        try validateSizes(sizes)

        let plan = try TransformPlan(settings: TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .acesAP0,
            inputRange: .data, outputRange: .data, exposureStops: 1))
        var measurements: [DevicePerformanceRepeatedMeasurement] = []
        measurements.reserveCapacity(sizes.count)

        for size in sizes {
            for _ in 0..<warmups {
                try checkCancellation(shouldCancel)
                _ = try CubeGenerator.generate3D(plan: plan, size: size, domain: .unit)
            }

            var seconds: [Double] = []
            seconds.reserveCapacity(repetitions)
            var nodes = 0
            var checksum: UInt64 = 0
            for _ in 0..<repetitions {
                try checkCancellation(shouldCancel)
                let start = ContinuousClock.now
                let lut = try CubeGenerator.generate3D(plan: plan, size: size, domain: .unit)
                let elapsed = start.duration(to: ContinuousClock.now)
                let elapsedSeconds = Double(elapsed.components.seconds) +
                    Double(elapsed.components.attoseconds) / 1e18
                seconds.append(elapsedSeconds)
                nodes = lut.samples.count
                checksum = checksumFor(lut)
            }

            let sorted = seconds.sorted()
            let median = sorted.count % 2 == 1
                ? sorted[sorted.count / 2]
                : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
            measurements.append(DevicePerformanceRepeatedMeasurement(
                size: size,
                nodes: nodes,
                seconds: seconds,
                minimumSeconds: sorted[0],
                medianSeconds: median,
                maximumSeconds: sorted[sorted.count - 1],
                checksum: checksum))
        }

        return DevicePerformanceRepeatedProbeResult(
            toolchain: ProcessInfo.processInfo.environment["SWIFT_VERSION"] ?? "swift-runtime",
            host: "Apple-platform-runtime",
            planVersion: plan.planVersion,
            warmups: warmups,
            repetitions: repetitions,
            measurements: measurements)
    }

    public static func encodedRepeatedJSON(
        sizes: [Int] = defaultSizes,
        repetitions: Int = 5,
        warmups: Int = 1
    ) throws -> Data {
        try JSONEncoder().encode(runRepeated(sizes: sizes, repetitions: repetitions, warmups: warmups))
    }

    private static func validateSizes(_ sizes: [Int]) throws {
        guard !sizes.isEmpty else { throw DevicePerformanceProbeError.emptySizes }
        var seen = Set<Int>()
        for size in sizes {
            guard (2...65).contains(size), (try? Grid3D(size: size, domain: .unit)) != nil else {
                throw DevicePerformanceProbeError.invalidSize(size)
            }
            guard seen.insert(size).inserted else {
                throw DevicePerformanceProbeError.duplicateSize(size)
            }
        }
    }

    private static func checkCancellation(_ shouldCancel: () -> Bool) throws {
        if shouldCancel() { throw DevicePerformanceProbeError.cancelled }
    }

    private static func checksumFor(_ lut: CubeLUT) -> UInt64 {
        var checksum: UInt64 = 1_469_598_103_934_665_603
        for sample in lut.samples {
            checksum ^= sample.r.bitPattern
            checksum &*= 1_099_511_628_211
            checksum ^= sample.g.bitPattern
            checksum &*= 1_099_511_628_211
            checksum ^= sample.b.bitPattern
            checksum &*= 1_099_511_628_211
        }
        return checksum
    }
}
