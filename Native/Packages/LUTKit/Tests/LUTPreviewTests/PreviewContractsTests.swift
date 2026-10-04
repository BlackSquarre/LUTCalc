import Foundation
import XCTest
import LUTCore
@testable import LUTPreview

final class PreviewContractsTests: XCTestCase {
    func testDisplayPreviewUsesIndependentLinearSRGBEncodingAndFinalClamp() throws {
        let settings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let plan = try TransformPlan(settings: settings)
        let identity = PreviewIdentity(documentID: UUID(), revision: 1,
                                       requestID: UUID(), planVersion: plan.planVersion)
        let request = try PreviewRequest(
            plan: plan, width: 2, height: 1,
            pixels: [
                RGBA64(rgb: RGB64(0.5, 0.25, 0), alpha: 1),
                RGBA64(rgb: RGB64(-0.5, 1.5, 0.5), alpha: 0.5)
            ], inputAlpha: .straight, outputAlpha: .straight, identity: identity
        )

        let result = try CPUPreview.renderDisplay(request)
        XCTAssertEqual(result.identity, identity)
        XCTAssertEqual(result.width, 2)
        XCTAssertEqual(result.height, 1)
        let first = try result.sample(x: 0, y: 0)
        XCTAssertEqual(first.encodedRGB.r, 0.7353569830524495, accuracy: 1e-12)
        XCTAssertEqual(first.encodedRGB.g, 0.5370987304831942, accuracy: 1e-12)
        XCTAssertEqual(first.encodedRGB.b, 0, accuracy: 1e-12)
        let second = try result.sample(x: 1, y: 0)
        XCTAssertEqual(second.encodedRGB.r, 0, accuracy: 1e-12)
        XCTAssertEqual(second.encodedRGB.g, 1, accuracy: 1e-12)
        XCTAssertEqual(second.encodedRGB.b, 0.7353569830524495, accuracy: 1e-12)
        XCTAssertEqual(second.alpha, 0.5, accuracy: 1e-12)
    }

    func testDisplayPreviewRejectsHLGWithoutHDRDisplayParameters() throws {
        let settings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .rec2100HLG,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let plan = try TransformPlan(settings: settings)
        let identity = PreviewIdentity(documentID: UUID(), revision: 1,
                                       requestID: UUID(), planVersion: plan.planVersion)
        let request = try PreviewRequest(
            plan: plan, width: 1, height: 1,
            pixels: [RGBA64(rgb: RGB64(0.5, 0.5, 0.5), alpha: 1)],
            inputAlpha: .straight, outputAlpha: .straight, identity: identity
        )
        XCTAssertThrowsError(try CPUPreview.renderDisplay(request)) {
            XCTAssertEqual($0 as? PreviewError, .unsupportedDisplayTransfer(.rec2100HLG))
        }
    }

    func testDisplayPreviewRejectsPQWithoutHDRDisplayParameters() throws {
        let settings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .rec2100PQ,
            inputSpace: .rec2020, outputSpace: .rec2020,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let plan = try TransformPlan(settings: settings)
        let identity = PreviewIdentity(documentID: UUID(), revision: 1,
                                       requestID: UUID(), planVersion: plan.planVersion)
        let request = try PreviewRequest(
            plan: plan, width: 1, height: 1,
            pixels: [RGBA64(rgb: RGB64(0.5, 0.5, 0.5), alpha: 1)],
            inputAlpha: .straight, outputAlpha: .straight, identity: identity
        )
        XCTAssertThrowsError(try CPUPreview.renderDisplay(request)) {
            XCTAssertEqual($0 as? PreviewError, .unsupportedDisplayTransfer(.rec2100PQ))
        }
    }

