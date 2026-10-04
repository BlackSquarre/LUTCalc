public enum MatrixError: Error, Equatable, Sendable {
    case invalidShape
    case singular
    case illConditioned
    case excessiveResidual
    case invalidChromaticity
    case invalidConeResponse
}

public struct Matrix3x3: Equatable, Sendable {
    public let rowMajor: [Double]

    public init(rowMajor: [Double]) throws {
        guard rowMajor.count == 9 else { throw MatrixError.invalidShape }
        guard rowMajor.allSatisfy(\.isFinite) else { throw NumericError.nonFinite }
        self.rowMajor = rowMajor
    }

    public static var identity: Matrix3x3 {
        try! Matrix3x3(rowMajor: [1, 0, 0, 0, 1, 0, 0, 0, 1])
    }

    public subscript(row: Int, column: Int) -> Double {
        precondition((0..<3).contains(row) && (0..<3).contains(column))
        return rowMajor[row * 3 + column]
    }

    public func applying(to input: RGB64) throws -> RGB64 {
        try RGB64(
            self[0, 0] * input.r + self[0, 1] * input.g + self[0, 2] * input.b,
            self[1, 0] * input.r + self[1, 1] * input.g + self[1, 2] * input.b,
            self[2, 0] * input.r + self[2, 1] * input.g + self[2, 2] * input.b
        )
    }

    public func multiplied(by right: Matrix3x3) throws -> Matrix3x3 {
        var output = [Double](repeating: 0, count: 9)
        for row in 0..<3 {
            for column in 0..<3 {
                output[row * 3 + column] = self[row, 0] * right[0, column]
                    + self[row, 1] * right[1, column]
                    + self[row, 2] * right[2, column]
            }
        }
        return try Matrix3x3(rowMajor: output)
    }

    private struct LU {
        var values: [Double]
        var permutation: [Int]
    }

    private func decomposed() throws -> LU {
        var values = rowMajor
        var permutation = [0, 1, 2]
        let rowScales = (0..<3).map { row in
            max(abs(values[row * 3]), abs(values[row * 3 + 1]), abs(values[row * 3 + 2]))
        }
        guard rowScales.allSatisfy({ $0 > 0 && $0.isFinite }) else { throw MatrixError.singular }
        for column in 0..<3 {
            let pivotRow = (column..<3).max { abs(values[$0 * 3 + column]) < abs(values[$1 * 3 + column]) }!
            let pivot = abs(values[pivotRow * 3 + column])
            guard pivot.isFinite, pivot > 0 else { throw MatrixError.singular }
            if pivotRow != column {
                for j in 0..<3 { values.swapAt(column * 3 + j, pivotRow * 3 + j) }
                permutation.swapAt(column, pivotRow)
            }
            let scale = rowScales[permutation[column]]
            guard pivot > 16 * Double.ulpOfOne * scale else { throw MatrixError.illConditioned }
            if column == 2 { break }
            for row in (column + 1)..<3 {
                values[row * 3 + column] /= values[column * 3 + column]
                for j in (column + 1)..<3 {
                    values[row * 3 + j] -= values[row * 3 + column] * values[column * 3 + j]
                }
            }
        }
        return LU(values: values, permutation: permutation)
    }

    private func solve(_ rhs: [Double], with lu: LU) throws -> [Double] {
        var result = lu.permutation.map { rhs[$0] }
        for row in 0..<3 {
            for column in 0..<row {
                result[row] -= lu.values[row * 3 + column] * result[column]
            }
        }
        for row in stride(from: 2, through: 0, by: -1) {
            for column in (row + 1)..<3 {
                result[row] -= lu.values[row * 3 + column] * result[column]
            }
            result[row] /= lu.values[row * 3 + row]
        }
        guard result.allSatisfy(\.isFinite) else { throw NumericError.nonFinite }
        return result
    }

