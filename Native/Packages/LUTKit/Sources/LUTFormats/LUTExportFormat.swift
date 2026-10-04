public enum LUTExportFormat: String, Codable, Hashable, CaseIterable, Sendable {
    case cube
    case spi3d
    case spi1d
    case threeDL = "3dl"
    case ilut
    case olut
    case lut
    case vlt
}

