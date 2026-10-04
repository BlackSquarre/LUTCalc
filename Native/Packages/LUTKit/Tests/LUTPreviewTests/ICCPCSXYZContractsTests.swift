import Foundation
import XCTest
import LUTCore
@testable import LUTPreview

final class ICCPCSXYZContractsTests: XCTestCase {
    func testMFT2PCSXYZIdentityUsesICCUnsignedOneFixedFifteen() throws {
        let profile = Data(makeProfile(tag: "A2B0", payload: mft2Identity(), pcs: "XYZ "))
        let transform = try ICCMFTXYZTransform(profileData: profile, tag: "A2B0")
        let xyz = try transform.rgbToXYZ(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(xyz.x, 0.5, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(xyz.y, 1.0, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(xyz.z, 1.5, accuracy: 4.0 / 32768.0)
    }

    func testMFT2PCSXYZIdentityEncodesBackAndRejectsOutOfRange() throws {
        let profile = Data(makeProfile(tag: "B2A0", payload: mft2Identity(), pcs: "XYZ "))
        let transform = try ICCMFTXYZTransform(profileData: profile, tag: "B2A0")
        let rgb = try transform.xyzToRGB(try XYZ64(0.5, 1.0, 1.5))
        XCTAssertEqual(rgb.r, 0.25, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(rgb.g, 0.5, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(rgb.b, 0.75, accuracy: 4.0 / 32768.0)
        XCTAssertThrowsError(try transform.xyzToRGB(try XYZ64(-0.001, 1, 1))) { error in
            XCTAssertEqual(error as? ICCMFTXYZError, .outsideDomain)
        }
    }

    func testMFT1PCSXYZIsRejectedBecauseICCDefinesNoEightBitPCSXYZ() throws {
        XCTAssertThrowsError(try ICCMFTXYZTransform(
            profileData: Data(makeProfile(tag: "A2B0", payload: mft1Identity(), pcs: "XYZ ")),
            tag: "A2B0")) { error in
            XCTAssertEqual(error as? ICCMFTXYZError, .unsupportedEncoding)
        }
    }

    func testMABPCSXYZIdentityUsesSameUnsignedOneFixedFifteenBoundary() throws {
        let profile = Data(makeProfile(tag: "A2B0", payload: mABIdentity(), pcs: "XYZ "))
        let transform = try ICCMABXYZTransform(profileData: profile, tag: "A2B0")
        let xyz = try transform.rgbToXYZ(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(xyz.x, 0.5, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(xyz.y, 1.0, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(xyz.z, 1.5, accuracy: 4.0 / 32768.0)
    }

    func testMBAPCSXYZIdentityEncodesBack() throws {
        let profile = Data(makeProfile(tag: "B2A0", payload: mABIdentity(type: "mBA "), pcs: "XYZ "))
        let transform = try ICCMABXYZTransform(profileData: profile, tag: "B2A0")
        let rgb = try transform.xyzToRGB(try XYZ64(0.5, 1.0, 1.5))
        XCTAssertEqual(rgb.r, 0.25, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(rgb.g, 0.5, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(rgb.b, 0.75, accuracy: 4.0 / 32768.0)
    }

    func testMABPCSXYZRejectsNonRGBAndLabProfiles() throws {
        let payload = mABIdentity()
        XCTAssertThrowsError(try ICCMABXYZTransform(
            profileData: Data(makeProfile(tag: "A2B0", payload: payload, colorSpace: "CMYK")),
            tag: "A2B0")) { error in
            XCTAssertEqual(error as? ICCMABXYZError, .unsupportedColorSpace)
        }
        XCTAssertThrowsError(try ICCMABXYZTransform(
            profileData: Data(makeProfile(tag: "A2B0", payload: payload, pcs: "Lab ")),
            tag: "A2B0")) { error in
            XCTAssertEqual(error as? ICCMABXYZError, .unsupportedPCS)
        }
    }

    func testMABPCSXYZRejectsEightBitCLUTEncoding() throws {
        XCTAssertThrowsError(try ICCMABXYZTransform(
            profileData: Data(makeProfile(tag: "A2B0", payload: mABIdentity(sampleBytes: 1), pcs: "XYZ ")),
            tag: "A2B0")) { error in
            XCTAssertEqual(error as? ICCMABXYZError, .unsupportedEncoding)
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
        for channel in 0..<3 { for index in 0..<256 {
            bytes[48 + channel * 256 + index] = UInt8(index)
        }}
        var cursor = 48 + 3 * 256
        for x in 0..<2 { for y in 0..<2 { for z in 0..<2 {
            for value in [x, y, z] { bytes[cursor] = UInt8(value * 255); cursor += 1 }
        }}}
        for channel in 0..<3 { for index in 0..<256 {
            bytes[cursor + channel * 256 + index] = UInt8(index)
        }}
        return bytes
    }

    private func mABIdentity(type: String = "mAB ", sampleBytes: Int = 2) -> [UInt8] {
        var payload = [UInt8](repeating: 0, count: 32)
        payload.replaceSubrange(0..<4, with: Array(type.utf8))
        payload[8] = 3; payload[9] = 3
        let curve = Array("curv".utf8) + [UInt8](repeating: 0, count: 8)
        var clut = [UInt8](repeating: 0, count: 20)
        clut[0] = 2; clut[1] = 2; clut[2] = 2; clut[16] = UInt8(sampleBytes)
        for x in 0..<2 { for y in 0..<2 { for z in 0..<2 {
            for value in [x, y, z] {
                if sampleBytes == 1 { clut.append(UInt8(value * 255)) }
                else { clut += be(UInt16(value * 65535)) }
            }
        }}}
        let sections: [(String, [UInt8])] = type == "mAB "
            ? [("A", Array(repeating: curve, count: 3).flatMap { $0 }), ("C", clut), ("B", Array(repeating: curve, count: 3).flatMap { $0 })]
            : [("B", Array(repeating: curve, count: 3).flatMap { $0 }), ("C", clut), ("A", Array(repeating: curve, count: 3).flatMap { $0 })]
        var offsets = [Int](repeating: 0, count: 5)
        var cursor = 32
        for (name, section) in sections {
            cursor = (cursor + 3) & ~3
            if payload.count < cursor { payload += [UInt8](repeating: 0, count: cursor - payload.count) }
            let start = cursor
            payload += section
            cursor = payload.count
            switch name {
            case "B": offsets[0] = start
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

    private func makeProfile(tag: String, payload: [UInt8], colorSpace: String = "RGB ", pcs: String = "XYZ ") -> [UInt8] {
        let tableEnd = 144
        var bytes = [UInt8](repeating: 0, count: tableEnd)
        bytes[16...19] = ArraySlice(colorSpace.utf8)
        bytes[20...23] = ArraySlice(pcs.utf8)
        bytes[36...39] = ArraySlice("acsp".utf8)
        bytes.replaceSubrange(128..<132, with: be(UInt32(1)))
        bytes.replaceSubrange(132..<136, with: Array(tag.utf8))
        bytes.replaceSubrange(136..<140, with: be(UInt32(tableEnd)))
        bytes.replaceSubrange(140..<144, with: be(UInt32(payload.count)))
        bytes += payload
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
            bytes.replaceSubrange((12 + index * 4)..<(16 + index * 4), with: be(Int32((value * 65536).rounded())))
        }
    }

    private func be(_ value: UInt16) -> [UInt8] { [UInt8(value >> 8), UInt8(value & 0xff)] }
    private func be(_ value: UInt32) -> [UInt8] { [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)] }
    private func be(_ value: Int32) -> [UInt8] { be(UInt32(bitPattern: value)) }
}
