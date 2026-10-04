import LUTCore
import LUTFormats
import LUTAnalysis

public enum JobFailure: Error, Equatable, Sendable {
    case invalidBlockSize
    case invalidWorkerCount
    case alreadyStarted
    case sinkState
    case outOfOrderBlock
    case rowCountMismatch
    case injectedWriteFailure
    case unsupportedUserLUT
    case conflictingInputTransforms
    case invalidInputInverseDomain
}

public enum JobState: String, Codable, Sendable {
    case queued
    case running
    case validating
    case committing
    case completed
    case cancelled
    case failed
}

public struct LUTGenerationRequest: Sendable {
    public let plan: TransformPlan
    public let size: Int
    public let domain: LUTDomain
    public let blockNodes: Int
    public let workerCount: Int
    /// Optional user LUT applied after output encoding and normalization.
    public let postLUT: CubeLUT?
    public let postLUTSettings: UserLUTPostStageSettings?
    public let postSampler: PreparedCubeSampler?
    /// Optional input shaper used by streamed 3DL generation. The coordinator
    /// evaluates each file-grid coordinate through this curve before the plan.
    public let inputShaper: CubeShaper?
    public let inputShaperSampler: PreparedCubeSampler?
    /// Optional strict 1D cubic inverse applied to the generation grid before
    /// the transform plan. Arbitrary 3D inversion is never inferred.
    public let inputTransferInverse: ImportedLUTInversePlan?
    /// Optional caller-supplied affine 3D inverse. Arbitrary 3D inversion is
    /// never inferred from a LUT volume.
    public let inputAffineInverse: KnownAffine3DInversePlan?

    public init(plan: TransformPlan, size: Int, domain: LUTDomain, blockNodes: Int = 4096,
                workerCount: Int = 2, postLUT: CubeLUT? = nil,
                postLUTSettings: UserLUTPostStageSettings? = nil,
                inputShaper: CubeShaper? = nil,
                inputTransferInverse: ImportedLUTInversePlan? = nil,
                inputAffineInverse: KnownAffine3DInversePlan? = nil) throws {
        guard blockNodes > 0 else { throw JobFailure.invalidBlockSize }
        guard (1...4).contains(workerCount) else { throw JobFailure.invalidWorkerCount }
        guard inputShaper == nil || (inputTransferInverse == nil && inputAffineInverse == nil) else {
            throw JobFailure.conflictingInputTransforms
        }
        guard inputTransferInverse == nil || inputAffineInverse == nil else {
            throw JobFailure.conflictingInputTransforms
        }
        if let inputAffineInverse, inputAffineInverse.outputDomain != domain {
            throw JobFailure.invalidInputInverseDomain
        }
        _ = try Grid3D(size: size, domain: domain)
        if let postLUT, postLUTSettings == nil {
            guard postLUT.dimension == .one, postLUT.shaper == nil,
                  postLUT.domain.min.r.bitPattern == 0,
                  postLUT.domain.min.g.bitPattern == 0,
                  postLUT.domain.min.b.bitPattern == 0,
                  postLUT.domain.max.r.bitPattern == 1.0.bitPattern,
                  postLUT.domain.max.g.bitPattern == 1.0.bitPattern,
                  postLUT.domain.max.b.bitPattern == 1.0.bitPattern else {
                throw JobFailure.unsupportedUserLUT
            }
        }
        self.plan = plan
        self.size = size
        self.domain = domain
        self.blockNodes = blockNodes
        self.workerCount = workerCount
        self.postLUT = postLUT
        self.postLUTSettings = postLUTSettings
        self.postSampler = try Self.prepare(postLUT, settings: postLUTSettings)
        self.inputShaper = inputShaper
        self.inputTransferInverse = inputTransferInverse
        self.inputAffineInverse = inputAffineInverse
        if let inputShaper {
            let lut = try CubeLUT(dimension: .one, size: inputShaper.size,
                                  domain: inputShaper.domain, samples: inputShaper.samples)
            self.inputShaperSampler = try lut.preparedSampler(interpolation: .trilinear)
        } else {
            self.inputShaperSampler = nil
        }
    }