    func testDisplayPreviewBitmapQuantizesOnlyAtExplicitDisplayBoundary() throws {
        let settings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let plan = try TransformPlan(settings: settings)
        let identity = PreviewIdentity(documentID: UUID(), revision: 1,
                                       requestID: UUID(), planVersion: plan.planVersion)
        let request = try PreviewRequest(
            plan: plan, width: 1, height: 1,
            pixels: [RGBA64(rgb: RGB64(0.5, 0.25, 0), alpha: 0.5)],
            inputAlpha: .straight, outputAlpha: .straight, identity: identity
        )
        let display = try CPUPreview.renderDisplay(request)
        let bitmap = try display.makeBitmap()
        XCTAssertEqual(bitmap.width, 1)
        XCTAssertEqual(bitmap.height, 1)
        XCTAssertEqual(bitmap.alphaMode, .straight)
        XCTAssertEqual(bitmap.rgba8, [188, 137, 0, 128])
        XCTAssertNotNil(bitmap.cgImage())
        XCTAssertEqual((try display.sample(x: 0, y: 0)).encodedRGB.r,
                       0.7353569830524495, accuracy: 1e-12)
    }

    func testDisplayPreviewBitmapPreservesPremultipliedAlphaContract() throws {
        let settings = TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let plan = try TransformPlan(settings: settings)
        let identity = PreviewIdentity(documentID: UUID(), revision: 1,
                                       requestID: UUID(), planVersion: plan.planVersion)
        let request = try PreviewRequest(
            plan: plan, width: 1, height: 1,
            pixels: [RGBA64(rgb: RGB64(0.5, 0.25, 0), alpha: 0.5)],
            inputAlpha: .straight, outputAlpha: .premultiplied, identity: identity
        )
        let bitmap = try CPUPreview.renderDisplay(request).makeBitmap()
        XCTAssertEqual(bitmap.alphaMode, .premultiplied)
        XCTAssertEqual(bitmap.rgba8, [94, 68, 0, 128])
        XCTAssertNotNil(bitmap.cgImage())
    }

    func testDisplayPreviewBitmapClampsPremultipliedChannelsToQuantizedAlpha() throws {
        let identity = PreviewIdentity(documentID: UUID(), revision: 1,
                                       requestID: UUID(), planVersion: "display-v1")
        let sample = try DisplayPreviewSample(encodedRGB: RGB64(1, 0.5, 0), alpha: 0.1)
        let result = DisplayPreviewResult(identity: identity,
                                          sourceTransfer: .linearScene,
                                          sourceSpace: .srgb,
                                          targetTransfer: .srgbW3CExtended,
                                          targetSpace: .srgb,
                                          outputAlpha: .premultiplied,
                                          width: 1, height: 1, pixels: [sample])

        let bitmap = try result.makeBitmap()
        XCTAssertEqual(bitmap.rgba8, [26, 26, 0, 26])
    }

