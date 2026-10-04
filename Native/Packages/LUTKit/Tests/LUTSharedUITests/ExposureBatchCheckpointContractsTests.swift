import Foundation
import Darwin
import CryptoKit
import XCTest
import LUTCore
import LUTFormats
import LUTJobs
import LUTSharedUI

final class ExposureBatchCheckpointContractsTests: XCTestCase {
    private enum ProcessObservationError: Error { case exitNotObserved(Int32) }
    private func startObservedProcess(executable: URL, arguments: [String]) throws -> (Process, XCTestExpectation) {
        let child = Process(), exited = XCTestExpectation(description: "Observed child exit")
        child.executableURL = executable; child.arguments = arguments
        // Register before launch so an early exit cannot precede observation.
        child.terminationHandler = { _ in exited.fulfill() }
        try child.run()
        return (child, exited)
    }
    private func observeExit(_ child: Process, _ exited: XCTestExpectation) async throws {
        await fulfillment(of: [exited], timeout: 15)
        guard !child.isRunning else {
            _ = kill(child.processIdentifier, SIGKILL)
            throw ProcessObservationError.exitNotObserved(child.processIdentifier)
        }
    }
    func testExitObservedBeforeAwaitCompletesWithoutBlockingWait() async throws {
        for _ in 0..<20 {
            let (child, exited) = try startObservedProcess(executable: URL(fileURLWithPath: "/usr/bin/true"), arguments: [])
            try await Task.sleep(for: .milliseconds(20))
            try await observeExit(child, exited)
            XCTAssertEqual(child.terminationReason, .exit); XCTAssertEqual(child.terminationStatus, 0)
        }
    }
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func request(_ root: URL, overwrite: Bool = false, size: Int = 17) throws -> ExposureBatchRequest {
        let base = try LUTGenerationRequest(plan: TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data,
            exposureStops: 0)), size: size, domain: .unit, blockNodes: 17, workerCount: 4)
        return try ExposureBatchRequest(base: base,
            settings: ExposureBatchSettings(minimumStops: 0, maximumStops: 1, subdivisions: 1),
            directory: root, basename: "durable", format: .cube, allowOverwrite: overwrite)
    }
    func testAutomaticSnapshotsActualFilesAndCompletedResumeWithoutExporter() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let input = try request(root), directory = root.appendingPathComponent("checkpoint")
        let store = ExposureBatchCheckpointStore(directory: directory)
        let final = try await ExposureBatchCoordinator().generate(input, exporter: NativeExportService(), checkpoint: store)
        XCTAssertEqual(final.state, .completed)
        let snapshot = try await store.loadSnapshot()
        XCTAssertEqual(snapshot.schemaVersion, 1); XCTAssertGreaterThanOrEqual(snapshot.revision, 7)
        XCTAssertEqual(snapshot.report, final); XCTAssertNil(snapshot.active)
        let resumed = try await ExposureBatchCoordinator().generate(input, exporter: MustNotExport(),
            checkpoint: ExposureBatchCheckpointStore(directory: directory), resuming: true)
        XCTAssertEqual(resumed.items, final.items)
        let grid = try Grid3D(size: 17, domain: .unit)
        for item in input.items {
            let lut = try CubeParser.parse(Data(contentsOf: item.url))
            for i in 0..<grid.nodeCount { let p = try grid.coordinate(at: i)
                for c in 0..<3 { XCTAssertEqual(lut.samples[i][c], p[c] * (item.index == 0 ? 1 : 2)) }
            }
        }
        print("Batch checkpoint independent identity/exposure: channels=29478, max=0, RMS=0, P99=0")
    }
    func testPreparedAndPublishedWindowsResumeWithoutRegeneration() async throws {
        for event in [ExposureBatchCheckpointEvent.preparedSaved, .published] {
            let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
            let input = try request(root), directory = root.appendingPathComponent("checkpoint")
            let store = ExposureBatchCheckpointStore(directory: directory,
                testHooks: .init { actual, index in if actual == event && index == 0 { throw JobFailure.injectedWriteFailure } })
            do { _ = try await ExposureBatchCoordinator().generate(input, exporter: NativeExportService(), checkpoint: store)
                XCTFail("Expected interrupted boundary") } catch JobFailure.injectedWriteFailure {}
            let disk = try await ExposureBatchCheckpointStore(directory: directory).loadSnapshot()
            XCTAssertEqual(disk.active?.phase, .prepared)
            XCTAssertEqual(FileManager.default.fileExists(atPath: input.items[0].url.path), event == .published)
            let exporter = CountExports()
            let result = try await ExposureBatchCoordinator().generate(input, exporter: exporter,
                checkpoint: ExposureBatchCheckpointStore(directory: directory), resuming: true)
            XCTAssertEqual(result.state, .completed)
            let count = await exporter.count; XCTAssertEqual(count, 1)
        }
    }
    func testOverwriteIntentRejectsExternalOwnerAndCheckpointMutation() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let input = try request(root, overwrite: true), directory = root.appendingPathComponent("checkpoint")
        try Data("original".utf8).write(to: input.items[0].url)
        let store = ExposureBatchCheckpointStore(directory: directory,
            testHooks: .init { actual, index in if actual == .preparedSaved && index == 0 { throw JobFailure.injectedWriteFailure } })
        do { _ = try await ExposureBatchCoordinator().generate(input, exporter: NativeExportService(), checkpoint: store) }
        catch JobFailure.injectedWriteFailure {}
        let external = Data("external owner".utf8); try external.write(to: input.items[0].url)
        do { _ = try await ExposureBatchCoordinator().generate(input, exporter: MustNotExport(),
            checkpoint: ExposureBatchCheckpointStore(directory: directory), resuming: true)
            XCTFail("Expected owner rejection") } catch FileSinkError.targetChanged {}
        XCTAssertEqual(try Data(contentsOf: input.items[0].url), external)
        do { _ = try await ExposureBatchCoordinator().generate(request(root, size: 33), exporter: MustNotExport(),
            checkpoint: ExposureBatchCheckpointStore(directory: directory), resuming: true)
            XCTFail("Expected request mismatch") } catch ExposureBatchError.checkpointMismatch {}
        let checkpoint = directory.appendingPathComponent("checkpoint.json")
        var bytes = try Data(contentsOf: checkpoint); bytes.append(0)
        try bytes.write(to: checkpoint)
        do { _ = try await ExposureBatchCheckpointStore(directory: directory).loadSnapshot()
            XCTFail("Expected damaged checkpoint rejection") } catch {}
    }
    func testLeaseExcludesAnotherCoordinatorAndTaskCancellationPersists() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let input = try request(root), directory = root.appendingPathComponent("checkpoint"), gate = CheckpointGate()
        let store = ExposureBatchCheckpointStore(directory: directory,
            testHooks: .init { actual, _ in if actual == .generatingSaved { await gate.pause() } })
        let task = Task { try await ExposureBatchCoordinator().generate(input, exporter: NativeExportService(), checkpoint: store) }
        await gate.wait()
        do { _ = try await ExposureBatchCoordinator().generate(input, exporter: MustNotExport(),
            checkpoint: ExposureBatchCheckpointStore(directory: directory), resuming: true)
            XCTFail("Expected lease exclusion") } catch ExposureBatchCheckpointError.busy {}
        task.cancel(); await gate.release()
        let result = try await task.value; XCTAssertEqual(result.state, .cancelled)
        let disk = try await ExposureBatchCheckpointStore(directory: directory).loadSnapshot()
        XCTAssertEqual(disk.report.state, .cancelled); XCTAssertFalse(FileManager.default.fileExists(atPath: input.items[0].url.path))
        let resumed = try await ExposureBatchCoordinator().generate(input, exporter: NativeExportService(),
            checkpoint: ExposureBatchCheckpointStore(directory: directory), resuming: true)
        XCTAssertEqual(resumed.state, .completed)
    }
    func testRealProcessKillAtSixBoundariesAndIndependentRestart() async throws {
        let executable = Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("LUTBatchRecoveryChecks")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable.path))
        for event in ["generatingSaved", "partialStaging", "staged", "preparedSaved", "published", "completedSaved"] {
            let root: URL
            if let evidence = ProcessInfo.processInfo.environment["LUTCALC_BATCH_RECOVERY_ARTIFACT_DIR"] {
                root = URL(fileURLWithPath: evidence).appendingPathComponent(event + "-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            } else { root = try folder() }
            defer { if ProcessInfo.processInfo.environment["LUTCALC_BATCH_RECOVERY_ARTIFACT_DIR"] == nil { try? FileManager.default.removeItem(at: root) } }
            let (child, childExited) = try startObservedProcess(executable: executable, arguments: [root.path, "interrupt", event])
            let marker = root.appendingPathComponent("boundary.txt")
            var entered = false
            for _ in 0..<500 {
                if FileManager.default.fileExists(atPath: marker.path) { entered = true; break }
                if !child.isRunning { break }
                try await Task.sleep(for: .milliseconds(20))
            }
            if !entered { if child.isRunning { kill(child.processIdentifier, SIGKILL) }; try await observeExit(child, childExited); XCTFail("Boundary not reached: \(event)"); continue }
            XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), event)
            do { _ = try await ExposureBatchCoordinator().generate(request(root), exporter: MustNotExport(),
                checkpoint: ExposureBatchCheckpointStore(directory: root.appendingPathComponent("checkpoint")), resuming: true)
                XCTFail("Expected cross-process lease exclusion") } catch ExposureBatchCheckpointError.busy {}
            XCTAssertEqual(kill(child.processIdentifier, SIGKILL), 0); try await observeExit(child, childExited)
            XCTAssertEqual(child.terminationReason, .uncaughtSignal); XCTAssertEqual(child.terminationStatus, SIGKILL)
            let directory = root.appendingPathComponent("checkpoint")
            let prior = try Data(contentsOf: directory.appendingPathComponent("checkpoint.json"))
            try prior.write(to: root.appendingPathComponent("checkpoint-before-kill.json"))
            let input = try request(root)
            let existingTarget = FileManager.default.fileExists(atPath: input.items[0].url.path)
            XCTAssertEqual(existingTarget, ["published", "completedSaved"].contains(event))
            let partials = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasPrefix(".lutcalc-") && $0.hasSuffix(".tmp") }
            if event == "partialStaging" {
                XCTAssertEqual(partials.count, 1)
                let bytes = try Data(contentsOf: directory.appendingPathComponent(try XCTUnwrap(partials.first)))
                XCTAssertGreaterThan(bytes.count, 0); XCTAssertThrowsError(try CubeParser.parse(bytes))
            }
            let crash = try JSONSerialization.data(withJSONObject: ["event": event, "pid": child.processIdentifier,
                "signal": child.terminationStatus, "targetExistsAtKill": existingTarget, "partialFiles": partials], options: [.sortedKeys])
            try crash.write(to: root.appendingPathComponent("crash.json"))
            let (restart, restartExited) = try startObservedProcess(executable: executable, arguments: [root.path, "resume"])
            try await observeExit(restart, restartExited); XCTAssertEqual(restart.terminationStatus, 0)
            let report = try JSONDecoder().decode(ExposureBatchReport.self, from: Data(contentsOf: root.appendingPathComponent("recovered-report.json")))
            XCTAssertEqual(report.state, .completed); XCTAssertEqual(report.items.map(\.state), [.completed, .completed])
            let stats = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("restart-stats.json"))) as! [String: Any]
            XCTAssertEqual(stats["generatedStops"] as! [Double], ["generatingSaved", "partialStaging", "staged"].contains(event) ? [0, 1] : [1])
            let grid = try Grid3D(size: 17, domain: .unit)
            for item in input.items {
                let lut = try CubeParser.parse(Data(contentsOf: item.url)); XCTAssertEqual(lut.samples.count, 4913)
                for i in 0..<grid.nodeCount { let p = try grid.coordinate(at: i)
                    for c in 0..<3 { XCTAssertEqual(lut.samples[i][c], p[c] * (item.index == 0 ? 1 : 2)) }
                }
            }
            print("Real batch recovery: boundary=\(event), SIGKILL=\(child.terminationStatus), restart=\(restart.terminationStatus), results=\(root.path)")
        }
    }

    func testStrictCheckpointStructureStageIdentityAndOwnedLocation() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let input = try request(root), directory = root.appendingPathComponent("checkpoint")
        let store = ExposureBatchCheckpointStore(directory: directory,
            testHooks: .init { event, index in if event == .preparedSaved && index == 0 { throw JobFailure.injectedWriteFailure } })
        do { _ = try await ExposureBatchCoordinator().generate(input, exporter: NativeExportService(), checkpoint: store) }
        catch JobFailure.injectedWriteFailure {}
        let disk = try await ExposureBatchCheckpointStore(directory: directory).loadSnapshot()
        let document = directory.appendingPathComponent("checkpoint.json"), original = try Data(contentsOf: document)
        func mutate(_ body: (inout [String: Any]) -> Void) throws -> Data {
            var envelope = try JSONSerialization.jsonObject(with: original) as! [String: Any]
            var payload = try JSONSerialization.jsonObject(with: Data(base64Encoded: envelope["payload"] as! String)!) as! [String: Any]
            body(&payload)
            let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            envelope["payload"] = bytes.base64EncodedString()
            envelope["sha256"] = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            return try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
        }
        for mutation in [try mutate { $0["schemaVersion"] = 2 }, try mutate { $0["unexpected"] = true },
                         try mutate { $0["ownerID"] = UUID().uuidString }] {
            try mutation.write(to: document)
            do { _ = try await ExposureBatchCheckpointStore(directory: directory).loadSnapshot(); XCTFail("Expected strict rejection") } catch {}
        }
        var duplicate = String(decoding: original, as: UTF8.self)
        duplicate.insert(contentsOf: "\"payload\":\"bad\",", at: duplicate.index(after: duplicate.startIndex))
        try Data(duplicate.utf8).write(to: document)
        do { _ = try await ExposureBatchCheckpointStore(directory: directory).loadSnapshot(); XCTFail("Expected duplicate rejection") } catch {}
        try original.write(to: document)
        let stage = directory.appendingPathComponent(try XCTUnwrap(disk.active).stagingFilename)
        let stageBytes = try Data(contentsOf: stage), replacement = directory.appendingPathComponent("replacement")
        try stageBytes.write(to: replacement)
        _ = try FileManager.default.replaceItemAt(stage, withItemAt: replacement)
        do { _ = try await ExposureBatchCoordinator().generate(input, exporter: MustNotExport(),
            checkpoint: ExposureBatchCheckpointStore(directory: directory), resuming: true)
            XCTFail("Expected equal-byte inode replacement rejection") } catch ExposureBatchCheckpointError.missingPreparedOutput {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: input.items[0].url.path))
        let other = root.appendingPathComponent("other"); try FileManager.default.createDirectory(at: other, withIntermediateDirectories: false)
        let link = root.appendingPathComponent("link"); try FileManager.default.createSymbolicLink(at: link, withDestinationURL: other)
        do { _ = try await ExposureBatchCoordinator().generate(input, exporter: MustNotExport(),
            checkpoint: ExposureBatchCheckpointStore(directory: link)); XCTFail("Expected existing link rejection") } catch FileSinkError.targetExists {}
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: other.path).isEmpty)
    }

    func testPreparedCancellationAndSuccessfulOverwritePreserveCommitBoundary() async throws {
        for event in [ExposureBatchCheckpointEvent.preparedSaved, .published] {
            let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
            let input = try request(root, overwrite: true), directory = root.appendingPathComponent("checkpoint"), gate = CheckpointGate()
            try Data("user original".utf8).write(to: input.items[0].url)
            let store = ExposureBatchCheckpointStore(directory: directory,
                testHooks: .init { actual, index in if actual == event && index == 0 { await gate.pause() } })
            let task = Task { try await ExposureBatchCoordinator().generate(input, exporter: NativeExportService(), checkpoint: store) }
            await gate.wait(); task.cancel(); await gate.release()
            let cancelled = try await task.value
            XCTAssertEqual(cancelled.state, .cancelled)
            let snapshot = try await ExposureBatchCheckpointStore(directory: directory).loadSnapshot()
            XCTAssertEqual(snapshot.report.state, .cancelled)
            if event == .preparedSaved {
                XCTAssertEqual(try Data(contentsOf: input.items[0].url), Data("user original".utf8))
                XCTAssertEqual(snapshot.active?.phase, .prepared)
            } else { XCTAssertEqual(cancelled.items[0].state, .completed) }
            let completed = try await ExposureBatchCoordinator().generate(input, exporter: NativeExportService(),
                checkpoint: ExposureBatchCheckpointStore(directory: directory), resuming: true)
            XCTAssertEqual(completed.state, .completed)
            XCTAssertEqual(try CubeParser.parse(Data(contentsOf: input.items[0].url)).samples.last, try RGB64(1, 1, 1))
        }
    }

    func testCheckpointWriteCompetitionKeepsExternalBytesAndNeverPublishesOutput() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let input = try request(root), directory = root.appendingPathComponent("checkpoint")
        let external = Data("external-checkpoint-owner".utf8)
        let store = ExposureBatchCheckpointStore(directory: directory,
            testHooks: .init { event, index in
                if event == .staged && index == 0 {
                    try external.write(to: directory.appendingPathComponent("checkpoint.json"))
                }
            })
        do { _ = try await ExposureBatchCoordinator().generate(input, exporter: NativeExportService(), checkpoint: store)
            XCTFail("Expected journal write competition rejection") } catch FileSinkError.targetChanged {}
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("checkpoint.json")), external)
        XCTAssertFalse(FileManager.default.fileExists(atPath: input.items[0].url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: input.items[1].url.path))
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasPrefix(".journal-") })
    }
}

private struct MustNotExport: ExposureBatchExporter {
    func generate(_ request: LUTGenerationRequest, to output: URL, allowOverwrite: Bool) async throws -> Int {
        XCTFail("Recovery must not regenerate completed/prepared output")
        throw JobFailure.injectedWriteFailure
    }
}
private actor CountExports: ExposureBatchExporter {
    var count = 0
    func generate(_ request: LUTGenerationRequest, to output: URL, allowOverwrite: Bool) async throws -> Int {
        count += 1; return try await NativeExportService().generate(request, to: output, allowOverwrite: allowOverwrite)
    }
}
private actor CheckpointGate {
    var entered = false
    var entry: CheckedContinuation<Void, Never>?, exit: CheckedContinuation<Void, Never>?
    func pause() async { await withCheckedContinuation { exit = $0; entered = true; entry?.resume(); entry = nil } }
    func wait() async { if !entered { await withCheckedContinuation { entry = $0 } } }
    func release() { exit?.resume(); exit = nil }
}
