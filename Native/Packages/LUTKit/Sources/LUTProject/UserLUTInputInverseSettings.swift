import LUTCore

/// 项目清单中对用户 LUT 独立 1D 输入反求的显式声明。
/// 该声明只描述资产和算法，不把任意 3D LUT 假定为可逆。
public struct UserLUTInputInverseSettings: Equatable, Codable, Sendable {
    public let assetPath: String
    public let interpolation: LUTInterpolation

    public init(assetPath: String, interpolation: LUTInterpolation) {
        self.assetPath = assetPath
        self.interpolation = interpolation
    }
}