    public func solving(_ rhs: RGB64) throws -> RGB64 {
        let values = try solve([rhs.r, rhs.g, rhs.b], with: decomposed())
        return try RGB64(values[0], values[1], values[2])
    }

    public func inverted(maxCondition: Double = 1e8) throws -> Matrix3x3 {
        let inverse: Matrix3x3
        if let exact = try exactUnimodularInverse() {
            inverse = exact
        } else {
            let lu = try decomposed()
            var result = [Double](repeating: 0, count: 9)
            for column in 0..<3 {
                var rhs = [Double](repeating: 0, count: 3)
                rhs[column] = 1
                let solution = try solve(rhs, with: lu)
                for row in 0..<3 { result[row * 3 + column] = solution[row] }
            }
            inverse = try Matrix3x3(rowMajor: result)
        }
        let condition = normInfinity * inverse.normInfinity
        guard condition.isFinite, condition <= maxCondition else { throw MatrixError.illConditioned }
        let product = try multiplied(by: inverse)
        let residual = (0..<3).map { row in
            (0..<3).reduce(0.0) { sum, column in
                sum + abs(product[row, column] - (row == column ? 1 : 0))
            }
        }.max()!
        guard residual <= 128 * Double.ulpOfOne * max(1, condition) else {
            throw MatrixError.excessiveResidual
        }
        return inverse
    }

    private func exactUnimodularInverse() throws -> Matrix3x3? {
        // Products and sums below are exact in Double for this bounded integer range.
        guard rowMajor.allSatisfy({ abs($0) <= 1024 && $0.rounded(.towardZero) == $0 }) else {
            return nil
        }
        let a = rowMajor[0], b = rowMajor[1], c = rowMajor[2]
        let d = rowMajor[3], e = rowMajor[4], f = rowMajor[5]
        let g = rowMajor[6], h = rowMajor[7], i = rowMajor[8]
        let adjugate = [
            e * i - f * h, c * h - b * i, b * f - c * e,
            f * g - d * i, a * i - c * g, c * d - a * f,
            d * h - e * g, b * g - a * h, a * e - b * d,
        ]
        let determinant = a * adjugate[0] + b * adjugate[3] + c * adjugate[6]
        guard abs(determinant) == 1 else { return nil }
        return try Matrix3x3(rowMajor: adjugate.map { $0 / determinant })
    }

    public var normInfinity: Double {
        (0..<3).map { row in (0..<3).reduce(0.0) { $0 + abs(self[row, $1]) } }.max()!
    }
}

public struct Chromaticity: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) throws {
        guard x.isFinite, y.isFinite, y != 0 else { throw MatrixError.invalidChromaticity }
        self.x = x
        self.y = y
    }

    public func xyz() throws -> RGB64 {
        try RGB64(x / y, 1, (1 - x - y) / y)
    }
}

public struct ColorPrimaries: Equatable, Sendable {
    public let red: Chromaticity
    public let green: Chromaticity
    public let blue: Chromaticity
    public let white: Chromaticity

    public init(red: Chromaticity, green: Chromaticity, blue: Chromaticity, white: Chromaticity) {
        self.red = red
        self.green = green
        self.blue = blue
        self.white = white
    }