    func testICCProfileHeaderAndDigestContract() throws {
        var bytes = [UInt8](repeating: 0, count: 132)
        bytes[0...3] = [0, 0, 0, 132]
        bytes[16...19] = ArraySlice("RGB ".utf8)
        bytes[20...23] = ArraySlice("XYZ ".utf8)
        bytes[36...39] = ArraySlice("acsp".utf8)
        let profile = try ICCProfileValidator.validate(Data(bytes))
        XCTAssertEqual(profile.byteCount, 132)
        XCTAssertEqual(profile.declaredByteCount, 132)
        XCTAssertEqual(profile.profileSignature, "acsp")
        XCTAssertNil(profile.profileClassSignature)
        XCTAssertNil(profile.profileClass)
        XCTAssertEqual(profile.colorChannelCount, 3)
        XCTAssertEqual(profile.pcsKind, .xyz)
        XCTAssertEqual(profile.tagCount, 0)
        XCTAssertEqual(profile.tagSignatures, [])
        XCTAssertEqual(profile.renderingIntent, 0)
        XCTAssertEqual(profile.sha256.count, 64)
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(bytes.dropLast())))
        bytes[36...39] = ArraySlice("nope".utf8)
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(bytes)))
    }

    func testICCProfileClassAndChannelMetadataAreDecodedWithoutChangingPayloadSemantics() throws {
        var bytes = [UInt8](repeating: 0, count: 132)
        bytes[0...3] = [0, 0, 0, 132]
        bytes[12...15] = ArraySlice("mntr".utf8)
        bytes[16...19] = ArraySlice("CMYK".utf8)
        bytes[20...23] = ArraySlice("Lab ".utf8)
        bytes[36...39] = ArraySlice("acsp".utf8)
        let profile = try ICCProfileValidator.validate(Data(bytes))
        XCTAssertEqual(profile.profileClassSignature, "mntr")
        XCTAssertEqual(profile.profileClass, .displayDevice)
        XCTAssertEqual(profile.colorChannelCount, 4)
        XCTAssertEqual(profile.pcsSignature, "Lab ")
        XCTAssertEqual(profile.pcsKind, .lab)
    }

    func testICCProfileUnknownFutureClassKeepsRawSignatureWithoutGuessing() throws {
        var bytes = [UInt8](repeating: 0, count: 132)
        bytes[0...3] = [0, 0, 0, 132]
        bytes[12...15] = ArraySlice("futr".utf8)
        bytes[16...19] = ArraySlice("RGB ".utf8)
        bytes[20...23] = ArraySlice("XYZ ".utf8)
        bytes[36...39] = ArraySlice("acsp".utf8)
        let profile = try ICCProfileValidator.validate(Data(bytes))
        XCTAssertEqual(profile.profileClassSignature, "futr")
        XCTAssertNil(profile.profileClass)
        XCTAssertEqual(profile.pcsKind, .xyz)
    }

    func testICCProfileRejectsNonSignatureProfileClassWhenHeaderIsPopulated() throws {
        var bytes = [UInt8](repeating: 0, count: 132)
        bytes[0...3] = [0, 0, 0, 132]
        bytes[12...15] = [0x00, 0x01, 0x02, 0x03]
        bytes[16...19] = ArraySlice("RGB ".utf8)
        bytes[20...23] = ArraySlice("XYZ ".utf8)
        bytes[36...39] = ArraySlice("acsp".utf8)
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(bytes))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidProfileClass)
        }
    }

    func testICCProfileRenderingIntentUsesHeaderEnumAndRejectsUnknownValue() throws {
        for value in 0...3 {
            var bytes = [UInt8](repeating: 0, count: 132)
            bytes[0...3] = [0, 0, 0, 132]
            bytes[16...19] = ArraySlice("RGB ".utf8)
            bytes[20...23] = ArraySlice("XYZ ".utf8)
            bytes[36...39] = ArraySlice("acsp".utf8)
            bytes[64...67] = [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff),
                                  UInt8((value >> 8) & 0xff), UInt8(value & 0xff)]
            XCTAssertEqual(try ICCProfileValidator.validate(Data(bytes)).renderingIntent, value)
        }

        var invalid = [UInt8](repeating: 0, count: 132)
        invalid[0...3] = [0, 0, 0, 132]
        invalid[16...19] = ArraySlice("RGB ".utf8)
        invalid[20...23] = ArraySlice("XYZ ".utf8)
        invalid[36...39] = ArraySlice("acsp".utf8)
        invalid[67] = 4
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(invalid))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidRenderingIntent)
        }
    }

    func testICCProfileTagDirectoryBoundsContract() throws {
        var bytes = makeProfile(tags: [("desc", descPayload("sRGB"))])
        let profile = try ICCProfileValidator.validate(Data(bytes))
        XCTAssertEqual(profile.tagCount, 1)
        XCTAssertEqual(profile.tagSignatures, ["desc"])
        XCTAssertEqual(profile.tags[0].textValue, "sRGB")
        let offsetField = 132 + 4
        bytes[offsetField..<offsetField + 4] = [0, 0, 0, 147]
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(bytes)))
    }

    func testICCProfileCommonTextPayloadsAreDecoded() throws {
        let a = textPayload("Copyright")
        let b = descPayload("sRGB IEC61966-2.1")
        let c = mlucPayload("Display manufacturer")
        let data = Data(makeProfile(tags: [("cprt", a), ("desc", b), ("dmnd", c)]))
        let profile = try ICCProfileValidator.validate(data)
        XCTAssertEqual(profile.tags.map { $0.signature }, ["cprt", "desc", "dmnd"])
        XCTAssertEqual(profile.tags.map { $0.typeSignature }, ["text", "desc", "mluc"])
        XCTAssertEqual(profile.tags.map { $0.textValue }, ["Copyright", "sRGB IEC61966-2.1", "Display manufacturer"])
    }

    func testICCProfileMalformedKnownTextPayloadIsRejected() throws {
        var payload = [UInt8]("desc".utf8) + [UInt8](repeating: 0, count: 4)
        payload += [0, 0, 0, 20] + Array("short".utf8) + [0]
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(tags: [("desc", Data(payload))])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
    }

    func testICCProfileTagPayloadHeaderAndUTF16BoundsAreEnforced() throws {
        let shortPayload = Data([UInt8]("sig ".utf8) + [0, 0, 0])
        XCTAssertThrowsError(try ICCProfileValidator.validate(
            Data(makeProfile(tags: [("abcd", shortPayload)])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }

        var malformed = [UInt8]("mluc".utf8) + [UInt8](repeating: 0, count: 4)
        malformed += bigEndian(UInt32(1)) + bigEndian(UInt32(12)) + Array("enUS".utf8)
        malformed += bigEndian(UInt32(3)) + bigEndian(UInt32(28)) + [0x00, 0x41, 0x00]
        XCTAssertThrowsError(try ICCProfileValidator.validate(
            Data(makeProfile(tags: [("dmnd", Data(malformed))])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
    }

    func testICCProfileFixedPointMetadataIsSummarizedWithoutConversion() throws {
        let data = Data(makeProfile(tags: [
            ("wtpt", xyzPayload(0.9642, 1.0, 0.8249)),
            ("tech", signaturePayload("sig "))
        ]))
        let profile = try ICCProfileValidator.validate(data)
        XCTAssertEqual(profile.tags[0].typeSignature, "XYZ ")
        XCTAssertEqual(profile.tags[0].fixedPointValues?.count, 3)
        XCTAssertEqual(profile.tags[0].fixedPointValues?[0] ?? .nan, 0.964202880859375, accuracy: 1e-12)
        XCTAssertEqual(profile.tags[0].fixedPointValues?[1] ?? .nan, 1.0, accuracy: 1e-12)
        XCTAssertEqual(profile.tags[0].fixedPointValues?[2] ?? .nan, 0.8249053955078125, accuracy: 1e-12)
        XCTAssertNil(profile.tags[0].textValue)
        XCTAssertEqual(profile.tags[1].signatureValue, "sig ")
        XCTAssertNil(profile.tags[1].fixedPointValues)
    }

    func testICCProfileMalformedFixedPointPayloadIsRejected() throws {
        var xyz = [UInt8]("XYZ ".utf8) + [UInt8](repeating: 0, count: 4)
        xyz += [0, 1, 0, 0]
        XCTAssertThrowsError(try ICCProfileValidator.validate(
            Data(makeProfile(tags: [("wtpt", Data(xyz))])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
    }

    func testICCProfileMLUCStringCannotOverlapRecordTable() throws {
        var payload = [UInt8]("mluc".utf8) + [UInt8](repeating: 0, count: 4)
        payload += bigEndian(UInt32(1)) + bigEndian(UInt32(12)) + Array("enUS".utf8)
        payload += bigEndian(UInt32(2)) + bigEndian(UInt32(16)) + [0x00, 0x41]
        XCTAssertThrowsError(try ICCProfileValidator.validate(
            Data(makeProfile(tags: [("dmnd", Data(payload))])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
    }

    func testICCProfileFixedStructureTagsAreSummarizedWithoutSamplingOrConversion() throws {
        let tagItems: [(String, Data)] = [
            ("rTRC", curvePayload([0x0100, 0x0200, 0x0300])),
            ("chrm", chromaticityPayload(channels: 3, colorant: 1,
                                           values: [0.64, 0.33, 0.30, 0.60, 0.15, 0.06])),
            ("para", parametricPayload(functionType: 3,
                                         values: [2.4, 0.055, 0.04045, 0.0, 0.0, 0.0])),
            ("view", viewingPayload(values: [0.9642, 1.0, 0.8249, 0.2, 0.2, 0.2], illuminant: 1)),
            ("meas", measurementPayload(observer: 1, geometry: 1, illuminant: 2,
                                          backing: [0.1, 0.2, 0.3], flare: 0.05))
        ]
        for (index, item) in tagItems.enumerated() {
            do { _ = try ICCProfileValidator.validate(Data(makeProfile(tags: [item]))) }
            catch { XCTFail("fixed tag \(index) \(item.0): \(error)") }
        }
        let data = Data(makeProfile(tags: tagItems))
        let profile = try ICCProfileValidator.validate(data)

        XCTAssertEqual(profile.tags[0].structureValue, 3)
        XCTAssertNil(profile.tags[0].fixedPointValues)

        XCTAssertEqual(profile.tags[1].integerValues, [3, 1])
        XCTAssertEqual(profile.tags[1].fixedPointValues?.count, 6)
        XCTAssertEqual(profile.tags[1].fixedPointValues?[0] ?? .nan, 0.64000, accuracy: 1.0 / 65536.0)

        XCTAssertEqual(profile.tags[2].parametricFunctionType, 3)
        XCTAssertEqual(profile.tags[2].fixedPointValues?.count, 6)
        XCTAssertEqual(profile.tags[2].fixedPointValues?[0] ?? .nan, 2.4, accuracy: 1.0 / 65536.0)

        XCTAssertEqual(profile.tags[3].fixedPointValues?.count, 6)
        XCTAssertEqual(profile.tags[3].integerValues, [1])

        XCTAssertEqual(profile.tags[4].fixedPointValues?.count, 4)
        XCTAssertEqual(profile.tags[4].integerValues, [1, 1, 2])
        XCTAssertEqual(profile.tags[4].fixedPointValues?[3] ?? .nan, 0.05, accuracy: 1.0 / 65536.0)
    }

    func testICCProfileFixedStructureTagBoundsAreRejected() throws {
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(tags: [
            ("rTRC", curvePayload([0x0100, 0x0200, 0x0300]).dropLast())
        ])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(tags: [
            ("chrm", chromaticityPayload(channels: 3, colorant: 1, values: [0.64]))
        ])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(tags: [
            ("para", parametricPayload(functionType: 4, values: [1, 2, 3, 4, 5]))
        ])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(tags: [
            ("view", Data([UInt8]("view".utf8) + [UInt8](repeating: 0, count: 20)))
        ])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(tags: [
            ("meas", Data([UInt8]("meas".utf8) + [UInt8](repeating: 0, count: 20)))
        ])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
    }

    func testICCProfileScalarMetadataTagsAreSummarizedWithoutPayloadStorage() throws {
        let data = Data(makeProfile(tags: [
            ("cicp", cicpPayload([9, 16, 9, 0])),
            ("date", dateTimePayload(year: 2026, month: 9, day: 25, hour: 17, minute: 3, second: 4)),
            ("desc", dataPayload("metadata"))
        ]))
        let profile = try ICCProfileValidator.validate(data)
        XCTAssertEqual(profile.tags[0].integerValues, [9, 16, 9, 0])
        XCTAssertEqual(profile.tags[1].integerValues, [2026, 9, 25, 17, 3, 4])
        XCTAssertEqual(profile.tags[2].integerValues, [0])
        XCTAssertEqual(profile.tags[2].structureValue, 9)
        XCTAssertNil(profile.tags[2].textValue)
    }

    func testICCProfileScalarMetadataTagBoundsAndFlagsAreRejected() throws {
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(tags: [
            ("cicp", Data([UInt8]("cicp".utf8) + [UInt8](repeating: 0, count: 7)))
        ])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(tags: [
            ("date", dateTimePayload(year: 2026, month: 2, day: 30, hour: 0, minute: 0, second: 0))
        ])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(tags: [
            ("meta", dataPayload("ascii", flag: 2))
        ])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(tags: [
            ("meta", dataPayload("unterminated", flag: 0, terminated: false))
        ])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
    }

    func testICCProfileColorantOrderMetadataIsSummarizedWithoutPayloadStorage() throws {
        let profile = try ICCProfileValidator.validate(Data(makeProfile(tags: [
            ("clro", colorantOrderPayload([2, 0, 1]))
        ])))
        let tag = try XCTUnwrap(profile.tags.first)
        XCTAssertEqual(tag.structureValue, 3)
        XCTAssertEqual(tag.integerValues, [2, 0, 1])
        XCTAssertNil(tag.textValue)
        XCTAssertNil(tag.fixedPointValues)
        XCTAssertNil(tag.signatureValue)
    }

    func testICCProfileColorantOrderBoundsAndPermutationAreRejected() throws {
        let payloads = [
            Data(colorantOrderPayload([2, 0, 1]).dropLast()),
            colorantOrderPayload([2, 0, 1]) + [0],
            colorantOrderPayload([0, 0, 1]),
            colorantOrderPayload([0, 1, 3]),
            colorantOrderPayload([])
        ]
        for payload in payloads {
            XCTAssertThrowsError(try ICCProfileValidator.validate(
                Data(makeProfile(tags: [("clro", Data(payload))])))) {
                XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
            }
        }
    }

    func testICCProfileColorantOrderCountMatchesHeaderColorChannels() throws {
        let five = colorantOrderPayload([4, 3, 2, 1, 0])
        let valid = try ICCProfileValidator.validate(Data(makeProfile(
            tags: [("clro", five)], colorSpace: "5CLR")))
        XCTAssertEqual(valid.tags[0].structureValue, 5)
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(
            tags: [("clro", five)], colorSpace: "RGB ")))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(
            tags: [("clro", colorantOrderPayload([2, 0, 1]))], colorSpace: "CMYK")))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
    }

    func testICCProfileLUTTagsExposeOnlyStructuralMetadata() throws {
        let lut8 = try ICCProfileValidator.validate(Data(makeProfile(
            tags: [("A2B0", lut8Payload(input: 3, output: 3, grid: 2))])))
        let lut8Tag = try XCTUnwrap(lut8.tags.first)
        XCTAssertEqual(lut8Tag.lutMetadata, ICCLUTTagMetadata(
            kind: .lut8, inputChannels: 3, outputChannels: 3, gridPoints: 2,
            inputTableEntries: 256, outputTableEntries: 256, clutByteCount: 24))
        XCTAssertNil(lut8Tag.curveValues)

        let lut16 = try ICCProfileValidator.validate(Data(makeProfile(
            tags: [("B2A0", lut16Payload(input: 3, output: 3, grid: 2, entries: 2))])))
        let lut16Tag = try XCTUnwrap(lut16.tags.first)
        XCTAssertEqual(lut16Tag.lutMetadata?.kind, .lut16)
        XCTAssertEqual(lut16Tag.lutMetadata?.inputTableEntries, 2)
        XCTAssertEqual(lut16Tag.lutMetadata?.outputTableEntries, 2)
        XCTAssertEqual(lut16Tag.lutMetadata?.clutByteCount, 48)

        let matrixLUT = try ICCProfileValidator.validate(Data(makeProfile(
            tags: [("A2B0", mABPayload())])))
        let matrixTag = try XCTUnwrap(matrixLUT.tags.first)
        XCTAssertEqual(matrixTag.lutMetadata?.kind, .lutAToB)
        XCTAssertEqual(matrixTag.lutMetadata?.inputChannels, 3)
        XCTAssertNil(matrixTag.lutMetadata?.gridPoints)
    }

    func testICCProfileLUTTagDimensionsAndOffsetsAreStrictlyValidated() throws {
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(
            tags: [("A2B0", lut8Payload(input: 0, output: 3, grid: 2))])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
        var malformed = mABPayload()
        malformed.replaceSubrange(12..<16, with: bigEndian(UInt32(9999)))
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(
            tags: [("A2B0", malformed)])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
        var duplicateOffsets = mABPayload()
        duplicateOffsets.replaceSubrange(12..<16, with: bigEndian(UInt32(32)))
        duplicateOffsets.replaceSubrange(16..<20, with: bigEndian(UInt32(32)))
        XCTAssertThrowsError(try ICCProfileValidator.validate(Data(makeProfile(
            tags: [("A2B0", duplicateOffsets)])))) {
            XCTAssertEqual($0 as? ICCProfileError, .invalidTagPayload)
        }
    }

    private func makeProfile(tags: [(String, Data)], colorSpace: String = "RGB ") -> [UInt8] {
        let tableEnd = 132 + tags.count * 12
        var bytes = [UInt8](repeating: 0, count: tableEnd)
        bytes[16...19] = ArraySlice(colorSpace.utf8)
        bytes[20...23] = ArraySlice("XYZ ".utf8)
        bytes[36...39] = ArraySlice("acsp".utf8)
        bytes.replaceSubrange(128..<132, with: bigEndian(UInt32(tags.count)))
        var offset = tableEnd
        for (index, item) in tags.enumerated() {
            let start = 132 + index * 12
            bytes.replaceSubrange(start..<start + 4, with: item.0.utf8)
            bytes.replaceSubrange(start + 4..<start + 8, with: bigEndian(UInt32(offset)))
            bytes.replaceSubrange(start + 8..<start + 12, with: bigEndian(UInt32(item.1.count)))
            bytes += item.1
            offset += item.1.count
        }
        bytes.replaceSubrange(0..<4, with: bigEndian(UInt32(bytes.count)))
        return bytes
    }

    private func lut8Payload(input: Int, output: Int, grid: Int) -> Data {
        let clutCount = Int(pow(Double(grid), Double(input))) * output
        var bytes = [UInt8](repeating: 0, count: 48 + input * 256 + clutCount + output * 256)
        bytes.replaceSubrange(0..<4, with: Array("mft1".utf8))
        bytes[8] = UInt8(input); bytes[9] = UInt8(output); bytes[10] = UInt8(grid)
        bytes[11] = 0
        return Data(bytes)
    }

    private func lut16Payload(input: Int, output: Int, grid: Int, entries: Int) -> Data {
        let clutCount = Int(pow(Double(grid), Double(input))) * output
        var bytes = [UInt8](repeating: 0, count: 52 + input * entries * 2 + clutCount * 2 + output * entries * 2)
        bytes.replaceSubrange(0..<4, with: Array("mft2".utf8))
        bytes[8] = UInt8(input); bytes[9] = UInt8(output); bytes[10] = UInt8(grid)
        bytes.replaceSubrange(48..<50, with: bigEndian(UInt16(entries)))
        bytes.replaceSubrange(50..<52, with: bigEndian(UInt16(entries)))
        return Data(bytes)
    }

    private func mABPayload() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        bytes.replaceSubrange(0..<4, with: Array("mAB ".utf8))
        bytes[8] = 3; bytes[9] = 3
        return Data(bytes)
    }

    private func bigEndian(_ value: UInt32) -> [UInt8] {
        [UInt8(truncatingIfNeeded: value >> 24), UInt8(truncatingIfNeeded: value >> 16),
               UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)]
    }

    private func bigEndian(_ value: UInt16) -> [UInt8] {
        [UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)]
    }

    private func textPayload(_ text: String) -> Data {
        Data([UInt8]("text".utf8) + [UInt8](repeating: 0, count: 4) + Array(text.utf8) + [0])
    }

    private func descPayload(_ text: String) -> Data {
        let value = Array(text.utf8) + [0]
        return Data([UInt8]("desc".utf8) + [UInt8](repeating: 0, count: 4) +
                    bigEndian(UInt32(value.count)) + value)
    }

    private func mlucPayload(_ text: String) -> Data {
        let utf16 = Array(text.utf16).flatMap { [UInt8($0 >> 8), UInt8($0)] }
        return Data([UInt8]("mluc".utf8) + [UInt8](repeating: 0, count: 4) +
                    bigEndian(UInt32(1)) + bigEndian(UInt32(12)) + Array("enUS".utf8) +
                    bigEndian(UInt32(utf16.count)) + bigEndian(UInt32(28)) + utf16)
    }

    private func xyzPayload(_ x: Double, _ y: Double, _ z: Double) -> Data {
        let values = [x, y, z].flatMap { fixed16($0) }
        return Data([UInt8]("XYZ ".utf8) + [UInt8](repeating: 0, count: 4) + values)
    }

    private func signaturePayload(_ value: String) -> Data {
        Data([UInt8]("sig ".utf8) + [UInt8](repeating: 0, count: 4) + Array(value.utf8))
    }

    private func cicpPayload(_ values: [UInt8]) -> Data {
        Data([UInt8]("cicp".utf8) + [UInt8](repeating: 0, count: 4) + values)
    }

    private func colorantOrderPayload(_ order: [UInt8]) -> Data {
        Data([UInt8]("clro".utf8) + [UInt8](repeating: 0, count: 4) +
             bigEndian(UInt32(order.count)) + order)
    }

    private func dateTimePayload(year: UInt16, month: UInt16, day: UInt16,
                                 hour: UInt16, minute: UInt16, second: UInt16) -> Data {
        let values = [year, month, day, hour, minute, second].flatMap { bigEndian($0) }
        return Data([UInt8]("dtim".utf8) + [UInt8](repeating: 0, count: 4) + values)
    }

    private func dataPayload(_ text: String, flag: UInt32 = 0, terminated: Bool = true) -> Data {
        var value = Array(text.utf8)
        if flag == 0, terminated { value.append(0) }
        return Data([UInt8]("data".utf8) + [UInt8](repeating: 0, count: 4) + bigEndian(flag) + value)
    }

    private func curvePayload(_ entries: [UInt16]) -> Data {
        var bytes = [UInt8]("curv".utf8) + [UInt8](repeating: 0, count: 4)
        bytes += bigEndian(UInt32(entries.count))
        for entry in entries { bytes += bigEndian(UInt32(entry)).suffix(2) }
        return Data(bytes)
    }

    private func chromaticityPayload(channels: UInt16, colorant: UInt16, values: [Double]) -> Data {
        Data([UInt8]("chrm".utf8) + [UInt8](repeating: 0, count: 4) +
             bigEndian(UInt32(channels)).suffix(2) + bigEndian(UInt32(colorant)).suffix(2) + values.flatMap { fixed16($0) })
    }

    private func parametricPayload(functionType: UInt16, values: [Double]) -> Data {
        var bytes = [UInt8]("para".utf8) + [UInt8](repeating: 0, count: 4)
        bytes += bigEndian(UInt32(functionType)).suffix(2)
        bytes += [0, 0]
        for value in values { bytes += fixed16(value) }
        return Data(bytes)
    }

    private func viewingPayload(values: [Double], illuminant: UInt32) -> Data {
        Data([UInt8]("view".utf8) + [UInt8](repeating: 0, count: 4) +
             values.flatMap { fixed16($0) } + bigEndian(illuminant))
    }

    private func measurementPayload(observer: UInt32, geometry: UInt32, illuminant: UInt32,
                                    backing: [Double], flare: Double) -> Data {
        Data([UInt8]("meas".utf8) + [UInt8](repeating: 0, count: 4) + bigEndian(observer) +
             backing.flatMap { fixed16($0) } + bigEndian(geometry) + fixed16(flare) + bigEndian(illuminant))
    }

    private func fixed16(_ value: Double) -> [UInt8] {
        let raw = Int32((value * 65536.0).rounded())
        let bits = UInt32(bitPattern: raw)
        return bigEndian(bits)
    }

    private func unsigned16(_ value: Double) -> [UInt8] {
        let raw = UInt32((value * 65535.0).rounded())
        return Array(bigEndian(raw).suffix(2))
    }

    func testAlphaZeroAndIdentityGate() throws {
        let plan = try TransformPlan(settings: TransformSettings(
            inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0
        ))
        let identity = PreviewIdentity(documentID: UUID(), revision: 1,
                                       requestID: UUID(), planVersion: plan.planVersion)
        let request = try PreviewRequest(plan: plan, width: 1, height: 1,
            pixels: [RGBA64(rgb: RGB64(1, 2, 3), alpha: 0)],
            inputAlpha: .premultiplied, outputAlpha: .straight, identity: identity)
        let result = try CPUPreview.render(request)
        XCTAssertEqual(try result.sample(x: 0, y: 0).output.rgb, try RGB64(0, 0, 0))
        XCTAssertTrue(PreviewIdentityGate(expected: identity, active: true).accepts(result))
        XCTAssertFalse(PreviewIdentityGate(expected: identity, active: false).accepts(result))
        XCTAssertFalse(PreviewIdentityGate(expected: PreviewIdentity(documentID: identity.documentID,
            revision: 2, requestID: identity.requestID, planVersion: identity.planVersion),
            active: true).accepts(result))
    }

    func testSameRevisionNewRequestInvalidatesOldResultAndCloseRejectsLateResult() async throws {
        let documentID = UUID()
        let session = PreviewSession(documentID: documentID)
        let slow = try await session.begin(revision: 4, planVersion: "plan-v1")
        let fast = try await session.begin(revision: 4, planVersion: "plan-v1")
        let acceptsSlow = await session.accepts(slow)
        let acceptsFast = await session.accepts(fast)
        XCTAssertFalse(acceptsSlow)
        XCTAssertTrue(acceptsFast)
        await session.close()
        let acceptsAfterClose = await session.accepts(fast)
        XCTAssertFalse(acceptsAfterClose)
    }
}
