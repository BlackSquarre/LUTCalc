import Foundation
import LUTCore
import LUTFormats
import LUTJobs

@main
struct LUTJobChecks {
    static func main() async {
        do {
            let plan = try TransformPlan(settings: TransformSettings(
                inputTransfer: .djiDLog2, outputTransfer: .linearScene,
                inputSpace: .djiDGamut2, outputSpace: .acesAP0,
                inputRange: .data, outputRange: .data, exposureStops: 1
            ))
            let expected = try CubeGenerator.generate3D(plan: plan, size: 17, domain: .unit).samples
            for workers in [1, 2, 4] {
                for blockSize in [1, 17, 4096] {
                    let sink = InMemoryCubeSink()
                    let request = try LUTGenerationRequest(plan: plan, size: 17, domain: .unit, blockNodes: blockSize, workerCount: workers)
                    let report = try await GenerationCoordinator().generate(request, sink: sink)
                    guard report.writtenNodes == expected.count,
                          report.maxPendingBlocks <= 2 * workers,
                          await sink.samples == expected,
                          await sink.state == .committed else {
                        throw CheckFailure.mismatch(workers: workers, blockNodes: blockSize)
                    }
                }
            }
            let reverseGate = ReverseCompletionGate()
            let reverseHooks = GenerationTestHooks(
                beforeComplete: { index in await reverseGate.beforeCompletion(index) },
                didReceive: { index in await reverseGate.didReceive(index) }
            )
            let reverseRequest = try LUTGenerationRequest(
                plan: plan, size: 3, domain: .unit, blockNodes: 3, workerCount: 4
            )
            let reverseSink = InMemoryCubeSink()
            let reverseJob = GenerationCoordinator(testHooks: reverseHooks)
            let reverseTask = Task { try await reverseJob.generate(reverseRequest, sink: reverseSink) }
            let forcedOrder = [3, 2, 1, 0, 7, 6, 5, 4, 8]
            for block in forcedOrder {
                await reverseGate.waitUntilEntered(block)
                await reverseGate.release(block)
                await reverseGate.waitUntilReceived(block)
            }
            let reverseReport = try await reverseTask.value
            let reverseExpected = try CubeGenerator.generate3D(plan: plan, size: 3, domain: .unit).samples
            guard await reverseGate.received == forcedOrder,
                  await reverseSink.samples == reverseExpected,
                  reverseReport.maxPendingBlocks == 4,
                  reverseReport.state == .completed else {
                throw CheckFailure.mismatch(workers: 4, blockNodes: 3)
            }
            let failureRequest = try LUTGenerationRequest(plan: plan, size: 3, domain: .unit, blockNodes: 3, workerCount: 2)
            let failureSink = InMemoryCubeSink(failAtBlock: 2)
            let failureJob = GenerationCoordinator()
            do {
                _ = try await failureJob.generate(failureRequest, sink: failureSink)
                throw CheckFailure.mismatch(workers: 2, blockNodes: 3)
            } catch JobFailure.injectedWriteFailure {}
            guard await failureJob.state == .failed, await failureSink.state == .aborted,
                  await failureSink.samples.isEmpty else {
                throw CheckFailure.mismatch(workers: 2, blockNodes: 3)
            }
            let cancelSink = InMemoryCubeSink(cancelAtBlock: 2)
            let cancelJob = GenerationCoordinator()
            do {
                _ = try await cancelJob.generate(failureRequest, sink: cancelSink)
                throw CheckFailure.mismatch(workers: 2, blockNodes: 3)
            } catch is CancellationError {}
            guard await cancelJob.state == .cancelled, await cancelSink.state == .aborted,
                  await cancelSink.samples.isEmpty else {
                throw CheckFailure.mismatch(workers: 2, blockNodes: 3)
            }
            let gateSink = ValidationGateSink()
            let realCancelJob = GenerationCoordinator()
            let realCancelTask = Task {
                try await realCancelJob.generate(failureRequest, sink: gateSink)
            }
            await gateSink.waitUntilValidation()
            realCancelTask.cancel()
            await gateSink.releaseValidation()
            do {
                _ = try await realCancelTask.value
                throw CheckFailure.mismatch(workers: 2, blockNodes: 3)
            } catch is CancellationError {}
            guard await realCancelJob.state == .cancelled, await gateSink.state == .aborted else {
                throw CheckFailure.mismatch(workers: 2, blockNodes: 3)
            }
            for boundary in 0..<9 {
                let blockSink = BlockGateSink(targetBlock: boundary)
                let blockJob = GenerationCoordinator()
                let blockTask = Task {
                    try await blockJob.generate(failureRequest, sink: blockSink)
                }
                await blockSink.waitUntilBlock()
                blockTask.cancel()
                await blockSink.releaseBlock()
                do {
                    _ = try await blockTask.value
                    throw CheckFailure.mismatch(workers: 2, blockNodes: boundary)
                } catch is CancellationError {}
                guard await blockJob.state == .cancelled, await blockSink.state == .aborted,
                      await blockSink.commits == 0 else {
                    throw CheckFailure.mismatch(workers: 2, blockNodes: boundary)
                }
            }
            for failsDuringCommit in [false, true] {
                let commitSink = CommitGateSink(failsDuringCommit: failsDuringCommit)
                let commitJob = GenerationCoordinator()
                let commitTask = Task {
                    try await commitJob.generate(failureRequest, sink: commitSink)
                }
                await commitSink.waitUntilCommit()
                guard await commitJob.state == .committing else {
                    throw CheckFailure.mismatch(workers: 2, blockNodes: 3)
                }
                commitTask.cancel()
                await commitSink.releaseCommit()
                if failsDuringCommit {
                    do {
                        _ = try await commitTask.value
                        throw CheckFailure.mismatch(workers: 2, blockNodes: 3)
                    } catch is CancellationError {}
                    guard await commitJob.state == .failed, await commitSink.state == .aborted else {
                        throw CheckFailure.mismatch(workers: 2, blockNodes: 3)
                    }
                } else {
                    let report = try await commitTask.value
                    guard report.state == .completed, await commitJob.state == .completed,
                          await commitSink.state == .committed else {
                        throw CheckFailure.mismatch(workers: 2, blockNodes: 3)
                    }
                }
            }
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lutcalc-job-check-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: directory) }
            for boundary in 0..<9 {
                let cancelledURL = directory.appendingPathComponent("cancel-\(boundary).cube")
                let cancelledFile = FileCubeSink(target: cancelledURL)
                let gatedFile = FileBlockGateSink(fileSink: cancelledFile, targetBlock: boundary)
                let fileJob = GenerationCoordinator()
                let fileTask = Task {
                    try await fileJob.generate(failureRequest, sink: gatedFile)
                }
                await gatedFile.waitUntilBlock()
                fileTask.cancel()
                await gatedFile.releaseBlock()
                do {
                    _ = try await fileTask.value
                    throw CheckFailure.mismatch(workers: 2, blockNodes: boundary)
                } catch is CancellationError {}
                let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
                guard await fileJob.state == .cancelled,
                      await cancelledFile.state == .aborted,
                      await gatedFile.commits == 0,
                      remaining.isEmpty else {
                    throw CheckFailure.mismatch(workers: 2, blockNodes: boundary)
                }
            }
            let fileURL = directory.appendingPathComponent("output.cube")
            let fileSink = FileCubeSink(target: fileURL)
            let fileRequest = try LUTGenerationRequest(plan: plan, size: 17, domain: .unit, blockNodes: 4096, workerCount: 2)
            let fileReport = try await GenerationCoordinator().generate(fileRequest, sink: fileSink)
            let parsed = try CubeParser.parse(url: fileURL)
            guard fileReport.state == .completed, parsed.samples == expected,
                  await fileSink.state == .committed else {
                throw CheckFailure.mismatch(workers: 2, blockNodes: 4096)
            }
            let oldBytes = try Data(contentsOf: fileURL)
            let existingSink = FileCubeSink(target: fileURL)
            do {
                _ = try await GenerationCoordinator().generate(fileRequest, sink: existingSink)
                throw CheckFailure.mismatch(workers: 2, blockNodes: 4096)
            } catch FileSinkError.targetExists {}
            guard try Data(contentsOf: fileURL) == oldBytes else {
                throw CheckFailure.mismatch(workers: 2, blockNodes: 4096)
            }
            let oldPayload = Data("old target content".utf8)
            let replacementURL = directory.appendingPathComponent("replacement.cube")
            try oldPayload.write(to: replacementURL)
            let replacementSink = FileCubeSink(target: replacementURL, allowOverwrite: true)
            let replacementReport = try await GenerationCoordinator().generate(fileRequest, sink: replacementSink)
            guard replacementReport.state == .completed,
                  try Data(contentsOf: replacementURL) != oldPayload,
                  try CubeParser.parse(url: replacementURL).samples == expected else {
                throw CheckFailure.mismatch(workers: 2, blockNodes: 4096)
            }

