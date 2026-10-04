/// Explicit user LUT stage after output encoding and signal normalization.
/// The imported domain belongs to the LUT; no implicit input/gamut inference.
public struct UserLUTPostStageSettings: Equatable, Codable, Sendable {
    public let interpolation: LUTInterpolation
    public let outside: LUTOutsidePolicy

    public init(interpolation: LUTInterpolation, outside: LUTOutsidePolicy) {
        self.interpolation = interpolation
        self.outside = outside
    }
}
