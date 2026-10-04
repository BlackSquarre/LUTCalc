import Foundation
import XCTest
import LUTCore
@testable import LUTPreview

final class ICCRGBProfileLinkContractsTests: XCTestCase {
    func testSystemSRGBProfileUsesExplicitMatrixRoute() throws {
        let url = URL(fileURLWithPath: "/System/Library/ColorSync/Profiles/sRGB Profile.icc")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("系统未提供 sRGB Profile.icc")
        }
        let data = try Data(contentsOf: url)
        let link = try ICCRGBProfileLink(sourceProfile: data, targetProfile: data,
                                         intent: .relativeColorimetric)
        let input = try RGB64(0.25, 0.5, 0.75)
        let output = try link.convert(input)
        XCTAssertEqual(output.r, input.r, accuracy: 2e-4)
        XCTAssertEqual(output.g, input.g, accuracy: 2e-4)
        XCTAssertEqual(output.b, input.b, accuracy: 2e-4)
    }

    func testMixedMatrixAndLUTProfilesAreRejectedWithoutGuessing() throws {
        let matrix = try XCTUnwrap(systemSRGBIfAvailable())
        let lut = Data(makeProfile(tag: "A2B0", payload: mft2Identity()))
        XCTAssertThrowsError(try ICCRGBProfileLink(sourceProfile: lut, targetProfile: matrix,
                                                   intent: .relativeColorimetric)) {
            XCTAssertEqual($0 as? ICCRGBProfileLinkError, .mismatchedProfileKinds)
        }
    }

    func testTwoLUTProfilesUseExplicitLUTRoute() throws {
        let source = Data(makeProfile(tag: "A2B0", payload: mft2Identity()))
        let target = Data(makeProfile(tag: "B2A0", payload: mft2Identity()))
        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)
        let input = try RGB64(0.25, 0.5, 0.75)
        let output = try link.convert(input)
        XCTAssertEqual(output.r, input.r, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(output.g, input.g, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(output.b, input.b, accuracy: 4.0 / 32768.0)
    }

    func testRelativeColorimetricUsesIntentOneTagsBeforeIntentZeroFallback() throws {
        let source = Data(makeProfile(tags: [
            ("A2B0", mft2Identity()),
            ("A2B1", mft2HalfOutputIdentity()),
        ]))
        let target = Data(makeProfile(tags: [("B2A1", mft2Identity())]))
        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)

        let output = try link.convert(RGB64(0.5, 0.5, 0.5))

        XCTAssertEqual(output.r, 0.25, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(output.g, 0.25, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(output.b, 0.25, accuracy: 4.0 / 32768.0)
    }

    func testLabLinkUsesRelativeIntentTags() throws {
        let source = Data(makeProfile(tags: [
            ("A2B0", mft2Identity()),
            ("A2B1", mft2HalfOutputIdentity()),
        ], pcs: "Lab "))
        let target = Data(makeProfile(tags: [("B2A1", mft2Identity())], pcs: "Lab "))
        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)

        let output = try link.convert(RGB64(0.5, 0.5, 0.5))

        XCTAssertEqual(output.r, 0.25, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(output.g, 0.25, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(output.b, 0.25, accuracy: 4.0 / 32768.0)
    }

    func testTwoLabMFTProfilesUseExplicitPCSRoute() throws {
        let source = Data(makeProfile(tag: "A2B0", payload: mft2Identity(), pcs: "Lab "))
        let target = Data(makeProfile(tag: "B2A0", payload: mft2Identity(), pcs: "Lab "))
        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)
        let input = try RGB64(0.25, 0.5, 0.75)
        let output = try link.convert(input)
        XCTAssertEqual(output.r, input.r, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(output.g, input.g, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(output.b, input.b, accuracy: 4.0 / 32768.0)
    }

    func testTwoLabMABProfilesUseExplicitPCSRoute() throws {
        let source = Data(makeProfile(tag: "A2B0", payload: mabIdentityPipeline(type: "mAB "), pcs: "Lab "))
        let target = Data(makeProfile(tag: "B2A0", payload: mabIdentityPipeline(type: "mBA "), pcs: "Lab "))
        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)
        let input = try RGB64(0.25, 0.5, 0.75)
        let output = try link.convert(input)
        XCTAssertEqual(output.r, input.r, accuracy: 4.0 / 65535.0)
        XCTAssertEqual(output.g, input.g, accuracy: 4.0 / 65535.0)
        XCTAssertEqual(output.b, input.b, accuracy: 4.0 / 65535.0)
    }

    func testLabAndXYZProfilesAreRejectedAsMismatchedPCS() throws {
        let lab = Data(makeProfile(tag: "A2B0", payload: mft2Identity(), pcs: "Lab "))
        let xyz = try XCTUnwrap(systemSRGBIfAvailable())
        XCTAssertThrowsError(try ICCRGBProfileLink(sourceProfile: lab, targetProfile: xyz,
                                                   intent: .relativeColorimetric)) {
            XCTAssertEqual($0 as? ICCRGBProfileLinkError, .mismatchedPCS)
        }
    }

    func testUnsupportedIntentIsRejectedBeforeProfileDispatch() throws {
        let matrix = try XCTUnwrap(systemSRGBIfAvailable())
        XCTAssertThrowsError(try ICCRGBProfileLink(sourceProfile: matrix, targetProfile: matrix,
                                                   intent: .perceptual)) {
            XCTAssertEqual($0 as? ICCRGBProfileLinkError,
                           .unsupportedRenderingIntent(.perceptual))
        }
    }

    func testPixelBufferLinkingIsExplicitAndPreservesAlphaSemantics() throws {
        let source = Data(makeProfile(tag: "A2B0", payload: mft2Identity()))
        let target = Data(makeProfile(tag: "B2A0", payload: mft2Identity()))
        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)

        let straight = [try RGBA64(rgb: RGB64(0.25, 0.5, 0.75), alpha: 0.5)]
        let straightOutput = try link.convert(straight, inputAlpha: .straight, outputAlpha: .straight)
        let straightPixel = try XCTUnwrap(straightOutput.first)
        XCTAssertEqual(straightPixel.rgb.r, 0.25, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(straightPixel.rgb.g, 0.5, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(straightPixel.rgb.b, 0.75, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(straightPixel.alpha, 0.5, accuracy: 0)

        let premultiplied = [try RGBA64(rgb: RGB64(0.125, 0.25, 0.375), alpha: 0.5)]
        let premultipliedOutput = try link.convert(premultiplied, inputAlpha: .premultiplied,
                                                   outputAlpha: .premultiplied)
        let premultipliedPixel = try XCTUnwrap(premultipliedOutput.first)
        XCTAssertEqual(premultipliedPixel.rgb.r, 0.125, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(premultipliedPixel.rgb.g, 0.25, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(premultipliedPixel.rgb.b, 0.375, accuracy: 4.0 / 32768.0)

        let transparent = [try RGBA64(rgb: RGB64(0.8, 0.2, 0.1), alpha: 0)]
        let transparentOutput = try link.convert(transparent, inputAlpha: .straight,
                                                 outputAlpha: .premultiplied)
        let transparentPixel = try XCTUnwrap(transparentOutput.first)
        XCTAssertEqual(transparentPixel.rgb, try RGB64(0, 0, 0))
        XCTAssertEqual(transparentPixel.alpha, 0, accuracy: 0)
    }

    private func systemSRGBIfAvailable() -> Data? {
        let url = URL(fileURLWithPath: "/System/Library/ColorSync/Profiles/sRGB Profile.icc")
        return try? Data(contentsOf: url)
    }

    private func mft2Identity() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 52 + 3 * 2 * 2 + 8 * 3 * 2 + 3 * 2 * 2)
        bytes.replaceSubrange(0..<4, with: Array("mft2".utf8))
        bytes[8] = 3; bytes[9] = 3; bytes[10] = 2
        writeMatrix(&bytes, values: [1, 0, 0, 0, 1, 0, 0, 0, 1])
        bytes.replaceSubrange(48..<50, with: be(UInt16(2)))
        bytes.replaceSubrange(50..<52, with: be(UInt16(2)))
        writeIdentityTables(&bytes, start: 52, entries: 2)
        var cursor = 52 + 3 * 2 * 2
        for x in 0..<2 { for y in 0..<2 { for z in 0..<2 {
            for value in [x, y, z] {
                bytes.replaceSubrange(cursor..<cursor + 2, with: be(UInt16(value * 65535)))
                cursor += 2
            }
        }}}
        writeIdentityTables(&bytes, start: cursor, entries: 2)
        return bytes
    }

    private func mft2HalfOutputIdentity() -> [UInt8] {
        var bytes = mft2Identity()
        let outputTableStart = 52 + 3 * 2 * 2 + 8 * 3 * 2
        for channel in 0..<3 {
            let offset = outputTableStart + (channel * 2 + 1) * 2
            bytes.replaceSubrange(offset..<offset + 2, with: be(UInt16(32768)))
        }
        return bytes
    }

    private func makeProfile(tag: String, payload: [UInt8], pcs: String = "XYZ ") -> [UInt8] {
        let tableEnd = 144
        var bytes = [UInt8](repeating: 0, count: tableEnd)
        bytes[16...19] = ArraySlice("RGB ".utf8); bytes[20...23] = ArraySlice(pcs.utf8)
        bytes[36...39] = ArraySlice("acsp".utf8)
        bytes.replaceSubrange(128..<132, with: be(UInt32(1)))
        bytes.replaceSubrange(132..<136, with: Array(tag.utf8))
        bytes.replaceSubrange(136..<140, with: be(UInt32(tableEnd)))
        bytes.replaceSubrange(140..<144, with: be(UInt32(payload.count)))
        bytes += payload
        bytes.replaceSubrange(0..<4, with: be(UInt32(bytes.count)))
        return bytes
    }

    private func makeProfile(tags: [(String, [UInt8])], pcs: String = "XYZ ") -> [UInt8] {
        let tableEnd = 132 + tags.count * 12
        var bytes = [UInt8](repeating: 0, count: tableEnd)
        bytes[16...19] = ArraySlice("RGB ".utf8); bytes[20...23] = ArraySlice(pcs.utf8)
        bytes[36...39] = ArraySlice("acsp".utf8)
        bytes.replaceSubrange(128..<132, with: be(UInt32(tags.count)))
        var cursor = tableEnd
        for (index, item) in tags.enumerated() {
            let start = 132 + index * 12
            bytes.replaceSubrange(start..<start + 4, with: Array(item.0.utf8))
            bytes.replaceSubrange(start + 4..<start + 8, with: be(UInt32(cursor)))
            bytes.replaceSubrange(start + 8..<start + 12, with: be(UInt32(item.1.count)))
            bytes += item.1
            cursor += item.1.count
        }
        bytes.replaceSubrange(0..<4, with: be(UInt32(bytes.count)))
        return bytes
    }

    private func writeIdentityTables(_ bytes: inout [UInt8], start: Int, entries: Int) {
        for channel in 0..<3 { for index in 0..<entries {
            let value = UInt16((Double(index) / Double(entries - 1) * 65535).rounded())
            let offset = start + (channel * entries + index) * 2
            bytes.replaceSubrange(offset..<offset + 2, with: be(value))
        }}
    }

    private func writeMatrix(_ bytes: inout [UInt8], values: [Double]) {
        for (index, value) in values.enumerated() {
            bytes.replaceSubrange((12 + index * 4)..<(16 + index * 4),
                                  with: be(Int32((value * 65536).rounded())))
        }
    }

    private func mabIdentityPipeline(type: String) -> [UInt8] {
        var payload = [UInt8](repeating: 0, count: 32)
        payload.replaceSubrange(0..<4, with: Array(type.utf8))
        payload[8] = 3
        payload[9] = 3
        let curves = Array(repeating: curveIdentity(), count: 3).flatMap { $0 }
        let clut = clutIdentity()
        let sections: [(String, [UInt8])] = type == "mAB "
            ? [("A", curves), ("C", clut), ("M", []), ("X", []), ("B", curves)]
            : [("B", curves), ("X", []), ("M", []), ("C", clut), ("A", curves)]
        var offsets = [Int](repeating: 0, count: 5)
        var cursor = 32
        for section in sections where !section.1.isEmpty {
            cursor = (cursor + 3) & ~3
            let start = cursor
            payload += [UInt8](repeating: 0, count: start - payload.count)
            payload += section.1
            cursor = payload.count
            switch section.0 {
            case "B": offsets[0] = start
            case "X": offsets[1] = start
            case "M": offsets[2] = start
            case "C": offsets[3] = start
            case "A": offsets[4] = start
            default: break
            }
        }
        for (index, value) in offsets.enumerated() {
            payload.replaceSubrange(12 + index * 4..<16 + index * 4, with: be(UInt32(value)))
        }
        return payload
    }

    private func curveIdentity() -> [UInt8] {
        Array("curv".utf8) + [UInt8](repeating: 0, count: 8)
    }

    private func clutIdentity() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 2; bytes[1] = 2; bytes[2] = 2; bytes[16] = 2
        for x in 0..<2 { for y in 0..<2 { for z in 0..<2 {
            for value in [Double(x), Double(y), Double(z)] {
                bytes += be(UInt16((value * 65535.0).rounded()))
            }
        }}}
        return bytes
    }

    private func be(_ value: UInt16) -> [UInt8] { [UInt8(value >> 8), UInt8(value & 0xff)] }
    private func be(_ value: UInt32) -> [UInt8] {
        [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff),
         UInt8((value >> 8) & 0xff), UInt8(value & 0xff)]
    }
    private func be(_ value: Int32) -> [UInt8] { be(UInt32(bitPattern: value)) }
}