            let cancelOverwriteURL = directory.appendingPathComponent("cancel-overwrite.cube")
            try oldPayload.write(to: cancelOverwriteURL)
            let cancelOverwriteFile = FileCubeSink(target: cancelOverwriteURL, allowOverwrite: true)
            let cancelOverwriteGate = FileBlockGateSink(fileSink: cancelOverwriteFile, targetBlock: 2)
            let cancelOverwriteJob = GenerationCoordinator()
            let cancelOverwriteTask = Task {
                try await cancelOverwriteJob.generate(failureRequest, sink: cancelOverwriteGate)
            }
            await cancelOverwriteGate.waitUntilBlock()
            cancelOverwriteTask.cancel()
            await cancelOverwriteGate.releaseBlock()
            do {
                _ = try await cancelOverwriteTask.value
                throw CheckFailure.mismatch(workers: 2, blockNodes: 2)
            } catch is CancellationError {}
            guard try Data(contentsOf: cancelOverwriteURL) == oldPayload,
                  await cancelOverwriteFile.state == .aborted else {
                throw CheckFailure.mismatch(workers: 2, blockNodes: 2)
            }

            let changedURL = directory.appendingPathComponent("externally-changed.cube")
            try oldPayload.write(to: changedURL)
            let changedFile = FileCubeSink(target: changedURL, allowOverwrite: true)
            let changedGate = FileBlockGateSink(fileSink: changedFile, targetBlock: 2)
            let changedJob = GenerationCoordinator()
            let changedTask = Task { try await changedJob.generate(failureRequest, sink: changedGate) }
            await changedGate.waitUntilBlock()
            let externalPayload = Data("external change".utf8)
            try externalPayload.write(to: changedURL)
            await changedGate.releaseBlock()
            do {
                _ = try await changedTask.value
                throw CheckFailure.mismatch(workers: 2, blockNodes: 2)
            } catch FileSinkError.targetChanged {}
            let allFiles = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            guard try Data(contentsOf: changedURL) == externalPayload,
                  await changedFile.state == .aborted,
                  !allFiles.contains(where: { $0.hasPrefix(".lutcalc-") }) else {
                throw CheckFailure.mismatch(workers: 2, blockNodes: 2)
            }
            let linkedURL = directory.appendingPathComponent("linked.cube")
            let replacementBytes = try Data(contentsOf: replacementURL)
            try FileManager.default.createSymbolicLink(at: linkedURL, withDestinationURL: replacementURL)
            do {
                _ = try await GenerationCoordinator().generate(
                    fileRequest, sink: FileCubeSink(target: linkedURL, allowOverwrite: true)
                )
                throw CheckFailure.mismatch(workers: 2, blockNodes: 4096)
            } catch FileSinkError.unsafeTarget {}
            guard try Data(contentsOf: replacementURL) == replacementBytes else {
                throw CheckFailure.mismatch(workers: 2, blockNodes: 4096)
            }
            print("H08 分块确定性通过：1/2/4 worker × 1/17/4096 节点块，17³ 全部节点相同")
            print("H08 强制乱序完成通过：接收顺序 3,2,1,0,7,6,5,4,8，写出顺序仍为 R 最快，待写缓存峰值 4 块")
            print("H08 注入写入失败通过：任务 failed，输出 abort，未提交部分数据")
            print("H08 注入取消通过：任务 cancelled，输出 abort，未提交部分数据")
            print("H08 真实 Task.cancel 通过：验证完成前挂起，取消后拒绝提交并 abort")
            print("H08 全部 9 个写块边界真实 Task.cancel 通过：均 aborted，0 次提交")
            print("H08 CUBE 文件 9 个写块边界取消通过：目标与任务临时文件均不存在")
            print("H08 committing 边界通过：取消后提交成功报 completed，提交抛取消错误报 failed")
            print("H08 流式文件通过：17³ 独立块写出和读回一致；拒绝覆盖时既有目标字节不变")
            print("H08 授权覆盖本地事务通过：成功替换；取消、外部修改、符号链接均不破坏原目标且无任务临时文件")
        } catch {
            fputs("LUTJobChecks: \(error)\n", stderr)
            exit(1)
        }
    }
}

