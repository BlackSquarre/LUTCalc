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
        XCTAssertEqual(try TransformPlan(settings: settings).planVersion, "minimal-cie-lstar-v1+" + OutputCodeUnitPolicy.completeV2.rawValue)
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
        XCTAssertEqual(try TransformPlan(settings: settings).planVersion, "minimal-acescc-v1")
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
