import XCTest
@testable import LUTCore

/// Enumerates every native transfer route so a newly added basePlanVersion
/// branch cannot silently omit the transfer pair or either colour-space ID.
final class TransformPlanIdentityCoverageContractsTests: XCTestCase {
    private let transfers: [TransferID] = [
        .djiDLog2, .linearScene, .nullLUTCalcLegacy,
        .srgbW3CExtended, .srgbLUTCalcLegacy, .rec709LUTCalcLegacy,
        .rec2020TenBit, .rec2020Continuous, .smpte240M, .rec2020TwelveBit,
        .cineon, .cineonLUTCalcLegacy, .redLogFilm, .redLogFilmLUTCalcLegacy,
        .redLog3G10LUTCalcLegacy, .sonySLog3, .sonySLog3LUTCalcLegacy,
        .sonySLog2, .sonySLog2LUTCalcLegacy, .sonySLog, .sonySLogLUTCalcLegacy,
        .nikonNLog, .nikonNLogLUTCalcLegacy, .arriLogCSUP2Scene,
        .arriLogCSUP3Scene, .arriLogC4, .blackmagicFilmGen5,
        .blackmagicFilmGen5LUTCalcLegacy, .blackmagicFilmLUTCalcLegacy,
        .blackmagicFilm4kLUTCalcLegacy, .blackmagicFilm46kLUTCalcLegacy,
        .bolexLogLUTCalcLegacy, .panalogLUTCalcLegacy, .djiX5LogLUTCalcLegacy,
        .goProProtuneLUTCalcLegacy, .djiX3DLogLUTCalcLegacy,
        .daVinciIntermediateLUTCalcLegacy, .canonCLog2, .canonCLog2LUTCalcLegacy,
        .canonCLog3, .canonCLogLUTCalcLegacy, .blackmagicPocketFilmLUTCalcLegacy,
        .panasonicVLog, .fujifilmFLog2, .fujifilmFLog2LUTCalcLegacy,
        .fujifilmFLogLUTCalcLegacy, .acesCCT, .acesCC, .acesProxy10,
        .acesProxy12, .insta360ILog, .xiaomiMiLog, .leicaLLog, .kineLog3,
        .gpLog2, .appleLogOriginal, .appleLog2, .rec2100HLG, .rec2100PQ,
        .bt1886, .proPhoto, .bbc04, .bbc05, .bbc06, .bbcWHP283400,
        .bbcWHP283800, .ituProposal400, .ituProposal800, .parameterizedGamma,
        .gamma15, .gamma16, .gamma17, .gamma18, .gamma19, .gamma20, .gamma21,
        .gamma22, .gamma23, .gamma24, .gamma25, .gamma26, .cieLStar
    ]

    private func gamma() throws -> ParameterizedGammaSettings {
        try ParameterizedGammaSettings(exponent: 2.2, linearSlope: 4.5,
                                        offset: 0.1, linearCut: 0.02,
                                        encodedCut: 0.09)
    }

    private func logC(for id: TransferID) throws -> ARRILogCSceneSettings? {
        switch id {
        case .arriLogCSUP2Scene:
            return try ARRILogCSceneSettings(algorithm: .sup2Published, exposureIndex: 800)
        case .arriLogCSUP3Scene:
            return try ARRILogCSceneSettings(algorithm: .sup3Published, exposureIndex: 800)
        default:
            return nil
        }
    }

    private func plan(input: TransferID, output: TransferID) throws -> TransformPlan {
        let inputGamma = input == .parameterizedGamma ? try gamma() : nil
        let outputGamma = output == .parameterizedGamma ? try gamma() : nil
        return try TransformPlan(settings: TransformSettings(
            inputTransfer: input, outputTransfer: output,
            inputSpace: .rec2020, outputSpace: .displayP3,
            inputRange: .data, outputRange: .data, exposureStops: 0,
            inputGamma: inputGamma, outputGamma: outputGamma,
            inputLogC: try logC(for: input), outputLogC: try logC(for: output)
        ))
    }

    func testEveryTransferIdentityContainsBothDirectionsAndColourSpaces() throws {
        for transfer in transfers {
            let decode = try plan(input: transfer, output: .linearScene).planVersion
            XCTAssertTrue(decode.contains(transfer.rawValue), "input transfer omitted: \(transfer)")
            XCTAssertTrue(decode.contains(TransferID.linearScene.rawValue), "output transfer omitted: \(transfer)")
            XCTAssertTrue(decode.contains("inSpace:" + ColorSpaceID.rec2020.rawValue), "input space omitted: \(transfer)")
            XCTAssertTrue(decode.contains("outSpace:" + ColorSpaceID.displayP3.rawValue), "output space omitted: \(transfer)")

            let encode = try plan(input: .linearScene, output: transfer).planVersion
            XCTAssertTrue(encode.contains(TransferID.linearScene.rawValue), "input transfer omitted: \(transfer)")
            XCTAssertTrue(encode.contains(transfer.rawValue), "output transfer omitted: \(transfer)")
            XCTAssertTrue(encode.contains("inSpace:" + ColorSpaceID.rec2020.rawValue), "input space omitted: \(transfer)")
            XCTAssertTrue(encode.contains("outSpace:" + ColorSpaceID.displayP3.rawValue), "output space omitted: \(transfer)")
        }
    }

    func testEveryTransferExecutesDoubleDecodeAndEncodePath() throws {
        for transfer in transfers {
            let decoded = try plan(input: transfer, output: .linearScene)
                .evaluate(RGB64(0.18, 0.18, 0.18))
            XCTAssertTrue(decoded.r.isFinite && decoded.g.isFinite && decoded.b.isFinite,
                          "decode produced a non-finite value: \(transfer)")

            let encoded = try plan(input: .linearScene, output: transfer)
                .evaluate(RGB64(0.18, 0.18, 0.18))
            XCTAssertTrue(encoded.r.isFinite && encoded.g.isFinite && encoded.b.isFinite,
                          "encode produced a non-finite value: \(transfer)")
        }
    }
}
