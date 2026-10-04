import Foundation
import LUTCore
import LUTFormats

private enum Failure: Error { case mismatch(String) }

private func cube(dimension: CubeDimension, domain: LUTDomain) throws -> CubeLUT {
    let count = dimension == .one ? 3 : 8
    let samples = try (0..<count).map { index in
        try RGB64(Double(index) / 7, Double(index) / 3 - 0.5, Double(index) / 11 + 1)
    }
    return try CubeLUT(dimension: dimension, size: dimension == .one ? 3 : 2,
                       domain: domain, samples: samples, title: "方言 Double")
}

private func volumeSamples() throws -> [RGB64] {
    var samples: [RGB64] = []
    samples.reserveCapacity(8)
    for index in 0..<8 {
        let red = Double(index % 2)
        let green = Double((index / 2) % 2)
        let blue = Double(index / 4)
        try samples.append(RGB64(red, green, blue))
    }
    return samples
}

do {
    guard CommandLine.arguments.count == 2 else { throw Failure.mismatch("output directory argument") }
    let directory = URL(fileURLWithPath: CommandLine.arguments[1])
    guard !FileManager.default.fileExists(atPath: directory.path) else {
        throw Failure.mismatch("output directory already exists")
    }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    let uniform = try LUTDomain(min: RGB64(-0.1, -0.1, -0.1), max: RGB64(1.5, 1.5, 1.5))
    let nonuniform = try LUTDomain(min: RGB64(-0.1, 0, 0.2), max: RGB64(1.5, 1.2, 2))
    for dimension in [CubeDimension.one, .three] {
        for (dialect, domain, name) in [
            (CubeDialect.general, LUTDomain.unit, "general"),
            (.resolveInputRange, uniform, "resolve"),
            (.domain, nonuniform, "domain"),
        ] {
            let source = try cube(dimension: dimension, domain: domain)
            let text = try CubeWriter.serialize(source, dialect: dialect)
            let readback = try CubeParser.parse(Data(text.utf8))
            guard source == readback else { throw Failure.mismatch("\(name) \(dimension)") }
            let file = directory.appendingPathComponent("\(name)-\(dimension.rawValue)d.cube")
            try Data(text.utf8).write(to: file, options: .atomic)
        }
    }
    do {
        _ = try CubeWriter.serialize(cube(dimension: .three, domain: uniform), dialect: .general)
        throw Failure.mismatch("general silently lost domain")
    } catch let error as CubeFailure where error.category == .unsupported {}
    do {
        _ = try CubeWriter.serialize(cube(dimension: .three, domain: nonuniform), dialect: .resolveInputRange)
        throw Failure.mismatch("resolve silently lost channel domain")
    } catch let error as CubeFailure where error.category == .unsupported {}
    let shaperDomain = try LUTDomain(min: RGB64(-1, -1, -1), max: RGB64(1, 1, 1))
    let cubeDomain = try LUTDomain(min: RGB64(0, 0, 0), max: RGB64(2, 2, 2))
    let shaper = try CubeShaper(size: 2, domain: shaperDomain,
                                samples: [RGB64(0, 0, 0), RGB64(2, 1, 0.5)])
    let volume = try volumeSamples()
    let combined = try CubeLUT(dimension: .three, size: 2, domain: cubeDomain,
                               samples: volume, title: "shaper 组合", shaper: shaper)
    let combinedText = try CubeWriter.serialize(combined, dialect: .resolveInputRange)
    guard try CubeParser.parse(Data(combinedText.utf8)) == combined else {
        throw Failure.mismatch("combined round trip")
    }
    let value = try combined.sample(RGB64(0, 0.5, 1), interpolation: .tetrahedral, outside: .reject)
    guard abs(value.r - 0.5) < 1e-15, abs(value.g - 0.375) < 1e-15,
          abs(value.b - 0.25) < 1e-15 else {
        throw Failure.mismatch("combined shaper before 3D")
    }
    for malformed in [
        combinedText.replacingOccurrences(of: "LUT_3D_SIZE 2\n", with: ""),
        combinedText.replacingOccurrences(of: "LUT_1D_SIZE 2\n", with: "LUT_1D_SIZE 2\nLUT_1D_SIZE 2\n"),
        combinedText.replacingOccurrences(of: "LUT_3D_INPUT_RANGE 0 2.0\n", with: "LUT_3D_INPUT_RANGE 0 2.0\nDOMAIN_MIN 0 0 0\n"),
        String(combinedText.dropLast(combinedText.split(separator: "\n").last!.count + 1)),
    ] {
        do {
            _ = try CubeParser.parse(Data(malformed.utf8))
            throw Failure.mismatch("malformed combined file accepted")
        } catch is CubeFailure {}
    }
    do {
        _ = try CubeWriter.serialize(combined, dialect: .domain)
        throw Failure.mismatch("combined domain dialect silently accepted")
    } catch let error as CubeFailure where error.category == .unsupported {}
    try Data(combinedText.utf8).write(to: directory.appendingPathComponent("resolve-shaper-3d.cube"), options: .atomic)
    print("H04 三种 CUBE 方言写出契约通过：1D/3D 各三类，非默认域保留与不支持时明确拒绝；目录 \(directory.path)")
} catch {
    fputs("LUTFormatChecks: \(error)\n", stderr)
    exit(1)
}
