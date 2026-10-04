import Foundation

/// Scene-exposure equations only. Sensor-normalized values have a different
/// black pedestal and unit, and must not enter a scene-reflectance plan.
public enum ARRILogCSceneAlgorithm: String, Codable, Sendable {
    case sup2Published = "arri.logc-sup2-compact-published.v1"
    case sup3Published = "arri.logc-sup3-compact-published.v1"

    public var transferID: TransferID {
        self == .sup2Published ? .arriLogCSUP2Scene : .arriLogCSUP3Scene
    }
    var firmware: ARRILogCCompact.Firmware { self == .sup2Published ? .sup2 : .sup3 }
}

public struct ARRILogCSceneSettings: Equatable, Codable, Sendable {
    public let algorithm: ARRILogCSceneAlgorithm
    public let exposureIndex: Int

    public init(algorithm: ARRILogCSceneAlgorithm, exposureIndex: Int) throws {
        _ = try ARRILogCCompact(firmware: algorithm.firmware, domain: .sceneExposure, exposureIndex: exposureIndex)
        self.algorithm = algorithm
        self.exposureIndex = exposureIndex
    }
    public func makeTransfer() throws -> ARRILogCCompact {
        try ARRILogCCompact(firmware: algorithm.firmware, domain: .sceneExposure, exposureIndex: exposureIndex)
    }
    private enum CodingKeys: String, CodingKey { case algorithm, exposureIndex }
    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(algorithm: fields.decode(ARRILogCSceneAlgorithm.self, forKey: .algorithm),
                      exposureIndex: fields.decode(Int.self, forKey: .exposureIndex))
    }
}

extension TransferID {
    public var requiresLogCSceneSettings: Bool { self == .arriLogCSUP2Scene || self == .arriLogCSUP3Scene }
}
