import Foundation
import XCTest
import LUTCore
@testable import LUTPreview

final class ICCMABContractsTests: XCTestCase {
    func testMABIdentityPipelineUsesAClutMMatrixBOrder() throws {
        let transform = try ICCMABTransform(profileData: Data(makeProfile(tag: "A2B0", payload: pipeline(type: "mAB "))), tag: "A2B0")
        let input = try RGB64(0.25, 0.5, 0.75)
        let output = try transform.sample(input)
        XCTAssertEqual(output.r, input.r, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.g, input.g, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.b, input.b, accuracy: 2.0 / 65535.0)
    }

    func testMABLabIdentityPipelineBridgesRGBToPCSLab() throws {
        let profile = Data(makeProfile(tag: "A2B0", payload: pipeline(type: "mAB "), pcs: "Lab "))
        let transform = try ICCMABLabTransform(profileData: profile, tag: "A2B0")
        let lab = try transform.rgbToLab(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(lab.lStar, 0.25, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(lab.aStar, 0.5 * 255.0 - 128.0, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(lab.bStar, 0.75 * 255.0 - 128.0, accuracy: 2.0 / 65535.0)
    }

    func testMBAIdentityPipelineUsesBMatrixMClutAOrder() throws {
        let transform = try ICCMABTransform(profileData: Data(makeProfile(tag: "B2A0", payload: pipeline(type: "mBA "))), tag: "B2A0")
        let output = try transform.sample(try RGB64(0.8, 0.2, 0.4))
        XCTAssertEqual(output.r, 0.8, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.g, 0.2, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.b, 0.4, accuracy: 2.0 / 65535.0)
    }

    func testMBALabIdentityPipelineBridgesPCSLabToRGB() throws {
        let profile = Data(makeProfile(tag: "B2A0", payload: pipeline(type: "mBA "), pcs: "Lab "))
        let transform = try ICCMABLabTransform(profileData: profile, tag: "B2A0")
        let lab = try CIELABColor(lStar: 0.8, aStar: 0.2 * 255.0 - 128.0,
                                  bStar: 0.4 * 255.0 - 128.0)
        let rgb = try transform.labToRGB(lab)
        XCTAssertEqual(rgb.r, 0.8, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(rgb.g, 0.2, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(rgb.b, 0.4, accuracy: 2.0 / 65535.0)
    }

    func testMABLabRejectsXYZPCSAndWrongDirection() throws {
        let xyz = Data(makeProfile(tag: "A2B0", payload: pipeline(type: "mAB ")))
        XCTAssertThrowsError(try ICCMABLabTransform(profileData: xyz, tag: "A2B0")) { error in
            XCTAssertEqual(error as? ICCMABLabError, .unsupportedPCS)
        }
        let lab = Data(makeProfile(tag: "A2B0", payload: pipeline(type: "mAB "), pcs: "Lab "))
        XCTAssertThrowsError(try ICCMABLabTransform(profileData: lab, tag: "B2A0")) { error in
            XCTAssertEqual(error as? ICCMABLabError, .invalidProfile)
        }
    }

    func testMABAppliesMatrixAndParametricCurveWithDoublePrecision() throws {
        let payload = pipeline(type: "mAB ", includeMatrix: true, includeParametricOutput: true)
        let transform = try ICCMABTransform(profileData: Data(makeProfile(tag: "A2B0", payload: payload)), tag: "A2B0")
        let output = try transform.sample(try RGB64(0.5, 0.25, 0.75))
        XCTAssertEqual(output.r, 0.25, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.g, 0.25, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.b, 0.75, accuracy: 2.0 / 65535.0)
    }

    func testMABRejectsDomainAndMalformedSections() throws {
        let profile = Data(makeProfile(tag: "A2B0", payload: pipeline(type: "mAB ")))
        let transform = try ICCMABTransform(profileData: profile, tag: "A2B0")
        XCTAssertThrowsError(try transform.sample(try RGB64(-0.01, 0.5, 0.5))) {
            XCTAssertEqual($0 as? ICCMABError, .outsideDomain)
        }
        var malformed = pipeline(type: "mAB ")
        malformed[28] = 0
        malformed[29] = 0
        malformed[30] = 0
        malformed[31] = 31
        XCTAssertThrowsError(try ICCMABTransform(profileData: Data(makeProfile(tag: "A2B0", payload: malformed)), tag: "A2B0"))
    }

    func testParametricTypeThreeUsesSixParametersAndBothBranches() throws {
        // ICC type 3: x < d -> f*x; x >= d -> (a*x+b)^g+c.
        let curve = curveParametric(3, [2, 1, 0, 0.125, 0.5, 0.25])
        let transform = try makeTransform(outputCurve: curve)
        let result = try transform.sample(try RGB64(0.25, 0.75, 0.5))
        XCTAssertEqual(result.r, 0.0625, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(result.g, 0.6875, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(result.b, 0.375, accuracy: 2.0 / 65535.0)
    }

    func testParametricTypeFourUsesOffsetOnBothBranches() throws {
        // ICC type 4: x < d -> c*x+f; x >= d -> (a*x+b)^g+e.
        let curve = curveParametric(4, [2, 1, 0, 0.25, 0.5, 0.125, 0.0625])
        let transform = try makeTransform(outputCurve: curve)
        let result = try transform.sample(try RGB64(0.25, 0.75, 0.5))
        XCTAssertEqual(result.r, 0.125, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(result.g, 0.6875, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(result.b, 0.375, accuracy: 2.0 / 65535.0)
    }

    func testCurveAndCLUTCannotConsumeNextSection() throws {
        var curveOverlap = pipeline(type: "mAB ")
        // The A section starts at 32; its second curve belongs inside CLUT.
        curveOverlap.replaceSubrange(40..<44, with: be(UInt32(100)))
        XCTAssertThrowsError(try ICCMABTransform(profileData: Data(makeProfile(tag: "A2B0", payload: curveOverlap)), tag: "A2B0"))

        var clutOverlap = pipeline(type: "mAB ")
        let clutStart = Int(clutOverlap[24]) << 24 | Int(clutOverlap[25]) << 16 |
            Int(clutOverlap[26]) << 8 | Int(clutOverlap[27])
        clutOverlap[clutStart] = 3 // A 3x2x2 grid needs more bytes than this section owns.
        XCTAssertThrowsError(try ICCMABTransform(profileData: Data(makeProfile(tag: "A2B0", payload: clutOverlap)), tag: "A2B0"))
    }

    func testMatrixUsesInterleavedOffsetsAndClipsBeforeNextCurve() throws {
        let payload = pipeline(type: "mAB ", matrixData: matrix(scale: [2, 0.5, 1],
                                                                    offset: [0.125, 0.25, -0.25]))
        let transform = try ICCMABTransform(profileData: Data(makeProfile(tag: "A2B0", payload: payload)), tag: "A2B0")
        let result = try transform.sample(try RGB64(0.75, 0.5, 0.1))
        XCTAssertEqual(result.r, 1, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(result.g, 0.5, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(result.b, 0, accuracy: 2.0 / 65535.0)
    }

    func testInvalidOptionalStageCombinationsAreRejected() throws {
        var missingB = pipeline(type: "mAB ")
        missingB.replaceSubrange(12..<16, with: be(UInt32(0)))
        XCTAssertThrowsError(try ICCMABTransform(profileData: Data(makeProfile(tag: "A2B0", payload: missingB)), tag: "A2B0"))
        var missingCLUT = pipeline(type: "mAB ")
        missingCLUT.replaceSubrange(24..<28, with: be(UInt32(0)))
        XCTAssertThrowsError(try ICCMABTransform(profileData: Data(makeProfile(tag: "A2B0", payload: missingCLUT)), tag: "A2B0"))
        var missingMatrix = pipeline(type: "mAB ", includeMatrix: true)
        missingMatrix.replaceSubrange(16..<20, with: be(UInt32(0)))
        XCTAssertThrowsError(try ICCMABTransform(profileData: Data(makeProfile(tag: "A2B0", payload: missingMatrix)), tag: "A2B0"))
    }

    func testCurveSectionsMayShareOffset() throws {
        var payload = pipeline(type: "mAB ")
        payload.replaceSubrange(12..<16, with: payload[28..<32])
        let transform = try ICCMABTransform(profileData: Data(makeProfile(tag: "A2B0", payload: payload)), tag: "A2B0")
        let output = try transform.sample(try RGB64(0.2, 0.4, 0.6))
        XCTAssertEqual(output.r, 0.2, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.g, 0.4, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.b, 0.6, accuracy: 2.0 / 65535.0)
    }

    func testNonUniformCLUTGridUsesLastChannelFastest() throws {
        let payload = pipeline(type: "mAB ", clutData: clutIdentity(grid: [2, 3, 4]))
        let transform = try ICCMABTransform(profileData: Data(makeProfile(tag: "A2B0", payload: payload)), tag: "A2B0")
        let output = try transform.sample(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(output.r, 0.25, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.g, 0.5, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.b, 0.75, accuracy: 2.0 / 65535.0)
    }

    func testMBAMatrixRunsAfterBCurves() throws {
        let payload = pipeline(type: "mBA ", includeMatrix: true)
        let transform = try ICCMABTransform(profileData: Data(makeProfile(tag: "B2A0", payload: payload)), tag: "B2A0")
        let output = try transform.sample(try RGB64(0.8, 0.4, 0.2))
        XCTAssertEqual(output.r, 0.4, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.g, 0.4, accuracy: 2.0 / 65535.0)
        XCTAssertEqual(output.b, 0.2, accuracy: 2.0 / 65535.0)
    }

    private func makeTransform(outputCurve: [UInt8]) throws -> ICCMABTransform {
        let payload = pipeline(type: "mAB ", outputCurve: outputCurve)
        return try ICCMABTransform(profileData: Data(makeProfile(tag: "A2B0", payload: payload)), tag: "A2B0")
    }

    private func pipeline(type: String, includeMatrix: Bool = false,
                          includeParametricOutput: Bool = false,
                          outputCurve: [UInt8]? = nil, matrixData: [UInt8]? = nil,
                          clutData: [UInt8]? = nil) -> [UInt8] {
        var payload = [UInt8](repeating: 0, count: 32)
        payload.replaceSubrange(0..<4, with: Array(type.utf8))
        payload[8] = 3; payload[9] = 3
        var sections: [(String, [UInt8])] = []
        let curves = Array(repeating: curveIdentity(), count: 3).flatMap { $0 }
        let selected = outputCurve ?? (includeParametricOutput ? curveParametric(0, [1]) : curveIdentity())
        let outputCurves = Array(repeating: selected, count: 3).flatMap { $0 }
        let selectedMatrix = matrixData ?? (includeMatrix ? matrix(scale: [0.5, 1, 1], offset: [0, 0, 0]) : [])
        let middleCurves = selectedMatrix.isEmpty ? [] : curves
        let selectedCLUT = clutData ?? clutIdentity()
        if type == "mAB " {
            sections = [("A", curves), ("C", selectedCLUT), ("M", middleCurves), ("X", selectedMatrix), ("B", outputCurves)]
        } else {
            sections = [("B", curves), ("X", selectedMatrix), ("M", middleCurves), ("C", selectedCLUT), ("A", outputCurves)]
        }
        var offsets = [Int](repeating: 0, count: 5)
        var cursor = 32
        for section in sections where !section.1.isEmpty {
            cursor = (cursor + 3) & ~3
            let start = cursor
            payload += [UInt8](repeating: 0, count: start - payload.count)
            payload += section.1
            cursor = payload.count
            if type == "mAB " {
                switch section.0 { case "B": offsets[0] = start; case "X": offsets[1] = start; case "M": offsets[2] = start; case "C": offsets[3] = start; case "A": offsets[4] = start; default: break }
            } else {
                switch section.0 { case "B": offsets[0] = start; case "X": offsets[1] = start; case "M": offsets[2] = start; case "C": offsets[3] = start; case "A": offsets[4] = start; default: break }
            }
        }
        for (index, value) in offsets.enumerated() { payload.replaceSubrange(12 + index * 4..<16 + index * 4, with: be(UInt32(value))) }
        return payload
    }

    private func curveIdentity() -> [UInt8] { Array("curv".utf8) + [UInt8](repeating: 0, count: 8) }
    private func curveGamma(_ gamma: Double) -> [UInt8] { Array("curv".utf8) + [UInt8](repeating: 0, count: 4) + be(UInt32(1)) + be(UInt16((gamma * 256).rounded())) + [0, 0] }
    private func curveParametric(_ type: UInt16, _ values: [Double]) -> [UInt8] {
        Array("para".utf8) + [UInt8](repeating: 0, count: 4) + be(type) + [0, 0] +
            values.flatMap { be(Int32(($0 * 65536).rounded())) }
    }
    private func matrix(scale: [Double], offset: [Double]) -> [UInt8] {
        var result: [UInt8] = []
        for row in 0..<3 {
            for column in 0..<3 {
                result += be(Int32(((row == column ? scale[row] : 0) * 65536).rounded()))
            }
            result += be(Int32((offset[row] * 65536).rounded()))
        }
        return result
    }
    private func clutIdentity(grid: [Int] = [2, 2, 2]) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = UInt8(grid[0]); bytes[1] = UInt8(grid[1]); bytes[2] = UInt8(grid[2]); bytes[16] = 2
        for x in 0..<grid[0] { for y in 0..<grid[1] { for z in 0..<grid[2] {
            for value in [Double(x) / Double(grid[0] - 1), Double(y) / Double(grid[1] - 1), Double(z) / Double(grid[2] - 1)] {
                bytes += be(UInt16((value * 65535).rounded()))
            }
        } } }
        return bytes
    }
    private func makeProfile(tag: String, payload: [UInt8], pcs: String = "XYZ ") -> [UInt8] {
        let tableEnd = 144
        var bytes = [UInt8](repeating: 0, count: tableEnd)
        bytes[16...19] = ArraySlice("RGB ".utf8); bytes[20...23] = ArraySlice(pcs.utf8); bytes[36...39] = ArraySlice("acsp".utf8)
        bytes.replaceSubrange(128..<132, with: be(UInt32(1)))
        bytes.replaceSubrange(132..<136, with: Array(tag.utf8)); bytes.replaceSubrange(136..<140, with: be(UInt32(tableEnd))); bytes.replaceSubrange(140..<144, with: be(UInt32(payload.count)))
        bytes += payload; bytes.replaceSubrange(0..<4, with: be(UInt32(bytes.count))); return bytes
    }
    private func be(_ value: UInt16) -> [UInt8] { [UInt8(value >> 8), UInt8(value & 0xff)] }
    private func be(_ value: UInt32) -> [UInt8] { [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)] }
    private func be(_ value: Int32) -> [UInt8] { be(UInt32(bitPattern: value)) }
}
