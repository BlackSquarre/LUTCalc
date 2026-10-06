import Foundation
import Compression
import CryptoKit

public enum ICCLUTTagKind: String, Equatable, Sendable {
    case lut8 = "mft1"
    case lut16 = "mft2"
    case lutAToB = "mAB "
    case lutBToA = "mBA "
}

/// ICC profile/device classes defined by ICC.1. Unknown future classes remain
/// representable through the raw four-character header signature.
public enum ICCProfileClass: String, Equatable, Sendable {
    case inputDevice = "scnr"
    case displayDevice = "mntr"
    case outputDevice = "prtr"
    case deviceLink = "link"
    case colorSpace = "spac"
    case abstract = "abst"
    case namedColor = "nmcl"
}

public enum ICCPCSKind: String, Equatable, Sendable {
    case xyz = "XYZ "
    case lab = "Lab "
}

/// Structural metadata for ICC LUT tags. This is deliberately not a decoded
/// sample table: it records only dimensions and bounded section sizes until a
/// separately validated conversion path is available.
public struct ICCLUTTagMetadata: Equatable, Sendable {
    public let kind: ICCLUTTagKind
    public let inputChannels: Int
    public let outputChannels: Int
    public let gridPoints: Int?
    public let inputTableEntries: Int?
    public let outputTableEntries: Int?
    public let clutByteCount: Int?
}

public struct ICCProfileTagValidation: Equatable, Sendable {
    public let signature: String
    public let typeSignature: String
    public let offset: Int
    public let byteCount: Int
    /// Decoded only for the bounded common `text`, `desc`, and `mluc` payloads.
    /// Other ICC payloads remain structurally validated but opaque.
    public let textValue: String?
    /// Fixed-point metadata summaries for fixed-structure payloads. These
    /// values are descriptive only; they are never used for color conversion.
    public let fixedPointValues: [Double]?
    /// Unsigned integer metadata fields for fixed-structure payloads, in the
    /// order documented by the ICC type (for example `chrm` channels/colorant).
    public let integerValues: [Int]?
    /// Fixed-structure function or table count, when present (for example
    /// `para` function type or `curv` entry count).
    public let structureValue: Int?
    /// Multiple four-byte signatures carried by a fixed-structure payload.
    public let signatureValues: [String]?
    /// Parametric curve function type, when the payload is `para`.
    public let parametricFunctionType: Int?
    /// Decoded four-byte value for a `sig ` payload, when valid.
    public let signatureValue: String?
    /// Decoded u16 curve entries for a bounded `curv` payload.
    public let curveValues: [Double]?
    /// Structural dimensions for `mft1`/`mft2`/`mAB `/`mBA ` tags.
    public let lutMetadata: ICCLUTTagMetadata?
}

public struct ICCProfileValidation: Equatable, Sendable {
    public let byteCount: Int
    public let declaredByteCount: Int
    /// ICC header version encoded as an unsigned 8.8.8.8 value at offset 8.
    public let profileVersion: UInt32
    public let profileSignature: String
    /// ICC header platform signature at offset 40. Legacy synthetic fixtures
    /// may leave this field zeroed when the platform is unknown.
    public let platformSignature: String?
    /// ICC header creator signature at offset 80. Legacy synthetic fixtures
    /// may leave this field zeroed when the creator is unknown.
    public let creatorSignature: String?
    /// ICC header device manufacturer signature at offset 48. Legacy
    /// synthetic fixtures may leave this field zeroed when unknown.
    public let manufacturerSignature: String?
    /// ICC header device model signature at offset 52. Legacy synthetic
    /// fixtures may leave this field zeroed when unknown.
    public let modelSignature: String?
    /// ICC profile/device class from header offset 12. Synthetic legacy
    /// fixtures may leave this header field zeroed, in which case it is nil.
    public let profileClassSignature: String?
    public let profileClass: ICCProfileClass?
    public let colorSpaceSignature: String
    /// Number of channels implied by the ICC color-space signature when the
    /// standard defines it. Unknown four-character spaces remain nil.
    public let colorChannelCount: Int?
    public let pcsSignature: String
    public let pcsKind: ICCPCSKind?
    /// ICC header rendering intent (0..3), retained as metadata only.
    public let renderingIntent: Int
    /// ICC header flags (bits 0 and 1 are defined by ICC.1).
    public let profileFlags: UInt32
    /// ICC device attributes (bits 0...3 are defined by ICC.1).
    public let deviceAttributes: UInt64
    public let tagCount: Int
    public let tagSignatures: [String]
    public let tags: [ICCProfileTagValidation]
    public let sha256: String
}

public enum ICCProfileError: Error, Equatable, Sendable {
    case tooShort
    case declaredLengthMismatch
    case invalidProfileVersion
    case invalidSignature
    case invalidPlatformSignature
    case invalidCreatorSignature
    case invalidManufacturerSignature
    case invalidModelSignature
    case invalidProfileID
    case invalidProfileClass
    case invalidColorSpaceSignature
    case invalidPCSSignature
    case invalidRenderingIntent
    case invalidProfileFlags
    case invalidDeviceAttributes
    case invalidTagTable
    case invalidTagRange
    case invalidTagPayload
    case duplicateTag
    case invalidPNG
    case unsupportedCompression
    case decompressionFailed
}

