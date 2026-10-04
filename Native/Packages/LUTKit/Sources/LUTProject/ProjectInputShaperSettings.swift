/// An explicit user asset applied through the existing linear input sampler.
/// Samples and domains remain in the original asset rather than project JSON.
public struct ProjectInputShaperSettings: Equatable, Codable, Sendable {
    public static let algorithm = "native.project-input-shaper-linear.v1"
    public let assetPath: String
    public let algorithm: String

    public init(assetPath: String, algorithm: String = Self.algorithm) {
        self.assetPath = assetPath
        self.algorithm = algorithm
    }
}
