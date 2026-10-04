import Foundation
import LUTCatalog
import LUTCore

private enum Failure: Error { case mismatch(String) }

do {
    let catalog = try AlgorithmCatalog.builtIn()
    guard catalog.transfers.count == 76, catalog.colorSpaces.count == 20, catalog.presets.count == 72,
          CameraCatalog.profiles.count == 66, Set(CameraCatalog.profiles.map(\.id)).count == 66 else {
        throw Failure.mismatch("built-in counts")
    }
    guard catalog.transfer(named: "D-Log2")?.id == .djiDLog2,
          catalog.transfer(named: "sRGB")?.id == .srgbW3CExtended,
          catalog.transfer(named: "sRGB (LUTCalc legacy)")?.id == .srgbLUTCalcLegacy,
          catalog.transfer(named: "S-Log3")?.id == .sonySLog3,
          catalog.transfer(named: "Nikon N-Log")?.id == .nikonNLog,
          catalog.transfer(named: "Nikon N-Log (LUTCalc legacy)")?.id == .nikonNLogLUTCalcLegacy,
          catalog.transfer(named: "Cineon")?.id == .cineon,
          catalog.transfer(named: "Cineon (LUTCalc legacy)")?.id == .cineonLUTCalcLegacy,
          catalog.transfer(named: "REDLogFilm")?.id == .redLogFilm,
          catalog.transfer(named: "REDLogFilm (LUTCalc legacy)")?.id == .redLogFilmLUTCalcLegacy,
          catalog.transfer(named: "RED Log3G10 (LUTCalc legacy)")?.id == .redLog3G10LUTCalcLegacy,
          catalog.transfer(named: "Canon C-Log (LUTCalc legacy)")?.id == .canonCLogLUTCalcLegacy,
          catalog.transfer(named: "BMD Pocket Film (LUTCalc legacy)")?.id == .blackmagicPocketFilmLUTCalcLegacy,
          catalog.transfer(named: "BMD Film (LUTCalc legacy)")?.id == .blackmagicFilmLUTCalcLegacy,
          catalog.transfer(named: "BMD Film4k (LUTCalc legacy)")?.id == .blackmagicFilm4kLUTCalcLegacy,
          catalog.transfer(named: "BMD Film4.6k (LUTCalc legacy)")?.id == .blackmagicFilm46kLUTCalcLegacy,
          catalog.transfer(named: "Bolex Log (LUTCalc legacy)")?.id == .bolexLogLUTCalcLegacy,
          catalog.transfer(named: "Panalog (LUTCalc legacy)")?.id == .panalogLUTCalcLegacy,
          catalog.transfer(named: "DJI X5/X7/X9 DLog (LUTCalc legacy)")?.id == .djiX5LogLUTCalcLegacy,
          catalog.transfer(named: "DaVinci Intermediate (LUTCalc legacy)")?.id == .daVinciIntermediateLUTCalcLegacy,
          catalog.transfer(named: "F-Log (LUTCalc legacy)")?.id == .fujifilmFLogLUTCalcLegacy,
          catalog.transfer(named: "S-Log3 (LUTCalc legacy)")?.id == .sonySLog3LUTCalcLegacy,
          catalog.transfer(named: "S-Log2")?.id == .sonySLog2,
          catalog.transfer(named: "S-Log2 (LUTCalc legacy)")?.id == .sonySLog2LUTCalcLegacy,
          catalog.transfer(named: "S-Log")?.id == .sonySLog,
          catalog.transfer(named: "S-Log (LUTCalc legacy)")?.id == .sonySLogLUTCalcLegacy,
          catalog.colorSpace(named: "S-Gamut3.Cine")?.id == .sonySGamut3Cine,
          catalog.colorSpace(named: "S-Gamut3")?.id == .sonySGamut3,
          catalog.colorSpace(named: "S-Gamut")?.id == .sonySGamut,
          catalog.colorSpace(named: "REDWideGamutRGB")?.id == .redWideGamutRGB,
          catalog.transfer(named: "LogC4")?.id == .arriLogC4,
          catalog.colorSpace(named: "ARRI Wide Gamut 4")?.id == .arriWideGamut4,
          catalog.transfer(named: "V-Log")?.id == .panasonicVLog,
          catalog.colorSpace(named: "V-Gamut")?.id == .panasonicVGamut,
          catalog.transfer(named: "Apple Log")?.id == .appleLogOriginal,
          catalog.transfer(named: "Apple Log 2")?.id == .appleLog2,
          catalog.transfer(named: "Rec.2020 10-bit")?.id == .rec2020TenBit,
          catalog.transfer(named: "Rec2100 HLG")?.id == .rec2100HLG,
          catalog.transfer(named: "Rec2100 PQ")?.id == .rec2100PQ,
          catalog.transfer(named: "BT.1886")?.id == .bt1886,
          catalog.transfer(named: "ACESproxy10")?.id == .acesProxy10,
          catalog.transfer(named: "ACESproxy12")?.id == .acesProxy12,
          catalog.transfer(named: "CIE L*")?.id == .cieLStar,
          catalog.colorSpace(named: "Rec.2020")?.id == .rec2020,
          catalog.colorSpace(named: "Apple Wide Gamut")?.id == .appleWideGamut,
          catalog.transfer(named: "missing") == nil,
          catalog.colorSpace(named: "missing") == nil,
          catalog.preset(named: "missing") == nil else {
        throw Failure.mismatch("alias or unknown ID")
    }
    for item in catalog.transfers {
        guard item.source.isEmpty == false, item.id.rawValue.contains(".v"),
              catalog.transfer(named: item.id.rawValue)?.id == item.id else {
            throw Failure.mismatch("transfer provenance \(item.id)")
        }
    }
    for item in catalog.colorSpaces {
        guard item.source.isEmpty == false, item.id.rawValue.contains(".v"),
              catalog.colorSpace(named: item.id.rawValue)?.id == item.id else {
            throw Failure.mismatch("space provenance \(item.id)")
        }
    }
    for item in catalog.presets {
        guard catalog.transfer(named: item.settings.inputTransfer.rawValue) != nil,
              catalog.transfer(named: item.settings.outputTransfer.rawValue) != nil,
              catalog.colorSpace(named: item.settings.inputSpace.rawValue) != nil,
              catalog.colorSpace(named: item.settings.outputSpace.rawValue) != nil else {
            throw Failure.mismatch("preset reference \(item.id)")
        }
    }
    let dlog = TransferDescriptor(id: .djiDLog2, aliases: ["collision"], source: "source", linearReference: .sceneReflectance)
    let linear = TransferDescriptor(id: .linearScene, aliases: ["collision"], source: "source", linearReference: .sceneReflectance)
    let linearDistinct = TransferDescriptor(id: .linearScene, aliases: [], source: "source", linearReference: .sceneReflectance)
    do {
        _ = try AlgorithmCatalog(transfers: [dlog, linear], colorSpaces: [], presets: [])
        throw Failure.mismatch("duplicate alias accepted")
    } catch CatalogError.duplicateName(_) {}
    do {
        _ = try AlgorithmCatalog(transfers: [dlog, dlog], colorSpaces: [], presets: [])
        throw Failure.mismatch("duplicate ID accepted")
    } catch CatalogError.duplicateName(_) {}
    let unknown = PresetDescriptor(id: "broken", settings: TransformSettings(
        inputTransfer: .djiDLog2, outputTransfer: .linearScene,
        inputSpace: .djiDGamut2, outputSpace: .srgb,
        inputRange: .data, outputRange: .data, exposureStops: 1
    ))
    do {
        _ = try AlgorithmCatalog(transfers: [dlog, linearDistinct], colorSpaces: [], presets: [unknown])
        throw Failure.mismatch("unknown preset dependency accepted")
    } catch CatalogError.unknownReference(_) {}
    print("APP-03 注册表基础契约通过：\(catalog.transfers.count) 曲线、\(catalog.colorSpaces.count) 色域、\(catalog.presets.count) 预设、稳定 ID/别名/来源、重复与悬空引用拒绝")
} catch {
    fputs("LUTCatalogChecks: \(error)\n", stderr)
    exit(1)
}
