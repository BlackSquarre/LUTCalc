import Foundation
import LUTCore
import LUTFormats

private enum CheckFailure: Error, CustomStringConvertible {
    case invalidFixture(String)
    case mismatch(String)

    var description: String {
        switch self {
        case .invalidFixture(let detail): "invalid fixture: \(detail)"
        case .mismatch(let detail): "mismatch: \(detail)"
        }
    }
}

private func dictionary(_ value: Any?, _ name: String) throws -> [String: Any] {
    guard let result = value as? [String: Any] else { throw CheckFailure.invalidFixture(name) }
    return result
}

private func array(_ value: Any?, _ name: String) throws -> [Any] {
    guard let result = value as? [Any] else { throw CheckFailure.invalidFixture(name) }
    return result
}

private func integer(_ value: Any?, _ name: String) throws -> Int {
    guard let result = value as? Int else { throw CheckFailure.invalidFixture(name) }
    return result
}

private func number(_ value: Any?, _ name: String) throws -> Double {
    guard let result = value as? Double else { throw CheckFailure.invalidFixture(name) }
    return result
}

private func vector(_ value: Any?, _ name: String) throws -> RGB64 {
    let values = try array(value, name)
    guard values.count == 3 else { throw CheckFailure.invalidFixture(name) }
    return try RGB64(number(values[0], name), number(values[1], name), number(values[2], name))
}

private func check(_ actual: Double, _ expected: Double, _ label: String) throws {
    let error = abs(actual - expected) / max(1, abs(expected))
    guard error <= 2e-12 else { throw CheckFailure.mismatch("\(label): \(actual) vs \(expected), scaled=\(error)") }
}

