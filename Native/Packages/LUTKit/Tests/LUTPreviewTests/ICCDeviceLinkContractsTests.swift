import Foundation
import XCTest
import LUTCore
@testable import LUTPreview

final class ICCDeviceLinkContractsTests: XCTestCase {
    func testDeviceLinkUsesHeaderIntentAndA2B0MFT2() throws {
        let profile = Data(makeProfile(
            classSignature: "link",
            colorSpace: "RGB ",
            pcs: "RGB ",
            intent: 1,
            tags: [("A2B0", mft2Scale(0.5))]
        ))

        let link = try ICCDeviceLinkTransform(profileData: profile)
        XCTAssertEqual(link.intent, .relativeColorimetric)
        XCTAssertEqual(link.inputChannels, 3)
        XCTAssertEqual(link.outputChannels, 3)
        let output = try link.sample(try RGB64(0.4, 0.6, 0.8))
        XCTAssertEqual(output.r, 0.2, accuracy: 2e-5)
        XCTAssertEqual(output.g, 0.3, accuracy: 2e-5)
        XCTAssertEqual(output.b, 0.4, accuracy: 2e-5)
    }

    func testDeviceLinkUsesA2B0MABAndDeclaredDimensions() throws {
        let profile = Data(makeProfile(
            classSignature: "link",
            colorSpace: "CMYK",
            pcs: "XYZ ",
            intent: 0,
            tags: [("A2B0", mabScale(inputChannels: 4, outputChannels: 3))]
        ))

        let link = try ICCDeviceLinkTransform(profileData: profile)
        XCTAssertEqual(link.intent, .perceptual)
        XCTAssertEqual(link.inputChannels, 4)
        XCTAssertEqual(link.outputChannels, 3)
        let output = try link.sample([0.2, 0.4, 0.6, 0.8])
        XCTAssertEqual(output, [0.2, 0.4, 0.6], accuracy: 2e-6)
    }

    func testDeviceLinkUsesA2B0MPEMatrix() throws {
        let profile = Data(makeProfile(
            classSignature: "link",
            colorSpace: "RGB ",
            pcs: "RGB ",
            intent: 0,
            tags: [("A2B0", mpetScale(0.5))]
        ))

        let link = try ICCDeviceLinkTransform(profileData: profile)
        let output = try link.sample([0.4, 0.6, 0.8])
        XCTAssertEqual(output, [0.2, 0.3, 0.4], accuracy: 0)
    }

    func testDeviceLinkRejectsNonLinkClassAndWrongIntentSelection() throws {
        let regular = Data(makeProfile(
            classSignature: "mntr",
            colorSpace: "RGB ",
            pcs: "RGB ",
            intent: 1,
            tags: [("A2B0", mft2Scale(0.5))]
        ))
        XCTAssertThrowsError(try ICCDeviceLinkTransform(profileData: regular)) {
            XCTAssertEqual($0 as? ICCDeviceLinkError, .unsupportedProfileClass)
        }

        let profile = Data(makeProfile(
            classSignature: "link",
            colorSpace: "RGB ",
            pcs: "RGB ",
            intent: 1,
            tags: [("A2B0", mft2Scale(0.5))]
        ))
        XCTAssertThrowsError(try ICCDeviceLinkTransform(
            profileData: profile, intent: .perceptual
        )) {
            XCTAssertEqual($0 as? ICCDeviceLinkError,
                           .headerIntentMismatch(header: .relativeColorimetric,
                                                  requested: .perceptual))
        }
    }

    func testDeviceLinkRejectsMissingA2B0AndReverseMABDirection() throws {
        let missing = Data(makeProfile(
            classSignature: "link", colorSpace: "RGB ", pcs: "RGB ", intent: 1,
            tags: [("A2B1", mft2Scale(0.5))]
        ))
        XCTAssertThrowsError(try ICCDeviceLinkTransform(profileData: missing)) {
            XCTAssertEqual($0 as? ICCDeviceLinkError, .missingA2B0)
        }

        let reverse = Data(makeProfile(
            classSignature: "link", colorSpace: "RGB ", pcs: "RGB ", intent: 1,
            tags: [("A2B0", mabScale(inputChannels: 3, outputChannels: 3, type: "mBA "))]
        ))
        XCTAssertThrowsError(try ICCDeviceLinkTransform(profileData: reverse)) {
            XCTAssertEqual($0 as? ICCDeviceLinkError, .unsupportedDirection)
        }
    }