    fileprivate static func prepare(_ lut: CubeLUT?, settings: UserLUTPostStageSettings?) throws -> PreparedCubeSampler? {
        guard let lut else {
            guard settings == nil else { throw JobFailure.unsupportedUserLUT }
            return nil
        }
        if settings?.outside == .legacyExtensionV1,
           lut.dimension != .one || settings?.interpolation != .tricubicLegacyV1 {
            throw VolumeError.unsupportedOutsidePolicy
        }
        return try lut.preparedSampler(interpolation: settings?.interpolation ?? .trilinear)
    }
}

public struct GenerationReport: Sendable {
    public let writtenNodes: Int
    public let blocks: Int
    public let maxPendingBlocks: Int
    public let state: JobState
}

public struct LUT1DGenerationRequest: Sendable {
    public let plan: TransformPlan
    public let size: Int
    public let domain: LUTDomain
    public let blockNodes: Int
    public let workerCount: Int
    public let postLUT: CubeLUT?
    public let postLUTSettings: UserLUTPostStageSettings?
    public let postSampler: PreparedCubeSampler?

    public init(plan: TransformPlan, size: Int, domain: LUTDomain,
                blockNodes: Int = 4096, workerCount: Int = 2,
                postLUT: CubeLUT? = nil, postLUTSettings: UserLUTPostStageSettings? = nil,
                inputTransferInverse: ImportedLUTInversePlan? = nil) throws {
        guard size >= 2 else { throw JobFailure.invalidBlockSize }
        guard size <= CubeParser.maxDecodedBytes / MemoryLayout<RGB64>.stride else {
            throw SPI1DFailure(.resourceLimit, line: 0)
        }
        guard domain.min.r.bitPattern == domain.min.g.bitPattern,
              domain.min.r.bitPattern == domain.min.b.bitPattern,
              domain.max.r.bitPattern == domain.max.g.bitPattern,
              domain.max.r.bitPattern == domain.max.b.bitPattern else {
            throw SPI1DFailure(.lossyRepresentation, line: 0)
        }
        guard plan.settings.inputSpace == plan.settings.outputSpace,
              plan.settings.sdrSaturation?.enabled != true,
              plan.settings.multitone?.enabled != true,
              plan.settings.highlightGamut?.enabled != true,
              plan.settings.gamutLimiter?.enabled != true,
              plan.settings.falseColour?.isActive != true,
              plan.settings.hlgOOTF?.enabled != true else {
            throw SPI1DFailure(.lossyRepresentation, line: 0)
        }
        guard inputTransferInverse == nil else {
            throw SPI1DFailure(.lossyRepresentation, line: 0)
        }
        if let postLUT {
            guard postLUT.dimension == .one, postLUT.shaper == nil else {
                throw SPI1DFailure(.lossyRepresentation, line: 0)
            }
            if postLUTSettings == nil {
                guard
                  postLUT.domain.min.r.bitPattern == 0,
                  postLUT.domain.min.g.bitPattern == 0,
                  postLUT.domain.min.b.bitPattern == 0,
                  postLUT.domain.max.r.bitPattern == 1.0.bitPattern,
                  postLUT.domain.max.g.bitPattern == 1.0.bitPattern,
                  postLUT.domain.max.b.bitPattern == 1.0.bitPattern else {
                throw SPI1DFailure(.lossyRepresentation, line: 0)
                }
            }
        }
        guard blockNodes > 0 else { throw JobFailure.invalidBlockSize }
        guard (1...4).contains(workerCount) else { throw JobFailure.invalidWorkerCount }
        self.plan = plan
        self.size = size
        self.domain = domain
        self.blockNodes = blockNodes
        self.workerCount = workerCount
        self.postLUT = postLUT
        self.postLUTSettings = postLUTSettings
        self.postSampler = try LUTGenerationRequest.prepare(postLUT, settings: postLUTSettings)
    }
}

public struct OneDGenerationReport: Sendable {
    public let writtenNodes: Int
    public let blocks: Int
    public let maxPendingBlocks: Int
    public let state: JobState
}

