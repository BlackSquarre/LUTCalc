import Foundation
import LUTCore
import LUTPreview
import LUTProject
import LUTSharedUI

private enum Failure: Error { case mismatch(String) }

@main
struct LUTDocumentSampleChecks {
    static func main() async {
        do {
            guard CommandLine.arguments.count == 2 else {
                throw Failure.mismatch("expected image fixture directory")
            }
            try await run(URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true))
            print("H13 文档取样与显示位图契约通过：显式源解释、Double 像素、项目修订、图像晚返回、后台 RGBA8 预览和关闭门控")
        } catch {
            fputs("LUTDocumentSampleChecks: \(error)\n", stderr)
            exit(1)
        }
    }

    @MainActor
    private static func run(_ folder: URL) async throws {
        let firstURL = folder.appendingPathComponent("rgba8.png")
        let secondURL = folder.appendingPathComponent("rgb8.png")
        let held = HeldImageLoader()
        let session = ProjectSampleSession(loader: held)
        guard session.startLoading(firstURL) else { throw Failure.mismatch("first load") }
        let first = await held.nextCall()
        guard first == firstURL else { throw Failure.mismatch("first URL") }
        guard session.startLoading(secondURL) else { throw Failure.mismatch("second load") }
        let second = await held.nextCall()
        guard second == secondURL else { throw Failure.mismatch("second URL") }
        try await held.finish(second)
        await session.waitForCurrentLoad()
        try await held.finish(first)
        await session.waitForPendingLoads()
        guard session.imageURL == secondURL,
              session.image?.bitsPerComponent == 8,
              session.image?.width == 2,
              session.loadStatus == .loaded else {
            throw Failure.mismatch("late image replaced current image")
        }

        let settings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 1)
        var document = try LUTProjectDocument(new: ProjectManifest(settings: settings,
            cubeSize: 17, domain: .unit))
        do {
            _ = try session.sample(document: document, x: 1, y: 0, confirmedSource: false)
            throw Failure.mismatch("unconfirmed source interpreted")
        } catch ProjectSampleError.sourceConfirmationRequired {}
        do {
            _ = try session.sample(document: document, x: 2, y: 0, confirmedSource: true)
            throw Failure.mismatch("out of range coordinate accepted")
        } catch ProjectSampleError.invalidCoordinate {}
        let old = try session.sample(document: document, x: 1, y: 0, confirmedSource: true)
        let codes = [254.0, 253.0, 252.0]
        let source = [old.pixel.source.rgb.r, old.pixel.source.rgb.g, old.pixel.source.rgb.b]
        let oldOutput = [old.pixel.planOutput.r, old.pixel.planOutput.g, old.pixel.planOutput.b]
        let oldError = zip(oldOutput, codes).map { abs($0.0 - 2 * $0.1 / 255) }.max()!
        guard oldError < 2e-12,
              zip(source, codes).allSatisfy({ $0.0 == $0.1 / 255 }),
              old.x == 1, old.y == 0,
              old.settings == settings,
              old.revision == 0 else {
            throw Failure.mismatch("8-bit raw source or Double evaluation")
        }
        let changed = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 2)
        try document.apply(ProjectManifest(id: document.manifest.id, settings: changed,
                                           cubeSize: 17, domain: .unit))
        let updated = try session.sample(document: document, x: 1, y: 0, confirmedSource: true)
        let newOutput = [updated.pixel.planOutput.r, updated.pixel.planOutput.g, updated.pixel.planOutput.b]
        let newError = zip(newOutput, codes).map { abs($0.0 - 4 * $0.1 / 255) }.max()!
        guard newError < 2e-12,
              updated.revision == 1,
              old.pixel.planOutput.r != updated.pixel.planOutput.r else {
            throw Failure.mismatch("project edit did not change sample snapshot")
        }
        print("H13 8-bit RGB 码值精确归一化；线性曝光样本最大绝对误差 \(max(oldError, newError))")

        let native = ProjectSampleSession()
        guard native.startLoading(secondURL) else { throw Failure.mismatch("native image load") }
        await native.waitForCurrentLoad()
        guard native.loadStatus == .loaded,
              try native.sample(document: document, x: 1, y: 0,
                                confirmedSource: true).pixel.source.rgb.r == Double(254) / 255 else {
            throw Failure.mismatch("native loader or sampler")
        }
        native.startDisplayPreview(document: document, confirmedSource: false)
        guard case .failed = native.displayStatus else {
            throw Failure.mismatch("unconfirmed display source interpreted")
        }
        native.startDisplayPreview(document: document, confirmedSource: true)
        for _ in 0..<500 where native.displayStatus == .running {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        guard native.displayStatus == .loaded,
              let bitmap = native.displayBitmap,
              bitmap.width == 2, bitmap.height == 1,
              bitmap.rgba8.count == 8,
              bitmap.cgImage() != nil else {
            throw Failure.mismatch("background display bitmap")
        }
        let asset = Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8)
        let path = "Resources/user.cube"
        let withAsset = try LUTProjectDocument(new: ProjectManifest(
            settings: settings, cubeSize: 17, domain: .unit,
            assetHashes: [path: ProjectAssets.sha256(of: asset)],
            assetRoles: [path: .userLUT]), assetContents: [path: asset])
        let baselineDocument = try LUTProjectDocument(new: ProjectManifest(
            settings: settings, cubeSize: 17, domain: .unit))
        let baselineSample = try native.sample(document: baselineDocument, x: 0, y: 0,
                                               confirmedSource: true)
        let withAssetSample = try native.sample(document: withAsset, x: 0, y: 0,
                                                 confirmedSource: true)
        guard withAssetSample.pixel.planOutput == baselineSample.pixel.planOutput else {
            throw Failure.mismatch("unit 1D user LUT was not applied to sample")
        }
        native.resetForDocumentSwitch()
        guard native.loadStatus == .idle, native.image == nil,
              native.imageURL == nil, native.sampleRecord == nil else {
            throw Failure.mismatch("document switch retained image or sample")
        }
        do {
            _ = try native.sample(document: document, x: 0, y: 0, confirmedSource: true)
            throw Failure.mismatch("document switch accepted stale image")
        } catch ProjectSampleError.noImage {}
        native.close()

        let switching = ProjectSampleSession(loader: held)
        guard switching.startLoading(firstURL) else { throw Failure.mismatch("switching load") }
        let switchedURL = await held.nextCall()
        switching.resetForDocumentSwitch()
        try await held.finish(switchedURL)
        await switching.waitForPendingLoads()
        guard switching.loadStatus == .idle, switching.image == nil,
              switching.imageURL == nil else {
            throw Failure.mismatch("late image crossed document switch")
        }

        guard session.startLoading(firstURL) else { throw Failure.mismatch("closing load") }
        let closing = await held.nextCall()
        session.close()
        try await held.finish(closing)
        await session.waitForPendingLoads()
        guard session.loadStatus == .closed,
              !session.startLoading(secondURL),
              session.imageURL == nil else {
            throw Failure.mismatch("closed session accepted image")
        }
    }
}

private actor HeldImageLoader: PreviewImageLoading {
    private var calls: [URL] = []
    private var waiter: CheckedContinuation<URL, Never>?
    private var pending: [URL: CheckedContinuation<PreviewImage, Error>] = [:]

    func load(_ url: URL) async throws -> PreviewImage {
        calls.append(url)
        waiter?.resume(returning: calls.removeFirst())
        waiter = nil
        return try await withCheckedThrowingContinuation { pending[url] = $0 }
    }

    func nextCall() async -> URL {
        if !calls.isEmpty { return calls.removeFirst() }
        return await withCheckedContinuation { waiter = $0 }
    }

    func finish(_ url: URL) throws {
        let image = try PreviewImageDecoder.decode(url: url)
        pending.removeValue(forKey: url)?.resume(returning: image)
    }
}
