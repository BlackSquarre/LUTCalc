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

    func testSystemDisplayP3ProfileUsesExplicitMatrixRoute() throws {
        let url = URL(fileURLWithPath: "/System/Library/ColorSync/Profiles/Display P3.icc")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("系统未提供 Display P3.icc")
        }
        let data = try Data(contentsOf: url)
        let link = try ICCRGBProfileLink(sourceProfile: data, targetProfile: data,
                                         intent: .relativeColorimetric)
        let input = try RGB64(0.17, 0.63, 0.91)
        let output = try link.convert(input)
        XCTAssertEqual(output.r, input.r, accuracy: 2e-4)
        XCTAssertEqual(output.g, input.g, accuracy: 2e-4)
        XCTAssertEqual(output.b, input.b, accuracy: 2e-4)
    }

    func testSystemDisplayP3ToSRGBRelativeLinkRejectsMismatchedPCSWhitePoint() throws {
        let p3URL = URL(fileURLWithPath: "/System/Library/ColorSync/Profiles/Display P3.icc")
        let srgbURL = URL(fileURLWithPath: "/System/Library/ColorSync/Profiles/sRGB Profile.icc")
        guard FileManager.default.fileExists(atPath: p3URL.path),
              FileManager.default.fileExists(atPath: srgbURL.path) else {
            throw XCTSkip("系统未同时提供 Display P3 与 sRGB profile")
        }
        let p3 = try Data(contentsOf: p3URL)
        let srgb = try Data(contentsOf: srgbURL)
        XCTAssertThrowsError(try ICCRGBProfileLink(sourceProfile: p3, targetProfile: srgb,
                                                   intent: .relativeColorimetric)) { error in
            guard case .matrix(.mismatchedPCSWhitePoint) = error as? ICCRGBProfileLinkError else {
                return XCTFail("应明确报告 matrix mismatchedPCSWhitePoint，实际为 \(error)")
            }
        }
    }

    func testSystemDisplayP3ToSRGBAbsoluteLinkUsesMediaWhitePointScaling() throws {
        let p3URL = URL(fileURLWithPath: "/System/Library/ColorSync/Profiles/Display P3.icc")
        let srgbURL = URL(fileURLWithPath: "/System/Library/ColorSync/Profiles/sRGB Profile.icc")
        guard FileManager.default.fileExists(atPath: p3URL.path),
              FileManager.default.fileExists(atPath: srgbURL.path) else {
            throw XCTSkip("系统未同时提供 Display P3 与 sRGB profile")
        }
        let p3 = try Data(contentsOf: p3URL)
        let srgb = try Data(contentsOf: srgbURL)
        let link = try ICCRGBProfileLink(sourceProfile: p3, targetProfile: srgb,
                                         intent: .absoluteColorimetric)
        let output = try link.convert(try RGB64(0.17, 0.63, 0.91))
        XCTAssertTrue([output.r, output.g, output.b].allSatisfy(\.isFinite))
        XCTAssertTrue([output.r, output.g, output.b].allSatisfy { (-4...4).contains($0) })
    }

    func testMixedMatrixAndLUTProfilesAreRejectedWithoutGuessing() throws {
        let matrix = try XCTUnwrap(systemSRGBIfAvailable())
        let lut = Data(makeProfile(tag: "A2B0", payload: mft2Identity()))
        XCTAssertThrowsError(try ICCRGBProfileLink(sourceProfile: lut, targetProfile: matrix,
                                                   intent: .relativeColorimetric)) {
            XCTAssertEqual($0 as? ICCRGBProfileLinkError, .mismatchedProfileKinds)
        }
    }

    func testNonDeviceProfileClassesAreRejectedBeforeRouteSelection() throws {
        let source = Data(makeProfile(tag: "A2B0", payload: mft2Identity(), profileClass: "abst"))
        let target = Data(makeProfile(tag: "B2A0", payload: mft2Identity(), profileClass: "mntr"))
        XCTAssertThrowsError(try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                                   intent: .relativeColorimetric)) { error in
            XCTAssertEqual(error as? ICCRGBProfileLinkError, .unsupportedProfileKind)
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

    func testAbsoluteColorimetricMatrixRouteIsExplicitWhenWhitePointsMatch() throws {
        let source = Data(makeProfile(tags: syntheticMatrixTRCTags(gamma: 2.0)))
        let target = Data(makeProfile(tags: syntheticMatrixTRCTags(gamma: nil)))
        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .absoluteColorimetric)
        let input = try RGB64(0.5, 0.25, 0.75)
        let output = try link.convert(input)
        XCTAssertEqual(output.r, input.r * input.r, accuracy: 2e-14)
        XCTAssertEqual(output.g, input.g * input.g, accuracy: 2e-14)
        XCTAssertEqual(output.b, input.b * input.b, accuracy: 2e-14)
        XCTAssertEqual(link.intent, .absoluteColorimetric)
    }

    func testAbsoluteColorimetricMatrixRouteScalesDifferentMediaWhitePoints() throws {
        var sourceTags = syntheticMatrixTRCTags(gamma: 2.0)
        sourceTags[3].1 = xyzPayload(0.75, 1.0, 0.5)
        var targetTags = syntheticMatrixTRCTags(gamma: nil)
        targetTags[3].1 = xyzPayload(1.5, 0.5, 1.0)

        let link = try ICCRGBProfileLink(
            sourceProfile: Data(makeProfile(tags: sourceTags)),
            targetProfile: Data(makeProfile(tags: targetTags)),
            intent: .absoluteColorimetric
        )
        let output = try link.convert(RGB64(0.5, 0.25, 0.75))

        XCTAssertEqual(output.r, 0.125, accuracy: 2e-14)
        XCTAssertEqual(output.g, 0.125, accuracy: 2e-14)
        XCTAssertEqual(output.b, 0.28125, accuracy: 2e-14)
    }

    func testAbsoluteColorimetricMPETRouteUsesDToB3AndBToD3WithoutMediaWhiteScaling() throws {
        let source = Data(makeProfile(tags: [
            ("D2B3", mpetMatrix(values: [1, 0, 0, 0,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0])),
            ("wtpt", xyzPayload(0.8, 1.1, 0.9)),
        ]))
        let target = Data(makeProfile(tags: [
            ("B2D3", mpetMatrix(values: [0.5, 0, 0, 0,
                                         0, 0.5, 0, 0,
                                         0, 0, 0.5, 0])),
            ("wtpt", xyzPayload(1.4, 0.7, 1.2)),
        ]))

        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .absoluteColorimetric)
        let output = try link.convert(RGB64(0.5, 0.25, 0.75))

        XCTAssertEqual(output.r, 0.25, accuracy: 2e-7)
        XCTAssertEqual(output.g, 0.125, accuracy: 2e-7)
        XCTAssertEqual(output.b, 0.375, accuracy: 2e-7)
    }

    func testAbsoluteColorimetricMPETRouteSupportsLabPCS() throws {
        let source = Data(makeProfile(tags: [
            ("D2B3", mpetMatrix(values: [100, 0, 0, 0,
                                         0, 255, 0, -128,
                                         0, 0, 255, -128])),
        ], pcs: "Lab "))
        let target = Data(makeProfile(tags: [
            ("B2D3", mpetMatrix(values: [0.01, 0, 0, 0,
                                         0, 1.0 / 255.0, 0, 128.0 / 255.0,
                                         0, 0, 1.0 / 255.0, 128.0 / 255.0])),
        ], pcs: "Lab "))

        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .absoluteColorimetric)
        let output = try link.convert(RGB64(0.5, 0.4, 0.6))

        XCTAssertEqual(output.r, 0.5, accuracy: 2e-7)
        XCTAssertEqual(output.g, 0.4, accuracy: 2e-7)
        XCTAssertEqual(output.b, 0.6, accuracy: 2e-7)
    }

    func testRelativeColorimetricMPETRouteUsesDToB1AndBToD1WithoutMediaWhiteScaling() throws {
        let source = Data(makeProfile(tags: [
            ("D2B1", mpetMatrix(values: [1, 0, 0, 0,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0])),
            ("wtpt", xyzPayload(0.8, 1.1, 0.9)),
        ]))
        let target = Data(makeProfile(tags: [
            ("B2D1", mpetMatrix(values: [0.5, 0, 0, 0,
                                         0, 0.5, 0, 0,
                                         0, 0, 0.5, 0])),
            ("wtpt", xyzPayload(1.4, 0.7, 1.2)),
        ]))

        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)
        let output = try link.convert(RGB64(0.5, 0.25, 0.75))

        XCTAssertEqual(output.r, 0.25, accuracy: 2e-7)
        XCTAssertEqual(output.g, 0.125, accuracy: 2e-7)
        XCTAssertEqual(output.b, 0.375, accuracy: 2e-7)
    }

    func testPerceptualMPETRouteUsesDToB0AndBToD0WithoutGuessing() throws {
        let source = Data(makeProfile(tags: [
            ("D2B0", mpetMatrix(values: [1, 0, 0, 0,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0])),
        ]))
        let target = Data(makeProfile(tags: [
            ("B2D0", mpetMatrix(values: [0.5, 0, 0, 0,
                                         0, 0.5, 0, 0,
                                         0, 0, 0.5, 0])),
        ]))

        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .perceptual)
        let output = try link.convert(RGB64(0.5, 0.25, 0.75))

        XCTAssertEqual(output.r, 0.25, accuracy: 2e-7)
        XCTAssertEqual(output.g, 0.125, accuracy: 2e-7)
        XCTAssertEqual(output.b, 0.375, accuracy: 2e-7)
    }

    func testSaturationMPETRouteUsesDToB2AndBToD2WithoutGuessing() throws {
        let source = Data(makeProfile(tags: [
            ("D2B2", mpetMatrix(values: [1, 0, 0, 0,
                                         0, 1, 0, 0,
                                         0, 0, 1, 0])),
        ]))
        let target = Data(makeProfile(tags: [
            ("B2D2", mpetMatrix(values: [0.5, 0, 0, 0,
                                         0, 0.5, 0, 0,
                                         0, 0, 0.5, 0])),
        ]))

        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .saturation)
        let output = try link.convert(RGB64(0.5, 0.25, 0.75))

        XCTAssertEqual(output.r, 0.25, accuracy: 2e-7)
        XCTAssertEqual(output.g, 0.125, accuracy: 2e-7)
        XCTAssertEqual(output.b, 0.375, accuracy: 2e-7)
    }

    func testAbsoluteColorimetricLUTRouteRemainsUnsupported() throws {
        let source = Data(makeProfile(tag: "A2B0", payload: mft2Identity()))
        let target = Data(makeProfile(tag: "B2A0", payload: mft2Identity()))
        XCTAssertThrowsError(try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                                   intent: .absoluteColorimetric)) {
            XCTAssertEqual($0 as? ICCRGBProfileLinkError,
                           .unsupportedRenderingIntent(.absoluteColorimetric))
        }
    }

    func testAbsoluteColorimetricLabMFTRouteScalesMediaWhitePoints() throws {
        let source = Data(makeProfile(tags: [
            ("A2B1", mft2Identity()),
            ("wtpt", xyzPayload(0.8, 1.1, 0.9)),
        ], pcs: "Lab "))
        let target = Data(makeProfile(tags: [
            ("B2A1", mft2Identity()),
            ("wtpt", xyzPayload(1.2, 0.9, 1.5)),
        ], pcs: "Lab "))

        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .absoluteColorimetric)
        let output = try link.convert(RGB64(0.5, 0.5, 0.5))

        XCTAssertEqual(output.r, 0.5456575526, accuracy: 3e-5)
        XCTAssertEqual(output.g, 0.4980657576, accuracy: 3e-5)
        XCTAssertEqual(output.b, 0.5013143781, accuracy: 3e-5)
    }

    func testAbsoluteColorimetricLabMABRouteScalesMediaWhitePoints() throws {
        let source = Data(makeProfile(tags: [
            ("A2B1", mabIdentityPipeline(type: "mAB ")),
            ("wtpt", xyzPayload(0.75, 1.0, 0.5)),
        ], pcs: "Lab "))
        let target = Data(makeProfile(tags: [
            ("B2A1", mabIdentityPipeline(type: "mBA ")),
            ("wtpt", xyzPayload(1.5, 0.5, 1.0)),
        ], pcs: "Lab "))

        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .absoluteColorimetric)
        let output = try link.convert(RGB64(0.5, 0.5, 0.5))

        XCTAssertEqual(output.r, 0.6715478929, accuracy: 3e-5)
        XCTAssertEqual(output.g, 0.4952032656, accuracy: 3e-5)
        XCTAssertEqual(output.b, 0.5024850060, accuracy: 3e-5)
    }

    func testAbsoluteColorimetricLabRequiresMediaWhitePoints() throws {
        let source = Data(makeProfile(tag: "A2B1", payload: mft2Identity(), pcs: "Lab "))
        let target = Data(makeProfile(tag: "B2A1", payload: mft2Identity(), pcs: "Lab "))
        XCTAssertThrowsError(try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                                   intent: .absoluteColorimetric)) {
            XCTAssertEqual($0 as? ICCRGBProfileLinkError,
                           .lab(.missingMediaWhitePoint))
        }
    }

    func testRelativeIntentIgnoresAbsoluteMPETagsWhenRelativeTagsAreAvailable() throws {
        let source = Data(makeProfile(tags: [
            ("D2B3", mpetMatrix(values: [0.5, 0, 0, 0,
                                         0, 0.5, 0, 0,
                                         0, 0, 0.5, 0])),
            ("A2B0", mft2Identity()),
        ]))
        let target = Data(makeProfile(tags: [
            ("B2D3", mpetMatrix(values: [0.5, 0, 0, 0,
                                         0, 0.5, 0, 0,
                                         0, 0, 0.5, 0])),
            ("B2A0", mft2Identity()),
        ]))

        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)
        let output = try link.convert(RGB64(0.25, 0.5, 0.75))

        XCTAssertEqual(output.r, 0.25, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(output.g, 0.5, accuracy: 4.0 / 32768.0)
        XCTAssertEqual(output.b, 0.75, accuracy: 4.0 / 32768.0)
    }

    func testAbsoluteColorimetricRejectsAnIncompleteAbsoluteMPEPair() throws {
        let source = Data(makeProfile(tag: "D2B3", payload: mpetMatrix(values: [
            1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0,
        ])))
        let target = Data(makeProfile(tag: "B2A0", payload: mft2Identity()))

        XCTAssertThrowsError(try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                                   intent: .absoluteColorimetric)) {
            XCTAssertEqual($0 as? ICCRGBProfileLinkError, .incompleteAbsoluteMPEPair)
        }
    }

    func testRelativeColorimetricRejectsAnIncompleteRelativeMPEPair() throws {
        let source = Data(makeProfile(tag: "D2B1", payload: mpetMatrix(values: [
            1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0,
        ])))
        let target = Data(makeProfile(tag: "B2A1", payload: mft2Identity()))

        XCTAssertThrowsError(try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                                   intent: .relativeColorimetric)) {
            XCTAssertEqual($0 as? ICCRGBProfileLinkError, .incompleteRelativeMPEPair)
        }
    }

    func testPerceptualRejectsAnIncompletePerceptualMPEPair() throws {
        let source = Data(makeProfile(tag: "D2B0", payload: mpetMatrix(values: [
            1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0,
        ])))
        let target = Data(makeProfile(tag: "B2A0", payload: mft2Identity()))

        XCTAssertThrowsError(try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                                   intent: .perceptual)) {
            XCTAssertEqual($0 as? ICCRGBProfileLinkError, .incompletePerceptualMPEPair)
        }
    }

    func testSaturationRejectsAnIncompleteSaturationMPEPair() throws {
        let source = Data(makeProfile(tag: "D2B2", payload: mpetMatrix(values: [
            1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0,
        ])))
        let target = Data(makeProfile(tag: "B2A0", payload: mft2Identity()))

        XCTAssertThrowsError(try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                                   intent: .saturation)) {
            XCTAssertEqual($0 as? ICCRGBProfileLinkError, .incompleteSaturationMPEPair)
        }
    }

    func testArbitraryChannelMPEXyzLinkUsesGenericDeviceArrays() throws {
        let source = Data(makeProfile(
            tag: "D2B3",
            payload: mpetMatrix(inputChannels: 3, outputChannels: 3, values: [
                1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
            ])
        ))
        let target = Data(makeProfile(
            tag: "B2D3",
            payload: mpetMatrix(inputChannels: 3, outputChannels: 4, values: [
                1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
                0.25, 0.5, 0.75, 0,
            ]),
            colorSpace: "CMYK"
        ))

        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .absoluteColorimetric)
        XCTAssertEqual(link.sourceDeviceChannels, 3)
        XCTAssertEqual(link.targetDeviceChannels, 4)

        let output = try link.convert([0.2, 0.3, 0.4])
        XCTAssertEqual(output.count, 4)
        XCTAssertEqual(output[0], 0.2, accuracy: 2e-7)
        XCTAssertEqual(output[1], 0.3, accuracy: 2e-7)
        XCTAssertEqual(output[2], 0.4, accuracy: 2e-7)
        XCTAssertEqual(output[3], 0.5, accuracy: 2e-7)
        XCTAssertThrowsError(try link.convert(RGB64(0.2, 0.3, 0.4))) {
            XCTAssertEqual($0 as? ICCRGBProfileLinkError,
                           .rgbRouteRequiresThreeChannels(source: 3, target: 4))
        }
    }

    func testArbitraryChannelMPELabLinkSupportsDifferentSourceAndTargetCounts() throws {
        let source = Data(makeProfile(
            tag: "D2B3",
            payload: mpetMatrix(inputChannels: 4, outputChannels: 3, values: [
                100, 0, 0, 0, 0,
                0, 255, 0, 0, -128,
                0, 0, 255, 0, -128,
            ]),
            colorSpace: "CMYK", pcs: "Lab "
        ))
        let target = Data(makeProfile(
            tag: "B2D3",
            payload: mpetMatrix(inputChannels: 3, outputChannels: 3, values: [
                0.01, 0, 0, 0,
                0, 1.0 / 255.0, 0, 128.0 / 255.0,
                0, 0, 1.0 / 255.0, 128.0 / 255.0,
            ]),
            pcs: "Lab "
        ))

        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .absoluteColorimetric)
        let output = try link.convert([0.5, 0.4, 0.6, 0.25])

        XCTAssertEqual(output.count, 3)
        XCTAssertEqual(output[0], 0.5, accuracy: 2e-7)
        XCTAssertEqual(output[1], 0.4, accuracy: 2e-7)
        XCTAssertEqual(output[2], 0.6, accuracy: 2e-7)
    }

    func testTraditionalMFT2ProfileLinkSupportsCMYKDeviceArrays() throws {
        let source = Data(makeProfile(
            tag: "A2B1",
            payload: mft2Identity(inputChannels: 4, outputChannels: 3),
            colorSpace: "CMYK"
        ))
        let target = Data(makeProfile(
            tag: "B2A1",
            payload: mft2Identity(inputChannels: 3, outputChannels: 4),
            colorSpace: "CMYK"
        ))
        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)
        XCTAssertEqual(link.sourceDeviceChannels, 4)
        XCTAssertEqual(link.targetDeviceChannels, 4)
        let output = try link.convert([0.2, 0.4, 0.6, 0.8])
        for (actual, expected) in zip(output, [0.2, 0.4, 0.6, 0.0]) {
            XCTAssertEqual(actual, expected, accuracy: 2.0 / 65535.0)
        }
        XCTAssertThrowsError(try link.convert(try RGB64(0.2, 0.4, 0.6))) {
            XCTAssertEqual($0 as? ICCRGBProfileLinkError,
                           .rgbRouteRequiresThreeChannels(source: 4, target: 4))
        }
    }

    func testTraditionalAbsoluteMFT2ProfileLinkScalesCMYKPCSXYZ() throws {
        let source = Data(makeProfile(tags: [
            ("A2B3", mft2Identity(inputChannels: 4, outputChannels: 3)),
            ("wtpt", xyzPayload(0.8, 1.0, 0.9))
        ], colorSpace: "CMYK"))
        let target = Data(makeProfile(tags: [
            ("B2A3", mft2Identity(inputChannels: 3, outputChannels: 4)),
            ("wtpt", xyzPayload(1.6, 0.5, 1.8))
        ], colorSpace: "CMYK"))
        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .absoluteColorimetric)
        let output = try link.convert([0.2, 0.4, 0.6, 0.8])
        for (actual, expected) in zip(output, [0.1, 0.8, 0.3, 0.0]) {
            XCTAssertEqual(actual, expected, accuracy: 2.0 / 65535.0)
        }
    }

    func testTraditionalMABProfileLinkSupportsCMYKDeviceArrays() throws {
        let source = Data(makeProfile(
            tag: "A2B1",
            payload: mabIdentityPipeline(type: "mAB ", inputChannels: 4, outputChannels: 3),
            colorSpace: "CMYK"
        ))
        let target = Data(makeProfile(
            tag: "B2A1",
            payload: mabIdentityPipeline(type: "mBA ", inputChannels: 3, outputChannels: 4),
            colorSpace: "CMYK"
        ))
        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)
        let output = try link.convert([0.2, 0.4, 0.6, 0.8])
        for (actual, expected) in zip(output, [0.2, 0.4, 0.6, 0.0]) {
            XCTAssertEqual(actual, expected, accuracy: 2.0 / 65535.0)
        }
    }

    func testTraditionalLabMABProfileLinkSupportsCMYKDeviceArrays() throws {
        let source = Data(makeProfile(
            tag: "A2B1",
            payload: mabIdentityPipeline(type: "mAB ", inputChannels: 4, outputChannels: 3),
            colorSpace: "CMYK", pcs: "Lab "
        ))
        let target = Data(makeProfile(
            tag: "B2A1",
            payload: mabIdentityPipeline(type: "mBA ", inputChannels: 3, outputChannels: 4),
            colorSpace: "CMYK", pcs: "Lab "
        ))
        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)
        let output = try link.convert([0.2, 0.4, 0.6, 0.8])
        for (actual, expected) in zip(output, [0.2, 0.4, 0.6, 0.0]) {
            XCTAssertEqual(actual, expected, accuracy: 2.0 / 65535.0)
        }
    }

    func testTraditionalAbsoluteLabMABProfileLinkScalesCMYKPCS() throws {
        let source = Data(makeProfile(tags: [
            ("A2B3", mabIdentityPipeline(type: "mAB ", inputChannels: 4, outputChannels: 3)),
            ("wtpt", xyzPayload(0.8, 1.0, 0.9))
        ], colorSpace: "CMYK", pcs: "Lab "))
        let target = Data(makeProfile(tags: [
            ("B2A3", mabIdentityPipeline(type: "mBA ", inputChannels: 3, outputChannels: 4)),
            ("wtpt", xyzPayload(1.6, 0.5, 1.8))
        ], colorSpace: "CMYK", pcs: "Lab "))
        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .absoluteColorimetric)
        let output = try link.convert([0.2, 0.4, 0.6, 0.8])
        XCTAssertEqual(output.count, 4)
        // The identity CLUT is identity in encoded Lab, not in RGB. These
        // expected values are the independently evaluated D50 Lab -> XYZ ->
        // media-white scaling -> D50 Lab path.
        XCTAssertEqual(output[0], 0.2935715779621544, accuracy: 2e-12)
        XCTAssertEqual(output[1], 0.4477083911771103, accuracy: 2e-12)
        XCTAssertEqual(output[2], 0.5522887827367406, accuracy: 2e-12)
    }

    func testTraditionalRGBRouteRejectsGenericDeviceArrays() throws {
        let source = Data(makeProfile(tag: "A2B0", payload: mft2Identity()))
        let target = Data(makeProfile(tag: "B2A0", payload: mft2Identity()))
        let link = try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                         intent: .relativeColorimetric)

        XCTAssertThrowsError(try link.convert([0.2, 0.3, 0.4])) {
            XCTAssertEqual($0 as? ICCRGBProfileLinkError, .unsupportedDeviceArrayRoute)
        }
    }

    func testNonMPETCMYKProfilesRemainOutsideTraditionalRGBBoundary() throws {
        let source = Data(makeProfile(tag: "A2B0", payload: mft2Identity(), colorSpace: "CMYK"))
        let target = Data(makeProfile(tag: "B2A0", payload: mft2Identity()))
        XCTAssertThrowsError(try ICCRGBProfileLink(sourceProfile: source, targetProfile: target,
                                                   intent: .relativeColorimetric)) {
            XCTAssertEqual($0 as? ICCRGBProfileLinkError, .unsupportedColorSpace)
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

    private func mft2Identity(inputChannels: Int = 3, outputChannels: Int = 3) -> [UInt8] {
        let nodeCount = Int(pow(2.0, Double(inputChannels)))
        var bytes = [UInt8](repeating: 0, count: 52 + inputChannels * 2 * 2 +
                            nodeCount * outputChannels * 2 + outputChannels * 2 * 2)
        bytes.replaceSubrange(0..<4, with: Array("mft2".utf8))
        bytes[8] = UInt8(inputChannels); bytes[9] = UInt8(outputChannels); bytes[10] = 2
        writeMatrix(&bytes, values: [1, 0, 0, 0, 1, 0, 0, 0, 1])
        bytes.replaceSubrange(48..<50, with: be(UInt16(2)))
        bytes.replaceSubrange(50..<52, with: be(UInt16(2)))
        writeIdentityTables(&bytes, start: 52, channels: inputChannels, entries: 2)
        var cursor = 52 + inputChannels * 2 * 2
        for node in 0..<nodeCount {
            var remainder = node
            var coordinates = [Int](repeating: 0, count: inputChannels)
            for axis in stride(from: inputChannels - 1, through: 0, by: -1) {
                coordinates[axis] = remainder % 2
                remainder /= 2
            }
            for channel in 0..<outputChannels {
                let value = channel < inputChannels ? coordinates[channel] : 0
                bytes.replaceSubrange(cursor..<cursor + 2, with: be(UInt16(value * 65535)))
                cursor += 2
            }
        }
        writeIdentityTables(&bytes, start: cursor, channels: outputChannels, entries: 2)
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

    private func makeProfile(tag: String, payload: [UInt8], colorSpace: String = "RGB ",
                             pcs: String = "XYZ ", profileClass: String? = nil) -> [UInt8] {
        let tableEnd = 144
        var bytes = [UInt8](repeating: 0, count: tableEnd)
        bytes[16...19] = ArraySlice(colorSpace.utf8); bytes[20...23] = ArraySlice(pcs.utf8)
        if let profileClass { bytes[12...15] = ArraySlice(profileClass.utf8) }
        bytes[36...39] = ArraySlice("acsp".utf8)
        bytes.replaceSubrange(128..<132, with: be(UInt32(1)))
        bytes.replaceSubrange(132..<136, with: Array(tag.utf8))
        bytes.replaceSubrange(136..<140, with: be(UInt32(tableEnd)))
        bytes.replaceSubrange(140..<144, with: be(UInt32(payload.count)))
        bytes += payload
        bytes.replaceSubrange(0..<4, with: be(UInt32(bytes.count)))
        return bytes
    }

    private func makeProfile(tags: [(String, [UInt8])], colorSpace: String = "RGB ",
                             pcs: String = "XYZ ", profileClass: String? = nil) -> [UInt8] {
        let tableEnd = 132 + tags.count * 12
        var bytes = [UInt8](repeating: 0, count: tableEnd)
        bytes[16...19] = ArraySlice(colorSpace.utf8); bytes[20...23] = ArraySlice(pcs.utf8)
        if let profileClass { bytes[12...15] = ArraySlice(profileClass.utf8) }
        bytes[36...39] = ArraySlice("acsp".utf8)
        bytes.replaceSubrange(128..<132, with: be(UInt32(tags.count)))
        var cursor = tableEnd
        for (index, item) in tags.enumerated() {
            let start = 132 + index * 12
            bytes.replaceSubrange(start..<start + 4, with: Array(item.0.utf8))
            bytes.replaceSubrange(start + 4..<start + 8, with: be(UInt32(cursor)))
            bytes.replaceSubrange(start + 8..<start + 12, with: be(UInt32(item.1.count)))
            bytes += item.1
            let paddedCount = (item.1.count + 3) / 4 * 4
            bytes += [UInt8](repeating: 0, count: paddedCount - item.1.count)
            cursor += paddedCount
        }
        bytes.replaceSubrange(0..<4, with: be(UInt32(bytes.count)))
        return bytes
    }

    private func syntheticMatrixTRCTags(gamma: Double?) -> [(String, [UInt8])] {
        let curve = gamma.map { value in
            Array("curv".utf8) + [UInt8](repeating: 0, count: 4) + be(UInt32(1)) +
                be(UInt16((value * 256).rounded()))
        } ?? (Array("curv".utf8) + [UInt8](repeating: 0, count: 8))
        return [
            ("rXYZ", xyzPayload(1, 0, 0)),
            ("gXYZ", xyzPayload(0, 1, 0)),
            ("bXYZ", xyzPayload(0, 0, 1)),
            ("wtpt", xyzPayload(1, 1, 1)),
            ("rTRC", curve), ("gTRC", curve), ("bTRC", curve),
        ]
    }

    private func xyzPayload(_ x: Double, _ y: Double, _ z: Double) -> [UInt8] {
        Array("XYZ ".utf8) + [UInt8](repeating: 0, count: 4) +
            [x, y, z].flatMap { be(Int32(($0 * 65536).rounded())) }
    }

    private func mpetMatrix(inputChannels: Int = 3, outputChannels: Int = 3,
                            values: [Float]) -> [UInt8] {
        precondition(values.count == outputChannels * (inputChannels + 1))
        var payload = Array("mpet".utf8) + [UInt8](repeating: 0, count: 4)
        let size = 12 + values.count * 4
        payload += be(UInt16(inputChannels)) + be(UInt16(outputChannels)) + be(UInt32(1))
        payload += be(UInt32(24)) + be(UInt32(size))
        payload += Array("matf".utf8) + [UInt8](repeating: 0, count: 4)
        payload += be(UInt16(inputChannels)) + be(UInt16(outputChannels))
        payload += values.flatMap(be)
        return payload
    }

    private func writeIdentityTables(_ bytes: inout [UInt8], start: Int,
                                     channels: Int = 3, entries: Int) {
        for channel in 0..<channels { for index in 0..<entries {
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

    private func mabIdentityPipeline(type: String, inputChannels: Int = 3,
                                     outputChannels: Int = 3) -> [UInt8] {
        var payload = [UInt8](repeating: 0, count: 32)
        payload.replaceSubrange(0..<4, with: Array(type.utf8))
        payload[8] = UInt8(inputChannels)
        payload[9] = UInt8(outputChannels)
        let inputCurves = Array(repeating: curveIdentity(), count: inputChannels).flatMap { $0 }
        let outputCurves = Array(repeating: curveIdentity(), count: outputChannels).flatMap { $0 }
        let clut = clutIdentity(inputChannels: inputChannels, outputChannels: outputChannels)
        let sections: [(String, [UInt8])] = type == "mAB "
            ? [("A", inputCurves), ("C", clut), ("M", []), ("X", []), ("B", outputCurves)]
            : [("B", inputCurves), ("X", []), ("M", []), ("C", clut), ("A", outputCurves)]
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

    private func clutIdentity(inputChannels: Int = 3, outputChannels: Int = 3) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 20)
        for axis in 0..<inputChannels { bytes[axis] = 2 }
        bytes[16] = 2
        let nodeCount = Int(pow(2.0, Double(inputChannels)))
        for node in 0..<nodeCount {
            var remainder = node
            var coordinates = [Int](repeating: 0, count: inputChannels)
            for axis in stride(from: inputChannels - 1, through: 0, by: -1) {
                coordinates[axis] = remainder % 2
                remainder /= 2
            }
            for channel in 0..<outputChannels {
                let value = channel < inputChannels ? coordinates[channel] : 0
                bytes += be(UInt16(value * 65535))
            }
        }
        return bytes
    }

    private func be(_ value: UInt16) -> [UInt8] { [UInt8(value >> 8), UInt8(value & 0xff)] }
    private func be(_ value: UInt32) -> [UInt8] {
        [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff),
         UInt8((value >> 8) & 0xff), UInt8(value & 0xff)]
    }
    private func be(_ value: Float) -> [UInt8] { be(value.bitPattern) }
    private func be(_ value: Int32) -> [UInt8] { be(UInt32(bitPattern: value)) }
}