public protocol OneDBlockSink: Actor {
    func prepare(size: Int, domain: LUTDomain, title: String) async throws
    func append(blockIndex: Int, samples: [RGB64]) async throws
    func validate(expectedNodes: Int) async throws
    func commit() async throws
    func abort() async
}

private struct OneDBlockResult: Sendable {
    let index: Int
    let samples: [RGB64]
}

public actor OneDGenerationCoordinator {
    public private(set) var state: JobState = .queued
    private let testHooks: GenerationTestHooks?

    public init() { testHooks = nil }
    package init(testHooks: GenerationTestHooks) { self.testHooks = testHooks }

    public func generate<S: OneDBlockSink>(_ request: LUT1DGenerationRequest,
                                           sink: S) async throws -> OneDGenerationReport {
        guard state == .queued else { throw JobFailure.alreadyStarted }
        let blockCount = request.size / request.blockNodes +
            (request.size % request.blockNodes == 0 ? 0 : 1)
        let hooks = testHooks
        state = .running
        do {
            try Task.checkCancellation()
            try await sink.prepare(size: request.size, domain: request.domain,
                                   title: "LUTCalc native \(request.plan.planVersion)")
            var writtenNodes = 0
            var maxPending = 0
            try await withThrowingTaskGroup(of: OneDBlockResult.self) { group in
                var nextLaunch = 0
                var nextWrite = 0
                var inFlight = 0
                var pending: [Int: OneDBlockResult] = [:]
                let window = 2 * request.workerCount

                func launchAvailable() {
                    while nextLaunch < blockCount,
                          inFlight < request.workerCount,
                          nextLaunch < nextWrite + window {
                        let blockIndex = nextLaunch
                        nextLaunch += 1
                        inFlight += 1
                        group.addTask {
                            let start = blockIndex * request.blockNodes
                            let count = min(request.blockNodes, request.size - start)
                            let lower = request.domain.min.r
                            let upper = request.domain.max.r
                            var samples: [RGB64] = []
                            samples.reserveCapacity(count)
                            for offset in 0..<count {
                                if offset % 256 == 0 { try Task.checkCancellation() }
                                let index = start + offset
                                let scalar = lower + (upper - lower) * Double(index) / Double(request.size - 1)
                                let base = try RGB64(
                                    request.plan.evaluateIndependentChannels(RGB64(scalar, 0, 0), sampleIndex: index).r,
                                    request.plan.evaluateIndependentChannels(RGB64(0, scalar, 0), sampleIndex: index).g,
                                    request.plan.evaluateIndependentChannels(RGB64(0, 0, scalar), sampleIndex: index).b)
                                let output = if let sampler = request.postSampler {
                                    try sampler.sample(base, outside: request.postLUTSettings?.outside ?? .reject)
                                } else { base }
                                samples.append(output)
                            }
                            try await hooks?.beforeComplete(blockIndex)
                            try Task.checkCancellation()
                            return OneDBlockResult(index: blockIndex, samples: samples)
                        }
                    }
                }

                launchAvailable()
                while nextWrite < blockCount {
                    try Task.checkCancellation()
                    guard let result = try await group.next() else { throw JobFailure.rowCountMismatch }
                    if let didReceive = hooks?.didReceive { await didReceive(result.index) }
                    inFlight -= 1
                    pending[result.index] = result
                    maxPending = max(maxPending, pending.count)
                    while let ready = pending.removeValue(forKey: nextWrite) {
                        try Task.checkCancellation()
                        try await sink.append(blockIndex: nextWrite, samples: ready.samples)
                        writtenNodes += ready.samples.count
                        nextWrite += 1
                    }
                    launchAvailable()
                }
            }
            state = .validating
            try Task.checkCancellation()
            try await sink.validate(expectedNodes: request.size)
            try Task.checkCancellation()
            state = .committing
            try await sink.commit()
            state = .completed
            return OneDGenerationReport(writtenNodes: writtenNodes, blocks: blockCount,
                                        maxPendingBlocks: maxPending, state: state)
        } catch {
            let commitStarted = state == .committing
            await sink.abort()
            state = !commitStarted && error is CancellationError ? .cancelled : .failed
            throw error
        }
    }
}