private func run(_ fixturePath: String) throws {
    let root = try dictionary(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: fixturePath))), "root")
    let ranges = try array(root["rangeCases"], "rangeCases")
    guard ranges.count == 12 else { throw CheckFailure.invalidFixture("range count") }
    for (index, raw) in ranges.enumerated() {
        let item = try dictionary(raw, "range \(index)")
        let bits = try integer(item["bits"], "bits")
        let range = try CodeRange.videoRGB(bitDepth: bits)
        guard range.blackCode == (try integer(item["black"], "black")),
              range.whiteCode == (try integer(item["white"], "white")),
              range.maxCode == (try integer(item["maxCode"], "maxCode")) else {
            throw CheckFailure.mismatch("range metadata \(index)")
        }
        let code = try integer(item["code"], "code")
        try check(Double(code) / Double(range.maxCode), number(item["data"], "data"), "range data \(index)")
        try check(range.dataToVideo(Double(code) / Double(range.maxCode)), number(item["video"], "video"), "range video \(index)")
        try check(range.videoToData(number(item["video"], "video")), number(item["data"], "data"), "range inverse \(index)")
    }

    let grid = try Grid3D(size: 3, domain: .unit)
    let nodes = try array(root["grid3"], "grid3")
    guard nodes.count == 27, grid.nodeCount == 27 else { throw CheckFailure.mismatch("grid count") }
    for (position, raw) in nodes.enumerated() {
        let item = try dictionary(raw, "grid \(position)")
        let index = try integer(item["index"], "index")
        guard position == index else { throw CheckFailure.mismatch("grid order \(position)") }
        let expected = try vector(item["coordinate"], "coordinate")
        let actual = try grid.coordinate(at: index)
        for channel in 0..<3 { try check(actual[channel], expected[channel], "grid \(index)/\(channel)") }
        let r = index % 3
        let g = (index / 3) % 3
        let b = index / 9
        guard try grid.nodeIndex(r: r, g: g, b: b) == index,
              try grid.channelOffset(r: r, g: g, b: b, channel: 2) == 3 * index + 2 else {
            throw CheckFailure.mismatch("grid indexing \(index)")
        }
    }

    for raw in try array(root["scaleCases"], "scaleCases") {
        let item = try dictionary(raw, "scale")
        let legacy = try number(item["legacy"], "legacy")
        let scene = try number(item["scene"], "scene")
        try check(LinearScale.legacyToScene(legacy), scene, "legacy to scene")
        try check(LinearScale.sceneToLegacy(scene), legacy, "scene to legacy")
    }

    for raw in try array(root["allocationCases"], "allocationCases") {
        let item = try dictionary(raw, "allocation")
        let size = try integer(item["size"], "size")
        let candidate = try Grid3D(size: size, domain: .unit)
        guard candidate.rgbDoubleBytes == (try integer(item["rgbDoubleBytes"], "rgbDoubleBytes")) else {
            throw CheckFailure.mismatch("allocation \(size)")
        }
    }

    let matrixFixture = try dictionary(root["matrix"], "matrix")
    let matrixValues = try array(matrixFixture["rowMajor"], "rowMajor").map { try number($0, "matrix value") }
    let inverseValues = try array(matrixFixture["inverseRowMajor"], "inverseRowMajor").map { try number($0, "inverse value") }
    let matrix = try Matrix3x3(rowMajor: matrixValues)
    let matrixOutput = try matrix.applying(to: vector(matrixFixture["input"], "matrix input"))
    let expectedOutput = try vector(matrixFixture["output"], "matrix output")
    for channel in 0..<3 { try check(matrixOutput[channel], expectedOutput[channel], "matrix output \(channel)") }
    let inverted = try matrix.inverted()
    for index in 0..<9 { try check(inverted.rowMajor[index], inverseValues[index], "matrix inverse \(index)") }

    let interpolation = try dictionary(root["interpolation"], "interpolation")
    let vertices = try array(interpolation["vertices"], "vertices").map { raw in
        try vector(dictionary(raw, "vertex")["value"], "vertex value")
    }
    let volume = try LUTVolume3D(size: 2, domain: .unit, samples: vertices)
    for (index, raw) in try array(interpolation["cases"], "cases").enumerated() {
        let item = try dictionary(raw, "interpolation \(index)")
        let point = try vector(item["point"], "point")
        let expectedTetra = try vector(item["tetrahedral"], "tetrahedral")
        let expectedLinear = try vector(item["trilinear"], "trilinear")
        let tetra = try volume.sample(point, interpolation: .tetrahedral, outside: .reject)
        let linear = try volume.sample(point, interpolation: .trilinear, outside: .reject)
        for channel in 0..<3 {
            try check(tetra[channel], expectedTetra[channel], "tetra \(index)/\(channel)")
            try check(linear[channel], expectedLinear[channel], "trilinear \(index)/\(channel)")
        }
    }
    let tie = try dictionary(interpolation["tie"], "tie")
    let tiePoint = try vector(tie["point"], "tie point")
    let tieTetra = try volume.sample(tiePoint, interpolation: .tetrahedral, outside: .reject)
    let tieLinear = try volume.sample(tiePoint, interpolation: .trilinear, outside: .reject)
    let expectedTieTetra = try vector(tie["tetrahedral"], "tie tetra")
    let expectedTieLinear = try vector(tie["trilinear"], "tie trilinear")
    for channel in 0..<3 {
        try check(tieTetra[channel], expectedTieTetra[channel], "tie tetra \(channel)")
        try check(tieLinear[channel], expectedTieLinear[channel], "tie trilinear \(channel)")
    }
    do {
        _ = try volume.sample(RGB64(-0.1, 0.5, 0.5), interpolation: .tetrahedral, outside: .reject)
        throw CheckFailure.mismatch("outside domain accepted")
    } catch VolumeError.outsideDomain {}
    let clamped = try volume.sample(RGB64(-0.1, 0.5, 0.5), interpolation: .tetrahedral, outside: .clampToDomain)
    let edge = try volume.sample(RGB64(0, 0.5, 0.5), interpolation: .tetrahedral, outside: .reject)
    guard clamped == edge else { throw CheckFailure.mismatch("outside clamp differs from edge") }
    let upper = try volume.sample(RGB64(1, 1, 1), interpolation: .tetrahedral, outside: .reject)
    guard upper == vertices[7] else { throw CheckFailure.mismatch("upper endpoint") }
    print("H07 用户 LUT 插值契约通过：14 个冻结插值结果、六种轴序、相等边界、上端点与域外策略")

    if CommandLine.arguments.count >= 3 {
        let dlogRef = try dictionary(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))), "D-Log2 reference")
        let toXYZ = try ColorPrimaries.djiDGamut2.rgbToXYZ()
        let expectedXYZ = try array(dlogRef["toXYZ"], "toXYZ")
        for index in 0..<9 { try check(toXYZ.rowMajor[index], number(expectedXYZ[index], "toXYZ value"), "D-Gamut2 XYZ \(index)") }
        let toAP0 = try ColorPrimaries.conversion(from: .djiDGamut2, to: .acesAP0, adaptation: .cieCAT02)
        let expectedAP0 = try array(dlogRef["toAP0"], "toAP0")
        for index in 0..<9 { try check(toAP0.rowMajor[index], number(expectedAP0[index], "toAP0 value"), "D-Gamut2 AP0 \(index)") }
        let decodeCases = try array(dlogRef["decode"], "decode")
        for (index, raw) in decodeCases.enumerated() {
            let pair = try array(raw, "decode \(index)")
            guard pair.count == 2 else { throw CheckFailure.invalidFixture("decode pair") }
            let signal = try number(pair[0], "signal")
            let scene = try number(pair[1], "scene")
            try check(DLog2.decodeDataToScene(signal), scene, "D-Log2 decode \(index)")
            try check(DLog2.encodeSceneToData(scene), signal, "D-Log2 encode \(index)")
        }
        for bits in [10, 12] {
            let range = try CodeRange.videoRGB(bitDepth: bits)
            var previous = -Double.infinity
            for code in 0...range.maxCode {
                let data = Double(code) / Double(range.maxCode)
                let scene = try DLog2.decodeDataToScene(data)
                guard scene > previous else { throw CheckFailure.mismatch("D-Log2 monotonicity \(bits)/\(code)") }
                previous = scene
                try check(DLog2.encodeSceneToData(scene), data, "D-Log2 data roundtrip \(bits)/\(code)")
                let video = try range.dataToVideo(data)
                try check(DLog2.decodeVideoToScene(video, codeRange: range), scene, "D-Log2 video decode \(bits)/\(code)")
                try check(DLog2.encodeSceneToVideo(scene, codeRange: range), video, "D-Log2 video encode \(bits)/\(code)")
            }
        }
        try runDLogGridRoundTrip()
    }

    do {
        _ = try Grid3D(size: Int.max, domain: .unit)
        throw CheckFailure.mismatch("overflow accepted")
    } catch NumericError.sizeOverflow {}
    do {
        _ = try RGB64(.nan, 0, 0)
        throw CheckFailure.mismatch("NaN accepted")
    } catch NumericError.nonFinite {}
    do {
        _ = try CodeRange(bitDepth: 10, blackCode: 940, whiteCode: 64, maxCode: 1023)
        throw CheckFailure.mismatch("reversed code range accepted")
    } catch NumericError.invalidCodeRange {}
    print("H02/H03 数值契约通过：12 个范围点、27 个网格点、2 个标度点、4 个内存尺寸、非对称矩阵及 D-Gamut2 参照")
}

