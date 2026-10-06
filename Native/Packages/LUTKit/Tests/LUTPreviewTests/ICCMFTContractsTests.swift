import Foundation
import XCTest
import LUTCore
@testable import LUTPreview

final class ICCMFTContractsTests: XCTestCase {
    func testMFT2SupportsFourChannelDeviceArrayAndKeepsMatrixBoundaryExplicit() throws {
        var payload = mft2Identity(inputChannels: 4, outputChannels: 3, grid: 2,
                                   inputEntries: 2, outputEntries: 2)
        let transform = try ICCMFTTransform(
            profileData: Data(makeProfile(tag: "A2B0", payload: payload, colorSpace: "CMYK")), tag: "A2B0")
        XCTAssertEqual(transform.inputChannels, 4)
        XCTAssertEqual(transform.outputChannels, 3)
        let output = try transform.sample([0.2, 0.4, 0.6, 0.8])
        XCTAssertEqual(output[0], 0.2, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output[1], 0.4, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output[2], 0.6, accuracy: 2.0 / 65535.0)
        XCTAssertThrowsError(try transform.sample([0.2, 0.4, 0.6])) { error in
            XCTAssertEqual(error as? ICCMFTError, .outsideDomain)
        }
    }

    func testMFT2RejectsNonIdentityMatrixOnNonPCSDeviceSide() throws {
        var payload = mft2Identity(inputChannels: 4, outputChannels: 3, grid: 2,
                                   inputEntries: 2, outputEntries: 2)
        writeMatrix(&payload, values: [9, 0, 0, 0, 9, 0, 0, 0, 9])
        XCTAssertThrowsError(try ICCMFTTransform(
            profileData: Data(makeProfile(tag: "A2B0", payload: payload, colorSpace: "CMYK")),
            tag: "A2B0")) { error in
            XCTAssertEqual(error as? ICCMFTError, .malformedTable)
        }
    }

    func testMFT2RejectsNonIdentityMatrixForNonThreeChannelPCSInput() throws {
        var payload = mft2Identity(inputChannels: 4, outputChannels: 3, grid: 2,
                                   inputEntries: 2, outputEntries: 2)
        writeMatrix(&payload, values: [9, 0, 0, 0, 9, 0, 0, 0, 9])
        XCTAssertThrowsError(try ICCMFTTransform(
            profileData: Data(makeProfile(tag: "A2B0", payload: payload, colorSpace: "XYZ ")),
            tag: "A2B0")) { error in
            XCTAssertEqual(error as? ICCMFTError, .malformedTable)
        }
    }

    func testMFT2RejectsDeviceChannelCountMismatchingProfileHeader() throws {
        let payload = mft2Identity(inputChannels: 4, outputChannels: 3, grid: 2,
                                   inputEntries: 2, outputEntries: 2)
        XCTAssertThrowsError(try ICCMFTTransform(
            profileData: Data(makeProfile(tag: "A2B0", payload: payload, colorSpace: "RGB ")),
            tag: "A2B0")) { error in
            XCTAssertEqual(error as? ICCMFTError, .malformedTable)
        }
    }

    func testMFT2SupportsPCSInputAndFourChannelDeviceOutput() throws {
        let payload = mft2Identity(inputChannels: 3, outputChannels: 4, grid: 2,
                                   inputEntries: 2, outputEntries: 2)
        let transform = try ICCMFTTransform(
            profileData: Data(makeProfile(tag: "B2A0", payload: payload, colorSpace: "CMYK")), tag: "B2A0")
        let output = try transform.sample([0.2, 0.4, 0.6])
        XCTAssertEqual(output.count, 4)
        for (actual, expected) in zip(output, [0.2, 0.4, 0.6, 0.0]) {
            XCTAssertEqual(actual, expected, accuracy: 2.0 / 65535.0)
        }
    }

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

    func testMFT2AcceptsICCMaximum255PointGridForOneDimensionalProfile() throws {
        let payload = mft2Identity(inputChannels: 1, outputChannels: 1, grid: 255,
                                   inputEntries: 2, outputEntries: 2)
        let transform = try ICCMFTTransform(
            profileData: Data(makeProfile(tag: "A2B0", payload: payload, colorSpace: "GRAY")),
            tag: "A2B0")
        XCTAssertEqual(transform.gridPoints, 255)
        let output = try transform.sample([0.375])
        XCTAssertEqual(output[0], 0.375, accuracy: 2.0 / 65535.0)
    }

