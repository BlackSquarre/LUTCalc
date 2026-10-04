import Foundation
import XCTest
import LUTCore
@testable import LUTPreview

final class ICCMFTContractsTests: XCTestCase {
    func testMFT1IdentityUsesDoubleTablesAndICCChannelOrder() throws {
        let transform = try ICCMFTTransform(profileData: Data(makeProfile(tag: "A2B0", payload: mft1Identity())), tag: "A2B0")
        for input in [try RGB64(0, 0, 0), try RGB64(0.25, 0.5, 0.75), try RGB64(1, 1, 1)] {
            let output = try transform.sample(input)
            XCTAssertEqual(output.r, input.r, accuracy: 1.0 / 255.0)
            XCTAssertEqual(output.g, input.g, accuracy: 1.0 / 255.0)
            XCTAssertEqual(output.b, input.b, accuracy: 1.0 / 255.0)
        }
    }

    func testMFT1LabIdentityBridgesRGBToPCSLab() throws {
        let profile = Data(makeProfile(tag: "A2B0", payload: mft1Identity(), pcs: "Lab "))
        let transform = try ICCMFTLabTransform(profileData: profile, tag: "A2B0")
        let lab = try transform.rgbToLab(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(lab.lStar, 0.25, accuracy: 2.0 / 255.0)
        XCTAssertEqual(lab.aStar, 0.5 * 255.0 - 128.0, accuracy: 2.0 / 255.0)
        XCTAssertEqual(lab.bStar, 0.75 * 255.0 - 128.0, accuracy: 2.0 / 255.0)
    }

    func testMFT2IdentityInterpolatesCLUTAndRejectsDomainErrors() throws {
        let transform = try ICCMFTTransform(profileData: Data(makeProfile(tag: "A2B0", payload: mft2Identity())), tag: "A2B0")
        let output = try transform.sample(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(output.r, 0.25, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.g, 0.5, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.b, 0.75, accuracy: 2.0 / 65535.0)
        XCTAssertThrowsError(try transform.sample(try RGB64(-0.1, 0.5, 0.5))) {
            XCTAssertEqual($0 as? ICCMFTError, .outsideDomain)
        }
        XCTAssertThrowsError(try RGB64(.nan, 0.5, 0.5)) {
            XCTAssertEqual($0 as? NumericError, .nonFinite)
        }
    }

    func testMFT2LabIdentityBridgesPCSLabToRGB() throws {
        let profile = Data(makeProfile(tag: "B2A0", payload: mft2Identity(), pcs: "Lab "))
        let transform = try ICCMFTLabTransform(profileData: profile, tag: "B2A0")
        let lab = try CIELABColor(lStar: 0.8, aStar: 0.2 * 255.0 - 128.0,
                                  bStar: 0.4 * 255.0 - 128.0)
        let rgb = try transform.labToRGB(lab)
        XCTAssertEqual(rgb.r, 0.8, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(rgb.g, 0.2, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(rgb.b, 0.4, accuracy: 2.0 / 65535.0)
    }

    func testMFTRejectsNonRGBChannelsAndMalformedLength() throws {
        var payload = mft1Identity()
        payload[8] = 4
        XCTAssertThrowsError(try ICCMFTTransform(profileData: Data(makeProfile(tag: "A2B0", payload: payload)), tag: "A2B0"))
        XCTAssertThrowsError(try ICCMFTTransform(profileData: Data(makeProfile(tag: "A2B0", payload: Array(mft1Identity().dropLast()))), tag: "A2B0"))
    }

    func testMFT1AppliesS15Fixed16MatrixBeforeCLUT() throws {
        var payload = mft1Identity()
        writeMatrix(&payload, values: [0.5, 0, 0, 0, 0.5, 0, 0, 0, 0.5])
        let transform = try ICCMFTTransform(profileData: Data(makeProfile(tag: "A2B0", payload: payload)), tag: "A2B0")
        let output = try transform.sample(try RGB64(0.8, 0.4, 0.2))
        XCTAssertEqual(output.r, 0.4, accuracy: 1.0 / 255.0)
        XCTAssertEqual(output.g, 0.2, accuracy: 1.0 / 255.0)
        XCTAssertEqual(output.b, 0.1, accuracy: 1.0 / 255.0)
    }

    func testMFT2AllowsDifferentInputAndOutputTableEntryCounts() throws {
        let payload = mft2Identity(inputEntries: 2, outputEntries: 3)
        let transform = try ICCMFTTransform(profileData: Data(makeProfile(tag: "A2B0", payload: payload)), tag: "A2B0")
        XCTAssertEqual(transform.tableEntries, 2)
        XCTAssertEqual(transform.outputTableEntries, 3)
        let output = try transform.sample(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(output.r, 0.25, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.g, 0.5, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.b, 0.75, accuracy: 2.0 / 65535.0)
    }

    func testMFTMatrixPrecedesInputTables() throws {
        var payload = mft2Identity(inputEntries: 3)
        writeMatrix(&payload, values: [0.5, 0, 0, 0, 1, 0, 0, 0, 1])
        // Red input table is [0, 0.25, 1]. A unit red input must first
        // become 0.5 in the matrix, then 0.25 through the table.
        payload.replaceSubrange(52..<54, with: be(UInt16(0)))
        payload.replaceSubrange(54..<56, with: be(UInt16(16384)))
        payload.replaceSubrange(56..<58, with: be(UInt16(65535)))
        let transform = try ICCMFTTransform(profileData: Data(makeProfile(tag: "A2B0", payload: payload)), tag: "A2B0")
        let output = try transform.sample(try RGB64(1, 0, 0))
        XCTAssertEqual(output.r, 16384.0 / 65535.0, accuracy: 2.0 / 65535.0)
    }

    private func mft1Identity() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 48 + 3 * 256 + 8 * 3 + 3 * 256)
        bytes.replaceSubrange(0..<4, with: Array("mft1".utf8))
        bytes[8] = 3; bytes[9] = 3; bytes[10] = 2
        writeIdentityMatrix(&bytes)
        writeIdentityTables(&bytes, start: 48, entries: 256, sampleBytes: 1)
        var cursor = 48 + 3 * 256
        for x in 0..<2 { for y in 0..<2 { for z in 0..<2 {
            bytes[cursor] = UInt8(x * 255); bytes[cursor + 1] = UInt8(y * 255); bytes[cursor + 2] = UInt8(z * 255); cursor += 3
        }}}
        writeIdentityTables(&bytes, start: cursor, entries: 256, sampleBytes: 1)
        return bytes
    }

    private func mft2Identity(inputEntries: Int = 2, outputEntries: Int = 2) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 52 + 3 * inputEntries * 2 + 8 * 3 * 2 + 3 * outputEntries * 2)
        bytes.replaceSubrange(0..<4, with: Array("mft2".utf8))
        bytes[8] = 3; bytes[9] = 3; bytes[10] = 2
        writeIdentityMatrix(&bytes)
        bytes.replaceSubrange(48..<50, with: be(UInt16(inputEntries)))
        bytes.replaceSubrange(50..<52, with: be(UInt16(outputEntries)))
        writeIdentityTables(&bytes, start: 52, entries: inputEntries, sampleBytes: 2)
        var cursor = 52 + 3 * inputEntries * 2
        for x in 0..<2 { for y in 0..<2 { for z in 0..<2 {
            for value in [x, y, z] { bytes.replaceSubrange(cursor..<cursor + 2, with: be(UInt16(value * 65535))); cursor += 2 }
        }}}
        writeIdentityTables(&bytes, start: cursor, entries: outputEntries, sampleBytes: 2)
        return bytes
    }

    private func writeIdentityTables(_ bytes: inout [UInt8], start: Int, entries: Int, sampleBytes: Int) {
        for channel in 0..<3 { for index in 0..<entries {
            let value = UInt16((Double(index) / Double(entries - 1) * 65535).rounded())
            let offset = start + (channel * entries + index) * sampleBytes
            if sampleBytes == 1 { bytes[offset] = UInt8((Double(index) / Double(entries - 1) * 255).rounded()) }
            else { bytes.replaceSubrange(offset..<offset + 2, with: be(value)) }
        }}
    }

    private func writeIdentityMatrix(_ bytes: inout [UInt8]) {
        writeMatrix(&bytes, values: [1, 0, 0, 0, 1, 0, 0, 0, 1])
    }

    private func writeMatrix(_ bytes: inout [UInt8], values: [Double]) {
        let fixed = values.map { Int32(($0 * 65536.0).rounded()) }
        for (index, value) in fixed.enumerated() {
            bytes.replaceSubrange((12 + index * 4)..<(16 + index * 4), with: be(value))
        }
    }

    private func makeProfile(tag: String, payload: [UInt8], pcs: String = "XYZ ") -> [UInt8] {
        let tableEnd = 144
        var bytes = [UInt8](repeating: 0, count: tableEnd)
        bytes[16...19] = ArraySlice("RGB ".utf8); bytes[20...23] = ArraySlice(pcs.utf8); bytes[36...39] = ArraySlice("acsp".utf8)
        bytes.replaceSubrange(128..<132, with: be(UInt32(1)))
        bytes.replaceSubrange(132..<136, with: Array(tag.utf8)); bytes.replaceSubrange(136..<140, with: be(UInt32(tableEnd))); bytes.replaceSubrange(140..<144, with: be(UInt32(payload.count)))
        bytes += payload; bytes.replaceSubrange(0..<4, with: be(UInt32(bytes.count))); return bytes
    }

    private func be(_ value: UInt16) -> [UInt8] {
        [UInt8((value >> 8) & 0xff), UInt8(value & 0xff)]
    }
    private func be(_ value: UInt32) -> [UInt8] {
        [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff),
         UInt8((value >> 8) & 0xff), UInt8(value & 0xff)]
    }
    private func be(_ value: Int32) -> [UInt8] { be(UInt32(bitPattern: value)) }
}
