import Foundation

/// REDLogFilm's registered analytic Cineon-style transfer.
///
/// The legacy registration uses the same 10-bit Cineon parameter tuple as the
/// existing Cineon implementation. It remains a distinct ID so metadata does
/// not silently change meaning if a RED-specific definition is added later.
public enum REDLogFilmTransfer {
    public static let referenceURL =
        "js/gamma.js:LUTGammaCineon REDLogFilm registration (cv=1023, bp=95, wp=685, nGamma=0.6, cv2d=0.002); shared analytic parameters independently cross-checked against Cineon"
    public static func encodeSceneToData(_ value: Double) throws -> Double { try CineonTransfer.encodeSceneToData(value) }
    public static func decodeDataToScene(_ value: Double) throws -> Double { try CineonTransfer.decodeDataToScene(value) }
    public static func encodeLegacyToData(_ value: Double) throws -> Double { try CineonTransfer.encodeLegacyToData(value) }
    public static func decodeDataToLegacy(_ value: Double) throws -> Double { try CineonTransfer.decodeDataToLegacy(value) }
}