    func testMFTInputTablesPrecedeMatrix() throws {
        var payload = mft2Identity(inputEntries: 3)
        writeMatrix(&payload, values: [0.5, 0, 0, 0, 1, 0, 0, 0, 1])
        // Red input table is [0, 0.25, 1]. ICC order evaluates the table
        // first, then the matrix: a unit red input becomes 0.5, not 0.25.
        payload.replaceSubrange(52..<54, with: be(UInt16(0)))
        payload.replaceSubrange(54..<56, with: be(UInt16(16384)))
        payload.replaceSubrange(56..<58, with: be(UInt16(65535)))
        let transform = try ICCMFTTransform(profileData: Data(makeProfile(tag: "A2B0", payload: payload)), tag: "A2B0")
        let output = try transform.sample(try RGB64(1, 0, 0))
        XCTAssertEqual(output.r, 0.5, accuracy: 2.0 / 65535.0)
    }

    func testMFTRejectsExtremeGridDimensionsBeforeResourceUse() {
        var payload = mft2Identity(inputChannels: 3, outputChannels: 3)
        payload[8] = 15
        payload[9] = 15
        payload[10] = 255
        XCTAssertThrowsError(try ICCMFTTransform(
            profileData: Data(makeProfile(tag: "A2B0", payload: payload, colorSpace: "RGB ")),
            tag: "A2B0"))
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

    private func mft2Identity(inputChannels: Int = 3, outputChannels: Int = 3,
                              grid: Int = 2, inputEntries: Int = 2,
                              outputEntries: Int = 2) -> [UInt8] {
        let clutNodes = Int(pow(Double(grid), Double(inputChannels)))
        var bytes = [UInt8](repeating: 0,
                            count: 52 + inputChannels * inputEntries * 2 +
                                clutNodes * outputChannels * 2 + outputChannels * outputEntries * 2)
        bytes.replaceSubrange(0..<4, with: Array("mft2".utf8))
        bytes[8] = UInt8(inputChannels); bytes[9] = UInt8(outputChannels); bytes[10] = UInt8(grid)
        writeIdentityMatrix(&bytes)
        bytes.replaceSubrange(48..<50, with: be(UInt16(inputEntries)))
        bytes.replaceSubrange(50..<52, with: be(UInt16(outputEntries)))
        writeIdentityTables(&bytes, start: 52, channels: inputChannels,
                            entries: inputEntries, sampleBytes: 2)
        var cursor = 52 + inputChannels * inputEntries * 2
        for node in 0..<clutNodes {
            var remainder = node
            var coordinates = [Int](repeating: 0, count: inputChannels)
            // ICC stores the first input dimension as the slowest one.
            for axis in stride(from: inputChannels - 1, through: 0, by: -1) {
                coordinates[axis] = remainder % grid
                remainder /= grid
            }
            let values = (0..<outputChannels).map { channel in
                channel < inputChannels ? coordinates[channel] : 0
            }
            for value in values {
                bytes.replaceSubrange(cursor..<cursor + 2,
                                       with: be(UInt16((Double(value) / Double(max(grid - 1, 1)) * 65535).rounded())))
                cursor += 2
            }
        }
        writeIdentityTables(&bytes, start: cursor, channels: outputChannels,
                            entries: outputEntries, sampleBytes: 2)
        return bytes
    }

    private func writeIdentityTables(_ bytes: inout [UInt8], start: Int,
                                     channels: Int = 3, entries: Int, sampleBytes: Int) {
        for channel in 0..<channels { for index in 0..<entries {
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

    private func makeProfile(tag: String, payload: [UInt8], pcs: String = "XYZ ",
                             colorSpace: String = "RGB ") -> [UInt8] {
        let tableEnd = 144
        var bytes = [UInt8](repeating: 0, count: tableEnd)
        bytes[16...19] = ArraySlice(colorSpace.utf8); bytes[20...23] = ArraySlice(pcs.utf8); bytes[36...39] = ArraySlice("acsp".utf8)
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
