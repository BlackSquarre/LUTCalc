import Foundation
import XCTest
import CoreGraphics
import ImageIO
import LUTPreview
@testable import LUTSharedUI

@MainActor
final class SecurityScopedLoaderContractsTests: XCTestCase {
    func testFileDialogCancellationClassification() {
        XCTAssertTrue(SystemFileDialogError.isUserCancellation(
            NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)))
        XCTAssertFalse(SystemFileDialogError.isUserCancellation(
            NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError)))
        XCTAssertFalse(SystemFileDialogError.isUserCancellation(
            NSError(domain: NSPOSIXErrorDomain, code: NSUserCancelledError)))
    }

    func testUserLUTLoaderStopsAccessAfterSuccessfulRead() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-security-scope-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("sample.cube")
        try Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8).write(to: url)

        let access = RecordingSecurityScopedResourceAccess(startResult: true)
        let loader = NativeUserLUTLoader(access: access)
        _ = try await loader.load(url)

        XCTAssertEqual(access.started, [url])
        XCTAssertEqual(access.stopped, [url])
    }

    func testUserLUTLoaderStopsAccessWhenParsingFails() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-security-scope-error-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("sample.cube")
        try Data("LUT_1D_SIZE 2\n0 0 0\n".utf8).write(to: url)

        let access = RecordingSecurityScopedResourceAccess(startResult: true)
        let loader = NativeUserLUTLoader(access: access)
        await XCTAssertThrowsErrorAsync(try await loader.load(url)) { _ in }

        XCTAssertEqual(access.started, [url])
        XCTAssertEqual(access.stopped, [url])
    }

    func testPreviewLoaderStopsAccessWhenFileDecodeFails() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-security-scope-invalid-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not an image".utf8).write(to: url)

        let access = RecordingSecurityScopedResourceAccess(startResult: true)
        let loader = NativePreviewImageLoader(access: access)
        await XCTAssertThrowsErrorAsync(try await loader.load(url)) { _ in }

        XCTAssertEqual(access.started, [url])
        XCTAssertEqual(access.stopped, [url])
    }

    func testPreviewCoordinationFailureReleasesSecurityScope() async throws {
        let url = URL(fileURLWithPath: "/tmp/lutcalc-provider-denied.png")
        let access = RecordingSecurityScopedResourceAccess(startResult: true)
        let decoder = RecordingCoordinatedPreviewDecoder(access: access, failure: TestReadError.denied)
        await XCTAssertThrowsErrorAsync(
            try await NativePreviewImageLoader(access: access, decoder: decoder).load(url)) { error in
                XCTAssertEqual(error as? TestReadError, .denied)
            }
        XCTAssertEqual(decoder.decodeURLs, [url])
        XCTAssertEqual(access.started, [url])
        XCTAssertEqual(access.stopped, [url])
    }

    func testPreviewCancellationReleasesSecurityScope() async throws {
        let url = URL(fileURLWithPath: "/tmp/lutcalc-provider-cancelled.png")
        let access = RecordingSecurityScopedResourceAccess(startResult: true)
        let decoder = RecordingCoordinatedPreviewDecoder(access: access, failure: CancellationError())
        await XCTAssertThrowsErrorAsync(
            try await NativePreviewImageLoader(access: access, decoder: decoder).load(url)) { error in
                XCTAssertTrue(error is CancellationError)
            }
        XCTAssertEqual(access.started, [url])
        XCTAssertEqual(access.stopped, [url])
    }

    func testNativePreviewCoordinatorPreservesOriginalPixelCodes() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-coordinated-image-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("sample.png")
        let codes = Data([0, 64, 128, 255, 255, 128, 64, 128])
        let provider = try XCTUnwrap(CGDataProvider(data: codes as CFData))
        let colourSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let source = try XCTUnwrap(CGImage(width: 2, height: 1, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: 8, space: colourSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL,
            "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, source, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let access = RecordingSecurityScopedResourceAccess(startResult: true)
        let decoder = RecordingCoordinatedPreviewDecoder(access: access)
        let image = try await NativePreviewImageLoader(access: access, decoder: decoder).load(url)
        XCTAssertEqual(image.width, 2)
        XCTAssertEqual(image.height, 1)
        XCTAssertEqual(image.bitsPerComponent, 8)
        XCTAssertEqual(image.pixels[0].rgb.g, 64.0 / 255.0)
        XCTAssertEqual(image.pixels[0].rgb.b, 128.0 / 255.0)
        XCTAssertEqual(image.pixels[1].rgb.r, 1)
        XCTAssertEqual(image.pixels[1].alpha, 128.0 / 255.0)
        XCTAssertEqual(decoder.decodeURLs, [url])
        XCTAssertEqual(access.started, [url])
        XCTAssertEqual(access.stopped, [url])
    }

    func testLocalURLWithNoSecurityScopeDoesNotCallStop() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-security-scope-local-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("sample.cube")
        try Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8).write(to: url)

        let access = RecordingSecurityScopedResourceAccess(startResult: false)
        let loader = NativeUserLUTLoader(access: access)
        _ = try await loader.load(url)

        XCTAssertEqual(access.started, [url])
        XCTAssertTrue(access.stopped.isEmpty)
    }

    func testUserLUTReadUsesCoordinatorWithinSecurityScope() async throws {
        let url = URL(fileURLWithPath: "/tmp/lutcalc-coordinated-user.cube")
        let access = RecordingSecurityScopedResourceAccess(startResult: true)
        let reader = RecordingCoordinatedFileReader(result: .success(
            Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8)))
        let imported = try await NativeUserLUTLoader(access: access, reader: reader).load(url)
        XCTAssertEqual(imported.format, .cube)
        XCTAssertEqual(reader.readURLs, [url])
        XCTAssertEqual(access.started, [url])
        XCTAssertEqual(access.stopped, [url])
    }

    func testUserLUTCoordinationFailureReleasesSecurityScope() async throws {
        let url = URL(fileURLWithPath: "/tmp/lutcalc-denied-user.cube")
        let access = RecordingSecurityScopedResourceAccess(startResult: true)
        let reader = RecordingCoordinatedFileReader(result: .failure(TestReadError.denied))
        await XCTAssertThrowsErrorAsync(
            try await NativeUserLUTLoader(access: access, reader: reader).load(url)) { error in
                XCTAssertEqual(error as? TestReadError, .denied)
            }
        XCTAssertEqual(reader.readURLs, [url])
        XCTAssertEqual(access.started, [url])
        XCTAssertEqual(access.stopped, [url])
    }

    func testNativeCoordinatorReadsLocalFileWithoutChangingBytes() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-coordinator-local-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("sample.cube")
        let expected = Data("LUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8)
        try expected.write(to: url, options: .atomic)

        let actual = try NativeCoordinatedFileReader().read(url, maxBytes: 1024)
        XCTAssertEqual(actual, expected)
    }
}

