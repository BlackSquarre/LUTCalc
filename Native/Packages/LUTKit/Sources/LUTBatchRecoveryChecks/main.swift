import Foundation
import Darwin
import LUTCore
import LUTJobs
import LUTSharedUI

/// Development-only child process. It is not a dependency or resource of either App.
@main struct BatchRecoveryChecks {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count >= 3 else { throw ExposureBatchCheckpointError.invalidCheckpoint }
        let root = URL(fileURLWithPath: args[1]), mode = args[2]
        let wanted = args.count > 3 ? ExposureBatchCheckpointEvent(rawValue: args[3]) : nil
        let base = try LUTGenerationRequest(plan: TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .rec2020, outputSpace: .rec2020, inputRange: .data, outputRange: .data,
            exposureStops: 0)), size: 17, domain: .unit, blockNodes: 17, workerCount: 4)
        let request = try ExposureBatchRequest(base: base,
            settings: ExposureBatchSettings(minimumStops: 0, maximumStops: 1, subdivisions: 1),
            directory: root, basename: "durable", format: .cube)
        let hooks = ExposureBatchCheckpointTestHooks { event, index in
            if mode == "interrupt", event == wanted, index == 0 {
                let marker = root.appendingPathComponent("boundary.txt")
                try Data(event.rawValue.utf8).write(to: marker, options: .atomic)
                let handle = try FileHandle(forWritingTo: marker); try handle.synchronize(); try handle.close()
                raise(SIGSTOP)
            }
        }
        let store = ExposureBatchCheckpointStore(directory: root.appendingPathComponent("checkpoint"), testHooks: hooks)
        let exporter = RecoveryExporter(partialRoot: mode == "interrupt" && args.last == "partialStaging" ? root : nil)
        let result = try await ExposureBatchCoordinator().generate(request, exporter: exporter,
            checkpoint: store, resuming: mode == "resume")
        guard result.state == .completed else { throw ExposureBatchCheckpointError.invalidCheckpoint }
        let snapshot = try await store.loadSnapshot()
        try JSONEncoder().encode(result).write(to: root.appendingPathComponent("recovered-report.json"), options: .atomic)
        let stops = await exporter.stops
        let data = try JSONSerialization.data(withJSONObject: ["generatedStops": stops,
            "revision": snapshot.revision, "abandonedStagingFiles": snapshot.abandonedStagingFiles], options: [.sortedKeys])
        try data.write(to: root.appendingPathComponent("restart-stats.json"), options: .atomic)
        print("批次进程 \(mode) 完成：实际生成 \(stops.count) 项，revision=\(snapshot.revision)")
    }
}
private actor RecoveryExporter: ExposureBatchExporter {
    var stops: [Double] = []
    let partialRoot: URL?
    init(partialRoot: URL?) { self.partialRoot = partialRoot }
    func generate(_ request: LUTGenerationRequest, to output: URL, allowOverwrite: Bool) async throws -> Int {
        stops.append(request.plan.settings.exposureStops)
        if let partialRoot, stops.count == 1 {
            return try await GenerationCoordinator().generate(request,
                sink: PartialStagingSink(file: FileCubeSink(target: output), root: partialRoot)).writtenNodes
        }
        return try await NativeExportService().generate(request, to: output, allowOverwrite: allowOverwrite)
    }
}
private actor PartialStagingSink: CubeBlockSink {
    let file: FileCubeSink, root: URL
    init(file: FileCubeSink, root: URL) { self.file = file; self.root = root }
    func prepare(size: Int, domain: LUTDomain, title: String) async throws {
        try await file.prepare(size: size, domain: domain, title: title)
    }
    func append(blockIndex: Int, samples: [RGB64]) async throws {
        try await file.append(blockIndex: blockIndex, samples: samples)
        if blockIndex == 0 {
            let marker = root.appendingPathComponent("boundary.txt")
            try Data("partialStaging".utf8).write(to: marker, options: .atomic)
            let handle = try FileHandle(forWritingTo: marker); try handle.synchronize(); try handle.close()
            raise(SIGSTOP)
        }
    }
    func validate(expectedNodes: Int) async throws { try await file.validate(expectedNodes: expectedNodes) }
    func commit() async throws { try await file.commit() }
    func abort() async { await file.abort() }
}
