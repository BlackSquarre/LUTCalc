import Foundation
import XCTest
import LUTCore
@testable import LUTPreview

final class ICCMatrixTRCContractsTests: XCTestCase {
    func testSystemSRGBProfileLoadsThroughValidatedMatrixTRCPath() throws {
        let url = URL(fileURLWithPath: "/System/Library/ColorSync/Profiles/sRGB Profile.icc")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("系统未提供 sRGB Profile.icc")
        }
        let data = try Data(contentsOf: url)
        let validation = try ICCProfileValidator.validate(data)
        XCTAssertEqual(validation.colorSpaceSignature, "RGB ")
        XCTAssertEqual(validation.pcsSignature, "XYZ ")
        XCTAssertTrue(validation.tagSignatures.contains("rTRC"))
        XCTAssertTrue(validation.tagSignatures.contains("rXYZ"))

        let plan = try ICCMatrixTRCTransform(profileData: data)
        let encoded = try RGB64(0.5, 0.25, 0.75)
        let xyz = try plan.encodedRGBToXYZ(encoded)
        XCTAssertTrue([xyz.x, xyz.y, xyz.z].allSatisfy(\.isFinite))
        let restored = try plan.xyzToEncodedRGB(xyz)
        XCTAssertEqual(restored.r, encoded.r, accuracy: 2e-4)
        XCTAssertEqual(restored.g, encoded.g, accuracy: 2e-4)
        XCTAssertEqual(restored.b, encoded.b, accuracy: 2e-4)
    }

    func testSystemDisplayP3ProfileLoadsThroughValidatedMatrixTRCPath() throws {
        let url = URL(fileURLWithPath: "/System/Library/ColorSync/Profiles/Display P3.icc")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("系统未提供 Display P3.icc")
        }
        let data = try Data(contentsOf: url)
        let validation = try ICCProfileValidator.validate(data)
        XCTAssertEqual(validation.colorSpaceSignature, "RGB ")
        XCTAssertEqual(validation.pcsSignature, "XYZ ")
        XCTAssertTrue(validation.tagSignatures.contains("rTRC"))
        XCTAssertTrue(validation.tagSignatures.contains("rXYZ"))

        let plan = try ICCMatrixTRCTransform(profileData: data)
        let encoded = try RGB64(0.17, 0.63, 0.91)
        let xyz = try plan.encodedRGBToXYZ(encoded)
        XCTAssertTrue([xyz.x, xyz.y, xyz.z].allSatisfy(\.isFinite))
        let restored = try plan.xyzToEncodedRGB(xyz)
        XCTAssertEqual(restored.r, encoded.r, accuracy: 2e-4)
        XCTAssertEqual(restored.g, encoded.g, accuracy: 2e-4)
        XCTAssertEqual(restored.b, encoded.b, accuracy: 2e-4)
    }

    func testSystemAdobeRGBProfileLoadsThroughValidatedMatrixTRCPath() throws {
        try assertSystemMatrixTRCProfile(
            path: "/System/Library/ColorSync/Profiles/AdobeRGB1998.icc",
            sample: try RGB64(0.19, 0.57, 0.83)
        )
    }

    func testSystemITU2020ProfileLoadsThroughValidatedMatrixTRCPath() throws {
        try assertSystemMatrixTRCProfile(
            path: "/System/Library/ColorSync/Profiles/ITU-2020.icc",
            sample: try RGB64(0.19, 0.57, 0.83)
        )
    }

    func testRealSystemDisplayProfileExecutesMatrixTRCPath() throws {
        let url = URL(fileURLWithPath: "/Library/ColorSync/Profiles/Displays/XBH-6C4F598C-E1DA-4CA4-82C7-618A66227F93.icc")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("系统未提供显示器 ICC profile")
        }
        let plan = try ICCMatrixTRCTransform(profileData: try Data(contentsOf: url))
        let input = try RGB64(0.21, 0.58, 0.87)
        let xyz = try plan.encodedRGBToXYZ(input)
        let restored = try plan.xyzToEncodedRGB(xyz)
        XCTAssertTrue([xyz.x, xyz.y, xyz.z].allSatisfy(\.isFinite))
        XCTAssertEqual(restored.r, input.r, accuracy: 3e-4)
        XCTAssertEqual(restored.g, input.g, accuracy: 3e-4)
        XCTAssertEqual(restored.b, input.b, accuracy: 3e-4)
    }

    private func assertSystemMatrixTRCProfile(path: String, sample: RGB64) throws {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("系统未提供 (url.lastPathComponent)")
        }
        let data = try Data(contentsOf: url)
        let validation = try ICCProfileValidator.validate(data)
        XCTAssertEqual(validation.colorSpaceSignature, "RGB ")
        XCTAssertEqual(validation.pcsSignature, "XYZ ")
        let plan = try ICCMatrixTRCTransform(profileData: data)
        let xyz = try plan.encodedRGBToXYZ(sample)
        XCTAssertTrue([xyz.x, xyz.y, xyz.z].allSatisfy(\.isFinite))
        let restored = try plan.xyzToEncodedRGB(xyz)
        XCTAssertEqual(restored.r, sample.r, accuracy: 2e-4)
        XCTAssertEqual(restored.g, sample.g, accuracy: 2e-4)
        XCTAssertEqual(restored.b, sample.b, accuracy: 2e-4)
    }

    func testMatrixTRCProfileLinkingUsesRelativeColorimetricPCSConnection() throws {
        let source = Data(makeProfile(tags: matrixTRCTags(gamma: 2.0)))
        let target = Data(makeProfile(tags: matrixTRCTags(curvePayloadData: curvePayload([0, 65535]))))
        let link = try ICCMatrixTRCProfileLink(sourceProfile: source, targetProfile: target,
                                              intent: .relativeColorimetric)
        let actual = try link.convert(RGB64(0.5, 0.25, 0.75))
        XCTAssertEqual(actual.r, 0.25, accuracy: 2e-14)
        XCTAssertEqual(actual.g, 0.0625, accuracy: 2e-14)
        XCTAssertEqual(actual.b, 0.5625, accuracy: 2e-14)
    }

    func testMatrixTRCProfileLinkingRejectsUnsupportedRenderingIntent() throws {
        let source = Data(makeProfile(tags: matrixTRCTags(gamma: 2.0)))
        XCTAssertThrowsError(try ICCMatrixTRCProfileLink(sourceProfile: source,
                                                          targetProfile: source,
                                                          intent: .perceptual)) {
            XCTAssertEqual($0 as? ICCMatrixTRCProfileLinkError, .unsupportedRenderingIntent(.perceptual))
        }
    }

    func testAbsoluteColorimetricUsesPCSConnectionWhenMediaWhitePointsMatch() throws {
        let source = Data(makeProfile(tags: matrixTRCTags(gamma: 2.0)))
        let target = Data(makeProfile(tags: matrixTRCTags(curvePayloadData: curvePayload([0, 65535]))))
        let relative = try ICCMatrixTRCProfileLink(sourceProfile: source, targetProfile: target,
                                                    intent: .relativeColorimetric)
        let absolute = try ICCMatrixTRCProfileLink(sourceProfile: source, targetProfile: target,
                                                    intent: .absoluteColorimetric)
        let input = try RGB64(0.5, 0.25, 0.75)
        let relativeOutput = try relative.convert(input)
        let actual = try absolute.convert(input)
        let independent = try RGB64(input.r * input.r, input.g * input.g, input.b * input.b)
        XCTAssertEqual(relativeOutput.r, independent.r, accuracy: 2e-14)
        XCTAssertEqual(relativeOutput.g, independent.g, accuracy: 2e-14)
        XCTAssertEqual(relativeOutput.b, independent.b, accuracy: 2e-14)
        XCTAssertEqual(actual.r, independent.r, accuracy: 2e-14)
        XCTAssertEqual(actual.g, independent.g, accuracy: 2e-14)
        XCTAssertEqual(actual.b, independent.b, accuracy: 2e-14)
        XCTAssertEqual(absolute.intent, .absoluteColorimetric)
    }

    func testAbsoluteColorimetricAcceptsMismatchedMediaWhitePoints() throws {
        let source = Data(makeProfile(tags: matrixTRCTags(gamma: 2.0)))
        var targetTags = matrixTRCTags(gamma: 2.0)
        targetTags[3].1 = xyzPayload(0.95047, 1.0, 1.08883)
        let link = try ICCMatrixTRCProfileLink(
            sourceProfile: source, targetProfile: Data(makeProfile(tags: targetTags)),
            intent: .absoluteColorimetric
        )
        XCTAssertEqual(link.intent, .absoluteColorimetric)
    }

    func testAbsoluteColorimetricScalesBetweenDifferentMediaWhitePoints() throws {
        var sourceTags = matrixTRCTags(gamma: 2.0)
        sourceTags[3].1 = xyzPayload(0.75, 1.0, 0.5)
        var targetTags = matrixTRCTags(curvePayloadData: curvePayload([0, 65535]))
        targetTags[3].1 = xyzPayload(1.5, 0.5, 1.0)

        let link = try ICCMatrixTRCProfileLink(
            sourceProfile: Data(makeProfile(tags: sourceTags)),
            targetProfile: Data(makeProfile(tags: targetTags)),
            intent: .absoluteColorimetric
        )
        let actual = try link.convert(RGB64(0.5, 0.25, 0.75))

        // ICC.1:2022-05 §6.3.2.2: relative -> absolute -> target-relative.
        // These powers-of-two white-point ratios make the independent result exact.
        XCTAssertEqual(actual.r, 0.125, accuracy: 2e-14)
        XCTAssertEqual(actual.g, 0.125, accuracy: 2e-14)
        XCTAssertEqual(actual.b, 0.28125, accuracy: 2e-14)
    }

    func testMatrixTRCProfileLinkingRejectsMismatchedPCSWhitePoints() throws {
        let source = Data(makeProfile(tags: matrixTRCTags(gamma: 2.0)))
        var targetTags = matrixTRCTags(gamma: 2.0)
        targetTags[3].1 = xyzPayload(0.95047, 1.0, 1.08883)
        XCTAssertThrowsError(try ICCMatrixTRCProfileLink(
            sourceProfile: source, targetProfile: Data(makeProfile(tags: targetTags)),
            intent: .relativeColorimetric
        )) {
            XCTAssertEqual($0 as? ICCMatrixTRCProfileLinkError, .mismatchedPCSWhitePoint)
        }
    }

    func testMatrixTRCStagesAndIndependentGammaReference() throws {
        let profile = makeProfile(tags: matrixTRCTags(gamma: 2.0))
        let plan = try ICCMatrixTRCTransform(profileData: Data(profile))
        XCTAssertEqual(plan.profileWhitePoint.x, 0.9642181396484375, accuracy: 0)
        XCTAssertEqual(plan.profileWhitePoint.y, 1, accuracy: 0)
        XCTAssertEqual(plan.profileWhitePoint.z, 0.8251953125, accuracy: 0)
        let trace = try plan.traceEncodedRGBToXYZ(try RGB64(0.25, 0.5, 0.75))

        XCTAssertEqual(trace.stages.map(\.id), [.encodedRGB, .decodeTransfer, .linearRGB, .matrix, .xyzOutput])
        let xyz = try XCTUnwrap(trace.xyzOutput)
        XCTAssertEqual(xyz.x, pow(0.25, 2.0), accuracy: 2e-14)
        XCTAssertEqual(xyz.y, pow(0.5, 2.0), accuracy: 2e-14)
        XCTAssertEqual(xyz.z, pow(0.75, 2.0), accuracy: 2e-14)
    }

    func testZeroCountCurveIsIdentityAndSampledTwoPointCurve() throws {
        var tags = matrixTRCTags(gamma: 2.0)
        for index in tags.indices where tags[index].0.hasSuffix("TRC") {
            tags[index].1 = Data([UInt8]("curv".utf8) + [UInt8](repeating: 0, count: 8))
        }
        let plan = try ICCMatrixTRCTransform(profileData: Data(makeProfile(tags: tags)))
        let encoded = try RGB64(0.125, 0.5, 0.875)
        let xyz = try plan.encodedRGBToXYZ(encoded)
        XCTAssertEqual(xyz.x, encoded.r, accuracy: 0)
        XCTAssertEqual(xyz.y, encoded.g, accuracy: 0)
        XCTAssertEqual(xyz.z, encoded.b, accuracy: 0)
        let restored = try plan.xyzToEncodedRGB(xyz)
        XCTAssertEqual(restored.r, encoded.r, accuracy: 0)
        XCTAssertEqual(restored.g, encoded.g, accuracy: 0)
        XCTAssertEqual(restored.b, encoded.b, accuracy: 0)

        var sampled = tags
        for index in sampled.indices where sampled[index].0.hasSuffix("TRC") {
            sampled[index].1 = Data([UInt8]("curv".utf8) + [UInt8](repeating: 0, count: 4) +
                                    bigEndian(UInt32(2)) + bigEndian(UInt16(0)) + bigEndian(UInt16.max))
        }
        let sampledPlan = try ICCMatrixTRCTransform(profileData: Data(makeProfile(tags: sampled)))
        let sampledXYZ = try sampledPlan.encodedRGBToXYZ(try RGB64(0.25, 0.5, 0.75))
        XCTAssertEqual(sampledXYZ.x, 0.25, accuracy: 0)
        XCTAssertEqual(sampledXYZ.y, 0.5, accuracy: 0)
        XCTAssertEqual(sampledXYZ.z, 0.75, accuracy: 0)
    }

    func testSampledCurveUsesUniformLinearInterpolationAndInverse() throws {
        let values = [0.0, 0.25, 0.75, 1.0]
        let curve = curvePayload(values.map { UInt16(($0 * 65535.0).rounded()) })
        let tags = matrixTRCTags(curvePayloadData: curve)
        let plan = try ICCMatrixTRCTransform(profileData: Data(makeProfile(tags: tags)))

        // These values exercise interior points of all three intervals.
        let xyz = try plan.encodedRGBToXYZ(try RGB64(0.375, 0.625, 0.875))
        XCTAssertEqual(xyz.x, 0.3125, accuracy: 2e-5)
        XCTAssertEqual(xyz.y, 0.6875, accuracy: 2e-5)
        XCTAssertEqual(xyz.z, 0.90625, accuracy: 2e-5)
        let restored = try plan.xyzToEncodedRGB(xyz)
        XCTAssertEqual(restored.r, 0.375, accuracy: 2e-12)
        XCTAssertEqual(restored.g, 0.625, accuracy: 2e-12)
        XCTAssertEqual(restored.b, 0.875, accuracy: 2e-12)
    }

    func testSampledCurveRoundTripOn33And65Grid() throws {
        let values = [0.0, 0.03125, 0.125, 0.375, 0.72, 1.0]
        let curve = curvePayload(values.map { UInt16(($0 * 65535.0).rounded()) })
        let plan = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(curvePayloadData: curve)
        )))
        var maximum = 0.0
        for size in [33, 65] {
            for r in 0..<size {
                for g in 0..<size {
                    for b in 0..<size {
                        let input = try RGB64(
                            Double(r) / Double(size - 1),
                            Double(g) / Double(size - 1),
                            Double(b) / Double(size - 1)
                        )
                        let restored = try plan.xyzToEncodedRGB(try plan.encodedRGBToXYZ(input))
                        maximum = max(
                            maximum,
                            abs(restored.r - input.r),
                            abs(restored.g - input.g),
                            abs(restored.b - input.b)
                        )
                    }
                }
            }
        }
        XCTAssertLessThan(maximum, 2e-12)
    }

    func testSampledCurveFlatAndNonMonotonicInverseAreRejected() throws {
        let quantizedHalf = Double(32768) / 65535.0
        let flat = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(curvePayloadData: curvePayload([0, 32768, 32768, 65535])))))
        XCTAssertThrowsError(try flat.xyzToEncodedRGB(try XYZ64(quantizedHalf, quantizedHalf, quantizedHalf))) { error in
            XCTAssertEqual(error as? ICCMatrixTRCError, .nonUnique(stage: .encodeTransfer))
        }

        let nonMonotonic = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(curvePayloadData: curvePayload([0, 49152, 16384, 65535])))))
        XCTAssertThrowsError(try nonMonotonic.xyzToEncodedRGB(try XYZ64(quantizedHalf, quantizedHalf, quantizedHalf))) { error in
            XCTAssertEqual(error as? ICCMatrixTRCError, .nonUnique(stage: .encodeTransfer))
        }
    }

    func testParametricTypeFourMatchesIndependentReference() throws {
        let values = [
            2.0, 1.0, 0.0, 1.0, 0.5, 0.0, 0.0,
        ]
        let plan = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(parametricValues: values)
        )))
        let actual = try plan.encodedRGBToXYZ(try RGB64(0.5, 0.5, 0.5))
        let expected = pow(values[1] * 0.5 + values[2], values[0]) + values[5]
        XCTAssertEqual(actual.x, expected, accuracy: 2e-13)
        XCTAssertEqual(actual.y, expected, accuracy: 2e-13)
        XCTAssertEqual(actual.z, expected, accuracy: 2e-13)
    }

    func testParametricTypesOneAndTwoMatchIndependentReferences() throws {
        let typeOneValues = [2.0, 1.0, 0.0]
        let typeOne = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(parametricValues: typeOneValues, functionType: 1)
        )))
        let one = try typeOne.encodedRGBToXYZ(try RGB64(0.5, 0.5, 0.5))
        XCTAssertEqual(one.x, pow(0.5, 2), accuracy: 2e-13)

        let typeTwoValues = [2.0, 1.0, 0.0, 0.1]
        let typeTwo = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(parametricValues: typeTwoValues, functionType: 2)
        )))
        let two = try typeTwo.encodedRGBToXYZ(try RGB64(0.5, 0.5, 0.5))
        let quantizedC = Double((0.1 * 65536.0).rounded()) / 65536.0
        XCTAssertEqual(two.x, pow(0.5, 2) + quantizedC, accuracy: 2e-13)
        XCTAssertEqual(try typeTwo.xyzToEncodedRGB(two).r, 0.5, accuracy: 2e-13)
    }

    func testParametricTypesOneAndTwoRejectFlatInverse() throws {
        let one = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(parametricValues: [2, 1, -0.25], functionType: 1)
        )))
        XCTAssertThrowsError(try one.xyzToEncodedRGB(try XYZ64(0, 0, 0))) { error in
            XCTAssertEqual(error as? ICCMatrixTRCError, .nonUnique(stage: .encodeTransfer))
        }

        let two = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(parametricValues: [2, 1, -0.25, 0.125], functionType: 2)
        )))
        XCTAssertThrowsError(try two.xyzToEncodedRGB(try XYZ64(0.125, 0.125, 0.125))) { error in
            XCTAssertEqual(error as? ICCMatrixTRCError, .nonUnique(stage: .encodeTransfer))
        }
    }

    func testParametricTypeThreeMatchesIndependentReferenceAndInverse() throws {
        // ICC type 3: y=(a*x+b)^g+c for x >= d, otherwise 0.
        let values = [2.0, 1.0, 0.0, 0.0, 0.25]
        let plan = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(parametricValues: values, functionType: 3)
        )))

        let lowInput = try RGB64(0.1, 0.1, 0.1)
        let low = try plan.encodedRGBToXYZ(lowInput)
        XCTAssertEqual(low.x, 0, accuracy: 2e-13)

        let highInput = try RGB64(0.5, 0.5, 0.5)
        let high = try plan.encodedRGBToXYZ(highInput)
        XCTAssertEqual(high.x, pow(values[1] * highInput.r + values[2], values[0]) + values[3], accuracy: 2e-13)
        XCTAssertEqual(try plan.xyzToEncodedRGB(high).r, highInput.r, accuracy: 2e-13)

        var maximum = 0.0
        for size in [33, 65] {
            for r in (size / 4)..<size {
                for g in (size / 4)..<size {
                    for b in (size / 4)..<size {
                        let input = try RGB64(
                            Double(r) / Double(size - 1),
                            Double(g) / Double(size - 1),
                            Double(b) / Double(size - 1)
                        )
                        let restored = try plan.xyzToEncodedRGB(try plan.encodedRGBToXYZ(input))
                        maximum = max(
                            maximum,
                            abs(restored.r - input.r),
                            abs(restored.g - input.g),
                            abs(restored.b - input.b)
                        )
                    }
                }
            }
        }
        XCTAssertLessThan(maximum, 2e-12)
    }

    func testParametricTypeThreeInverseRejectsGapAndOverlap() throws {
        // Type 3 has a constant zero low branch; zero is therefore non-unique.
        let gap = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(parametricValues: [2, 1, 0, 0, 0.5], functionType: 3)
        )))
        XCTAssertThrowsError(try gap.xyzToEncodedRGB(try XYZ64(0, 0, 0))) { error in
            XCTAssertEqual(error as? ICCMatrixTRCError, .nonUnique(stage: .encodeTransfer))
        }

        // The high branch remains invertible above the threshold.
        let overlap = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(parametricValues: [2, 1, 0, 0, 0.5], functionType: 3)
        )))
        XCTAssertEqual(try overlap.xyzToEncodedRGB(try XYZ64(0.36, 0.36, 0.36)).r,
                       sqrt(0.36), accuracy: 2e-13)
    }

    func testParametricTypeFourInverseRejectsGapAndOverlap() throws {
        let gap = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(parametricValues: [2, 1, 0, 0.25, 0.5, 0, 0], functionType: 4)
        )))
        XCTAssertThrowsError(try gap.xyzToEncodedRGB(try XYZ64(0.1875, 0.1875, 0.1875))) { error in
            XCTAssertEqual(error as? ICCMatrixTRCError, .outsideDomain(stage: .encodeTransfer))
        }

        let overlap = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(parametricValues: [2, 1, 0, 1, 0.5, 0, 0], functionType: 4)
        )))
        XCTAssertThrowsError(try overlap.xyzToEncodedRGB(try XYZ64(0.36, 0.36, 0.36))) { error in
            XCTAssertEqual(error as? ICCMatrixTRCError, .nonUnique(stage: .encodeTransfer))
        }
    }

    func testMatrixTRCRoundTrip33And65Grid() throws {
        let plan = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(gamma: 2.0)
        )))
        var maximum = 0.0
        for size in [33, 65] {
            for r in 0..<size {
                for g in 0..<size {
                    for b in 0..<size {
                        let input = try RGB64(
                            Double(r) / Double(size - 1),
                            Double(g) / Double(size - 1),
                            Double(b) / Double(size - 1)
                        )
                        let restored = try plan.xyzToEncodedRGB(try plan.encodedRGBToXYZ(input))
                        maximum = max(
                            maximum,
                            abs(restored.r - input.r),
                            abs(restored.g - input.g),
                            abs(restored.b - input.b)
                        )
                    }
                }
            }
        }
        XCTAssertLessThan(maximum, 2e-12)
    }

    func testNonRGBAndMissingRequiredTagsAreRejected() throws {
        XCTAssertThrowsError(try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(gamma: 2.0), colorSpace: "GRAY"
        )))) { error in
            XCTAssertEqual(error as? ICCMatrixTRCError, .unsupportedColorSpace)
        }
        XCTAssertThrowsError(try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(gamma: 2.0), pcs: "Lab "
        )))) { error in
            XCTAssertEqual(error as? ICCMatrixTRCError, .unsupportedPCS)
        }

        var tags = matrixTRCTags(gamma: 2.0)
        tags.removeAll { $0.0 == "gTRC" }
        XCTAssertThrowsError(try ICCMatrixTRCTransform(profileData: Data(makeProfile(tags: tags)))) { error in
            XCTAssertEqual(error as? ICCMatrixTRCError, .missingTag("gTRC"))
        }
    }

    func testUnsupportedCurveAndOutOfDomainInputAreRejected() throws {
        XCTAssertThrowsError(try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(parametricValues: [2.4, 1, 0, 1, 0], functionType: 5)
        )))) { error in
            XCTAssertEqual(error as? ICCMatrixTRCError, .invalidProfile)
        }

        let plan = try ICCMatrixTRCTransform(profileData: Data(makeProfile(
            tags: matrixTRCTags(gamma: 2.0)
        )))
        XCTAssertThrowsError(try plan.encodedRGBToXYZ(try RGB64(-0.01, 0.5, 0.5))) { error in
            XCTAssertEqual(error as? ICCMatrixTRCError, .outsideDomain(stage: .decodeTransfer))
        }
    }

    private func matrixTRCTags(
        gamma: Double? = nil,
        parametricValues: [Double]? = nil,
        functionType: UInt16 = 4,
        curvePayloadData: Data? = nil
    ) -> [(String, Data)] {
        let curve: Data
        if let curvePayloadData {
            curve = curvePayloadData
        } else if let gamma {
            curve = curvePayload(gamma: gamma)
        } else {
            curve = parametricPayload(functionType: functionType, values: parametricValues!)
        }
        return [
            ("rXYZ", xyzPayload(1, 0, 0)),
            ("gXYZ", xyzPayload(0, 1, 0)),
            ("bXYZ", xyzPayload(0, 0, 1)),
            ("wtpt", xyzPayload(0.964212, 1, 0.825188)),
            ("rTRC", curve), ("gTRC", curve), ("bTRC", curve),
        ]
    }

    private func makeProfile(
        tags: [(String, Data)], colorSpace: String = "RGB ", pcs: String = "XYZ "
    ) -> [UInt8] {
        let tableEnd = 132 + tags.count * 12
        var bytes = [UInt8](repeating: 0, count: tableEnd)
        bytes[16...19] = ArraySlice(colorSpace.utf8)
        bytes[20...23] = ArraySlice(pcs.utf8)
        bytes[36...39] = ArraySlice("acsp".utf8)
        bytes.replaceSubrange(128..<132, with: bigEndian(UInt32(tags.count)))
        var offset = tableEnd
        for (index, item) in tags.enumerated() {
            let start = 132 + index * 12
            bytes.replaceSubrange(start..<start + 4, with: item.0.utf8)
            bytes.replaceSubrange(start + 4..<start + 8, with: bigEndian(UInt32(offset)))
            bytes.replaceSubrange(start + 8..<start + 12, with: bigEndian(UInt32(item.1.count)))
            bytes += item.1
            let paddedCount = (item.1.count + 3) / 4 * 4
            bytes += [UInt8](repeating: 0, count: paddedCount - item.1.count)
            offset += paddedCount
        }
        bytes.replaceSubrange(0..<4, with: bigEndian(UInt32(bytes.count)))
        return bytes
    }

    private func xyzPayload(_ x: Double, _ y: Double, _ z: Double) -> Data {
        Data([UInt8]("XYZ ".utf8) + [UInt8](repeating: 0, count: 4) +
             [x, y, z].flatMap { fixed16($0) })
    }

    private func curvePayload(gamma: Double) -> Data {
        Data([UInt8]("curv".utf8) + [UInt8](repeating: 0, count: 4) +
             bigEndian(UInt32(1)) + unsigned16(gamma * 256.0))
    }

    private func curvePayload(_ values: [UInt16]) -> Data {
        Data([UInt8]("curv".utf8) + [UInt8](repeating: 0, count: 4) +
             bigEndian(UInt32(values.count)) + values.flatMap(bigEndian))
    }

    private func parametricPayload(functionType: UInt16, values: [Double]) -> Data {
        var bytes = [UInt8]("para".utf8) + [UInt8](repeating: 0, count: 4)
        bytes += bigEndian(functionType) + [0, 0]
        for value in values { bytes += fixed16(value) }
        return Data(bytes)
    }

    private func bigEndian(_ value: UInt32) -> [UInt8] {
        [UInt8(truncatingIfNeeded: value >> 24), UInt8(truncatingIfNeeded: value >> 16),
               UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)]
    }

    private func bigEndian(_ value: UInt16) -> [UInt8] {
        [UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)]
    }

    private func fixed16(_ value: Double) -> [UInt8] {
        let bits = UInt32(bitPattern: Int32((value * 65536.0).rounded()))
        return bigEndian(bits)
    }

    private func unsigned16(_ value: Double) -> [UInt8] {
        bigEndian(UInt16(clamping: Int(value.rounded())))
    }
}
