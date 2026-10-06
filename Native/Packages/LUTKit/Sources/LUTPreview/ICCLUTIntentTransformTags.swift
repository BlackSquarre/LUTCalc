import Foundation

/// ICC LUT tag selection for the intents whose transform is encoded by the
/// user-supplied A2B/B2A pipeline itself. Relative intent keeps the historical
/// A2B1/B2A1 to A2B0/B2A0 fallback; perceptual and saturation require their
/// exact intent tags and never borrow another intent's transform.
enum ICCLUTIntentTransformTags {
    static func sourceCandidates(in profile: ICCProfileValidation,
                                 intent: ICCMatrixTRCRenderingIntent) -> [String] {
        let names: [String]
        switch intent {
        case .perceptual: names = ["A2B0"]
        case .relativeColorimetric: names = ["A2B1", "A2B0"]
        case .saturation: names = ["A2B2"]
        case .absoluteColorimetric: names = ["A2B3"]
        }
        return names.filter(profile.tagSignatures.contains)
    }

    static func targetCandidates(in profile: ICCProfileValidation,
                                 intent: ICCMatrixTRCRenderingIntent) -> [String] {
        let names: [String]
        switch intent {
        case .perceptual: names = ["B2A0"]
        case .relativeColorimetric: names = ["B2A1", "B2A0"]
        case .saturation: names = ["B2A2"]
        case .absoluteColorimetric: names = ["B2A3"]
        }
        return names.filter(profile.tagSignatures.contains)
    }

    static func sourceName(_ intent: ICCMatrixTRCRenderingIntent) -> String {
        switch intent {
        case .perceptual: return "A2B0"
        case .relativeColorimetric: return "A2B1/A2B0"
        case .saturation: return "A2B2"
        case .absoluteColorimetric: return "A2B3"
        }
    }

    static func targetName(_ intent: ICCMatrixTRCRenderingIntent) -> String {
        switch intent {
        case .perceptual: return "B2A0"
        case .relativeColorimetric: return "B2A1/B2A0"
        case .saturation: return "B2A2"
        case .absoluteColorimetric: return "B2A3"
        }
    }
}