public protocol CubeBlockSink: Actor {
    func prepare(size: Int, domain: LUTDomain, title: String) async throws
    func append(blockIndex: Int, samples: [RGB64]) async throws
    func validate(expectedNodes: Int) async throws
    func commit() async throws
    func abort() async
}

private struct BlockResult: Sendable {
    let index: Int
    let samples: [RGB64]
}

/// A worker error annotated with its block so concurrent completion order does
/// not change the reported sample location. The underlying error remains the
/// original `PlanError`, cancellation, or sink-independent generation error.
private struct IndexedBlockFailure: Error, @unchecked Sendable {
    let blockIndex: Int
    let underlying: Error
}

package struct GenerationTestHooks: Sendable {
    package let beforeComplete: @Sendable (Int) async throws -> Void
    package let didReceive: @Sendable (Int) async -> Void

    package init(beforeComplete: @escaping @Sendable (Int) async throws -> Void,
                 didReceive: @escaping @Sendable (Int) async -> Void) {
        self.beforeComplete = beforeComplete
        self.didReceive = didReceive
    }
}

public actor GenerationCoordinator {
    public private(set) var state: JobState = .queued
    private let testHooks: GenerationTestHooks?

    public init() { testHooks = nil }
    package init(testHooks: GenerationTestHooks) { self.testHooks = testHooks }

    public func generate<S: CubeBlockSink>(_ request: LUTGenerationRequest, sink: S) async throws -> GenerationReport {
        guard state == .queued else { throw JobFailure.alreadyStarted }
        let grid = try Grid3D(size: request.size, domain: request.domain)
        guard grid.rgbDoubleBytes <= CubeParser.maxDecodedBytes else {
            throw CubeGenerationFailure.memoryBudgetExceeded
        }
        let blockCount = grid.nodeCount / request.blockNodes + (grid.nodeCount % request.blockNodes == 0 ? 0 : 1)
        let hooks = testHooks
        state = .running
        do {
            try Task.checkCancellation()
            try await sink.prepare(size: request.size, domain: request.domain, title: "LUTCalc native \(request.plan.planVersion)")
            var writtenNodes = 0
            var maxPending = 0
            try await withThrowingTaskGroup(of: Result<BlockResult, IndexedBlockFailure>.self) { group in
                var nextLaunch = 0
                var nextWrite = 0
                var inFlight = 0
                var pending: [Int: BlockResult] = [:]
                var firstFailure: IndexedBlockFailure?
                let window = 2 * request.workerCount

                func launchAvailable() {
                    while nextLaunch < blockCount,
                          inFlight < request.workerCount,
                          nextLaunch < nextWrite + window {
                        let blockIndex = nextLaunch
                        nextLaunch += 1
                        inFlight += 1
                        group.addTask {
                            do {
                                return .success(try await Self.computeBlock(
                                    blockIndex, request: request, grid: grid,
                                    beforeComplete: hooks?.beforeComplete
                                ))
                            } catch {
                                return .failure(IndexedBlockFailure(blockIndex: blockIndex,
                                                                     underlying: error))
                            }
                        }
                    }
                }

                launchAvailable()
                while inFlight > 0 || (firstFailure == nil && nextWrite < blockCount) {
                    try Task.checkCancellation()
                    guard let result = try await group.next() else {
                        if firstFailure == nil { throw JobFailure.rowCountMismatch }
                        break
                    }
                    inFlight -= 1
                    switch result {
                    case .failure(let failure):
                        if firstFailure == nil || failure.blockIndex < firstFailure!.blockIndex {
                            firstFailure = failure
                        }
                        group.cancelAll()
                    case .success(let block):
                        if let didReceive = hooks?.didReceive { await didReceive(block.index) }
                        guard firstFailure == nil else { continue }
                        pending[block.index] = block
                        maxPending = max(maxPending, pending.count)
                        while let ready = pending.removeValue(forKey: nextWrite) {
                            try Task.checkCancellation()
                            try await sink.append(blockIndex: nextWrite, samples: ready.samples)
                            writtenNodes += ready.samples.count
                            nextWrite += 1
                        }
                        launchAvailable()
                    }
                }
                if let firstFailure { throw firstFailure.underlying }
                guard nextWrite == blockCount else { throw JobFailure.rowCountMismatch }
            }
            state = .validating
            try Task.checkCancellation()
            try await sink.validate(expectedNodes: grid.nodeCount)
            try Task.checkCancellation()
            state = .committing
            try await sink.commit()
            state = .completed
            return GenerationReport(writtenNodes: writtenNodes, blocks: blockCount, maxPendingBlocks: maxPending, state: state)
        } catch {
            let commitStarted = state == .committing
            await sink.abort()
            state = !commitStarted && error is CancellationError ? .cancelled : .failed
            throw error
        }
    }

    nonisolated private static func computeBlock(
        _ blockIndex: Int, request: LUTGenerationRequest, grid: Grid3D,
        beforeComplete: (@Sendable (Int) async throws -> Void)?
    ) async throws -> BlockResult {
        let start = blockIndex * request.blockNodes
        let count = min(request.blockNodes, grid.nodeCount - start)
        var samples: [RGB64] = []
        samples.reserveCapacity(count)
        for offset in 0..<count {
            if offset % 256 == 0 { try Task.checkCancellation() }
            let index = start + offset
            let coordinate = try grid.coordinate(at: index)
            let inverseInput: RGB64
            if let inputAffineInverse = request.inputAffineInverse {
                inverseInput = try inputAffineInverse.apply(coordinate)
            } else if let inputTransferInverse = request.inputTransferInverse {
                inverseInput = try inputTransferInverse.apply(coordinate)
            } else {
                inverseInput = coordinate
            }
            let shapedInput: RGB64
            if let sampler = request.inputShaperSampler {
                shapedInput = try sampler.sample(inverseInput, outside: .reject)
            } else {
                shapedInput = inverseInput
            }
            let base = try request.plan.evaluate(shapedInput, sampleIndex: index)
            if let sampler = request.postSampler {
                samples.append(try sampler.sample(base, outside: request.postLUTSettings?.outside ?? .reject))
            } else {
                samples.append(base)
            }
        }
        try await beforeComplete?(blockIndex)
        try Task.checkCancellation()
        return BlockResult(index: blockIndex, samples: samples)
    }
}

