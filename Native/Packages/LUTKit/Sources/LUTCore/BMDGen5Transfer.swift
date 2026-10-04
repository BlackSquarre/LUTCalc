import Foundation

public enum BMDGen5Transfer {
    public static let referenceURL = "https://github.com/aces-aswf/aces-input-and-colorspaces/blob/29b722bccd529460696a8382394504cae2e88419/blackmagic_design/CSC.Blackmagic.BMDFilm_WideGamut_Gen5_to_ACES.ctl"
    private static let a = 0.08692876065491224
    private static let b = 0.005494072432257808
    private static let c = 0.5300133392291939
    private static let d = 8.283605932402494
    private static let e = 0.09246575342465753
    private static let cut = 0.005
    public static func encodeSceneToData(_ x:Double)throws->Double {
        guard x.isFinite else {throw NumericError.nonFinite}
        let y=x<cut ? d*x+e : a*log(x+b)+c
        guard y.isFinite else {throw NumericError.nonFinite};return y
    }
    public static func decodeDataToScene(_ y:Double)throws->Double {
        guard y.isFinite else {throw NumericError.nonFinite}
        let x=y<d*cut+e ? (y-e)/d : exp((y-c)/a)-b
        guard x.isFinite else {throw NumericError.nonFinite};return x
    }
    // Historical rounded coefficients, approximate log base and 0.2 grey
    // units are separate from the published scene transfer.
    public static func encodeLegacyToData(_ x:Double)throws->Double {
        guard x.isFinite else {throw NumericError.nonFinite}
        let y=x>=0.005555556
            ? 0.074437531*log(x*0.9+0.005494072)/log(2.718281828)+0.516414159
            : (x+0.022202504)/0.156642493
        guard y.isFinite else {throw NumericError.nonFinite};return y
    }
    public static func decodeLegacyDataToLegacy(_ y:Double)throws->Double {
        guard y.isFinite else {throw NumericError.nonFinite}
        let x=y>=0.177206446
            ? (pow(2.718281828,(y-0.516414159)/0.074437531)-0.005494072)/0.9
            : 0.156642493*y-0.022202504
        guard x.isFinite else {throw NumericError.nonFinite};return x
    }
}