private func runDLogGridRoundTrip() throws {
    let grid = try Grid3D(size: 33, domain: .unit)
    let forward = try ColorPrimaries.conversion(from: .djiDGamut2, to: .acesAP0, adaptation: .cieCAT02)
    let inverse = try forward.inverted()
    var largest = 0.0
    var worstIndex = 0
    for index in 0..<grid.nodeCount {
        let code = try grid.coordinate(at: index)
        let scene = try RGB64(
            DLog2.decodeDataToScene(code.r),
            DLog2.decodeDataToScene(code.g),
            DLog2.decodeDataToScene(code.b)
        )
        let roundTrip = try inverse.applying(to: forward.applying(to: scene))
        let result = try RGB64(
            DLog2.encodeSceneToData(roundTrip.r),
            DLog2.encodeSceneToData(roundTrip.g),
            DLog2.encodeSceneToData(roundTrip.b)
        )
        for channel in 0..<3 {
            let error = abs(result[channel] - code[channel])
            if error > largest { largest = error; worstIndex = index }
            guard error <= 2e-10 else { throw CheckFailure.mismatch("33^3 roundtrip \(index)/\(channel): \(error)") }
        }
    }
    let range = try CodeRange.videoRGB(bitDepth: 10)
    for index in 0...1023 {
        let data = Double(index) / 1023
        let sceneData = try DLog2.decodeDataToScene(data)
        try check(DLog2.encodeSceneToData(sceneData), data, "1D data \(index)")
        let video = try range.dataToVideo(data)
        let sceneVideo = try DLog2.decodeVideoToScene(video, codeRange: range)
        try check(DLog2.encodeSceneToVideo(sceneVideo, codeRange: range), video, "1D legal \(index)")
    }
    print("H05 33³ D-Log2/D-Gamut2 往返通过：最大绝对误差 \(largest)，节点 \(worstIndex)；1D data/legal 各 1024 点通过")
}