public enum SinkState: String, Sendable {
    case idle
    case writing
    case validated
    case committed
    case aborted
}

public actor InMemoryCubeSink: CubeBlockSink {
    public private(set) var state: SinkState = .idle
    public private(set) var samples: [RGB64] = []
    private var nextBlock = 0
    private let failAtBlock: Int?
    private let cancelAtBlock: Int?

    public init(failAtBlock: Int? = nil, cancelAtBlock: Int? = nil) {
        self.failAtBlock = failAtBlock
        self.cancelAtBlock = cancelAtBlock
    }

    public func prepare(size: Int, domain: LUTDomain, title: String) throws {
        guard state == .idle else { throw JobFailure.sinkState }
        state = .writing
    }

    public func append(blockIndex: Int, samples newSamples: [RGB64]) throws {
        guard state == .writing else { throw JobFailure.sinkState }
        guard blockIndex == nextBlock else { throw JobFailure.outOfOrderBlock }
        if blockIndex == failAtBlock { throw JobFailure.injectedWriteFailure }
        if blockIndex == cancelAtBlock { throw CancellationError() }
        samples.append(contentsOf: newSamples)
        nextBlock += 1
    }

    public func validate(expectedNodes: Int) throws {
        guard state == .writing else { throw JobFailure.sinkState }
        guard samples.count == expectedNodes else { throw JobFailure.rowCountMismatch }
        state = .validated
    }

    public func commit() throws {
        guard state == .validated else { throw JobFailure.sinkState }
        state = .committed
    }

    public func abort() {
        if state != .committed { state = .aborted; samples.removeAll() }
    }
}
