import Foundation
import XCTest
import LUTCore
@testable import LUTPreview

final class ICCLUTProfileLinkContractsTests: XCTestCase {
    func testPerceptualIntentUsesExactA2B0AndB2A0Tags() throws {
        let source = Data(makeProfile(tag: "A2B0", payload: mft2Identity()))
        let target = Data(makeProfile(tag: "B2A0", payload: mft2Identity()))
        let link = try ICCLUTProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .perceptual)
        let actual = try link.convert(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(actual.r, 0.25, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(actual.g, 0.5, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(actual.b, 0.75, accuracy: 4.0 / 32768.0)
    }

    func testSaturationIntentUsesExactA2B2AndB2A2Tags() throws {
        let source = Data(makeProfile(tag: "A2B2", payload: mft2Identity()))
        let target = Data(makeProfile(tag: "B2A2", payload: mft2Identity()))
        let link = try ICCLUTProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .saturation)
        let actual = try link.convert(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(actual.r, 0.25, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(actual.g, 0.5, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(actual.b, 0.75, accuracy: 4.0 / 32768.0)
    }

    func testAbsoluteIntentUsesA2B3B2A3AndMediaWhitePointScale() throws {
        let source = Data(makeProfile(tags: [
            ("A2B3", mft2Identity()), ("wtpt", xyzPayload(0.8, 1.0, 0.9))
        ]))
        let target = Data(makeProfile(tags: [
            ("B2A3", mft2Identity()), ("wtpt", xyzPayload(1.6, 0.5, 1.8))
        ]))
        let link = try ICCLUTProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .absoluteColorimetric)
        let actual = try link.convert(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(actual.r, 0.125, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(actual.g, 1.0, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(actual.b, 0.375, accuracy: 4.0 / 32768.0)
    }

    func testMFT2PCSXYZProfileLinkUsesRelativePCSConnection() throws {
        let source = Data(makeProfile(tag: "A2B0", payload: mft2Identity()))
        let target = Data(makeProfile(tag: "B2A0", payload: mft2Identity()))
        let link = try ICCLUTProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)
        let actual = try link.convert(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(actual.r, 0.25, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(actual.g, 0.5, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(actual.b, 0.75, accuracy: 4.0 / 32768.0)
    }

    func testMABAndMBAProfileLinkUsesRelativePCSConnection() throws {
        let source = Data(makeProfile(tag: "A2B0", payload: mABIdentity(type: "mAB ")))
        let target = Data(makeProfile(tag: "B2A0", payload: mABIdentity(type: "mBA ")))
        let link = try ICCLUTProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)
        let actual = try link.convert(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(actual.r, 0.25, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(actual.g, 0.5, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(actual.b, 0.75, accuracy: 4.0 / 32768.0)
    }

    func testRelativeIntentFallsBackWhenIntentOneTagTypeIsUnsupported() throws {
        let source = Data(makeProfile(tags: [("A2B1", mft1Identity()), ("A2B0", mft2Identity())]))
        let target = Data(makeProfile(tags: [("B2A1", mft1Identity()), ("B2A0", mft2Identity())]))
        let link = try ICCLUTProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)
        let actual = try link.convert(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(actual.r, 0.25, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(actual.g, 0.5, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(actual.b, 0.75, accuracy: 4.0 / 32768.0)
    }

    func testRelativeIntentFallsBackWhenIntentOnePCSXYZEncodingIsUnsupported() throws {
        let source = Data(makeProfile(tags: [
            ("A2B1", mABIdentity(type: "mAB ", clutSampleBytes: 1)),
            ("A2B0", mABIdentity(type: "mAB ")),
        ]))
        let target = Data(makeProfile(tags: [
            ("B2A1", mABIdentity(type: "mBA ", clutSampleBytes: 1)),
            ("B2A0", mABIdentity(type: "mBA ")),
        ]))
        let link = try ICCLUTProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)
        let actual = try link.convert(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(actual.r, 0.25, accuracy: 4.0 / 65535.0)
        XCTAssertEqual(actual.g, 0.5, accuracy: 4.0 / 65535.0)
        XCTAssertEqual(actual.b, 0.75, accuracy: 4.0 / 65535.0)
    }

    func testRelativeIntentDoesNotHideMalformedSupportedTag() throws {
        var malformed = mft2Identity()
        malformed.removeLast()
        let source = Data(makeProfile(tags: [("A2B1", malformed), ("A2B0", mft2Identity())]))
        let target = Data(makeProfile(tag: "B2A0", payload: mft2Identity()))
        XCTAssertThrowsError(try ICCLUTProfileLink(sourceProfile: source, targetProfile: target,
                                                   intent: .relativeColorimetric)) { error in
            XCTAssertEqual(error as? ICCLUTProfileLinkError, .invalidProfile)
        }
    }

    func testLinkRejectsUnsupportedIntentEncodingAndPCS() throws {
        let mft2 = Data(makeProfile(tag: "A2B0", payload: mft2Identity()))
        let target = Data(makeProfile(tag: "B2A0", payload: mft2Identity()))
        XCTAssertThrowsError(try ICCLUTProfileLink(sourceProfile: mft2, targetProfile: target,
                                                   intent: .absoluteColorimetric)) {
            XCTAssertEqual($0 as? ICCLUTProfileLinkError,
                           .missingTransformTag("A2B3"))
        }
        XCTAssertThrowsError(try ICCLUTProfileLink(
            sourceProfile: Data(makeProfile(tag: "A2B0", payload: mft1Identity())),
            targetProfile: target, intent: .relativeColorimetric)) {
            XCTAssertEqual($0 as? ICCLUTProfileLinkError, .unsupportedTagType("mft1"))
        }
        XCTAssertThrowsError(try ICCLUTProfileLink(
            sourceProfile: Data(makeProfile(tag: "A2B0", payload: mft2Identity(), pcs: "Lab ")),
            targetProfile: target, intent: .relativeColorimetric)) {
            XCTAssertEqual($0 as? ICCLUTProfileLinkError, .unsupportedPCS)
        }
    }

    func testLinkRejectsMABDirectionMismatches() throws {
        let targetMBA = Data(makeProfile(tag: "B2A0", payload: mABIdentity(type: "mBA ")))
        XCTAssertThrowsError(try ICCLUTProfileLink(
            sourceProfile: Data(makeProfile(tag: "A2B0", payload: mABIdentity(type: "mBA "))),
            targetProfile: targetMBA, intent: .relativeColorimetric)) {
            XCTAssertEqual($0 as? ICCLUTProfileLinkError, .unsupportedTagType("direction"))
        }

        let sourceMAB = Data(makeProfile(tag: "A2B0", payload: mABIdentity(type: "mAB ")))
        XCTAssertThrowsError(try ICCLUTProfileLink(
            sourceProfile: sourceMAB,
            targetProfile: Data(makeProfile(tag: "B2A0", payload: mABIdentity(type: "mAB "))),
            intent: .relativeColorimetric)) {
            XCTAssertEqual($0 as? ICCLUTProfileLinkError, .unsupportedTagType("direction"))
        }
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

    private func mft1Identity() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 48 + 3 * 256 + 8 * 3 + 3 * 256)
        bytes.replaceSubrange(0..<4, with: Array("mft1".utf8))
        bytes[8] = 3; bytes[9] = 3; bytes[10] = 2
        writeMatrix(&bytes, values: [1, 0, 0, 0, 1, 0, 0, 0, 1])
        for channel in 0..<3 { for index in 0..<256 { bytes[48 + channel * 256 + index] = UInt8(index) }}
        var cursor = 48 + 3 * 256
        for x in 0..<2 { for y in 0..<2 { for z in 0..<2 {
            for value in [x, y, z] { bytes[cursor] = UInt8(value * 255); cursor += 1 }
        }}}
        for channel in 0..<3 { for index in 0..<256 { bytes[cursor + channel * 256 + index] = UInt8(index) }}
        return bytes
    }

    private func mABIdentity(type: String, clutSampleBytes: Int = 2) -> [UInt8] {
        var payload = [UInt8](repeating: 0, count: 32)
        payload.replaceSubrange(0..<4, with: Array(type.utf8))
        payload[8] = 3; payload[9] = 3
        let curve = Array("curv".utf8) + [UInt8](repeating: 0, count: 8)
        var clut = [UInt8](repeating: 0, count: 20)
        clut[0] = 2; clut[1] = 2; clut[2] = 2; clut[16] = UInt8(clutSampleBytes)
        for x in 0..<2 { for y in 0..<2 { for z in 0..<2 {
            for value in [x, y, z] {
                if clutSampleBytes == 1 { clut.append(UInt8(value * 255)) }
                else { clut += be(UInt16(value * 65535)) }
            }
        }}}
        let sections: [(String, [UInt8])] = type == "mAB "
            ? [("A", Array(repeating: curve, count: 3).flatMap { $0 }),
               ("C", clut), ("B", Array(repeating: curve, count: 3).flatMap { $0 })]
            : [("B", Array(repeating: curve, count: 3).flatMap { $0 }),
               ("C", clut), ("A", Array(repeating: curve, count: 3).flatMap { $0 })]
        var offsets = [Int](repeating: 0, count: 5)
        var cursor = 32
        for (name, section) in sections {
            cursor = (cursor + 3) & ~3
            if payload.count < cursor { payload += [UInt8](repeating: 0, count: cursor - payload.count) }
            let start = cursor; payload += section; cursor = payload.count
            switch name { case "B": offsets[0] = start; case "C": offsets[3] = start; case "A": offsets[4] = start; default: break }
        }
        for (index, value) in offsets.enumerated() {
            payload.replaceSubrange(12 + index * 4..<16 + index * 4, with: be(UInt32(value)))
        }
        return payload
    }

    private func makeProfile(tag: String, payload: [UInt8], colorSpace: String = "RGB ", pcs: String = "XYZ ") -> [UInt8] {
        makeProfile(tags: [(tag, payload)], colorSpace: colorSpace, pcs: pcs)
    }

    private func makeProfile(tags: [(String, [UInt8])], colorSpace: String = "RGB ", pcs: String = "XYZ ") -> [UInt8] {
        let tableEnd = 132 + tags.count * 12
        var bytes = [UInt8](repeating: 0, count: tableEnd)
        bytes[16...19] = ArraySlice(colorSpace.utf8); bytes[20...23] = ArraySlice(pcs.utf8)
        bytes[36...39] = ArraySlice("acsp".utf8); bytes.replaceSubrange(128..<132, with: be(UInt32(tags.count)))
        var cursor = tableEnd
        for (index, item) in tags.enumerated() {
            let offset = 132 + index * 12
            bytes.replaceSubrange(offset..<offset + 4, with: Array(item.0.utf8))
            bytes.replaceSubrange(offset + 4..<offset + 8, with: be(UInt32(cursor)))
            bytes.replaceSubrange(offset + 8..<offset + 12, with: be(UInt32(item.1.count)))
            bytes += item.1
            let paddedCount = (item.1.count + 3) / 4 * 4
            bytes += [UInt8](repeating: 0, count: paddedCount - item.1.count)
            cursor += paddedCount
        }
        bytes.replaceSubrange(0..<4, with: be(UInt32(bytes.count))); return bytes
    }

    private func xyzPayload(_ x: Double, _ y: Double, _ z: Double) -> [UInt8] {
        var bytes = Array("XYZ ".utf8) + [0, 0, 0, 0]
        for value in [x, y, z] {
            bytes += be(Int32((value * 65536).rounded()))
        }
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
            bytes.replaceSubrange((12 + index * 4)..<(16 + index * 4), with: be(Int32((value * 65536).rounded())))
        }
    }

    private func be(_ value: UInt16) -> [UInt8] { [UInt8(value >> 8), UInt8(value & 0xff)] }
    private func be(_ value: UInt32) -> [UInt8] { [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)] }
    private func be(_ value: Int32) -> [UInt8] { be(UInt32(bitPattern: value)) }
}