    public static var djiDGamut2: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.7347, y: 0.2653),
            green: Chromaticity(x: 0.1600, y: 0.8400),
            blue: Chromaticity(x: 0.0900, y: -0.0800),
            white: Chromaticity(x: 0.3127, y: 0.3290)
        )
    }

    public static var acesAP0: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.73470, y: 0.26530),
            green: Chromaticity(x: 0.00000, y: 1.00000),
            blue: Chromaticity(x: 0.00010, y: -0.07700),
            white: Chromaticity(x: 0.32168, y: 0.33767)
        )
    }

    public static var sonySGamut3Cine: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.766, y: 0.275),
            green: Chromaticity(x: 0.225, y: 0.800),
            blue: Chromaticity(x: 0.089, y: -0.087),
            white: Chromaticity(x: 0.3127, y: 0.3290)
        )
    }

    public static var sonySGamut: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.730, y: 0.280),
            green: Chromaticity(x: 0.140, y: 0.855),
            blue: Chromaticity(x: 0.100, y: -0.050),
            white: Chromaticity(x: 0.3127, y: 0.3290)
        )
    }

    public static var sonySGamut3: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.730, y: 0.280),
            green: Chromaticity(x: 0.140, y: 0.855),
            blue: Chromaticity(x: 0.100, y: -0.050),
            white: Chromaticity(x: 0.3127, y: 0.3290)
        )
    }

    public static var redWideGamutRGB: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.780308, y: 0.304253),
            green: Chromaticity(x: 0.121595, y: 1.493994),
            blue: Chromaticity(x: 0.095612, y: -0.084589),
            white: Chromaticity(x: 0.3127, y: 0.3290)
        )
    }

    public static var arriWideGamut3: ColorPrimaries {
        // ARRI 2017 Log C VFX data, published chromaticities and D65 white.
        try! ColorPrimaries(
            red: Chromaticity(x: 0.6840, y: 0.3130),
            green: Chromaticity(x: 0.2210, y: 0.8480),
            blue: Chromaticity(x: 0.0861, y: -0.1020),
            white: Chromaticity(x: 0.3127, y: 0.3290)
        )
    }

    public static var arriWideGamut4: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.7347, y: 0.2653),
            green: Chromaticity(x: 0.1424, y: 0.8576),
            blue: Chromaticity(x: 0.0991, y: -0.0308),
            white: Chromaticity(x: 0.3127, y: 0.3290)
        )
    }

    public static var panasonicVGamut: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.730, y: 0.280),
            green: Chromaticity(x: 0.165, y: 0.840),
            blue: Chromaticity(x: 0.100, y: -0.030),
            white: Chromaticity(x: 0.3127, y: 0.3290)
        )
    }

    public static var blackmagicWideGamutGen5:ColorPrimaries {
        // Published ACES Gen5 CTL chromaticities, including its precise white.
        try! ColorPrimaries(red:Chromaticity(x:0.7177215,y:0.3171181),
            green:Chromaticity(x:0.2280410,y:0.8615690),
            blue:Chromaticity(x:0.1005841,y:-0.0820452),
            white:Chromaticity(x:0.3127170,y:0.3290312))
    }

    public static var canonCinemaGamut: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.7400, y: 0.2700),
            green: Chromaticity(x: 0.1700, y: 1.1400),
            blue: Chromaticity(x: 0.0800, y: -0.1000),
            white: Chromaticity(x: 0.3127, y: 0.3290)
        )
    }

    public static var fujifilmFGamut: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.70800, y: 0.29200),
            green: Chromaticity(x: 0.17000, y: 0.79700),
            blue: Chromaticity(x: 0.13100, y: 0.04600),
            white: Chromaticity(x: 0.31270, y: 0.32900)
        )
    }

    public static var fujifilmFGamutC: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.73470, y: 0.26530),
            green: Chromaticity(x: 0.02630, y: 0.97370),
            blue: Chromaticity(x: 0.11730, y: -0.02240),
            white: Chromaticity(x: 0.31270, y: 0.32900)
        )
    }

    public static var acesAP1: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.713, y: 0.293),
            green: Chromaticity(x: 0.165, y: 0.830),
            blue: Chromaticity(x: 0.128, y: 0.044),
            white: Chromaticity(x: 0.32168, y: 0.33767)
        )
    }

    public static var rec2020: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.70800, y: 0.29200),
            green: Chromaticity(x: 0.17000, y: 0.79700),
            blue: Chromaticity(x: 0.13100, y: 0.04600),
            white: Chromaticity(x: 0.31270, y: 0.32900)
        )
    }

    public static var appleWideGamut: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.725, y: 0.301),
            green: Chromaticity(x: 0.221, y: 0.814),
            blue: Chromaticity(x: 0.068, y: -0.076),
            white: Chromaticity(x: 0.3127, y: 0.3290)
        )
    }

    public static var kinefinityWideGamut: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.7571, y: 0.2282),
            green: Chromaticity(x: 0.2139, y: 1.1480),
            blue: Chromaticity(x: 0.0536, y: -0.2236),
            white: Chromaticity(x: 0.3127, y: 0.3290)
        )
    }

    public static var proPhoto: ColorPrimaries {
        // RIMM-ROMM chromaticities and D50 reference white (ITU-R BT.2380-0 §2.7).
        try! ColorPrimaries(
            red: Chromaticity(x: 0.7347, y: 0.2653),
            green: Chromaticity(x: 0.1596, y: 0.8404),
            blue: Chromaticity(x: 0.0366, y: 0.0001),
            white: Chromaticity(x: 0.34567, y: 0.35850)
        )
    }

    public static var srgb: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.640, y: 0.330),
            green: Chromaticity(x: 0.300, y: 0.600),
            blue: Chromaticity(x: 0.150, y: 0.060),
            white: Chromaticity(x: 0.3127, y: 0.3290)
        )
    }

    /// Display P3 primaries with the D65 white point. The transfer function
    /// remains an independent setting (normally the W3C sRGB curve).
    public static var displayP3: ColorPrimaries {
        try! ColorPrimaries(
            red: Chromaticity(x: 0.680, y: 0.320),
            green: Chromaticity(x: 0.265, y: 0.690),
            blue: Chromaticity(x: 0.150, y: 0.060),
            white: Chromaticity(x: 0.3127, y: 0.3290)
        )
    }

    public func rgbToXYZ() throws -> Matrix3x3 {
        let r = try red.xyz()
        let g = try green.xyz()
        let b = try blue.xyz()
        let p = try Matrix3x3(rowMajor: [r.r, g.r, b.r, 1, 1, 1, r.b, g.b, b.b])
        let scale = try p.solving(white.xyz())
        return try Matrix3x3(rowMajor: [
            r.r * scale.r, g.r * scale.g, b.r * scale.b,
            scale.r, scale.g, scale.b,
            r.b * scale.r, g.b * scale.g, b.b * scale.b,
        ])
    }

    public static func conversion(from source: ColorPrimaries, to destination: ColorPrimaries, adaptation: ChromaticAdaptation) throws -> Matrix3x3 {
        let src = try source.rgbToXYZ()
        let dstInverse = try destination.rgbToXYZ().inverted()
        let cat = try adaptation.matrix(from: source.white, to: destination.white)
        return try dstInverse.multiplied(by: cat).multiplied(by: src)
    }
}

public enum ChromaticAdaptation: String, Codable, Sendable {
    case cieCAT02
    case bradford

    public func matrix(from source: Chromaticity, to destination: Chromaticity) throws -> Matrix3x3 {
        if source == destination { return .identity }
        let a: Matrix3x3
        switch self {
        case .cieCAT02:
            a = try Matrix3x3(rowMajor: [
                0.7328, 0.4296, -0.1624,
                -0.7036, 1.6975, 0.0061,
                0.0030, 0.0136, 0.9834,
            ])
        case .bradford:
            a = try Matrix3x3(rowMajor: [
                0.8951, 0.2664, -0.1614,
                -0.7502, 1.7135, 0.0367,
                0.0389, -0.0685, 1.0296,
            ])
        }
        let src = try a.applying(to: source.xyz())
        let dst = try a.applying(to: destination.xyz())
        guard src.r != 0, src.g != 0, src.b != 0 else { throw MatrixError.invalidConeResponse }
        let diagonal = try Matrix3x3(rowMajor: [
            dst.r / src.r, 0, 0,
            0, dst.g / src.g, 0,
            0, 0, dst.b / src.b,
        ])
        return try a.inverted().multiplied(by: diagonal).multiplied(by: a)
    }
}
