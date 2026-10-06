import Foundation
import XCTest
import LUTCore
@testable import LUTPreview

final class ICCMPEContractsTests: XCTestCase {

    func testDToB3MatrixPreservesNegativeAndAboveOnePCSValues() throws {
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            matrixElement([1, 0, 0, 0,
                           0, 1, 0, 0,
                           0, 0, 1, 0]),
        ])))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")

        let xyz = try transform.deviceRGBToPCSXYZ(RGB64(-0.25, 0.75, 1.5))

        XCTAssertEqual(xyz.x, -0.25, accuracy: 0)
        XCTAssertEqual(xyz.y, 0.75, accuracy: 0)
        XCTAssertEqual(xyz.z, 1.5, accuracy: 0)
    }

    func testDToB3LabPCSUsesContinuousFloatLabEncoding() throws {
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            matrixElement([100, 0, 0, 0,
                           0, 255, 0, -128,
                           0, 0, 255, -128]),
        ]), pcs: "Lab "))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")

        let lab = try transform.deviceRGBToPCSLab(RGB64(0.5, 0.4, 0.6))

        XCTAssertEqual(lab.lStar, 0.5, accuracy: 0)
        XCTAssertEqual(lab.aStar, 0.4 * 255.0 - 128.0, accuracy: 0)
        XCTAssertEqual(lab.bStar, 0.6 * 255.0 - 128.0, accuracy: 0)
    }

    func testBToD3LabPCSUsesContinuousFloatLabEncoding() throws {
        let profile = Data(makeProfile(tag: "B2D3", payload: mpet(elements: [
            matrixElement([0.01, 0, 0, 0,
                           0, 1.0 / 255.0, 0, 128.0 / 255.0,
                           0, 0, 1.0 / 255.0, 128.0 / 255.0]),
        ]), pcs: "Lab "))
        let transform = try ICCMPETransform(profileData: profile, tag: "B2D3")
        let lab = try CIELABColor(lStar: 0.25, aStar: 12, bStar: -20)

        let rgb = try transform.pcsLabToDeviceRGB(lab)

        XCTAssertEqual(rgb.r, 0.25, accuracy: 2e-7)
        XCTAssertEqual(rgb.g, (12.0 + 128.0) / 255.0, accuracy: 2e-7)
        XCTAssertEqual(rgb.b, (-20.0 + 128.0) / 255.0, accuracy: 2e-7)
    }

    func testCurveSetFormulaUsesDoubleEvaluation() throws {
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            curveSetElement(formulas: [
                [2, 1, 0, 0], [2, 1, 0, 0], [2, 1, 0, 0],
            ]),
        ])))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")

        let xyz = try transform.deviceRGBToPCSXYZ(RGB64(0.25, 0.5, 0.75))

        XCTAssertEqual(xyz.x, 0.0625, accuracy: 1e-15)
        XCTAssertEqual(xyz.y, 0.25, accuracy: 1e-15)
        XCTAssertEqual(xyz.z, 0.5625, accuracy: 1e-15)
    }

    func testCurveSetSupportsAllICCFormulaTypes() throws {
        let logarithmic = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            curveSetElement(type: 1, parameters: [
                [1, 1, 1, 1, 0], [1, 1, 1, 1, 0], [1, 1, 1, 1, 0],
            ]),
        ])))
        let logTransform = try ICCMPETransform(profileData: logarithmic, tag: "D2B3")
        let logXYZ = try logTransform.deviceRGBToPCSXYZ(RGB64(0.5, 0.5, 0.5))
        XCTAssertEqual(logXYZ.x, Foundation.log10(1.5), accuracy: 1e-15)

        let exponential = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            curveSetElement(type: 2, parameters: [
                [1, 2, 1, 0, 0], [1, 2, 1, 0, 0], [1, 2, 1, 0, 0],
            ]),
        ])))
        let exponentialTransform = try ICCMPETransform(profileData: exponential, tag: "D2B3")
        let exponentialXYZ = try exponentialTransform.deviceRGBToPCSXYZ(RGB64(0.5, 0.5, 0.5))
        XCTAssertEqual(exponentialXYZ.x, Foundation.pow(2.0, 0.5), accuracy: 1e-15)
    }

    func testMPEFormulaCurveRejectsTraditionalParametricTypesThreeAndFour() {
        // ICC.1:2022-05 Table 60 defines parf only for function types 0..2.
        // Types 3 and 4 belong to the separate para tag type.
        let cases: [(Int, [Float])] = [
            (3, [2, 1, 0, 0, 0.5, 1]),
            (4, [2, 1, 0, 0, 1, 0.5, 1]),
        ]

        for (type, parameters) in cases {
            let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
                curveSetElement(type: type, parameters: [parameters, parameters, parameters]),
            ])))

            XCTAssertThrowsError(try ICCMPETransform(profileData: profile, tag: "D2B3")) {
                XCTAssertEqual($0 as? ICCMPEError, .unsupportedCurve("parf-\(type)"))
            }
        }
    }

    func testFormulaSegmentsRespectICCBreakpoints() throws {
        let lower = formulaSegment(type: 0, parameters: [1, 1, 0, 0])
        let upper = formulaSegment(type: 0, parameters: [2, 1, 0, 0])
        let curve = segmentedCurve(breakpoints: [0.5], segments: [lower, upper])
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            curveSetElement(curves: [curve, curve, curve]),
        ])))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")

        let xyz = try transform.deviceRGBToPCSXYZ(RGB64(0.25, 0.75, 0.5))

        XCTAssertEqual(xyz.x, 0.25, accuracy: 1e-15)
        XCTAssertEqual(xyz.y, 0.5625, accuracy: 1e-15)
        XCTAssertEqual(xyz.z, 0.5, accuracy: 1e-15)
    }

    func testBreakpointEqualityUsesTheEarlierSegment() throws {
        let lower = formulaSegment(type: 0, parameters: [1, 1, 0, 0])
        let upper = formulaSegment(type: 0, parameters: [2, 1, 0, 0])
        let curve = segmentedCurve(breakpoints: [0.5], segments: [lower, upper])
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            curveSetElement(curves: [curve, curve, curve]),
        ])))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")

        let xyz = try transform.deviceRGBToPCSXYZ(RGB64(0.5, 0.5, 0.5))

        XCTAssertEqual(xyz.x, 0.5, accuracy: 0)
        XCTAssertEqual(xyz.y, 0.5, accuracy: 0)
        XCTAssertEqual(xyz.z, 0.5, accuracy: 0)
    }

    func testEqualSuccessiveBreakpointsAreMalformed() {
        let first = formulaSegment(type: 0, parameters: [1, 1, 0, 0])
        let empty = formulaSegment(type: 0, parameters: [2, 1, 0, 0])
        let last = formulaSegment(type: 0, parameters: [3, 1, 0, 0])
        let curve = segmentedCurve(breakpoints: [0.5, 0.5], segments: [first, empty, last])
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            curveSetElement(curves: [curve, curve, curve]),
        ])))
        XCTAssertThrowsError(try ICCMPETransform(profileData: profile, tag: "D2B3")) {
            XCTAssertEqual($0 as? ICCMPEError, .malformed)
        }
    }

    func testCLUTUsesFirstDimensionLeastRapidOrderAndClipsOnlyAtCLUTInput() throws {
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [clutIdentityElement()])))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")

        let xyz = try transform.deviceRGBToPCSXYZ(RGB64(-0.25, 1.5, 0.5))

        XCTAssertEqual(xyz.x, 0, accuracy: 1e-15)
        XCTAssertEqual(xyz.y, 1, accuracy: 1e-15)
        XCTAssertEqual(xyz.z, 0.5, accuracy: 1e-15)
    }

    func testCLUTUsesFirstDimensionLeastRapidOrderForNonUniformGrid() throws {
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            nonUniformCLUTElement()
        ])))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")

        // Grid [2, 3, 2], input (1, 0, 0) addresses index 6 when the
        // first dimension is least rapid: 1 * (3 * 2) + 0 * 2 + 0.
        let xyz = try transform.deviceRGBToPCSXYZ(RGB64(1, 0, 0))
        XCTAssertEqual(xyz.x, 6, accuracy: 1e-15)
        XCTAssertEqual(xyz.y, 6, accuracy: 1e-15)
        XCTAssertEqual(xyz.z, 6, accuracy: 1e-15)
    }

    func testUnknownProcessingElementIsRejected() throws {
        let unknown = element(signature: "zzzz", input: 3, output: 3, body: [])
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [unknown])))

        XCTAssertThrowsError(try ICCMPETransform(profileData: profile, tag: "D2B3")) {
            XCTAssertEqual($0 as? ICCMPEError, .unsupportedProcessingElement("zzzz"))
        }
    }

    func testACSPlaceholderElementsPassThrough() throws {
        let begin = element(signature: "bACS", input: 3, output: 3, body: Array("TEST".utf8))
        let end = element(signature: "eACS", input: 3, output: 3, body: Array("TEST".utf8))
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [begin, end])))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")

        let xyz = try transform.deviceRGBToPCSXYZ(RGB64(-0.25, 0.5, 1.5))

        XCTAssertEqual(xyz.x, -0.25, accuracy: 0)
        XCTAssertEqual(xyz.y, 0.5, accuracy: 0)
        XCTAssertEqual(xyz.z, 1.5, accuracy: 0)
    }

    func testMPEAllowsIdenticalSharedElementRanges() throws {
        let matrix = matrixElement([1, 0, 0, 0,
                                    0, 1, 0, 0,
                                    0, 0, 1, 0])
        let profile = Data(makeProfile(tag: "D2B3", payload: mpetSharing(matrix, count: 2)))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")

        let xyz = try transform.deviceRGBToPCSXYZ(RGB64(0.25, 0.5, 0.75))

        XCTAssertEqual(xyz.x, 0.25, accuracy: 0)
        XCTAssertEqual(xyz.y, 0.5, accuracy: 0)
        XCTAssertEqual(xyz.z, 0.75, accuracy: 0)
    }

    func testDescendingBreakpointsAreMalformed() {
        let formula = formulaSegment(type: 0, parameters: [1, 1, 0, 0])
        let curve = segmentedCurve(breakpoints: [0.75, 0.5],
                                   segments: [formula, formula, formula])
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            curveSetElement(curves: [curve, curve, curve]),
        ])))

        XCTAssertThrowsError(try ICCMPETransform(profileData: profile, tag: "D2B3")) {
            XCTAssertEqual($0 as? ICCMPEError, .malformed)
        }
    }

    func testCurveBreakpointsMustBeStrictlyIncreasingButNeedNotBeNormalized() throws {
        let formula = formulaSegment(type: 0, parameters: [1, 1, 0, 0])
        let malformedCases: [[Float]] = [[0.5, 0.5], [1.0, -1.0]]
        for breakpoints in malformedCases {
            let curve = segmentedCurve(breakpoints: breakpoints,
                                        segments: [formula, formula, formula])
            let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
                curveSetElement(curves: [curve, curve, curve]),
            ])))
            XCTAssertThrowsError(try ICCMPETransform(profileData: profile, tag: "D2B3")) {
                XCTAssertEqual($0 as? ICCMPEError, .malformed)
            }
        }

        // ICC.1 defines curve breakpoints over the float32 input domain; they
        // are not restricted to the CLUT's normalized 0...1 domain.
        let curve = segmentedCurve(breakpoints: [-2.0, 3.0],
                                   segments: [formula, sampledSegment([0.25, 0.75]), formula])
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            curveSetElement(curves: [curve, curve, curve]),
        ])))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")
        XCTAssertEqual(try transform.deviceRGBToPCSXYZ(RGB64(0.5, 0.5, 0.5)).x,
                       0.25, accuracy: 1e-15)
    }

    func testNonFiniteMatrixParametersAreRejected() {
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            matrixElement([Float.infinity, 0, 0, 0,
                           0, 1, 0, 0,
                           0, 0, 1, 0]),
        ])))

        XCTAssertThrowsError(try ICCMPETransform(profileData: profile, tag: "D2B3")) {
            XCTAssertEqual($0 as? ICCMPEError, .invalidFloat)
        }
    }

    func testSampledMiddleSegmentInterpolatesFromPreviousCurveValueAndStoredSamples() throws {
        let lower = formulaSegment(type: 0, parameters: [1, 2, 0, 0])
        let sampled = sampledSegment([0.8, 1.4])
        let upper = formulaSegment(type: 0, parameters: [1, 1, 0, 0])
        let curve = segmentedCurve(breakpoints: [0.25, 0.75],
                                   segments: [lower, sampled, upper])
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            curveSetElement(curves: [curve, curve, curve]),
        ])))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")
        let first = Double(Float(0.8))
        let last = Double(Float(1.4))

        XCTAssertEqual(try transform.deviceRGBToPCSXYZ(RGB64(0.25, 0.25, 0.25)).x,
                       0.5, accuracy: 0)
        XCTAssertEqual(try transform.deviceRGBToPCSXYZ(RGB64(0.375, 0.375, 0.375)).x,
                       0.5 + (first - 0.5) * 0.5, accuracy: 1e-15)
        XCTAssertEqual(try transform.deviceRGBToPCSXYZ(RGB64(0.5, 0.5, 0.5)).x,
                       first, accuracy: 0)
        XCTAssertEqual(try transform.deviceRGBToPCSXYZ(RGB64(0.625, 0.625, 0.625)).x,
                       first + (last - first) * 0.5, accuracy: 1e-15)
        XCTAssertEqual(try transform.deviceRGBToPCSXYZ(RGB64(0.75, 0.75, 0.75)).x,
                       last, accuracy: 0)
    }

    func testSingleSampleMiddleSegmentSpansItsEntireInterval() throws {
        let lower = formulaSegment(type: 0, parameters: [1, 2, 0, 0])
        let sampled = sampledSegment([1.4])
        let upper = formulaSegment(type: 0, parameters: [1, 1, 0, 0])
        let curve = segmentedCurve(breakpoints: [0.25, 0.75],
                                   segments: [lower, sampled, upper])
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            curveSetElement(curves: [curve, curve, curve]),
        ])))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")
        let endpoint = Double(Float(1.4))

        let xyz = try transform.deviceRGBToPCSXYZ(RGB64(0.5, 0.5, 0.5))

        let expected = 0.5 + (endpoint - 0.5) * 0.5
        XCTAssertEqual(xyz.x, expected, accuracy: 1e-15)
        XCTAssertEqual(xyz.y, expected, accuracy: 1e-15)
        XCTAssertEqual(xyz.z, expected, accuracy: 1e-15)
    }

    func testSampledCurveSegmentRequiresPrecedingSegment() throws {
        let formula = formulaSegment(type: 0, parameters: [1, 1, 0, 0])
        let sampled = sampledSegment([0.5])
        let firstSampled = segmentedCurve(breakpoints: [0.75], segments: [sampled, formula])
        let firstProfile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            curveSetElement(curves: [firstSampled, firstSampled, firstSampled]),
        ])))
        XCTAssertThrowsError(try ICCMPETransform(profileData: firstProfile, tag: "D2B3")) {
            XCTAssertEqual($0 as? ICCMPEError, .malformed)
        }

        // A final sampled segment is valid: it extends to the normalized
        // curve-domain endpoint (1.0), using the preceding segment value as
        // its implicit first sample.
        let lastSampled = segmentedCurve(breakpoints: [0.25], segments: [formula, sampled])
        let lastProfile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            curveSetElement(curves: [lastSampled, lastSampled, lastSampled]),
        ])))
        let transform = try ICCMPETransform(profileData: lastProfile, tag: "D2B3")
        let endpoint = Double(Float(0.5))
        let output = try transform.deviceRGBToPCSXYZ(RGB64(1.0, 1.0, 1.0))
        XCTAssertEqual(output.x, endpoint, accuracy: 0)
        XCTAssertEqual(output.y, endpoint, accuracy: 0)
        XCTAssertEqual(output.z, endpoint, accuracy: 0)

        let midpoint = try transform.deviceRGBToPCSXYZ(RGB64(0.625, 0.625, 0.625))
        XCTAssertEqual(midpoint.x, 0.25 + (endpoint - 0.25) * 0.5, accuracy: 1e-15)
    }

    func testFinalSampledSegmentInterpolatesMultipleSamplesToDomainEndpoint() throws {
        let lower = formulaSegment(type: 0, parameters: [1, 1, 0, 0])
        let sampled = sampledSegment([0.5, 0.75])
        let curve = segmentedCurve(breakpoints: [0.25], segments: [lower, sampled])
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            curveSetElement(curves: [curve, curve, curve]),
        ])))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")

        let endpoint = Double(Float(0.75))
        let output = try transform.deviceRGBToPCSXYZ(RGB64(1.0, 1.0, 1.0))
        XCTAssertEqual(output.x, endpoint, accuracy: 0)

        // At 3/4 of the final interval, interpolate between the two stored
        // samples rather than treating the last sample as an interior value.
        let quarter = try transform.deviceRGBToPCSXYZ(RGB64(0.8125, 0.8125, 0.8125))
        XCTAssertEqual(quarter.x, 0.625, accuracy: 1e-15)
    }

    func testFourChannelDeviceToPCSUsesProfileChannelCountAndDynamicMatrix() throws {
        let profile = Data(makeProfile(tag: "D2B3", colorSpace: "CMYK", payload: mpet(input: 4, output: 3, elements: [
            dynamicMatrixElement(input: 4, output: 3, values: [
                1, 2, 3, 4, 0,
                0, 1, 0, 0, 0.5,
                0, 0, 1, 0, -0.25,
            ]),
        ])))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")

        let xyz = try transform.deviceToPCSXYZ([0.1, 0.2, 0.3, 0.4])

        XCTAssertEqual(xyz.x, 3.0, accuracy: 1e-15)
        XCTAssertEqual(xyz.y, 0.7, accuracy: 1e-15)
        XCTAssertEqual(xyz.z, 0.05, accuracy: 1e-15)
    }

    func testFourChannelCurveSetCanFeedDynamicMatrix() throws {
        let profile = Data(makeProfile(tag: "D2B3", colorSpace: "CMYK", payload: mpet(input: 4, output: 3, elements: [
            dynamicCurveSetElement(channelCount: 4, type: 0,
                                   parameters: [[1, 1, 0, 0], [1, 2, 0, 0],
                                                [1, 3, 0, 0], [1, 4, 0, 0]]),
            dynamicMatrixElement(input: 4, output: 3, values: [
                1, 0, 0, 0, 0,
                0, 1, 0, 0, 0,
                0, 0, 1, 0, 0,
            ]),
        ])))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")

        let xyz = try transform.deviceToPCSXYZ([0.1, 0.2, 0.3, 0.4])

        XCTAssertEqual(xyz.x, 0.1, accuracy: 1e-15)
        XCTAssertEqual(xyz.y, 0.4, accuracy: 1e-15)
        XCTAssertEqual(xyz.z, 0.9, accuracy: 1e-15)
    }

    func testFourChannelPCSOutputUsesDynamicBToDMatrix() throws {
        let profile = Data(makeProfile(tag: "B2D3", colorSpace: "CMYK", payload: mpet(input: 3, output: 4, elements: [
            dynamicMatrixElement(input: 3, output: 4, values: [
                1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
                1, 1, 1, 0,
            ]),
        ])))
        let transform = try ICCMPETransform(profileData: profile, tag: "B2D3")

        let device = try transform.pcsXYZToDevice(XYZ64(0.1, 0.2, 0.3))

        XCTAssertEqual(device.count, 4)
        for (actual, expected) in zip(device, [0.1, 0.2, 0.3, 0.6]) {
            XCTAssertEqual(actual, expected, accuracy: 1e-15)
        }
    }

    func testFourChannelCLUTUsesFirstDimensionLeastRapidOrder() throws {
        let profile = Data(makeProfile(tag: "D2B3", colorSpace: "CMYK", payload: mpet(input: 4, output: 3, elements: [
            dynamicCLUTElement(input: 4, output: 3)
        ])))
        let transform = try ICCMPETransform(profileData: profile, tag: "D2B3")

        let xyz = try transform.deviceToPCSXYZ([0.25, 0.5, 0.75, 1.0])

        XCTAssertEqual(xyz.x, 0.25, accuracy: 1e-15)
        XCTAssertEqual(xyz.y, 0.5, accuracy: 1e-15)
        XCTAssertEqual(xyz.z, 0.75, accuracy: 1e-15)
    }

    func testDeviceToPCSRejectsMPEDimensionsThatDoNotMatchProfile() {
        let profile = Data(makeProfile(tag: "D2B3", colorSpace: "CMYK", payload: mpet(input: 3, output: 3, elements: [
            dynamicMatrixElement(input: 3, output: 3, values: [
                1, 0, 0, 0,
                0, 1, 0, 0,
                0, 0, 1, 0,
            ]),
        ])))

        XCTAssertThrowsError(try ICCMPETransform(profileData: profile, tag: "D2B3")) {
            XCTAssertEqual($0 as? ICCMPEError, .unsupportedChannels)
        }
    }

    func testMPETElementCountOverflowIsMalformedWithoutAllocatingElementTable() {
        var payload = mpet(elements: [matrixElement([1, 0, 0, 0,
                                                       0, 1, 0, 0,
                                                       0, 0, 1, 0])])
        payload.replaceSubrange(12..<16, with: be(UInt32.max))
        let profile = Data(makeProfile(tag: "D2B3", payload: payload))

        XCTAssertThrowsError(try ICCMPETransform(profileData: profile, tag: "D2B3")) {
            XCTAssertEqual($0 as? ICCMPEError, .malformed)
        }
    }

    func testCurveOffsetIntegerOverflowIsMalformed() {
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            curveSetElement(formulas: [
                [1, 1, 0, 0], [1, 1, 0, 0], [1, 1, 0, 0],
            ])
        ])))
        var malformed = profile
        // The profile helper rebuilds the payload; replace the cvst table
        // entry in-place at the tag payload offset.
        let payloadStart = 144
        let cvstOffset = Int(UInt32(profile[payloadStart + 16]) << 24 |
                             UInt32(profile[payloadStart + 17]) << 16 |
                             UInt32(profile[payloadStart + 18]) << 8 |
                             UInt32(profile[payloadStart + 19]))
        malformed.replaceSubrange(payloadStart + cvstOffset + 12..<payloadStart + cvstOffset + 16,
                                  with: be(UInt32.max))
        XCTAssertThrowsError(try ICCMPETransform(profileData: malformed, tag: "D2B3")) {
            XCTAssertEqual($0 as? ICCMPEError, .malformed)
        }
    }

    func testCLUTInputChannelCountAboveGridHeaderIsMalformed() {
        let profile = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            element(signature: "clut", input: 17, output: 3,
                    body: [UInt8](repeating: 2, count: 16))
        ])))

        XCTAssertThrowsError(try ICCMPETransform(profileData: profile, tag: "D2B3")) {
            XCTAssertEqual($0 as? ICCMPEError, .malformed)
        }
    }

    func testMPEElementsRejectZeroInputOrOutputChannels() {
        let zeroInput = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            element(signature: "matf", input: 0, output: 3,
                    body: [UInt8](repeating: 0, count: 12))
        ])))
        XCTAssertThrowsError(try ICCMPETransform(profileData: zeroInput, tag: "D2B3")) {
            XCTAssertEqual($0 as? ICCMPEError, .unsupportedChannels)
        }

        let zeroOutput = Data(makeProfile(tag: "D2B3", payload: mpet(elements: [
            element(signature: "matf", input: 3, output: 0, body: [])
        ])))
        XCTAssertThrowsError(try ICCMPETransform(profileData: zeroOutput, tag: "D2B3")) {
            XCTAssertEqual($0 as? ICCMPEError, .unsupportedChannels)
        }
    }

    private func makeProfile(tag: String, colorSpace: String = "RGB ", payload: [UInt8], pcs: String = "XYZ ") -> [UInt8] {
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

    private func mpet(input: Int = 3, output: Int = 3, elements: [[UInt8]]) -> [UInt8] {
        let tableEnd = 16 + elements.count * 8
        var payload = Array("mpet".utf8) + [UInt8](repeating: 0, count: 4)
        payload += be(UInt16(input)) + be(UInt16(output)) + be(UInt32(elements.count))
        var cursor = tableEnd
        for element in elements {
            cursor = (cursor + 3) & ~3
            payload += be(UInt32(cursor)) + be(UInt32(element.count))
            cursor += element.count
        }
        for element in elements {
            while payload.count % 4 != 0 { payload.append(0) }
            payload += element
        }
        return payload
    }

    private func mpetSharing(_ element: [UInt8], count: Int) -> [UInt8] {
        let offset = 16 + count * 8
        var payload = Array("mpet".utf8) + [UInt8](repeating: 0, count: 4)
        payload += be(UInt16(3)) + be(UInt16(3)) + be(UInt32(count))
        for _ in 0..<count {
            payload += be(UInt32(offset)) + be(UInt32(element.count))
        }
        payload += element
        return payload
    }

    private func matrixElement(_ values: [Float]) -> [UInt8] {
        precondition(values.count == 12)
        return dynamicMatrixElement(input: 3, output: 3, values: values)
    }

    private func dynamicMatrixElement(input: Int, output: Int, values: [Float]) -> [UInt8] {
        precondition(values.count == output * (input + 1))
        return element(signature: "matf", input: input, output: output,
                       body: values.flatMap { be($0) })
    }

    private func dynamicCLUTElement(input: Int, output: Int) -> [UInt8] {
        precondition(input == 4 && output == 3)
        var body = [UInt8](repeating: 0, count: 16)
        for axis in 0..<input { body[axis] = 2 }
        for index in 0..<(1 << input) {
            // ICC stores the first input dimension least rapidly.
            let coordinates = (0..<input).map { axis in
                let shift = input - axis - 1
                return Float((index >> shift) & 1)
            }
            let values: [Float] = [
                coordinates[0], coordinates[1], coordinates[2],
            ]
            body += values.flatMap { be($0) }
        }
        return element(signature: "clut", input: input, output: output, body: body)
    }

    private func curveSetElement(formulas: [[Float]]) -> [UInt8] {
        precondition(formulas.count == 3 && formulas.allSatisfy { $0.count == 4 })
        return curveSetElement(curves: formulas.map {
            segmentedCurve(breakpoints: [], segments: [formulaSegment(type: 0, parameters: $0)])
        })
    }

    private func curveSetElement(type: Int, parameters: [[Float]]) -> [UInt8] {
        precondition(parameters.count == 3)
        return curveSetElement(curves: parameters.map {
            segmentedCurve(breakpoints: [], segments: [formulaSegment(type: type, parameters: $0)])
        })
    }

    private func dynamicCurveSetElement(channelCount: Int, type: Int,
                                        parameters: [[Float]]) -> [UInt8] {
        precondition(parameters.count == channelCount)
        let curves = parameters.map {
            segmentedCurve(breakpoints: [], segments: [formulaSegment(type: type, parameters: $0)])
        }
        return curveSetElement(curves: curves)
    }

    private func curveSetElement(curves: [[UInt8]]) -> [UInt8] {
        precondition(!curves.isEmpty)
        let headerSize = 12 + curves.count * 8
        var payload = Array("cvst".utf8) + [UInt8](repeating: 0, count: 4)
        payload += be(UInt16(curves.count)) + be(UInt16(curves.count))
        var cursor = headerSize
        for curve in curves {
            payload += be(UInt32(cursor)) + be(UInt32(curve.count))
            cursor += curve.count
        }
        payload += curves.flatMap { $0 }
        return payload
    }

    private func segmentedCurve(breakpoints: [Float], segments: [[UInt8]]) -> [UInt8] {
        var curve = Array("curf".utf8) + [UInt8](repeating: 0, count: 4)
        curve += be(UInt16(segments.count)) + [0, 0]
        curve += breakpoints.flatMap { be($0) }
        curve += segments.flatMap { $0 }
        return curve
    }

    private func formulaSegment(type: Int, parameters: [Float]) -> [UInt8] {
        Array("parf".utf8) + [UInt8](repeating: 0, count: 4) +
            be(UInt16(type)) + [0, 0] + parameters.flatMap { be($0) }
    }

    private func sampledSegment(_ samples: [Float]) -> [UInt8] {
        Array("samf".utf8) + [UInt8](repeating: 0, count: 4) +
            be(UInt32(samples.count)) + samples.flatMap { be($0) }
    }

    private func clutIdentityElement() -> [UInt8] {
        var body = [UInt8](repeating: 0, count: 16)
        body[0] = 2
        body[1] = 2
        body[2] = 2
        // ICC mpet CLUT storage varies the first input dimension least rapidly.
        for r in 0...1 {
            for g in 0...1 {
                for b in 0...1 {
                    body += [Float(r), Float(g), Float(b)].flatMap { be($0) }
                }
            }
        }
        return element(signature: "clut", input: 3, output: 3, body: body)
    }

    private func nonUniformCLUTElement() -> [UInt8] {
        var body = [UInt8](repeating: 0, count: 16)
        body[0] = 2
        body[1] = 3
        body[2] = 2
        // First dimension is least rapid per ICC. Values encode the flat
        // index so a transposed implementation cannot pass this fixture.
        for index in 0..<(2 * 3 * 2) {
            body += [Float(index), Float(index), Float(index)].flatMap { be($0) }
        }
        return element(signature: "clut", input: 3, output: 3, body: body)
    }

    private func element(signature: String, input: Int, output: Int,
                         body: [UInt8]) -> [UInt8] {
        Array(signature.utf8) + [UInt8](repeating: 0, count: 4) +
            be(UInt16(input)) + be(UInt16(output)) + body
    }

    private func be(_ value: UInt16) -> [UInt8] {
        [UInt8(value >> 8), UInt8(value & 0xff)]
    }

    private func be(_ value: UInt32) -> [UInt8] {
        [UInt8((value >> 24) & 0xff), UInt8((value >> 16) & 0xff),
         UInt8((value >> 8) & 0xff), UInt8(value & 0xff)]
    }

    private func be(_ value: Float) -> [UInt8] { be(value.bitPattern) }
}
