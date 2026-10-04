import Foundation

public enum ExposureBatchFailure:Error,Equatable,Sendable {
    case invalidSequence,resourceLimit,invalidFilename,duplicateFilename
    case checkpointMismatch,completedOutputChanged(Int),alreadyStarted
}

/// Rational ticks replace accumulated floating point steps. Stops replace the
/// base request exposure, matching Generate Set rather than adding to it.
public struct ExposureBatchSequence:Equatable,Codable,Sendable {
    public static let algorithm = "native.exposure-batch-rational.v1"
    public static let maximumItems = 1024
    public let minimumStops:Int,maximumStops:Int,subdivisions:Int
    public var stops:[Double] {
        let first=minimumStops*subdivisions
        return (0...((maximumStops-minimumStops)*subdivisions)).map {Double(first+$0)/Double(subdivisions)}
    }
    public init(minimumStops:Int = -2,maximumStops:Int = 2,subdivisions:Int = 3)throws {
        guard minimumStops<=maximumStops,(1...4).contains(subdivisions) else{throw ExposureBatchFailure.invalidSequence}
        let (span,a)=maximumStops.subtractingReportingOverflow(minimumStops)
        let (ticks,b)=span.multipliedReportingOverflow(by:subdivisions)
        let (_,c)=minimumStops.multipliedReportingOverflow(by:subdivisions)
        let (_,d)=maximumStops.multipliedReportingOverflow(by:subdivisions)
        guard !a,!b,!c,!d,ticks<Self.maximumItems else{throw ExposureBatchFailure.resourceLimit}
        self.minimumStops=minimumStops;self.maximumStops=maximumStops;self.subdivisions=subdivisions
    }
    public func filenames(basename: String, fileExtension: String) throws -> [String] {
        guard !basename.isEmpty, basename != ".", basename != "..",
              !basename.contains("/"), !basename.contains("\\"), !basename.contains("\0"),
              !fileExtension.isEmpty, !fileExtension.contains("/"), !fileExtension.contains("\\"), !fileExtension.contains("\0") else {
            throw ExposureBatchFailure.invalidFilename
        }
        var names = Set<String>()
        return try stops.map { stop in
            let suffix = stop == 0 ? "0-Native" : String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), stop)
                .replacingOccurrences(of: ".", with: "p")
            let name = basename + "_" + suffix + "." + fileExtension
            guard name.utf8.count <= 255 else { throw ExposureBatchFailure.invalidFilename }
            guard names.insert(name).inserted else { throw ExposureBatchFailure.duplicateFilename }
            return name
        }
    }
    private enum CodingKeys:String,CodingKey{case minimumStops,maximumStops,subdivisions}
    public init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        try self.init(minimumStops:c.decode(Int.self,forKey:.minimumStops),maximumStops:c.decode(Int.self,forKey:.maximumStops),subdivisions:c.decode(Int.self,forKey:.subdivisions))
    }
}
