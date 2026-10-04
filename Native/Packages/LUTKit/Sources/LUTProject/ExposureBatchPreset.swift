import Foundation
import LUTCore
import LUTFormats

/// Stored configuration is not a destination grant or an instruction to run.
public struct ExposureBatchPreset: Equatable, Codable, Sendable {
    public let algorithm: String
    public let sequence: ExposureBatchSequence
    public let basename: String
    public let format: LUTExportFormat
    public let threeDLFlavor: ThreeDLFlavor
    public let blockNodes: Int
    public let workerCount: Int

    public init(sequence: ExposureBatchSequence, basename: String, format: LUTExportFormat,
                blockNodes: Int = 4096, workerCount: Int = 2, threeDLFlavor: ThreeDLFlavor = .flame) throws {
        _ = try sequence.filenames(basename: basename, fileExtension: format.rawValue)
        guard blockNodes > 0, (1...4).contains(workerCount) else { throw ProjectError.invalidSettings }
        guard format == .threeDL || threeDLFlavor == .flame else { throw ProjectError.invalidSettings }
        algorithm = ExposureBatchSequence.algorithm
        self.sequence = sequence; self.basename = basename; self.format = format
        self.threeDLFlavor = threeDLFlavor
        self.blockNodes = blockNodes; self.workerCount = workerCount
    }
    private enum CodingKeys: String, CodingKey { case algorithm, sequence, basename, format, blockNodes, workerCount, threeDLFlavor }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let algorithm = try values.decode(String.self, forKey: .algorithm)
        guard algorithm == ExposureBatchSequence.algorithm else { throw ProjectError.unknownAlgorithm(algorithm) }
        try self.init(sequence: values.decode(ExposureBatchSequence.self, forKey: .sequence),
            basename: values.decode(String.self, forKey: .basename), format: values.decode(LUTExportFormat.self, forKey: .format),
            blockNodes: values.decode(Int.self, forKey: .blockNodes), workerCount: values.decode(Int.self, forKey: .workerCount),
            threeDLFlavor: values.contains(.threeDLFlavor) ? values.decode(ThreeDLFlavor.self, forKey: .threeDLFlavor) : .flame)
    }
}