private enum CheckFailure: Error {
    case mismatch(workers: Int, blockNodes: Int)
}

private actor ValidationGateSink: CubeBlockSink {
    private(set) var state: SinkState = .idle
    private var count = 0
    private var nextBlock = 0
    private var enteredValidation = false
    private var enteredWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func prepare(size: Int, domain: LUTDomain, title: String) throws { state = .writing }

    func append(blockIndex: Int, samples: [RGB64]) throws {
        guard state == .writing, blockIndex == nextBlock else { throw JobFailure.outOfOrderBlock }
        count += samples.count
        nextBlock += 1
    }

    func validate(expectedNodes: Int) async throws {
        guard state == .writing, count == expectedNodes else { throw JobFailure.rowCountMismatch }
        enteredValidation = true
        enteredWaiter?.resume()
        enteredWaiter = nil
        await withCheckedContinuation { releaseWaiter = $0 }
        state = .validated
    }

    func commit() throws { state = .committed }
    func abort() { state = .aborted }

    func waitUntilValidation() async {
        if enteredValidation { return }
        await withCheckedContinuation { enteredWaiter = $0 }
    }

    func releaseValidation() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

private actor BlockGateSink: CubeBlockSink {
    private(set) var state: SinkState = .idle
    private(set) var commits = 0
    private let targetBlock: Int
    private var nextBlock = 0
    private var entered = false
    private var enteredWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    init(targetBlock: Int) { self.targetBlock = targetBlock }

    func prepare(size: Int, domain: LUTDomain, title: String) throws { state = .writing }

    func append(blockIndex: Int, samples: [RGB64]) async throws {
        guard state == .writing, blockIndex == nextBlock else { throw JobFailure.outOfOrderBlock }
        if blockIndex == targetBlock {
            entered = true
            enteredWaiter?.resume()
            enteredWaiter = nil
            await withCheckedContinuation { releaseWaiter = $0 }
        }
        nextBlock += 1
    }

    func validate(expectedNodes: Int) throws { state = .validated }
    func commit() throws { commits += 1; state = .committed }
    func abort() { state = .aborted }

    func waitUntilBlock() async {
        if entered { return }
        await withCheckedContinuation { enteredWaiter = $0 }
    }

    func releaseBlock() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

private actor FileBlockGateSink: CubeBlockSink {
    private(set) var commits = 0
    private let fileSink: FileCubeSink
    private let targetBlock: Int
    private var entered = false
    private var enteredWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    init(fileSink: FileCubeSink, targetBlock: Int) {
        self.fileSink = fileSink
        self.targetBlock = targetBlock
    }

    func prepare(size: Int, domain: LUTDomain, title: String) async throws {
        try await fileSink.prepare(size: size, domain: domain, title: title)
    }

    func append(blockIndex: Int, samples: [RGB64]) async throws {
        try await fileSink.append(blockIndex: blockIndex, samples: samples)
        if blockIndex == targetBlock {
            entered = true
            enteredWaiter?.resume()
            enteredWaiter = nil
            await withCheckedContinuation { releaseWaiter = $0 }
        }
    }

    func validate(expectedNodes: Int) async throws {
        try await fileSink.validate(expectedNodes: expectedNodes)
    }

    func commit() async throws {
        try await fileSink.commit()
        commits += 1
    }

    func abort() async { await fileSink.abort() }

    func waitUntilBlock() async {
        if entered { return }
        await withCheckedContinuation { enteredWaiter = $0 }
    }

    func releaseBlock() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

private actor CommitGateSink: CubeBlockSink {
    private(set) var state: SinkState = .idle
    private let failsDuringCommit: Bool
    private var entered = false
    private var enteredWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    init(failsDuringCommit: Bool) { self.failsDuringCommit = failsDuringCommit }

    func prepare(size: Int, domain: LUTDomain, title: String) throws { state = .writing }
    func append(blockIndex: Int, samples: [RGB64]) throws {}
    func validate(expectedNodes: Int) throws { state = .validated }

    func commit() async throws {
        entered = true
        enteredWaiter?.resume()
        enteredWaiter = nil
        await withCheckedContinuation { releaseWaiter = $0 }
        if failsDuringCommit { throw CancellationError() }
        state = .committed
    }

    func abort() { if state != .committed { state = .aborted } }

    func waitUntilCommit() async {
        if entered { return }
        await withCheckedContinuation { enteredWaiter = $0 }
    }

    func releaseCommit() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

private actor ReverseCompletionGate {
    private var entered: Set<Int> = []
    private var enteredWaiters: [Int: CheckedContinuation<Void, Never>] = [:]
    private var releaseWaiters: [Int: CheckedContinuation<Void, Never>] = [:]
    private(set) var received: [Int] = []
    private var receiveWaiters: [Int: CheckedContinuation<Void, Never>] = [:]

    func beforeCompletion(_ index: Int) async {
        entered.insert(index)
        enteredWaiters.removeValue(forKey: index)?.resume()
        await withCheckedContinuation { releaseWaiters[index] = $0 }
    }

    func didReceive(_ index: Int) {
        received.append(index)
        receiveWaiters.removeValue(forKey: index)?.resume()
    }

    func waitUntilEntered(_ index: Int) async {
        if entered.contains(index) { return }
        await withCheckedContinuation { enteredWaiters[index] = $0 }
    }

    func release(_ index: Int) {
        releaseWaiters.removeValue(forKey: index)?.resume()
    }

    func waitUntilReceived(_ index: Int) async {
        if received.contains(index) { return }
        await withCheckedContinuation { receiveWaiters[index] = $0 }
    }
}