private func runParserCases(_ manifestPath: String) throws {
    let manifestURL = URL(fileURLWithPath: manifestPath)
    let cases = try array(JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)), "parser cases")
    guard cases.count == 8 else { throw CheckFailure.invalidFixture("parser case count") }
    for raw in cases {
        let item = try dictionary(raw, "parser case")
        guard let file = item["file"] as? String, let expected = item["expected"] as? String else {
            throw CheckFailure.invalidFixture("parser case fields")
        }
        let input = try Data(contentsOf: manifestURL.deletingLastPathComponent().appendingPathComponent(file))
        do {
            let parsed = try CubeParser.parse(input)
            guard expected == "accept" else { throw CheckFailure.mismatch("\(file) was accepted") }
            guard parsed.size == (try integer(item["size"], "size")),
                  parsed.dimension.rawValue == (try integer(item["dimension"], "dimension")) else {
                throw CheckFailure.mismatch("\(file) shape")
            }
            let expectedRows = try array(item["rows"], "rows")
            guard parsed.samples.count == expectedRows.count else { throw CheckFailure.mismatch("\(file) row count") }
            for (index, row) in expectedRows.enumerated() {
                let expectedValue = try vector(row, "row \(index)")
                for channel in 0..<3 { try check(parsed.samples[index][channel], expectedValue[channel], "\(file) row \(index)") }
            }
            let serialized = try CubeWriter.serialize(parsed)
            let reread = try CubeParser.parse(Data(serialized.utf8))
            guard parsed == reread else { throw CheckFailure.mismatch("\(file) roundtrip") }
        } catch let failure as CubeFailure {
            guard expected == "reject", let category = item["error"] as? String,
                  failure.category.rawValue == category else {
                throw CheckFailure.mismatch("\(file): unexpected \(failure.category.rawValue)")
            }
        }
    }
    print("H04 CUBE 解析契约通过：8 个文件样例及有效扩展域往返")
}

private func runFirstChain(_ fixturePath: String) throws {
    let source = try dictionary(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: fixturePath))), "first chain")
    let cases = try array(source["cases"], "first chain cases")
    guard cases.count == 4 else { throw CheckFailure.invalidFixture("first chain count") }
    let settings = TransformSettings(
        inputTransfer: .djiDLog2, outputTransfer: .linearScene,
        inputSpace: .djiDGamut2, outputSpace: .acesAP0,
        inputRange: .data, outputRange: .data, exposureStops: 1
    )
    let plan = try TransformPlan(settings: settings)
    for (index, raw) in cases.enumerated() {
        let item = try dictionary(raw, "first chain \(index)")
        let input = try vector(item["input"], "input")
        let expected = try vector(item["outputLinearAP0"], "output")
        let trace = try plan.trace(input)
        guard trace.stages.map(\.id) == [1, 2, 3, 4, 10, 13, 19] else {
            throw CheckFailure.mismatch("stage order \(index)")
        }
        for channel in 0..<3 { try check(trace.output[channel], expected[channel], "first chain \(index)/\(channel)") }
    }
    print("H06 非恒等链通过：4 个 DJI D-Log2/D-Gamut2 → 曝光 +1 → 线性 AP0 独立参照及阶段顺序")
}

