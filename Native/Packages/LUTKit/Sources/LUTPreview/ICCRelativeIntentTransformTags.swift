import Foundation

enum ICCRelativeIntentTransformTags {
    static func sourceCandidates(in profile: ICCProfileValidation) -> [String] {
        ["A2B1", "A2B0"].filter(profile.tagSignatures.contains)
    }

    static func targetCandidates(in profile: ICCProfileValidation) -> [String] {
        ["B2A1", "B2A0"].filter(profile.tagSignatures.contains)
    }

    static func source(in profile: ICCProfileValidation) -> String? {
        if profile.tagSignatures.contains("A2B1") { return "A2B1" }
        if profile.tagSignatures.contains("A2B0") { return "A2B0" }
        return nil
    }

    static func target(in profile: ICCProfileValidation) -> String? {
        if profile.tagSignatures.contains("B2A1") { return "B2A1" }
        if profile.tagSignatures.contains("B2A0") { return "B2A0" }
        return nil
    }
}