    func testDeviceLinkRejectsInputDimensionMismatch() throws {
        let profile = Data(makeProfile(
            classSignature: "link", colorSpace: "CMYK", pcs: "RGB ", intent: 1,
            tags: [("A2B0", mft2Scale(0.5, inputChannels: 3, outputChannels: 3))]
        ))
        XCTAssertThrowsError(try ICCDeviceLinkTransform(profileData: profile)) {
            XCTAssertEqual($0 as? ICCDeviceLinkError, .dimensionMismatch)
        }
    }

    func testGeneratedLittleCMSDeviceLinkMatchesIndependentPipelineSamples() throws {
        let url = URL(fileURLWithPath: "/tmp/lutcalc-srgb-p3-link-20261005.icc")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("需要先用 linkicc 生成临时 device-link 夹具")
        }
        let data = try Data(contentsOf: url)
        let validation = try ICCProfileValidator.validate(data)
        XCTAssertEqual(validation.profileClass, .deviceLink)
        XCTAssertEqual(validation.colorSpaceSignature, "RGB ")
        XCTAssertEqual(validation.pcsSignature, "RGB ")
        let link = try ICCDeviceLinkTransform(profileData: data, intent: .relativeColorimetric)
        // Expected values were generated with Little CMS 2.19's public
        // cmsPipelineEvalFloat on the profile's A2B0 pipeline. This avoids
        // treating transicc's CGATS front end as the numerical reference.
        let samples: [(RGB64, RGB64)] = [
            (try RGB64(0.4, 0.6, 0.8), try RGB64(0.444083303, 0.594644070, 0.782909870)),
            (try RGB64(0.1, 0.2, 0.3), try RGB64(0.123826966, 0.197497517, 0.291859299)),
            (try RGB64(1, 0, 0), try RGB64(0.917524993, 0.200213626, 0.138521403))
        ]
        for (input, expected) in samples {
            let actual = try link.sample(input)
            // The reference pipeline evaluates the profile stages in
            // float32, while the production route intentionally keeps
            // Double throughout; the observed conversion difference stays
            // below 3e-5 for this profile.
            XCTAssertEqual(actual.r, expected.r, accuracy: 3.0e-5)
            XCTAssertEqual(actual.g, expected.g, accuracy: 3.0e-5)
            XCTAssertEqual(actual.b, expected.b, accuracy: 3.0e-5)
        }
    }

    private func makeProfile(classSignature: String, colorSpace: String, pcs: String,
                             intent: Int, tags: [(String, [UInt8])]) -> [UInt8] {
        var payloads: [(String, [UInt8], Int)] = []
        var cursor = 132 + tags.count * 12
        for (signature, payload) in tags {
            let aligned = (cursor + 3) & ~3
            cursor = aligned
            payloads.append((signature, payload, cursor))
            cursor += payload.count
        }
        var bytes = [UInt8](repeating: 0, count: cursor)
        putU32(&bytes, 0, UInt32(cursor))
        putASCII(&bytes, 36, "acsp")
        putASCII(&bytes, 12, classSignature)
        putASCII(&bytes, 16, colorSpace)
        putASCII(&bytes, 20, pcs)
        putU32(&bytes, 64, UInt32(intent))
        putU32(&bytes, 128, UInt32(tags.count))
        for (index, (signature, payload, offset)) in payloads.enumerated() {
            let table = 132 + index * 12
            putASCII(&bytes, table, signature)
            putU32(&bytes, table + 4, UInt32(offset))
            putU32(&bytes, table + 8, UInt32(payload.count))
            bytes.replaceSubrange(offset..<(offset + payload.count), with: payload)
        }
        return bytes
    }

    private func mft2Scale(_ scale: Double, inputChannels: Int = 3,
                           outputChannels: Int = 3) -> [UInt8] {
        let grid = 2
        let entries = 2
        let header = 52
        let clutCount = Int(pow(Double(grid), Double(inputChannels))) * outputChannels
        let size = header + inputChannels * entries * 2 + clutCount * 2 + outputChannels * entries * 2
        var bytes = [UInt8](repeating: 0, count: size)
        putASCII(&bytes, 0, "mft2")
        bytes[8] = UInt8(inputChannels); bytes[9] = UInt8(outputChannels); bytes[10] = UInt8(grid)
        let identity: [Double] = [1, 0, 0, 0, 1, 0, 0, 0, 1]
        for (index, value) in identity.enumerated() {
            putI32(&bytes, 12 + index * 4, Int32((value * 65536).rounded()))
        }
        putU16(&bytes, 48, UInt16(entries)); putU16(&bytes, 50, UInt16(entries))
        var cursor = header
        for index in 0..<(inputChannels * entries) {
            putU16(&bytes, cursor, UInt16(index % entries == 0 ? 0 : 65535)); cursor += 2
        }
        let nodeCount = Int(pow(Double(grid), Double(inputChannels)))
        for node in 0..<nodeCount {
            var remainder = node
            var coordinates = Array(repeating: 0, count: inputChannels)
            for axis in stride(from: inputChannels - 1, through: 0, by: -1) {
                coordinates[axis] = remainder % grid
                remainder /= grid
            }
            for channel in 0..<outputChannels {
                let coordinate = coordinates[min(channel, inputChannels - 1)]
                let value = scale * Double(coordinate) / Double(grid - 1)
                putU16(&bytes, cursor, UInt16((value * 65535).rounded())); cursor += 2
            }
        }
        for index in 0..<(outputChannels * entries) {
            putU16(&bytes, cursor, UInt16(index % entries == 0 ? 0 : 65535)); cursor += 2
        }
        return bytes
    }

    private func mabScale(inputChannels: Int, outputChannels: Int, type: String = "mAB ") -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 32 + outputChannels * 12 + outputChannels * 2)
        putASCII(&bytes, 0, type)
        bytes[8] = UInt8(inputChannels); bytes[9] = UInt8(outputChannels)
        putU32(&bytes, 12, UInt32(32))
        let curveStart = 32
        for index in 0..<outputChannels {
            let offset = curveStart + index * 12
            putASCII(&bytes, offset, "curv")
            putU32(&bytes, offset + 8, 0)
        }
        return bytes
    }

    private func mpetScale(_ scale: Double) -> [UInt8] {
        // mpet header + one element record + matf element. The matrix is
        // diagonal with a zero offset, so the route has an exact expected
        // result without depending on sampled tables.
        let elementOffset = 24
        let elementSize = 12 + 12 * 4
        var bytes = [UInt8](repeating: 0, count: elementOffset + elementSize)
        putASCII(&bytes, 0, "mpet")
        putU16(&bytes, 8, 3)
        putU16(&bytes, 10, 3)
        putU32(&bytes, 12, 1)
        putU32(&bytes, 16, UInt32(elementOffset))
        putU32(&bytes, 20, UInt32(elementSize))
        putASCII(&bytes, elementOffset, "matf")
        putU16(&bytes, elementOffset + 8, 3)
        putU16(&bytes, elementOffset + 10, 3)
        let values: [Double] = [scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, scale, 0]
        for (index, value) in values.enumerated() {
            putU32(&bytes, elementOffset + 12 + index * 4,
                   Float(value).bitPattern)
        }
        return bytes
    }

    private func putASCII(_ bytes: inout [UInt8], _ offset: Int, _ value: String) {
        bytes.replaceSubrange(offset..<(offset + 4), with: Array(value.utf8.prefix(4)))
    }

    private func putU16(_ bytes: inout [UInt8], _ offset: Int, _ value: UInt16) {
        bytes[offset] = UInt8(value >> 8); bytes[offset + 1] = UInt8(value & 0xff)
    }

    private func putU32(_ bytes: inout [UInt8], _ offset: Int, _ value: UInt32) {
        bytes[offset] = UInt8((value >> 24) & 0xff); bytes[offset + 1] = UInt8((value >> 16) & 0xff)
        bytes[offset + 2] = UInt8((value >> 8) & 0xff); bytes[offset + 3] = UInt8(value & 0xff)
    }

    private func putI32(_ bytes: inout [UInt8], _ offset: Int, _ value: Int32) {
        putU32(&bytes, offset, UInt32(bitPattern: value))
    }
}

private extension Array where Element == Double {
    func equal(_ other: [Double], accuracy: Double) -> Bool {
        count == other.count && zip(self, other).allSatisfy { abs($0 - $1) <= accuracy }
    }
}

private func XCTAssertEqual(_ lhs: [Double], _ rhs: [Double], accuracy: Double,
                            file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(lhs.equal(rhs, accuracy: accuracy), "\(lhs) != \(rhs)", file: file, line: line)
}
