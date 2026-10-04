import LUTCore

public enum CameraPresetResolver {
    public static func applying(_ camera:CameraExposureSettings,to settings:TransformSettings)throws->TransformSettings {
        try camera.validate()
        var result=settings
        if camera.inputPolicy != .explicitCurrentInput {
            let p=camera.profile
            let mapping:(TransferID,ColorSpaceID)
            switch (p.legacyGamma,p.legacyGamut) {
            case ("S-Log3","Sony S-Gamut3.cine"):
                mapping=(camera.inputPolicy == .legacyAvailableDefaults ? .sonySLog3LUTCalcLegacy : .sonySLog3,.sonySGamut3Cine)
            case ("S-Log3","Sony S-Gamut3"):
                mapping=(camera.inputPolicy == .legacyAvailableDefaults ? .sonySLog3LUTCalcLegacy : .sonySLog3,.sonySGamut3)
            case ("S-Log2","Sony S-Gamut"):
                mapping=(camera.inputPolicy == .legacyAvailableDefaults ? .sonySLog2LUTCalcLegacy : .sonySLog2,.sonySGamut)
            case ("S-Log","Sony S-Gamut"):
                mapping=(camera.inputPolicy == .legacyAvailableDefaults ? .sonySLogLUTCalcLegacy : .sonySLog,.sonySGamut)
            case ("Nikon N-Log", "Rec2020"):
                mapping=(camera.inputPolicy == .legacyAvailableDefaults ? .nikonNLogLUTCalcLegacy : .nikonNLog,.rec2020)
            case ("Cineon", "Rec709"):
                mapping=(camera.inputPolicy == .legacyAvailableDefaults ? .cineonLUTCalcLegacy : .cineon,.srgb)
            case ("Fujifilm F-Log2","Fujifilm F-Log Gamut"):
                mapping=(camera.inputPolicy == .legacyAvailableDefaults ? .fujifilmFLog2LUTCalcLegacy : .fujifilmFLog2,.fujifilmFGamut)
            case ("Fujifilm F-Log","Fujifilm F-Log Gamut") where camera.inputPolicy == .legacyAvailableDefaults:
                mapping=(.fujifilmFLogLUTCalcLegacy,.fujifilmFGamut)
            case ("LogC4","ARRI Wide Gamut 4") where camera.inputPolicy == .publishedAvailableDefaults:
                mapping=(.arriLogC4,.arriWideGamut4)
            case ("LogC (Sup 3.x & 4.x)","Alexa Wide Gamut") where camera.inputPolicy == .publishedAvailableDefaults:
                mapping=(.arriLogCSUP3Scene,.arriWideGamut3)
            case ("BMDFilm Gen5","Blackmagic Wide Gamut"):
                mapping=(camera.inputPolicy == .legacyAvailableDefaults ? .blackmagicFilmGen5LUTCalcLegacy : .blackmagicFilmGen5,.blackmagicWideGamutGen5)
            case ("Canon C-Log2", "Canon Cinema Gamut"):
                mapping=(camera.inputPolicy == .legacyAvailableDefaults ? .canonCLog2LUTCalcLegacy : .canonCLog2, .canonCinemaGamut)
            case ("C-Log", "Canon Cinema Gamut") where camera.inputPolicy == .legacyAvailableDefaults:
                mapping=(.canonCLogLUTCalcLegacy, .canonCinemaGamut)
            case ("Apple Log","Rec2020") where camera.inputPolicy == .publishedAvailableDefaults:
                mapping=(.appleLogOriginal,.rec2020)
            case ("Panasonic V-Log","Panasonic V-Gamut") where camera.inputPolicy == .publishedAvailableDefaults:
                mapping=(.panasonicVLog,.panasonicVGamut)
            default:throw CameraExposureError.unsupportedDefaults(p.id)
            }
            result=result.withInput(transfer:mapping.0,space:mapping.1).withInputRange(.data)
            if mapping.0 == .arriLogCSUP3Scene {
                result=result.withInputLogC(try ARRILogCSceneSettings(algorithm:.sup3Published,exposureIndex:camera.recordedISO))
            }
        }
        result=try camera.applyingExposure(to:result)
        _=try TransformPlan(settings:result)
        return result
    }
}