private enum TestReadError: Error, Equatable { case denied }

private final class RecordingCoordinatedPreviewDecoder: CoordinatedPreviewImageDecoding,
                                                        @unchecked Sendable {
    private let lock = NSLock()
    private let access: RecordingSecurityScopedResourceAccess
    private let failure: (any Error)?
    private var urls: [URL] = []

    init(access: RecordingSecurityScopedResourceAccess, failure: (any Error)? = nil) {
        self.access = access
        self.failure = failure
    }

    var decodeURLs: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }

    func decode(_ url: URL) throws -> PreviewImage {
        XCTAssertEqual(access.started, [url], "协调解码必须在授权作用域内开始")
        XCTAssertTrue(access.stopped.isEmpty, "协调解码完成前不能释放授权")
        lock.lock()
        urls.append(url)
        lock.unlock()
        if let failure { throw failure }
        return try NativeCoordinatedPreviewImageDecoder().decode(url)
    }
}

private final class RecordingCoordinatedFileReader: CoordinatedFileReading, @unchecked Sendable {
    private let lock = NSLock()
    private let result: Result<Data, Error>
    private var urls: [URL] = []

    init(result: Result<Data, Error>) { self.result = result }

    var readURLs: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }

    func read(_ url: URL, maxBytes: Int) throws -> Data {
        lock.lock()
        urls.append(url)
        lock.unlock()
        return try result.get()
    }
}

private final class RecordingSecurityScopedResourceAccess: SecurityScopedResourceAccessing,
                                                           @unchecked Sendable {
    private let lock = NSLock()
    private let startResult: Bool
    private var startedURLs: [URL] = []
    private var stoppedURLs: [URL] = []

    init(startResult: Bool) {
        self.startResult = startResult
    }

    var started: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return startedURLs
    }

    var stopped: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return stoppedURLs
    }

    func startAccessing(_ url: URL) -> Bool {
        lock.lock()
        startedURLs.append(url)
        lock.unlock()
        return startResult
    }

    func stopAccessing(_ url: URL) {
        lock.lock()
        stoppedURLs.append(url)
        lock.unlock()
    }
}

@MainActor
private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ handler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("expected an error")
    } catch {
        handler(error)
    }
}
