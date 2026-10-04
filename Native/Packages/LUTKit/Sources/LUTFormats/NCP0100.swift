import Foundation

public enum NCP0100FailureCategory: String, Equatable, Sendable {
    case invalidLength
    case invalidSignature
    case unsupportedLayout
    case unsupportedProfile
    case invalidName
    case invalidControlPoints
    case invalidLUTCode
    /// Writing is deliberately unavailable until a vendor-backed fixture and
    /// independent Nikon software/device round trip establish the contract.
    case writeUnsupported
}

public struct NCP0100Failure: Error, Equatable, Sendable {
    public let category: NCP0100FailureCategory

    public init(_ category: NCP0100FailureCategory) {
        self.category = category
    }
}

public struct NCP0100ControlPoint: Equatable, Sendable {
    public let x: UInt8
    public let y: UInt8
}

/// Read-only view of the observed 638-byte NCP "0100" record layout.
/// Unknown bytes are not interpreted, and this type makes no camera compatibility claim.
public struct NCP0100PictureControl: Equatable, Sendable {
    public let name: String
    public let profileCode: UInt16
    public let rawAdjustments: [UInt8]
    public let controlPoints: [NCP0100ControlPoint]
    public let lutCodes: [UInt16]

    public var lutValues: [Double] {
        lutCodes.map { Double($0) / 32767.0 }
    }
}

public enum NCP0100Reader {
    public static let fileLength = 638
    public static let lutCount = 256

    public static func read(_ data: Data) throws -> NCP0100PictureControl {
        guard data.count == fileLength else { throw NCP0100Failure(.invalidLength) }
        let bytes = [UInt8](data)
        guard Array(bytes[0..<4]) == [0x4e, 0x43, 0x50, 0] else {
            throw NCP0100Failure(.invalidSignature)
        }

        func word(_ offset: Int) -> UInt32 {
            (UInt32(bytes[offset]) << 24) | (UInt32(bytes[offset + 1]) << 16) |
            (UInt32(bytes[offset + 2]) << 8) | UInt32(bytes[offset + 3])
        }
        func short(_ offset: Int) -> UInt16 {
            (UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
        }

        guard word(4) == 1, word(8) == 36,
              Array(bytes[12..<16]) == Array("0100".utf8),
              word(48) == 2, word(52) == 578,
              bytes[56] == 0x49, bytes[57] == 0x30,
              word(634) == 0 else {
            throw NCP0100Failure(.unsupportedLayout)
        }

        let nameBytes = Array(bytes[16..<36])
        let end = nameBytes.firstIndex(of: 0) ?? nameBytes.count
        guard nameBytes[end...].allSatisfy({ $0 == 0 }),
              nameBytes[..<end].allSatisfy({ (0x20...0x7e).contains($0) }),
              let name = String(bytes: nameBytes[..<end], encoding: .ascii) else {
            throw NCP0100Failure(.invalidName)
        }

        let profileCode = short(36)
        let knownProfiles: Set<UInt16> = [0x00c3, 0x0001, 0x03c2, 0x0014, 0x03d5,
                                          0x00d6, 0x0486, 0x04c7, 0x064d]
        guard knownProfiles.contains(profileCode) else {
            throw NCP0100Failure(.unsupportedProfile)
        }

        let count = Int(bytes[64])
        guard count <= 28 else { throw NCP0100Failure(.invalidControlPoints) }
        var points: [NCP0100ControlPoint] = []
        points.reserveCapacity(count)
        for index in 0..<count {
            let x = bytes[65 + 2 * index]
            let y = bytes[66 + 2 * index]
            if let last = points.last, x <= last.x {
                throw NCP0100Failure(.invalidControlPoints)
            }
            points.append(NCP0100ControlPoint(x: x, y: y))
        }

        var codes: [UInt16] = []
        codes.reserveCapacity(lutCount)
        for index in 0..<lutCount {
            let code = short(122 + index * 2)
            guard code <= 32767 else { throw NCP0100Failure(.invalidLUTCode) }
            codes.append(code)
        }

        return NCP0100PictureControl(name: name, profileCode: profileCode,
                                     rawAdjustments: Array(bytes[40..<48]),
                                     controlPoints: points, lutCodes: codes)
    }
}

/// Explicit write boundary for NCP 0100.
///
/// The repository has a third-party read-only layout observation, but no
/// model/firmware-scoped Nikon export evidence. Keeping this entry point
/// failure-only prevents callers from mistaking the observed layout for a
/// vendor-compatible encoder and guarantees that an existing target is never
/// touched.
public enum NCP0100Writer {
    public static func write(_ control: NCP0100PictureControl, to target: URL) throws {
        _ = control
        _ = target
        throw NCP0100Failure(.writeUnsupported)
    }
}