private func runSRGB(_ referencePath: String, _ legacyPath: String) throws {
    let standard = try dictionary(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: referencePath))), "sRGB reference")
    let legacy = try dictionary(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: legacyPath))), "sRGB legacy")
    var worstStandard = 0.0
    var worstLegacy = 0.0
    var largestCorrection = 0.0
    for direction in ["encode", "decode"] {
        let standardCases = try array(standard[direction], "standard \(direction)")
        let legacyCases = try array(legacy[direction], "legacy \(direction)")
        guard standardCases.count == legacyCases.count else { throw CheckFailure.invalidFixture("sRGB count") }
        for index in standardCases.indices {
            let entry = try dictionary(standardCases[index], "standard case")
            let oldEntry = try dictionary(legacyCases[index], "legacy case")
            let input = try number(entry["input"], "sRGB input")
            guard input == (try number(oldEntry["input"], "legacy input")) else { throw CheckFailure.invalidFixture("sRGB input mismatch") }
            let expected = try number(entry["expected"], "sRGB expected")
            let oldExpected = try number(oldEntry["expected"], "legacy expected")
            let actual = try direction == "encode" ? SRGBTransfer.encode(input, variant: .w3cExtended) : SRGBTransfer.decode(input, variant: .w3cExtended)
            let oldActual = try direction == "encode" ? SRGBTransfer.encode(input, variant: .lutcalcLegacy) : SRGBTransfer.decode(input, variant: .lutcalcLegacy)
            try check(actual, expected, "sRGB standard \(direction)/\(index)")
            try check(oldActual, oldExpected, "sRGB legacy \(direction)/\(index)")
            let newError = abs(actual - expected)
            let oldError = abs(oldExpected - expected)
            guard newError <= oldError + 5e-15 else { throw CheckFailure.mismatch("sRGB regression \(direction)/\(index)") }
            worstStandard = max(worstStandard, newError)
            worstLegacy = max(worstLegacy, abs(oldActual - oldExpected))
            largestCorrection = max(largestCorrection, abs(actual - oldExpected))
        }
    }
    print("H11 sRGB 双版本契约通过：独立高精度最大绝对误差 \(worstStandard)，旧版复现最大误差 \(worstLegacy)，最大版本差异 \(largestCorrection)")
}

private func runSRGBPlan(_ fixturePath: String) throws {
    let fixture = try dictionary(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: fixturePath))), "sRGB plan")
    let cases = try array(fixture["cases"], "sRGB plan cases")
    guard cases.count == 4 else { throw CheckFailure.invalidFixture("sRGB plan count") }
    for (variant, field, range, bits) in [
        (TransferID.srgbW3CExtended, "standardData", SignalNormalization.data, 10),
        (.srgbLUTCalcLegacy, "legacyData", .data, 10),
        (.srgbW3CExtended, "standardVideo10", .video, 10),
        (.srgbW3CExtended, "standardVideo12", .video, 12),
    ] {
        let plan = try TransformPlan(settings: TransformSettings(
            inputTransfer: .djiDLog2, outputTransfer: variant,
            inputSpace: .djiDGamut2, outputSpace: .srgb,
            inputRange: .data, outputRange: range, exposureStops: 1, rangeBitDepth: bits
        ))
        for (index, raw) in cases.enumerated() {
            let item = try dictionary(raw, "sRGB plan case")
            let trace = try plan.trace(vector(item["input"], "sRGB plan input"))
            guard trace.stages.map(\.id) == [1, 2, 3, 4, 10, 13, 19],
                  trace.stages[5].inputUnit == .sceneReflectance,
                  trace.stages[5].outputUnit == .encodedData else {
                throw CheckFailure.mismatch("sRGB stage trace \(index)")
            }
            let expectedLinear = try vector(item["linearSRGB"], "linear sRGB")
            let expectedOutput = try vector(item[field], field)
            for channel in 0..<3 {
                try check(trace.stages[5].input[channel], expectedLinear[channel], "sRGB linear \(index)/\(channel)")
                try check(trace.output[channel], expectedOutput[channel], "sRGB \(field) \(index)/\(channel)")
            }
        }
    }
    for variant in [TransferID.srgbW3CExtended, .srgbLUTCalcLegacy] {
        let plan = try TransformPlan(settings: TransformSettings(
            inputTransfer: variant, outputTransfer: .linearScene,
            inputSpace: .srgb, outputSpace: .srgb,
            inputRange: .data, outputRange: .data, exposureStops: 0
        ))
        let input = try RGB64(0.0403, -0.1, 1.1)
        let output = try plan.evaluate(input)
        let curve: SRGBVariant = variant == .srgbW3CExtended ? .w3cExtended : .lutcalcLegacy
        for channel in 0..<3 {
            let decoded = try SRGBTransfer.decode(input[channel], variant: curve)
            let expected = variant == .srgbLUTCalcLegacy ? decoded * 0.9 : decoded
            try check(output[channel], expected, "sRGB input \(variant.rawValue)/\(channel)")
        }
    }
    let inputRange = try CodeRange.videoRGB(bitDepth: 12)
    let videoInput = try RGB64(
        inputRange.dataToVideo(0.0403), inputRange.dataToVideo(-0.1), inputRange.dataToVideo(1.1)
    )
    let videoPlan = try TransformPlan(settings: TransformSettings(
        inputTransfer: .srgbW3CExtended, outputTransfer: .linearScene,
        inputSpace: .srgb, outputSpace: .srgb,
        inputRange: .video, outputRange: .data, exposureStops: 0, rangeBitDepth: 12
    ))
    let videoResult = try videoPlan.evaluate(videoInput)
    for channel in 0..<3 {
        let data = try inputRange.videoToData(videoInput[channel])
        try check(videoResult[channel], SRGBTransfer.decode(data, variant: .w3cExtended), "sRGB video input/\(channel)")
    }
    for bits in [10, 12] {
        let range = try CodeRange.videoRGB(bitDepth: bits)
        for code in 0...range.maxCode {
            let data = Double(code) / Double(range.maxCode)
            let linear = try SRGBTransfer.decode(data, variant: .w3cExtended)
            try check(SRGBTransfer.encode(linear, variant: .w3cExtended), data, "sRGB full data \(bits)/\(code)")
            let video = try range.dataToVideo(data)
            let normalized = try range.videoToData(video)
            try check(SRGBTransfer.decode(normalized, variant: .w3cExtended), linear, "sRGB full video \(bits)/\(code)")
        }
    }
    print("H11 sRGB 计划契约通过：4 点独立矩阵/曲线参照、双版本输入输出、10/12-bit 全码 data/video")
}