public enum ICCProfileValidator {
    public static let maxProfileBytes = 16 * 1024 * 1024

    /// Returns one validated user-supplied tag payload without retaining it in
    /// the profile summary. Callers must consume the bytes immediately.
    public static func payload(forTag signature: String, in data: Data) throws -> Data {
        guard signature.utf8.count == 4 else { throw ICCProfileError.invalidTagTable }
        _ = try validate(data)
        let bytes = [UInt8](data)
        let tagCount = Int(bytes[128]) << 24 | Int(bytes[129]) << 16 |
            Int(bytes[130]) << 8 | Int(bytes[131])
        for index in 0..<tagCount {
            let start = 132 + index * 12
            let tag = String(bytes: bytes[start..<(start + 4)], encoding: .ascii) ?? ""
            guard tag != signature else {
                let offset = Int(bytes[start + 4]) << 24 | Int(bytes[start + 5]) << 16 |
                    Int(bytes[start + 6]) << 8 | Int(bytes[start + 7])
                let size = Int(bytes[start + 8]) << 24 | Int(bytes[start + 9]) << 16 |
                    Int(bytes[start + 10]) << 8 | Int(bytes[start + 11])
                return Data(bytes[offset..<(offset + size)])
            }
        }
        throw ICCProfileError.invalidTagRange
    }

