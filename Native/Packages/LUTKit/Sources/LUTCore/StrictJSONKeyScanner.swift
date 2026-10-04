import Foundation

package enum StrictJSONKeyError: Error, Equatable, Sendable {
    case malformed
    case structureLimit
    case duplicateKey(String)
}

package struct StrictJSONKeyScanner {
    private let bytes: [UInt8]
    private var offset = 0
    private var visited = 0

    package static func validate(_ data: Data) throws {
        guard String(data: data, encoding: .utf8) != nil else { throw StrictJSONKeyError.malformed }
        var scanner = Self(bytes: Array(data))
        try scanner.value(path: "", depth: 0)
        scanner.whitespace()
        guard scanner.offset == scanner.bytes.count else { throw StrictJSONKeyError.malformed }
    }

    private mutating func value(path: String, depth: Int) throws {
        visited += 1
        guard visited <= 65_536, depth <= 32 else { throw StrictJSONKeyError.structureLimit }
        whitespace()
        guard offset < bytes.count else { throw StrictJSONKeyError.malformed }
        switch bytes[offset] {
        case 0x7B: try object(path: path, depth: depth)
        case 0x5B: try array(path: path, depth: depth)
        case 0x22: _ = try string()
        default:
            let start = offset
            while offset < bytes.count, ![0x2C, 0x7D, 0x5D, 0x20, 0x09, 0x0A, 0x0D].contains(bytes[offset]) {
                offset += 1
            }
            guard offset > start else { throw StrictJSONKeyError.malformed }
        }
    }

    private mutating func object(path: String, depth: Int) throws {
        offset += 1
        whitespace()
        if take(0x7D) { return }
        var keys: Set<String> = []
        while true {
            let key = try string()
            let keyPath = path.isEmpty ? key : path + "." + key
            guard keys.insert(key).inserted else { throw StrictJSONKeyError.duplicateKey(keyPath) }
            whitespace()
            guard take(0x3A) else { throw StrictJSONKeyError.malformed }
            try value(path: keyPath, depth: depth + 1)
            whitespace()
            if take(0x7D) { return }
            guard take(0x2C) else { throw StrictJSONKeyError.malformed }
            whitespace()
        }
    }

    private mutating func array(path: String, depth: Int) throws {
        offset += 1
        whitespace()
        if take(0x5D) { return }
        var index = 0
        while true {
            try value(path: path + "[\(index)]", depth: depth + 1)
            index += 1
            whitespace()
            if take(0x5D) { return }
            guard take(0x2C) else { throw StrictJSONKeyError.malformed }
            whitespace()
        }
    }

    private mutating func string() throws -> String {
        guard take(0x22) else { throw StrictJSONKeyError.malformed }
        let start = offset - 1
        var escaped = false
        while offset < bytes.count {
            let byte = bytes[offset]
            offset += 1
            if escaped {
                escaped = false
            } else if byte == 0x5C {
                escaped = true
            } else if byte == 0x22 {
                do {
                    return try JSONDecoder().decode(String.self, from: Data(bytes[start..<offset]))
                } catch {
                    throw StrictJSONKeyError.malformed
                }
            }
        }
        throw StrictJSONKeyError.malformed
    }

    private mutating func whitespace() {
        while offset < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[offset]) {
            offset += 1
        }
    }

    private mutating func take(_ byte: UInt8) -> Bool {
        guard offset < bytes.count, bytes[offset] == byte else { return false }
        offset += 1
        return true
    }
}