private func runLegacyExposure(_ binaryPath: String) throws {
    struct Metadata: Decodable {
        let size: Int
        let inputRange: String
        let outputRange: String
    }
    let metadataPath = URL(fileURLWithPath: binaryPath).deletingPathExtension().appendingPathExtension("json")
    let metadata = try JSONDecoder().decode(Metadata.self, from: Data(contentsOf: metadataPath))
    guard [17, 33, 65].contains(metadata.size),
        ["Data", "Legal"].contains(metadata.inputRange),
        ["Data", "Legal"].contains(metadata.outputRange) else {
        throw CheckFailure.invalidFixture("legacy ranges or size")
    }
    let bytes = Array(try Data(contentsOf: URL(fileURLWithPath: binaryPath)))
    let size = metadata.size
    guard size * size * size * 3 * 8 == bytes.count else {
        throw CheckFailure.invalidFixture("legacy Float64 size")
    }
    let grid = try Grid3D(size: size, domain: .unit)
    let plan = try TransformPlan(settings: TransformSettings(
        inputTransfer: .djiDLog2, outputTransfer: .djiDLog2,
        inputSpace: .djiDGamut2, outputSpace: .djiDGamut2,
        inputRange: metadata.inputRange == "Data" ? .data : .video,
        outputRange: metadata.outputRange == "Data" ? .data : .video,
        exposureStops: 1
    ))
    var worst = 0.0
    var worstIndex = 0
    var worstChannel = 0
    var maxAbsoluteError = 0.0
    var sumSquaredScaledError = 0.0
    var violations = 0
    var scaledErrors: [Double] = []
    scaledErrors.reserveCapacity(grid.nodeCount * 3)
    for index in 0..<grid.nodeCount {
        let actual = try plan.evaluate(grid.coordinate(at: index), sampleIndex: index)
        for channel in 0..<3 {
            let offset = (index * 3 + channel) * 8
            var bits: UInt64 = 0
            for byte in 0..<8 { bits |= UInt64(bytes[offset + byte]) << (8 * byte) }
            let expected = Double(bitPattern: bits)
            guard expected.isFinite else { throw CheckFailure.invalidFixture("legacy nonfinite \(index)/\(channel)") }
            let absoluteError = abs(actual[channel] - expected)
            let error = absoluteError / max(1, abs(expected))
            guard error.isFinite else { throw CheckFailure.invalidFixture("legacy nonfinite error \(index)/\(channel)") }
            scaledErrors.append(error)
            sumSquaredScaledError += error * error
            maxAbsoluteError = max(maxAbsoluteError, absoluteError)
            if error > worst { worst = error; worstIndex = index; worstChannel = channel }
            if error > 2e-12 { violations += 1 }
        }
    }
    scaledErrors.sort()
    let rms = sqrt(sumSquaredScaledError / Double(scaledErrors.count))
    let p99 = scaledErrors[Int(ceil(0.99 * Double(scaledErrors.count))) - 1]
    let report = "\(size)³ \(metadata.inputRange)→\(metadata.outputRange)：最大尺度化误差 \(worst)，最大绝对误差 \(maxAbsoluteError)，RMS \(rms)，P99 \(p99)，最差节点 \(worstIndex)/通道 \(worstChannel)，超门槛通道 \(violations)/\(scaledErrors.count)"
    guard violations == 0 else { throw CheckFailure.mismatch("legacy full path " + report) }
    print("H06 旧完整无调节链对照通过：" + report)
}

