import XCTest
import LUTCatalog
import LUTCore

final class RegistryContractsTests: XCTestCase {
    func testStableIDsAndNoFallback() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "D-Log2")?.id, .djiDLog2)
        XCTAssertEqual(catalog.transfer(named: "sRGB")?.id, .srgbW3CExtended)
        XCTAssertEqual(catalog.transfer(named: "sRGB (LUTCalc legacy)")?.linearReference, .legacyGrey02)
        XCTAssertNil(catalog.transfer(named: "unknown.v1"))
        XCTAssertNil(catalog.colorSpace(named: "unknown.v1"))
        XCTAssertNil(catalog.preset(named: "unknown.v1"))
        XCTAssertEqual(catalog.preset(named: "dji.dlog2-to-srgb-w3c.v1")?.settings.outputSpace, .srgb)
    }

    func testBlockedLookupRegistrationsHaveNoNativeCatalogIdentity() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(AlgorithmCatalog.blockedLookupRegistrationNames.count, 45)
        for name in AlgorithmCatalog.blockedLookupRegistrationNames {
            XCTAssertNil(catalog.transfer(named: name), "查表注册不得意外解析为原生 transfer: \(name)")
            XCTAssertNil(catalog.colorSpace(named: name), "查表注册不得意外解析为原生色域: \(name)")
            XCTAssertNil(catalog.preset(named: name), "查表注册不得意外解析为原生预设: \(name)")
        }
    }

    /// Sony STD4/STD5 are historical SimpleLog output look LUTs.  Their names
    /// must not be silently replaced by the independently published SMPTE
    /// 240M or Rec.709 scalar transfers: the former has its own OETF and the
    /// latter is the LUTCalc legacy transfer with different range semantics.
    /// This is a negative contract until a vendor formula and an independent
    /// non-grey reference are available.
    func testSonyStdLookupNamesCannotAliasPublishedScalarTransfers() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let standardIDs: Set<TransferID> = [.smpte240M, .rec709LUTCalcLegacy]
        for name in ["Sony STD4 - SMPTE240M", "Sony STD5 - Rec709"] {
            XCTAssertNil(catalog.transfer(named: name))
            XCTAssertNil(catalog.colorSpace(named: name))
            XCTAssertNil(catalog.preset(named: name))
        }
        XCTAssertEqual(catalog.transfer(named: "SMPTE 240M")?.id, .smpte240M)
        XCTAssertEqual(catalog.transfer(named: "Rec.709 (LUTCalc legacy)")?.id,
                       .rec709LUTCalcLegacy)
        XCTAssertEqual(standardIDs, [.smpte240M, .rec709LUTCalcLegacy])
    }

    /// `Rec709 (800%)` is an old two-spline input/output display mapping. Its
    /// 800% headroom and SimpleLog bridge are not the Rec.709 OETF or the
    /// reference-display BT.1886 EOTF, so the sampled registration must remain
    /// blocked until a complete public definition and independent reference
    /// exist.
    func testRec709800LookupCannotAliasRec709OrBT1886() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertNil(catalog.transfer(named: "Rec709 (800%)"))
        XCTAssertNil(catalog.colorSpace(named: "Rec709 (800%)"))
        XCTAssertNil(catalog.preset(named: "Rec709 (800%)"))
        XCTAssertEqual(catalog.transfer(named: "Rec.709 (LUTCalc legacy)")?.id,
                       .rec709LUTCalcLegacy)
        XCTAssertEqual(catalog.transfer(named: "BT.1886")?.id, .bt1886)
    }

    /// These Sony STD look curves are distinct SimpleLog spline registrations;
    /// their x4.5/x3.5/x5 labels do not define a public gamma transfer.
    func testSonyStdLookupsCannotAliasPublishedTransfers() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        for name in ["Sony STD1", "Sony STD2 - x4.5", "Sony STD3 - x3.5", "Sony STD6 - x5"] {
            XCTAssertNil(catalog.transfer(named: name))
            XCTAssertNil(catalog.colorSpace(named: name))
            XCTAssertNil(catalog.preset(named: name))
        }
        XCTAssertEqual(catalog.transfer(named: "Rec.709 (LUTCalc legacy)")?.id,
                       .rec709LUTCalcLegacy)
        XCTAssertEqual(catalog.transfer(named: "BT.1886")?.id, .bt1886)
    }

    /// S-Log3 display look registrations are vendor-specific sampled curves;
    /// their names must not be treated as aliases for the S-Log3 scalar
    /// transfer or for a generic Rec.709/BT.1886 display curve.
    func testSLog3DisplayLookupsCannotAliasPublishedTransfers() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let names = ["Amira709", "Alexa-X-2", "LC709A", "LC709", "Sony Cine+709",
                     "Varicam V709", "REDGamma", "REDGamma2", "REDGamma3", "REDGamma4"]
        for name in names {
            XCTAssertNil(catalog.transfer(named: name))
            XCTAssertNil(catalog.colorSpace(named: name))
            XCTAssertNil(catalog.preset(named: name))
        }
        XCTAssertEqual(catalog.transfer(named: "S-Log3")?.id, .sonySLog3)
        XCTAssertEqual(catalog.transfer(named: "Rec.709 (LUTCalc legacy)")?.id,
                       .rec709LUTCalcLegacy)
        XCTAssertEqual(catalog.transfer(named: "BT.1886")?.id, .bt1886)
    }

    func testDLog2IdentityPresetIsVLTRepresentable() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let settings = try XCTUnwrap(catalog.preset(named: "dji.dlog2-to-dlog2-identity.v1")?.settings)
        XCTAssertEqual(settings.exposureStops, 0)
        XCTAssertEqual(settings.inputSpace, .djiDGamut2)
        XCTAssertEqual(settings.outputSpace, .djiDGamut2)
        let plan = try TransformPlan(settings: settings)
        for sample in [try RGB64(0, 0, 0), try RGB64(0.25, 0.5, 0.75), try RGB64(1, 1, 1)] {
            let result = try plan.evaluate(sample)
            XCTAssertEqual(result.r, sample.r, accuracy: 2e-12)
            XCTAssertEqual(result.g, sample.g, accuracy: 2e-12)
            XCTAssertEqual(result.b, sample.b, accuracy: 2e-12)
            XCTAssertTrue((0...1).contains(result.r) && (0...1).contains(result.g) && (0...1).contains(result.b))
        }
    }

    func testDuplicateAndMissingReferencesFail() throws {
        let item = TransferDescriptor(id: .djiDLog2, aliases: [], source: "source", linearReference: .sceneReflectance)
        XCTAssertThrowsError(try AlgorithmCatalog(transfers: [item, item], colorSpaces: [], presets: [])) {
            XCTAssertEqual($0 as? CatalogError, .duplicateName(TransferID.djiDLog2.rawValue))
        }
        let preset = PresetDescriptor(id: "missing.v1", settings: TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: .linearScene,
            inputSpace: .djiDGamut2, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0
        ))
        XCTAssertThrowsError(try AlgorithmCatalog(transfers: [item], colorSpaces: [], presets: [preset])) {
            XCTAssertEqual($0 as? CatalogError, .unknownReference(TransferID.linearScene.rawValue))
        }
    }

    func testBuiltInPresetPlanIdentitiesDoNotAliasDifferentSettings() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        var byVersion: [String: (id: String, settings: TransformSettings)] = [:]
        for preset in catalog.presets {
            let version = try TransformPlan(settings: preset.settings).planVersion
            if let prior = byVersion[version] {
                XCTAssertEqual(prior.settings, preset.settings,
                               "预设计划身份冲突: (prior.id) 与 (preset.id) -> (version)")
            } else {
                byVersion[version] = (preset.id, preset.settings)
            }
        }
    }

    func testRec2100HLGPlanAndCatalogRegistration() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "Rec2100 HLG")?.id, .rec2100HLG)
        XCTAssertEqual(catalog.colorSpace(named: "Rec.2020")?.id, .rec2020)
        let settings = try XCTUnwrap(catalog.preset(named: "rec2100.hlg-exposure-one.v1")?.settings)
        XCTAssertEqual(settings.inputTransfer, .rec2100HLG)
        XCTAssertEqual(settings.outputTransfer, .rec2100HLG)
        let plan = try TransformPlan(settings: settings)
        let result = try plan.evaluate(RGB64(
            HLGTransfer.encodeSceneToData(0.18),
            HLGTransfer.encodeSceneToData(0.25),
            HLGTransfer.encodeSceneToData(1.0 / 24.0)
        ))
        XCTAssertEqual(result.r, 0.8093982436264028, accuracy: 2e-12)
        XCTAssertEqual(result.g, 0.8716434708741772, accuracy: 2e-12)
        XCTAssertEqual(result.b, 0.5, accuracy: 2e-12)
    }

    func testRec2100PQCatalogRegistration() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "Rec2100 PQ")?.id, .rec2100PQ)
        XCTAssertEqual(catalog.transfer(named: TransferID.rec2100PQ.rawValue)?.linearReference,
                       .sceneReflectance)
        let settings = try XCTUnwrap(catalog.preset(named: "rec2100.pq-reference.v1")?.settings)
        let plan = try TransformPlan(settings: settings)
        let value = 0.01
        let encoded = try PQTransfer.encodeNormalizedLuminanceToData(value)
        XCTAssertEqual(try plan.evaluate(RGB64(encoded, encoded, encoded)).r, encoded, accuracy: 2e-12)
    }

    func testRec2100PQReferenceRemainsSeparateFromLegacyOOTF() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let settings = try XCTUnwrap(catalog.preset(named: "rec2100.pq-reference.v1")?.settings)

        // The standard catalog route is the ST 2084 absolute-luminance transfer.
        // It must not silently acquire the historical LUTGammaOOTFPQ percentage
        // input, knee, or Lw/scale behavior.
        XCTAssertNil(catalog.transfer(named: "PQ OOTF"))
        XCTAssertNil(catalog.preset(named: "rec2100.pq-ootf.v1"))
        XCTAssertNil(settings.hlgOOTF)

        let normalizedScene = 0.18
        let standardCode = try PQTransfer.encodeNormalizedLuminanceToData(normalizedScene)
        let planCode = try TransformPlan(settings: settings).evaluate(
            RGB64(standardCode, standardCode, standardCode)
        ).r
        XCTAssertEqual(planCode, standardCode, accuracy: 2e-12)

        let legacy = try LegacyPQOOTF(inputPeakNits: 1_000,
                                      outputPeakNits: 1_000,
                                      scale: .nits)
        XCTAssertEqual(try legacy.forward(normalizedScene, side: .output),
                       5.704834098099198,
                       accuracy: 2e-15)
        XCTAssertNotEqual(try PQTransfer.decodeDataToAbsoluteLuminance(standardCode),
                          try legacy.forward(normalizedScene, side: .output),
                          accuracy: 1e-6)
    }

    func testBT1886CatalogRegistration() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "BT.1886")?.id, .bt1886)
        XCTAssertEqual(catalog.transfer(named: "BT.1886")?.linearReference, .absoluteNits)
        let settings = try XCTUnwrap(catalog.preset(named: "bt1886.reference-display.v1")?.settings)
        XCTAssertEqual(settings.inputTransfer, .bt1886)
        XCTAssertEqual(try TransformPlan(settings: settings).evaluate(RGB64(0.5, 0.5, 0.5)).r,
                       0.5, accuracy: 2e-12)
    }

    func testCIELStarCatalogAndPlanRegistration() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "CIE L*")?.id, .cieLStar)
        XCTAssertEqual(catalog.transfer(named: "CIE L*")?.linearReference, .legacyGrey02)
        let settings = try XCTUnwrap(catalog.preset(named: "cie.l-star-exposure-one.v1")?.settings)
        XCTAssertEqual(settings.inputTransfer, .cieLStar)
        let planVersion = try TransformPlan(settings: settings).planVersion
        XCTAssertTrue(planVersion.contains("cie.l-star.v1"))
        XCTAssertTrue(planVersion.contains("inSpace:srgb.d65.v1"))
        XCTAssertTrue(planVersion.contains("outSpace:srgb.d65.v1"))
        let sample = try CIELStarTransfer.encodeLegacyToData(0.18)
        let output = try TransformPlan(settings: settings).evaluate(RGB64(sample, sample, sample))
        XCTAssertTrue(output.r.isFinite)
    }

    func testConventionalGammaBatchCatalogRegistration() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let cases: [(String, TransferID)] = [
            ("γ1.5", .gamma15), ("γ1.6", .gamma16), ("γ1.7", .gamma17),
            ("γ1.8", .gamma18), ("γ1.9", .gamma19), ("γ2.0", .gamma20),
            ("γ2.1", .gamma21), ("γ2.2", .gamma22), ("γ2.3", .gamma23),
            ("γ2.4", .gamma24), ("γ2.5", .gamma25), ("γ2.6", .gamma26)
        ]
        for (name, id) in cases {
            let descriptor = try XCTUnwrap(catalog.transfer(named: name))
            XCTAssertEqual(descriptor.id, id)
            XCTAssertEqual(descriptor.linearReference, .legacyGrey02)
            XCTAssertTrue(descriptor.source.contains(ParameterizedGammaTransfer.referenceSource))
        }
    }

    func testParameterizedGammaFamilyContract() throws {
        XCTAssertEqual(ParameterizedGammaTransfer.familyID, "gamma.parameterized.v1")
        XCTAssertEqual(ParameterizedGammaTransfer.referenceSource, "js/gamma.js:LUTGammaGam")
        let catalog = try AlgorithmCatalog.builtIn()
        let gammaDescriptors = catalog.transfers.filter { $0.source.contains(ParameterizedGammaTransfer.referenceSource) }
        XCTAssertEqual(gammaDescriptors.count, 18)
        XCTAssertTrue(gammaDescriptors.allSatisfy { $0.linearReference == .legacyGrey02 })
    }

    func testFLog2HasDistinctPublishedCatalogIdentity() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "F-Log2")?.id, .fujifilmFLog2)
        XCTAssertEqual(catalog.colorSpace(named: "F-Gamut")?.id, .fujifilmFGamut)
        let settings = try XCTUnwrap(catalog.preset(named: "fujifilm.flog2-exposure-one.v1")?.settings)
        XCTAssertEqual(settings.inputTransfer, .fujifilmFLog2)
        XCTAssertEqual(settings.inputSpace, .fujifilmFGamut)
        XCTAssertEqual(ColorPrimaries.fujifilmFGamut, ColorPrimaries.rec2020)
    }

    func testFLog2CGamutHasDistinctPublishedIdentityAndPreset() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.colorSpace(named: "F-Gamut C")?.id, .fujifilmFGamutC)
        XCTAssertEqual(catalog.colorSpace(named: "F-Log2 C")?.id, .fujifilmFGamutC)
        XCTAssertNotEqual(ColorPrimaries.fujifilmFGamutC, ColorPrimaries.fujifilmFGamut)
        XCTAssertEqual(ColorPrimaries.fujifilmFGamutC.red.x, 0.73470, accuracy: 0)
        XCTAssertEqual(ColorPrimaries.fujifilmFGamutC.red.y, 0.26530, accuracy: 0)
        XCTAssertEqual(ColorPrimaries.fujifilmFGamutC.green.x, 0.02630, accuracy: 0)
        XCTAssertEqual(ColorPrimaries.fujifilmFGamutC.green.y, 0.97370, accuracy: 0)
        XCTAssertEqual(ColorPrimaries.fujifilmFGamutC.blue.x, 0.11730, accuracy: 0)
        XCTAssertEqual(ColorPrimaries.fujifilmFGamutC.blue.y, -0.02240, accuracy: 0)
        XCTAssertEqual(ColorPrimaries.fujifilmFGamutC.white.x, 0.31270, accuracy: 0)
        XCTAssertEqual(ColorPrimaries.fujifilmFGamutC.white.y, 0.32900, accuracy: 0)

        let descriptor = try XCTUnwrap(catalog.colorSpaces.first { $0.id == .fujifilmFGamutC })
        XCTAssertTrue(descriptor.source.contains("F-Log2C_DataSheet_E_Ver.1.0"))
        let preset = try XCTUnwrap(catalog.preset(named: "fujifilm.flog2c-exposure-one.v1")?.settings)
        XCTAssertEqual(preset.inputTransfer, .fujifilmFLog2)
        XCTAssertEqual(preset.outputTransfer, .fujifilmFLog2)
        XCTAssertEqual(preset.inputSpace, .fujifilmFGamutC)
        XCTAssertEqual(preset.outputSpace, .fujifilmFGamutC)
    }

    func testFLog2LegacyHasIndependentCatalogIdentity() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "F-Log2 (LUTCalc legacy)")?.id, .fujifilmFLog2LUTCalcLegacy)
        XCTAssertEqual(catalog.transfer(named: "F-Log2 (LUTCalc legacy)")?.linearReference, .legacyGrey02)
        let settings = try XCTUnwrap(catalog.preset(named: "fujifilm.flog2-legacy-exposure-one.v1")?.settings)
        XCTAssertEqual(settings.inputTransfer, .fujifilmFLog2LUTCalcLegacy)
        XCTAssertEqual(settings.outputTransfer, .fujifilmFLog2LUTCalcLegacy)
        XCTAssertEqual(settings.inputSpace, .fujifilmFGamut)
    }

    func testACEScctHasPublishedAP1Identity() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "ACEScct")?.id, .acesCCT)
        XCTAssertEqual(catalog.colorSpace(named: "ACEScg AP1")?.id, .acesAP1)
        let settings = try XCTUnwrap(catalog.preset(named: "aces.acescct-exposure-one.v1")?.settings)
        XCTAssertEqual(settings.inputTransfer, .acesCCT)
        XCTAssertEqual(settings.inputSpace, .acesAP1)
    }

    func testACESccHasPublishedAP1Identity() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "ACEScc")?.id, .acesCC)
        XCTAssertEqual(catalog.transfer(named: "ACEScc")?.linearReference, .sceneReflectance)
        let settings = try XCTUnwrap(catalog.preset(named: "aces.acescc-exposure-one.v1")?.settings)
        XCTAssertEqual(settings.inputTransfer, .acesCC)
        XCTAssertEqual(settings.outputTransfer, .acesCC)
        XCTAssertEqual(settings.inputSpace, .acesAP1)
        XCTAssertEqual(try TransformPlan(settings: settings).planVersion,
                       "minimal-acescc-v1:aces.cc.v1:aces.cc.v1:inSpace:aces.ap1.v1:outSpace:aces.ap1.v1")
    }

    func testACESproxyHasPublishedAP1Identities() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        for (name, id, preset) in [
            ("ACESproxy10", TransferID.acesProxy10, "aces.acesproxy10-exposure-one.v1"),
            ("ACESproxy12", TransferID.acesProxy12, "aces.acesproxy12-exposure-one.v1")
        ] {
            XCTAssertEqual(catalog.transfer(named: name)?.id, id)
            let settings = try XCTUnwrap(catalog.preset(named: preset)?.settings)
            XCTAssertEqual(settings.inputTransfer, id)
            XCTAssertEqual(settings.inputSpace, .acesAP1)
        }
    }

    func testILogUsesBT2020Identity() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "Insta360 I-Log")?.id, .insta360ILog)
        let settings = try XCTUnwrap(catalog.preset(named: "insta360.ilog-exposure-one.v1")?.settings)
        XCTAssertEqual(settings.inputTransfer, .insta360ILog)
        XCTAssertEqual(settings.inputSpace, .rec2020)
        XCTAssertEqual(settings.outputSpace, .rec2020)
    }

    func testMiLogUsesBT2020Identity() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "Xiaomi Mi-Log")?.id, .xiaomiMiLog)
        let settings = try XCTUnwrap(catalog.preset(named: "xiaomi.milog-exposure-one.v1")?.settings)
        XCTAssertEqual(settings.inputTransfer, .xiaomiMiLog)
        XCTAssertEqual(settings.inputSpace, .rec2020)
        XCTAssertEqual(settings.outputSpace, .rec2020)
    }

    func testLeicaLLogUsesBT2020CameraSubsetIdentity() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "Leica L-Log")?.id, .leicaLLog)
        let settings = try XCTUnwrap(catalog.preset(named: "leica.llog-exposure-one.v1")?.settings)
        XCTAssertEqual(settings.inputTransfer, .leicaLLog)
        XCTAssertEqual(settings.inputSpace, .rec2020)
        XCTAssertEqual(settings.outputSpace, .rec2020)
    }

    func testKineLog3UsesKinefinityWideGamutIdentity() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        XCTAssertEqual(catalog.transfer(named: "KineLOG3")?.id, .kineLog3)
        XCTAssertEqual(catalog.colorSpace(named: "Kinefinity Wide Gamut")?.id, .kinefinityWideGamut)
        let settings = try XCTUnwrap(catalog.preset(named: "kinefinity.kinelog3-exposure-one.v1")?.settings)
        XCTAssertEqual(settings.inputTransfer, .kineLog3)
        XCTAssertEqual(settings.inputSpace, .kinefinityWideGamut)
        XCTAssertEqual(settings.outputSpace, .kinefinityWideGamut)
    }
}