    public static func validate(_ data: Data) throws -> ICCProfileValidation {
        guard data.count >= 132, data.count <= maxProfileBytes else { throw ICCProfileError.tooShort }
        let bytes = [UInt8](data)
        let declared = Int(bytes[0]) << 24 | Int(bytes[1]) << 16 | Int(bytes[2]) << 8 | Int(bytes[3])
        guard declared == data.count else { throw ICCProfileError.declaredLengthMismatch }
        let profileVersion = UInt32(bytes[8]) << 24 | UInt32(bytes[9]) << 16 |
            UInt32(bytes[10]) << 8 | UInt32(bytes[11])
        // ICC.1 encodes major/minor/bug-fix in the upper 16 bits. The lower
        // 16 bits are reserved and must remain zero; accepting a zero version
        // preserves legacy synthetic fixtures with unspecified metadata.
        guard (profileVersion & 0x0000FFFF) == 0 else {
            throw ICCProfileError.invalidProfileVersion
        }
        let signature = String(bytes: bytes[36..<40], encoding: .ascii) ?? ""
        guard signature == "acsp" else { throw ICCProfileError.invalidSignature }
        let rawPlatform = String(bytes: bytes[40..<44], encoding: .ascii) ?? ""
        let platform: String?
        if bytes[40..<44].allSatisfy({ $0 == 0 }) {
            platform = nil
        } else {
            guard Self.validSignature(rawPlatform) else { throw ICCProfileError.invalidPlatformSignature }
            platform = rawPlatform
        }
        let rawCreator = String(bytes: bytes[80..<84], encoding: .ascii) ?? ""
        let creator: String?
        if bytes[80..<84].allSatisfy({ $0 == 0 }) {
            creator = nil
        } else {
            guard Self.validSignature(rawCreator) else { throw ICCProfileError.invalidCreatorSignature }
            creator = rawCreator
        }
        let rawManufacturer = String(bytes: bytes[48..<52], encoding: .ascii) ?? ""
        let manufacturer: String?
        if bytes[48..<52].allSatisfy({ $0 == 0 }) {
            manufacturer = nil
        } else {
            guard Self.validSignature(rawManufacturer) else { throw ICCProfileError.invalidManufacturerSignature }
            manufacturer = rawManufacturer
        }
        let rawModel = String(bytes: bytes[52..<56], encoding: .ascii) ?? ""
        let model: String?
        if bytes[52..<56].allSatisfy({ $0 == 0 }) {
            model = nil
        } else {
            guard Self.validSignature(rawModel) else { throw ICCProfileError.invalidModelSignature }
            model = rawModel
        }
        // ICC.1 permits an all-zero profile ID when the digest is unavailable.
        // Otherwise it is the MD5 of the complete profile with this 16-byte
        // field itself zeroed (the ID is metadata, never conversion input).
        let profileID = Array(bytes[84..<100])
        if profileID.contains(where: { $0 != 0 }) {
            var digestInput = bytes
            digestInput.replaceSubrange(84..<100, with: repeatElement(UInt8(0), count: 16))
            let expected = Array(Insecure.MD5.hash(data: Data(digestInput)))
            guard profileID == expected else { throw ICCProfileError.invalidProfileID }
        }
        // ICC.1 reserves bytes 100...127 in the profile header. They must be
        // zero so future header extensions cannot be mistaken for this format.
        guard bytes[100..<128].allSatisfy({ $0 == 0 }) else {
            throw ICCProfileError.invalidTagTable
        }
        let rawProfileClass = String(bytes: bytes[12..<16], encoding: .ascii) ?? ""
        let profileClass: String?
        if bytes[12..<16].allSatisfy({ $0 == 0 }) {
            profileClass = nil
        } else {
            guard Self.validSignature(rawProfileClass) else { throw ICCProfileError.invalidProfileClass }
            profileClass = rawProfileClass
        }
        let colorSpace = String(bytes: bytes[16..<20], encoding: .ascii) ?? ""
        guard Self.validSignature(colorSpace) else { throw ICCProfileError.invalidColorSpaceSignature }
        let pcs = String(bytes: bytes[20..<24], encoding: .ascii) ?? ""
        guard Self.validSignature(pcs) else { throw ICCProfileError.invalidPCSSignature }
        let renderingIntent = Int(bytes[64]) << 24 | Int(bytes[65]) << 16 |
            Int(bytes[66]) << 8 | Int(bytes[67])
        guard (0...3).contains(renderingIntent) else {
            throw ICCProfileError.invalidRenderingIntent
        }
        let profileFlags = UInt32(bytes[44]) << 24 | UInt32(bytes[45]) << 16 |
            UInt32(bytes[46]) << 8 | UInt32(bytes[47])
        // ICC.1 defines only embedded (bit 0) and independent (bit 1).
        guard (profileFlags & ~UInt32(0x3)) == 0 else {
            throw ICCProfileError.invalidProfileFlags
        }
        var deviceAttributes: UInt64 = 0
        for byte in bytes[56..<64] {
            deviceAttributes = (deviceAttributes << 8) | UInt64(byte)
        }
        // ICC.1 defines transparency, matte, negative and black-and-white
        // in the low four bits; all higher bits are reserved.
        guard (deviceAttributes & ~UInt64(0xF)) == 0 else {
            throw ICCProfileError.invalidDeviceAttributes
        }
        let tagCount = Int(bytes[128]) << 24 | Int(bytes[129]) << 16 |
            Int(bytes[130]) << 8 | Int(bytes[131])
        guard tagCount <= 4096 else { throw ICCProfileError.invalidTagTable }
        let (tableBytes, tableOverflow) = tagCount.multipliedReportingOverflow(by: 12)
        let (tableEnd, endOverflow) = 132.addingReportingOverflow(tableBytes)
        guard !tableOverflow, !endOverflow, tableEnd <= data.count else {
            throw ICCProfileError.invalidTagTable
        }
        var tagSignatures: [String] = []
        var tags: [ICCProfileTagValidation] = []
        var seenTags = Set<String>()
        tagSignatures.reserveCapacity(tagCount)
        tags.reserveCapacity(tagCount)
        for index in 0..<tagCount {
            let start = 132 + index * 12
            let tag = String(bytes: bytes[start..<(start + 4)], encoding: .ascii) ?? ""
            guard Self.validSignature(tag) else { throw ICCProfileError.invalidTagTable }
            guard seenTags.insert(tag).inserted else { throw ICCProfileError.duplicateTag }
            let offset = Int(bytes[start + 4]) << 24 | Int(bytes[start + 5]) << 16 |
                Int(bytes[start + 6]) << 8 | Int(bytes[start + 7])
            let size = Int(bytes[start + 8]) << 24 | Int(bytes[start + 9]) << 16 |
                Int(bytes[start + 10]) << 8 | Int(bytes[start + 11])
            guard offset % 4 == 0 else { throw ICCProfileError.invalidTagRange }
            let (tagEnd, tagOverflow) = offset.addingReportingOverflow(size)
            guard size > 0, offset >= tableEnd, !tagOverflow, tagEnd <= data.count else {
                throw ICCProfileError.invalidTagRange
            }
            let payload = Data(bytes[offset..<tagEnd])
            // All ICC tag payloads start with a four-byte type signature and a
            // four-byte reserved field. Keep the reserved bytes opaque, but
            // require the complete fixed header before interpreting any tag.
            guard payload.count >= 8,
                  payload[payload.startIndex + 4..<payload.startIndex + 8].allSatisfy({ $0 == 0 })
            else { throw ICCProfileError.invalidTagPayload }
            let typeSignature = String(bytes: payload.prefix(4), encoding: .ascii) ?? ""
            guard Self.validSignature(typeSignature) else { throw ICCProfileError.invalidTagPayload }
            let summary = try Self.decodeCommonTextPayload(typeSignature, payload,
                                                           colorSpace: colorSpace)
            tagSignatures.append(tag)
            tags.append(ICCProfileTagValidation(signature: tag, typeSignature: typeSignature,
                                                offset: offset, byteCount: size,
                                                textValue: summary.textValue,
                                                fixedPointValues: summary.fixedPointValues,
                                                integerValues: summary.integerValues,
                                                structureValue: summary.structureValue,
                                                signatureValues: summary.signatureValues,
                                                parametricFunctionType: summary.parametricFunctionType,
                                                signatureValue: summary.signatureValue,
                                                curveValues: summary.curveValues,
                                                lutMetadata: summary.lutMetadata))
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return ICCProfileValidation(byteCount: data.count, declaredByteCount: declared,
                                    profileVersion: profileVersion,
                                    profileSignature: signature,
                                    platformSignature: platform, creatorSignature: creator,
                                    manufacturerSignature: manufacturer, modelSignature: model,
                                    profileClassSignature: profileClass,
                                    profileClass: profileClass.flatMap(ICCProfileClass.init(rawValue:)),
                                    colorSpaceSignature: colorSpace,
                                    colorChannelCount: Self.colorChannelCount(colorSpace),
                                    pcsSignature: pcs,
                                    pcsKind: ICCPCSKind(rawValue: pcs), renderingIntent: renderingIntent,
                                    profileFlags: profileFlags, deviceAttributes: deviceAttributes,
                                    tagCount: tagCount,
                                    tagSignatures: tagSignatures, tags: tags, sha256: digest)
    }

    private struct ICCPayloadSummary {
        let textValue: String?
        let fixedPointValues: [Double]?
        let integerValues: [Int]?
        let structureValue: Int?
        let signatureValues: [String]?
        let parametricFunctionType: Int?
        let signatureValue: String?
        let curveValues: [Double]?
        let lutMetadata: ICCLUTTagMetadata?

        init(
            textValue: String? = nil,
            fixedPointValues: [Double]? = nil,
            integerValues: [Int]? = nil,
            structureValue: Int? = nil,
            signatureValues: [String]? = nil,
            parametricFunctionType: Int? = nil,
            signatureValue: String? = nil,
            curveValues: [Double]? = nil,
            lutMetadata: ICCLUTTagMetadata? = nil
        ) {
            self.textValue = textValue
            self.fixedPointValues = fixedPointValues
            self.integerValues = integerValues
            self.structureValue = structureValue
            self.signatureValues = signatureValues
            self.parametricFunctionType = parametricFunctionType
            self.signatureValue = signatureValue
            self.curveValues = curveValues
            self.lutMetadata = lutMetadata
        }
    }

    private static func decodeCommonTextPayload(_ type: String, _ payload: Data,
                                                colorSpace: String) throws -> ICCPayloadSummary {
        let bytes = [UInt8](payload)
        switch type {
        case "mft1", "mft2", "mAB ", "mBA ":
            return ICCPayloadSummary(lutMetadata: try decodeLUTPayload(type, bytes))
        case "text":
            guard bytes.count >= 8 else { throw ICCProfileError.invalidTagPayload }
            var value = Array(bytes.dropFirst(8))
            if value.last == 0 { value.removeLast() }
            return ICCPayloadSummary(textValue: try decodeASCII(value, allowEmpty: true),
                                     fixedPointValues: nil, integerValues: nil, structureValue: nil,
                                     signatureValues: nil, parametricFunctionType: nil, signatureValue: nil)
        case "desc":
            guard bytes.count >= 12 else { throw ICCProfileError.invalidTagPayload }
            let length = try readUInt32(bytes, at: 8)
            let (end, overflow) = 12.addingReportingOverflow(length)
            guard length > 0, !overflow, end <= bytes.count else {
                throw ICCProfileError.invalidTagPayload
            }
            var value = Array(bytes[12..<end])
            guard value.last == 0 else { throw ICCProfileError.invalidTagPayload }
            value.removeLast()
            return ICCPayloadSummary(textValue: try decodeASCII(value, allowEmpty: true),
                                     fixedPointValues: nil, integerValues: nil, structureValue: nil,
                                     signatureValues: nil, parametricFunctionType: nil, signatureValue: nil)
        case "mluc":
            guard bytes.count >= 16 else { throw ICCProfileError.invalidTagPayload }
            let recordCount = try readUInt32(bytes, at: 8)
            let recordSize = try readUInt32(bytes, at: 12)
            guard recordCount > 0, recordSize == 12 else {
                throw ICCProfileError.invalidTagPayload
            }
            let (tableBytes, tableOverflow) = recordCount.multipliedReportingOverflow(by: recordSize)
            let (tableEnd, endOverflow) = 16.addingReportingOverflow(tableBytes)
            guard !tableOverflow, !endOverflow, tableEnd <= bytes.count else {
                throw ICCProfileError.invalidTagPayload
            }
            var firstValue: String?
            for index in 0..<recordCount {
                let start = 16 + index * recordSize
                let length = try readUInt32(bytes, at: start + 4)
                let offset = try readUInt32(bytes, at: start + 8)
                let (end, overflow) = offset.addingReportingOverflow(length)
                guard length % 2 == 0, offset >= tableEnd, !overflow, end <= bytes.count else {
                    throw ICCProfileError.invalidTagPayload
                }
                let valueData = Data(bytes[offset..<end])
                guard let value = String(data: valueData, encoding: .utf16BigEndian) else {
                    throw ICCProfileError.invalidTagPayload
                }
                if firstValue == nil { firstValue = value }
            }
            return ICCPayloadSummary(textValue: firstValue,
                                     fixedPointValues: nil, integerValues: nil, structureValue: nil,
                                     signatureValues: nil, parametricFunctionType: nil, signatureValue: nil)
        case "XYZ ":
            guard bytes.count >= 20, (bytes.count - 8) % 12 == 0 else {
                throw ICCProfileError.invalidTagPayload
            }
            var values: [Double] = []
            values.reserveCapacity((bytes.count - 8) / 4)
            for offset in stride(from: 8, to: bytes.count, by: 4) {
                let raw = try readInt32(bytes, at: offset)
                values.append(Double(raw) / 65536.0)
            }
            return ICCPayloadSummary(textValue: nil, fixedPointValues: values,
                                     integerValues: nil, structureValue: nil, signatureValues: nil,
                                     parametricFunctionType: nil, signatureValue: nil)
        case "sig ":
            guard bytes.count >= 12 else { throw ICCProfileError.invalidTagPayload }
            let value = String(bytes: bytes[8..<12], encoding: .ascii) ?? ""
            guard validSignature(value) else { throw ICCProfileError.invalidTagPayload }
            return ICCPayloadSummary(textValue: nil, fixedPointValues: nil,
                                     integerValues: nil, structureValue: nil, signatureValues: nil,
                                     parametricFunctionType: nil, signatureValue: value)
        case "cicp":
            guard bytes.count == 12 else { throw ICCProfileError.invalidTagPayload }
            return ICCPayloadSummary(textValue: nil, fixedPointValues: nil,
                                     integerValues: bytes[8..<12].map(Int.init), structureValue: nil,
                                     signatureValues: nil, parametricFunctionType: nil,
                                     signatureValue: nil)
        case "dtim":
            guard bytes.count == 20 else { throw ICCProfileError.invalidTagPayload }
            var values: [Int] = []
            values.reserveCapacity(6)
            for offset in stride(from: 8, to: 20, by: 2) {
                values.append(try readUInt16(bytes, at: offset))
            }
            let year = values[0]
            let month = values[1]
            let day = values[2]
            let leapYear = year.isMultiple(of: 4) &&
                (!year.isMultiple(of: 100) || year.isMultiple(of: 400))
            let monthDays: [Int] = [31, leapYear ? 29 : 28, 31, 30, 31, 30,
                                    31, 31, 30, 31, 30, 31]
            guard (1...9999).contains(year),
                  (1...12).contains(month),
                  (1...monthDays[month - 1]).contains(day),
                  values[3] <= 23, values[4] <= 59, values[5] <= 59 else {
                throw ICCProfileError.invalidTagPayload
            }
            return ICCPayloadSummary(textValue: nil, fixedPointValues: nil,
                                     integerValues: values, structureValue: nil,
                                     signatureValues: nil, parametricFunctionType: nil,
                                     signatureValue: nil)
        case "data":
            guard bytes.count >= 12 else { throw ICCProfileError.invalidTagPayload }
            let flag = try readUInt32(bytes, at: 8)
            guard flag == 0 || flag == 1 else { throw ICCProfileError.invalidTagPayload }
            if flag == 0 {
                let value = Array(bytes.dropFirst(12))
                guard value.last == 0, value.allSatisfy({ $0 <= 0x7F }) else {
                    throw ICCProfileError.invalidTagPayload
                }
            }
            return ICCPayloadSummary(textValue: nil, fixedPointValues: nil,
                                     integerValues: [flag], structureValue: bytes.count - 12,
                                     signatureValues: nil, parametricFunctionType: nil,
                                     signatureValue: nil)
        case "clro":
            guard bytes.count >= 12 else { throw ICCProfileError.invalidTagPayload }
            let count = Int(try readUInt32(bytes, at: 8))
            let (end, overflow) = 12.addingReportingOverflow(count)
            guard count > 0, !overflow, end == bytes.count,
                  let colorChannels = Self.colorChannelCount(colorSpace),
                  count == colorChannels else {
                throw ICCProfileError.invalidTagPayload
            }
            let order = bytes[12..<end].map(Int.init)
            guard order.count == count,
                  Set(order).count == count,
                  order.allSatisfy({ $0 < count }) else {
                throw ICCProfileError.invalidTagPayload
            }
            return ICCPayloadSummary(textValue: nil, fixedPointValues: nil,
                                     integerValues: order, structureValue: count,
                                     signatureValues: nil, parametricFunctionType: nil,
                                     signatureValue: nil)
        case "curv":
            guard bytes.count >= 12 else { throw ICCProfileError.invalidTagPayload }
            let count = try readUInt32(bytes, at: 8)
            let (entryBytes, overflow) = count.multipliedReportingOverflow(by: 2)
            let (end, endOverflow) = 12.addingReportingOverflow(entryBytes)
            guard !overflow, !endOverflow, end == bytes.count else {
                throw ICCProfileError.invalidTagPayload
            }
            var values: [Double] = []
            values.reserveCapacity(Int(count))
            for offset in stride(from: 12, to: end, by: 2) {
                let raw = try readUInt16(bytes, at: offset)
                values.append(Double(raw) / (count == 1 ? 256.0 : 65535.0))
            }
            return ICCPayloadSummary(textValue: nil, fixedPointValues: nil,
                                     integerValues: nil, structureValue: Int(count), signatureValues: nil,
                                     parametricFunctionType: nil, signatureValue: nil,
                                     curveValues: values)
        case "chrm":
            guard bytes.count >= 12 else { throw ICCProfileError.invalidTagPayload }
            let channels = try readUInt16(bytes, at: 8)
            let colorant = try readUInt16(bytes, at: 10)
            // ICC chromaticityType stores x/y u16Fixed16 coordinates for each
            // channel (two four-byte values per channel).
            let (valueBytes, overflow) = channels.multipliedReportingOverflow(by: 8)
            let (end, endOverflow) = 12.addingReportingOverflow(valueBytes)
            guard channels > 0, !overflow, !endOverflow, end == bytes.count else {
                throw ICCProfileError.invalidTagPayload
            }
            var values: [Double] = []
            values.reserveCapacity(channels * 2)
            for offset in stride(from: 12, to: end, by: 4) {
                values.append(Double(try readUInt32(bytes, at: offset)) / 65536.0)
            }
            return ICCPayloadSummary(textValue: nil, fixedPointValues: values,
                                     integerValues: [channels, colorant], structureValue: nil,
                                     signatureValues: nil, parametricFunctionType: nil, signatureValue: nil)
        case "para":
            guard bytes.count >= 12 else { throw ICCProfileError.invalidTagPayload }
            let functionType = try readUInt16(bytes, at: 8)
            let parameterCount: Int
            switch functionType {
            case 0: parameterCount = 1
            case 1: parameterCount = 3
            case 2: parameterCount = 4
            // ICC parametricCurveType function 3 has five parameters:
            // g, a, b, c and d. Function 4 is the seven-parameter form.
            case 3: parameterCount = 5
            case 4: parameterCount = 7
            default: throw ICCProfileError.invalidTagPayload
            }
            let (parameterBytes, overflow) = parameterCount.multipliedReportingOverflow(by: 4)
            let (end, endOverflow) = 12.addingReportingOverflow(parameterBytes)
            guard !overflow, !endOverflow, end == bytes.count else {
                throw ICCProfileError.invalidTagPayload
            }
            var values: [Double] = []
            values.reserveCapacity(parameterCount)
            for offset in stride(from: 12, to: end, by: 4) {
                values.append(Double(try readInt32(bytes, at: offset)) / 65536.0)
            }
            return ICCPayloadSummary(textValue: nil, fixedPointValues: values,
                                     integerValues: nil, structureValue: nil, signatureValues: nil,
                                     parametricFunctionType: functionType, signatureValue: nil,
                                     curveValues: nil)
        case "view":
            guard bytes.count == 36 else { throw ICCProfileError.invalidTagPayload }
            var values: [Double] = []
            values.reserveCapacity(6)
            for offset in stride(from: 8, to: 32, by: 4) {
                values.append(Double(try readInt32(bytes, at: offset)) / 65536.0)
            }
            return ICCPayloadSummary(textValue: nil, fixedPointValues: values,
                                     integerValues: [try readUInt32(bytes, at: 32)], structureValue: nil,
                                     signatureValues: nil, parametricFunctionType: nil,
                                     signatureValue: nil)
        case "meas":
            guard bytes.count == 36 else { throw ICCProfileError.invalidTagPayload }
            let observer = try readUInt32(bytes, at: 8)
            var values: [Double] = []
            values.reserveCapacity(4)
            for offset in stride(from: 12, to: 24, by: 4) {
                values.append(Double(try readInt32(bytes, at: offset)) / 65536.0)
            }
            values.append(Double(try readUInt32(bytes, at: 28)) / 65536.0)
            let geometry = try readUInt32(bytes, at: 24)
            let illuminant = try readUInt32(bytes, at: 32)
            return ICCPayloadSummary(textValue: nil, fixedPointValues: values,
                                     integerValues: [observer, geometry, illuminant], structureValue: nil,
                                     signatureValues: nil,
                                     parametricFunctionType: nil, signatureValue: nil)
        default:
            return ICCPayloadSummary(textValue: nil, fixedPointValues: nil,
                                     integerValues: nil, structureValue: nil, signatureValues: nil,
                                     parametricFunctionType: nil, signatureValue: nil)
        }
    }

    private static func decodeLUTPayload(_ type: String, _ bytes: [UInt8]) throws -> ICCLUTTagMetadata {
        guard bytes.count >= 12 else { throw ICCProfileError.invalidTagPayload }
        let kind: ICCLUTTagKind
        switch type {
        case "mft1": kind = .lut8
        case "mft2": kind = .lut16
        case "mAB ": kind = .lutAToB
        case "mBA ": kind = .lutBToA
        default: throw ICCProfileError.invalidTagPayload
        }
        let input = Int(bytes[8])
        let output = Int(bytes[9])
        guard (1...16).contains(input), (1...16).contains(output) else {
            throw ICCProfileError.invalidTagPayload
        }
        if kind == .lut8 || kind == .lut16 {
            guard bytes.count >= (kind == .lut8 ? 48 : 52), bytes[11] == 0 else {
                throw ICCProfileError.invalidTagPayload
            }
            let grid = Int(bytes[10])
            guard (1...255).contains(grid) else { throw ICCProfileError.invalidTagPayload }
            let power = powBounded(grid, input)
            let (clutCount, overflow) = power.multipliedReportingOverflow(by: output)
            guard !overflow else { throw ICCProfileError.invalidTagPayload }
            let entryBytes = kind == .lut8 ? 1 : 2
            let inputEntries = kind == .lut8 ? 256 : try readUInt16(bytes, at: 48)
            let outputEntries = kind == .lut8 ? 256 : try readUInt16(bytes, at: 50)
            guard inputEntries >= 2, inputEntries <= 65535,
                  outputEntries >= 2, outputEntries <= 65535 else {
                throw ICCProfileError.invalidTagPayload
            }
            let header = kind == .lut8 ? 48 : 52
            let (inputBytes, iOverflow) = input.multipliedReportingOverflow(by: inputEntries * entryBytes)
            let (clutBytes, cOverflow) = clutCount.multipliedReportingOverflow(by: entryBytes)
            let (outputBytes, oOverflow) = output.multipliedReportingOverflow(by: outputEntries * entryBytes)
            let total = header.addingReportingOverflow(inputBytes)
                .partialValue.addingReportingOverflow(clutBytes)
                .partialValue.addingReportingOverflow(outputBytes)
            guard !iOverflow, !cOverflow, !oOverflow, !total.overflow, total.partialValue == bytes.count else {
                throw ICCProfileError.invalidTagPayload
            }
            return ICCLUTTagMetadata(kind: kind, inputChannels: input, outputChannels: output,
                                     gridPoints: grid, inputTableEntries: inputEntries,
                                     outputTableEntries: outputEntries, clutByteCount: clutCount * entryBytes)
        }

        guard bytes.count >= 32 else { throw ICCProfileError.invalidTagPayload }
        var offsets: [Int] = []
        for offset in stride(from: 12, through: 28, by: 4) {
            let value = try readUInt32(bytes, at: offset)
            if value != 0 {
                guard value >= 32, value < bytes.count else { throw ICCProfileError.invalidTagPayload }
                offsets.append(value)
            }
        }
        // The five fields are semantic offsets (B, matrix, M, CLUT, A), not
        // a directory sorted by physical payload position.
        // A/B/M curve arrays may share storage; matrix and CLUT cannot alias
        // another processing element (ICC.1:2022-05, 10.12 and 10.13).
        let allOffsets = try stride(from: 12, through: 28, by: 4).map { try readUInt32(bytes, at: $0) }
        let matrixOffset = allOffsets[1]
        let clutOffset = allOffsets[3]
        guard offsets.allSatisfy({ $0 % 4 == 0 }),
              (matrixOffset == 0 || offsets.filter { $0 == matrixOffset }.count == 1),
              (clutOffset == 0 || offsets.filter { $0 == clutOffset }.count == 1) else {
            throw ICCProfileError.invalidTagPayload
        }
        return ICCLUTTagMetadata(kind: kind, inputChannels: input, outputChannels: output,
                                 gridPoints: nil, inputTableEntries: nil,
                                 outputTableEntries: nil, clutByteCount: nil)
    }

    private static func powBounded(_ base: Int, _ exponent: Int) -> Int {
        var result = 1
        for _ in 0..<exponent {
            let (next, overflow) = result.multipliedReportingOverflow(by: base)
            if overflow || next > maxProfileBytes { return maxProfileBytes + 1 }
            result = next
        }
        return result
    }

    private static func decodeASCII(_ bytes: [UInt8], allowEmpty: Bool) throws -> String {
        guard allowEmpty || !bytes.isEmpty,
              bytes.allSatisfy({ $0 <= 0x7F }) else {
            throw ICCProfileError.invalidTagPayload
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func readUInt32(_ bytes: [UInt8], at offset: Int) throws -> Int {
        guard offset >= 0, offset <= bytes.count - 4 else {
            throw ICCProfileError.invalidTagPayload
        }
        let value = Int(bytes[offset]) << 24 | Int(bytes[offset + 1]) << 16 |
            Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
        return value
    }

    private static func readUInt16(_ bytes: [UInt8], at offset: Int) throws -> Int {
        guard offset >= 0, offset <= bytes.count - 2 else {
            throw ICCProfileError.invalidTagPayload
        }
        return Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
    }

    private static func readInt32(_ bytes: [UInt8], at offset: Int) throws -> Int32 {
        guard offset >= 0, offset <= bytes.count - 4 else {
            throw ICCProfileError.invalidTagPayload
        }
        let bits = UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16 |
            UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
        return Int32(bitPattern: bits)
    }

    private static func colorChannelCount(_ signature: String) -> Int? {
        switch signature {
        case "GRAY": return 1
        case "RGB ", "XYZ ", "Lab ", "Luv ", "YCbr", "Yxy ",
             "HSV ", "HLS ", "CMY ": return 3
        case "CMYK": return 4
        default:
            guard signature.count == 4, signature.hasSuffix("CLR"),
                  let prefix = signature.unicodeScalars.first else { return nil }
            switch prefix.value {
            case 0x32...0x39: return Int(prefix.value - 0x30)
            case 0x41...0x46: return Int(prefix.value - 0x41 + 10)
            default: return nil
            }
        }
    }

    private static func validSignature(_ value: String) -> Bool {
        // ICC signatures are four printable ASCII bytes. Punctuation is
        // valid; restricting this to alphanumeric characters rejects legal
        // private or future signatures before their payload can be inspected.
        value.utf8.count == 4 && value.unicodeScalars.allSatisfy { scalar in
            (0x20...0x7E).contains(scalar.value)
        }
    }
}

struct SourceICCProfile: Sendable {
    let name: String
    let data: Data
    let validation: ICCProfileValidation
}

enum SourceICCReader {
    static func profile(from url: URL) throws -> SourceICCProfile? {
        let data: Data
        do { data = try Data(contentsOf: url, options: [.mappedIfSafe]) }
        catch { throw ICCProfileError.invalidPNG }
        let signature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        guard data.starts(with: signature) else { return nil }
        var offset = signature.count
        var foundICCProfile = false
        var decodedProfile: SourceICCProfile?
        while offset + 12 <= data.count {
            let length = Int(data[offset]) << 24 | Int(data[offset + 1]) << 16 |
                Int(data[offset + 2]) << 8 | Int(data[offset + 3])
            let contentStart = offset + 8
            let contentEnd = contentStart + length
            guard length >= 0, contentEnd + 4 <= data.count else { throw ICCProfileError.invalidPNG }
            let type = data[(offset + 4)..<contentStart]
            let expectedCRC = UInt32(data[contentEnd]) << 24 |
                UInt32(data[contentEnd + 1]) << 16 |
                UInt32(data[contentEnd + 2]) << 8 | UInt32(data[contentEnd + 3])
            let crcInput = Data(data[(offset + 4)..<contentEnd])
            guard crc32(crcInput) == expectedCRC else { throw ICCProfileError.invalidPNG }
            if type.elementsEqual(Data("iCCP".utf8)) {
                guard !foundICCProfile else { throw ICCProfileError.invalidPNG }
                foundICCProfile = true
                let content = Data(data[contentStart..<contentEnd])
                guard let zero = content.firstIndex(of: 0), zero > 0, zero + 2 < content.count else {
                    throw ICCProfileError.invalidPNG
                }
                let name = String(decoding: content[..<zero], as: UTF8.self)
                guard content[zero + 1] == 0 else { throw ICCProfileError.unsupportedCompression }
                let compressed = Data(content[(zero + 2)...])
                let profile = try decompressZlib(compressed)
                let validation = try ICCProfileValidator.validate(profile)
                decodedProfile = SourceICCProfile(name: name, data: profile, validation: validation)
            }
            offset = contentEnd + 4
            if type.elementsEqual(Data("IEND".utf8)) { break }
        }
        return decodedProfile
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var value: UInt32 = 0xFFFFFFFF
        for byte in data {
            value ^= UInt32(byte)
            for _ in 0..<8 {
                let mask: UInt32 = (value & 1) == 0 ? 0 : 0xFFFFFFFF
                value = (value >> 1) ^ (0xEDB88320 & mask)
            }
        }
        return ~value
    }

    private static func decompressZlib(_ compressed: Data) throws -> Data {
        guard compressed.count >= 6 else { throw ICCProfileError.decompressionFailed }
        let header = Int(compressed[0]) << 8 | Int(compressed[1])
        guard (compressed[0] & 0x0F) == 8, (header % 31) == 0 else {
            throw ICCProfileError.decompressionFailed
        }
        let raw = Data(compressed.dropFirst(2).dropLast(4))
        var capacity = max(4096, compressed.count * 4)
        while capacity <= ICCProfileValidator.maxProfileBytes {
            var output = [UInt8](repeating: 0, count: capacity)
            let decoded = output.withUnsafeMutableBytes { destination in
                raw.withUnsafeBytes { source in
                    compression_decode_buffer(destination.bindMemory(to: UInt8.self).baseAddress!,
                                               capacity, source.bindMemory(to: UInt8.self).baseAddress!,
                                               raw.count, nil, COMPRESSION_ZLIB)
                }
            }
            if decoded > 0 { return Data(output.prefix(decoded)) }
            capacity *= 2
        }
        throw ICCProfileError.decompressionFailed
    }
}