private func runLegacyStages(_ fixturePath: String) throws {
    struct Sample: Decodable {
        let index: Int
        let decodedLegacy: [Double]
        let colorLegacy: [Double]
        let encodedData: [Double]
    }
    struct Fixture: Decodable {
        let size: Int
        let inputRange: String
        let outputRange: String
        let exposureGain: Double
        let legacyLinearToSceneScale: Double
        let samples: [Sample]
    }
    let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: URL(fileURLWithPath: fixturePath)))
    guard fixture.size == 17, fixture.inputRange == "Data", fixture.outputRange == "Data",
        fixture.exposureGain == 2, fixture.legacyLinearToSceneScale == 0.9,
        fixture.samples.count == 32 else {
        throw CheckFailure.invalidFixture("legacy stage metadata")
    }
    let grid = try Grid3D(size: fixture.size, domain: .unit)
    let plan = try TransformPlan(settings: TransformSettings(
        inputTransfer: .djiDLog2, outputTransfer: .djiDLog2,
        inputSpace: .djiDGamut2, outputSpace: .djiDGamut2,
        inputRange: .data, outputRange: .data, exposureStops: 1
    ))
    var seen: Set<Int> = []
    var worstByStage: [Int: Double] = [:]
    for sample in fixture.samples {
        guard (0..<grid.nodeCount).contains(sample.index), seen.insert(sample.index).inserted else {
            throw CheckFailure.invalidFixture("legacy stage index")
        }
        let trace = try plan.trace(grid.coordinate(at: sample.index), sampleIndex: sample.index)
        let expectedStages: [(Int, [Double], Double)] = [
            (2, sample.decodedLegacy, fixture.legacyLinearToSceneScale),
            (10, sample.colorLegacy, fixture.legacyLinearToSceneScale),
            (19, sample.encodedData, 1),
        ]
        for (stageID, expected, scale) in expectedStages {
            guard expected.count == 3, expected.allSatisfy(\.isFinite),
                let actual = trace.stages.first(where: { $0.id == stageID })?.output else {
                throw CheckFailure.invalidFixture("legacy stage \(sample.index)/\(stageID)")
            }
            for channel in 0..<3 {
                let reference = expected[channel] * scale
                let error = abs(actual[channel] - reference) / max(1, abs(reference))
                worstByStage[stageID] = max(worstByStage[stageID] ?? 0, error)
                try check(actual[channel], reference, "legacy stage \(stageID)/\(sample.index)/\(channel)")
            }
        }
    }
    print("BASE-05 固定种子阶段对照通过：\(fixture.samples.count) 节点；解码 \(worstByStage[2] ?? 0)，色域/曝光 \(worstByStage[10] ?? 0)，最终编码 \(worstByStage[19] ?? 0) 最大尺度化误差")
}

do {
    guard (2...10).contains(CommandLine.arguments.count) else { throw CheckFailure.invalidFixture("expected numeric, D-Log2, parser, first-chain, sRGB and legacy fixture paths") }
    try run(CommandLine.arguments[1])
    if CommandLine.arguments.count >= 4 { try runParserCases(CommandLine.arguments[3]) }
    if CommandLine.arguments.count >= 5 { try runFirstChain(CommandLine.arguments[4]) }
    if CommandLine.arguments.count >= 7 { try runSRGB(CommandLine.arguments[5], CommandLine.arguments[6]) }
    if CommandLine.arguments.count == 8 { try runSRGBPlan(CommandLine.arguments[7]) }
    if CommandLine.arguments.count >= 9 {
        try runSRGBPlan(CommandLine.arguments[7])
        try runLegacyExposure(CommandLine.arguments[8])
    }
    if CommandLine.arguments.count == 10 { try runLegacyStages(CommandLine.arguments[9]) }
} catch {
    fputs("LUTContractChecks: \(error)\n", stderr)
    exit(1)
}
