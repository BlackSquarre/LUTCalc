import Foundation
import LUTCore
import LUTPreview

private enum Failure: Error { case mismatch(String) }

private func exact(_ value: Double, _ expected: Int, depth: Int, label: String) throws {
    let denominator = depth == 8 ? 255.0 : 65535.0
    guard value == Double(expected) / denominator else {
        throw Failure.mismatch("\(label): \(value) != \(expected)/\(Int(denominator))")
    }
}

do {
    guard CommandLine.arguments.count == 2 else { throw Failure.mismatch("fixture directory") }
    let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    let rgba8: PreviewImage
    do {
        rgba8 = try PreviewImageDecoder.decode(url: directory.appendingPathComponent("rgba8.png"))
    } catch { throw Failure.mismatch("rgba8.png: \(error)") }
    guard rgba8.width == 2, rgba8.height == 1, rgba8.bitsPerComponent == 8,
          rgba8.alphaMode == .straight, rgba8.pixels.count == 2,
          rgba8.decodedColorSpaceName != nil,
          rgba8.colorSpaceProvenance == .sourceICCUnverified,
          rgba8.sourceEmbeddedICCProfileName == nil else { throw Failure.mismatch("8-bit metadata provenance") }
    try exact(rgba8.pixels[0].rgb.r, 0, depth: 8, label: "rgba8 r0")
    try exact(rgba8.pixels[0].rgb.g, 64, depth: 8, label: "rgba8 g0")
    try exact(rgba8.pixels[0].rgb.b, 128, depth: 8, label: "rgba8 b0")
    try exact(rgba8.pixels[0].alpha, 255, depth: 8, label: "rgba8 a0")
    try exact(rgba8.pixels[1].rgb.r, 255, depth: 8, label: "rgba8 r1")
    try exact(rgba8.pixels[1].rgb.g, 128, depth: 8, label: "rgba8 g1")
    try exact(rgba8.pixels[1].rgb.b, 64, depth: 8, label: "rgba8 b1")
    try exact(rgba8.pixels[1].alpha, 128, depth: 8, label: "rgba8 a1")
    let embedded: PreviewImage
    do {
        embedded = try PreviewImageDecoder.decode(
            url: directory.appendingPathComponent("rgba8-embedded-icc.png"))
    } catch { throw Failure.mismatch("rgba8-embedded-icc.png: \(error)") }
    guard embedded.colorSpaceProvenance == .sourceEmbeddedICC else { throw Failure.mismatch("embedded provenance") }
    guard let profileName = embedded.sourceEmbeddedICCProfileName, !profileName.isEmpty else { throw Failure.mismatch("embedded name") }
    guard embedded.metadataProfileName == profileName else { throw Failure.mismatch("embedded metadata name") }
    guard let sourceProfile = embedded.sourceEmbeddedICCProfile else { throw Failure.mismatch("embedded bytes") }
    guard let sourceValidation = embedded.sourceICCValidation else { throw Failure.mismatch("embedded validation") }
    guard sourceValidation.byteCount == sourceProfile.count,
          sourceValidation.declaredByteCount == sourceProfile.count,
          sourceValidation.profileSignature == "acsp",
          sourceValidation.sha256.count == 64 else { throw Failure.mismatch("embedded validation fields") }
    let xyzTags = sourceValidation.tags.filter { $0.typeSignature == "XYZ " }
    guard !xyzTags.isEmpty,
          xyzTags.allSatisfy({ values in
              guard let fixed = values.fixedPointValues, fixed.count >= 3 else { return false }
              return fixed.allSatisfy(\.isFinite)
          }) else { throw Failure.mismatch("embedded XYZ metadata") }
    guard sourceValidation.tags.contains(where: {
        $0.signature == "tech" && $0.signatureValue == "CRT "
    }) else { throw Failure.mismatch("embedded signature metadata") }
    guard embedded.decodedICCProfile != nil else { throw Failure.mismatch("decoded ICC") }
    guard embedded.pixels == rgba8.pixels else { throw Failure.mismatch("embedded pixels") }

    let rgba16 = try PreviewImageDecoder.decode(url: directory.appendingPathComponent("rgba16.png"))
    guard rgba16.width == 2, rgba16.height == 1, rgba16.bitsPerComponent == 16,
          rgba16.alphaMode == .straight, rgba16.pixels.count == 2,
          rgba16.decodedColorSpaceName != nil,
          rgba16.colorSpaceProvenance == .sourceICCUnverified,
          rgba16.sourceEmbeddedICCProfileName == nil else { throw Failure.mismatch("16-bit metadata provenance") }
    try exact(rgba16.pixels[0].rgb.r, 0, depth: 16, label: "rgba16 r0")
    try exact(rgba16.pixels[0].rgb.g, 16384, depth: 16, label: "rgba16 g0")
    try exact(rgba16.pixels[0].rgb.b, 32768, depth: 16, label: "rgba16 b0")
    try exact(rgba16.pixels[0].alpha, 65535, depth: 16, label: "rgba16 a0")
    try exact(rgba16.pixels[1].rgb.r, 65535, depth: 16, label: "rgba16 r1")
    try exact(rgba16.pixels[1].rgb.g, 32768, depth: 16, label: "rgba16 g1")
    try exact(rgba16.pixels[1].rgb.b, 16384, depth: 16, label: "rgba16 b1")
    try exact(rgba16.pixels[1].alpha, 32768, depth: 16, label: "rgba16 a1")

    let rgb8 = try PreviewImageDecoder.decode(url: directory.appendingPathComponent("rgb8.png"))
    guard rgb8.bitsPerComponent == 8, rgb8.alphaMode == .straight,
          rgb8.pixels[0].alpha == 1, rgb8.pixels[1].alpha == 1 else {
        throw Failure.mismatch("RGB without alpha")
    }
    try exact(rgb8.pixels[0].rgb.r, 1, depth: 8, label: "rgb8 r0")
    try exact(rgb8.pixels[1].rgb.b, 252, depth: 8, label: "rgb8 b1")

    let gray8 = try PreviewImageDecoder.decode(url: directory.appendingPathComponent("gray8.png"))
    guard gray8.bitsPerComponent == 8, gray8.alphaMode == .straight,
          gray8.pixels.count == 2,
          gray8.pixels[0].rgb.r == gray8.pixels[0].rgb.g,
          gray8.pixels[0].rgb.g == gray8.pixels[0].rgb.b,
          gray8.pixels[1].rgb.r == gray8.pixels[1].rgb.g,
          gray8.pixels[1].rgb.g == gray8.pixels[1].rgb.b else {
        throw Failure.mismatch("gray8 layout")
    }
    try exact(gray8.pixels[0].rgb.r, 32, depth: 8, label: "gray8 p0")
    try exact(gray8.pixels[1].rgb.b, 224, depth: 8, label: "gray8 p1")

    let gray16 = try PreviewImageDecoder.decode(url: directory.appendingPathComponent("gray16.png"))
    guard gray16.bitsPerComponent == 16, gray16.alphaMode == .straight,
          gray16.pixels.count == 2 else { throw Failure.mismatch("gray16 layout") }
    try exact(gray16.pixels[0].rgb.g, 16384, depth: 16, label: "gray16 p0")
    try exact(gray16.pixels[1].rgb.r, 49152, depth: 16, label: "gray16 p1")

    let grayAlpha = try PreviewImageDecoder.decode(url: directory.appendingPathComponent("gray8-alpha.png"))
    guard grayAlpha.bitsPerComponent == 8, grayAlpha.alphaMode == .straight,
          grayAlpha.pixels.count == 2 else { throw Failure.mismatch("gray alpha layout") }
    try exact(grayAlpha.pixels[0].rgb.b, 64, depth: 8, label: "gray alpha p0 gray")
    try exact(grayAlpha.pixels[0].alpha, 128, depth: 8, label: "gray alpha p0 alpha")
    try exact(grayAlpha.pixels[1].rgb.r, 192, depth: 8, label: "gray alpha p1 gray")
    try exact(grayAlpha.pixels[1].alpha, 255, depth: 8, label: "gray alpha p1 alpha")

    let tiff16 = try PreviewImageDecoder.decode(url: directory.appendingPathComponent("rgba16.tiff"))
    guard tiff16.bitsPerComponent == 16, tiff16.width == 2, tiff16.height == 1,
          tiff16.alphaMode == .straight else { throw Failure.mismatch("TIFF metadata") }
    try exact(tiff16.pixels[0].rgb.g, 16384, depth: 16, label: "tiff16 g0")
    try exact(tiff16.pixels[1].rgb.b, 16384, depth: 16, label: "tiff16 b1")
    try exact(tiff16.pixels[1].alpha, 32768, depth: 16, label: "tiff16 a1")
    let rotated = try PreviewImageDecoder.decode(url: directory.appendingPathComponent("rgba16-rotated.tiff"))
    guard rotated.width == 1, rotated.height == 2 else { throw Failure.mismatch("rotated dimensions") }
    try exact(rotated.pixels[0].rgb.g, 16384, depth: 16, label: "rotated top")
    try exact(rotated.pixels[1].rgb.b, 16384, depth: 16, label: "rotated bottom")
    let expectedOrientations: [(Int, Int, [Int])] = [
        (2, 3, [1, 2, 3, 4, 5, 6]),
        (2, 3, [2, 1, 4, 3, 6, 5]),
        (2, 3, [6, 5, 4, 3, 2, 1]),
        (2, 3, [5, 6, 3, 4, 1, 2]),
        (3, 2, [1, 3, 5, 2, 4, 6]),
        (3, 2, [5, 3, 1, 6, 4, 2]),
        (3, 2, [6, 4, 2, 5, 3, 1]),
        (3, 2, [2, 4, 6, 1, 3, 5]),
    ]
    for (index, expected) in expectedOrientations.enumerated() {
        let image = try PreviewImageDecoder.decode(url: directory.appendingPathComponent("orientation-\(index + 1).tiff"))
        guard image.width == expected.0, image.height == expected.1 else {
            throw Failure.mismatch("orientation \(index + 1) dimensions")
        }
        for (pixelIndex, code) in expected.2.enumerated() {
            try exact(image.pixels[pixelIndex].rgb.r, code * 1000, depth: 16,
                      label: "orientation \(index + 1) pixel \(pixelIndex)")
        }
    }
    let premultiplied = try PreviewImageDecoder.decode(
        url: directory.appendingPathComponent("premultiplied16.tiff"))
    guard premultiplied.alphaMode == .premultiplied else {
        throw Failure.mismatch("associated alpha semantics")
    }
    try exact(premultiplied.pixels[1].rgb.r, 32768, depth: 16, label: "premultiplied red")
    try exact(premultiplied.pixels[1].alpha, 32768, depth: 16, label: "premultiplied alpha")
    let jpeg = try PreviewImageDecoder.decode(url: directory.appendingPathComponent("rgb8.jpeg"))
    guard jpeg.width == 2, jpeg.height == 1, jpeg.bitsPerComponent == 8,
          jpeg.pixels.count == 2, jpeg.pixels.allSatisfy({ $0.alpha == 1 }),
          jpeg.decodedColorSpaceName != nil else { throw Failure.mismatch("JPEG metadata") }

    let plan = try TransformPlan(settings: TransformSettings(
        inputTransfer: .linearScene, outputTransfer: .linearScene,
        inputSpace: .srgb, outputSpace: .srgb,
        inputRange: .data, outputRange: .data, exposureStops: 0
    ))
    let identity = PreviewIdentity(documentID: UUID(), revision: 1,
                                   requestID: UUID(), planVersion: plan.planVersion)
    let request = try rgba16.previewRequest(plan: plan, outputAlpha: .straight, identity: identity)
    guard request.pixels == rgba16.pixels, request.inputAlpha == .straight,
          request.identity == identity else { throw Failure.mismatch("raw preview request") }

    let scratch = FileManager.default.temporaryDirectory
        .appendingPathComponent("lutcalc-image-check-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: scratch) }
    let corruptICC = scratch.appendingPathComponent("rgba8-embedded-icc-bad-crc.png")
    var corruptBytes = try Data(contentsOf: directory.appendingPathComponent("rgba8-embedded-icc.png"))
    var chunkOffset = 8
    var changedCRC = false
    while chunkOffset + 12 <= corruptBytes.count {
        let length = Int(corruptBytes[chunkOffset]) << 24 |
            Int(corruptBytes[chunkOffset + 1]) << 16 |
            Int(corruptBytes[chunkOffset + 2]) << 8 | Int(corruptBytes[chunkOffset + 3])
        let contentStart = chunkOffset + 8
        let contentEnd = contentStart + length
        guard length >= 0, contentEnd + 4 <= corruptBytes.count else { break }
        if Data(corruptBytes[(chunkOffset + 4)..<contentStart]) == Data("iCCP".utf8) {
            corruptBytes[contentEnd + 3] ^= 0xFF
            changedCRC = true
            break
        }
        chunkOffset = contentEnd + 4
    }
    guard changedCRC else { throw Failure.mismatch("iCCP corruption fixture") }
    try corruptBytes.write(to: corruptICC)
    do {
        _ = try PreviewImageDecoder.decode(url: corruptICC)
        throw Failure.mismatch("bad iCCP CRC accepted")
    } catch PreviewImageError.invalidImage {}
      catch PreviewImageError.invalidICCProfile {}

    let duplicateICC = scratch.appendingPathComponent("rgba8-embedded-icc-duplicate.png")
    let sourcePNG = try Data(contentsOf: directory.appendingPathComponent("rgba8-embedded-icc.png"))
    var duplicateBytes = Data(sourcePNG.prefix(8))
    var sourceOffset = 8
    var iccpChunk: Data?
    var chunks: [Data] = []
    while sourceOffset + 12 <= sourcePNG.count {
        let length = Int(sourcePNG[sourceOffset]) << 24 |
            Int(sourcePNG[sourceOffset + 1]) << 16 |
            Int(sourcePNG[sourceOffset + 2]) << 8 | Int(sourcePNG[sourceOffset + 3])
        let chunkEnd = sourceOffset + 12 + length
        guard length >= 0, chunkEnd <= sourcePNG.count else { break }
        let chunk = Data(sourcePNG[sourceOffset..<chunkEnd])
        chunks.append(chunk)
        if Data(sourcePNG[(sourceOffset + 4)..<(sourceOffset + 8)]) == Data("iCCP".utf8) {
            iccpChunk = chunk
        }
        sourceOffset = chunkEnd
        if Data(sourcePNG[(sourceOffset - 8 - length)..<(sourceOffset - 4 - length)]) == Data("IEND".utf8) { break }
    }
    guard let iccpChunk else { throw Failure.mismatch("iCCP duplicate fixture source") }
    var inserted = false
    for chunk in chunks {
        let type = Data(chunk[4..<8])
        if type == Data("IEND".utf8), !inserted {
            duplicateBytes.append(iccpChunk)
            inserted = true
        }
        duplicateBytes.append(chunk)
    }
    guard inserted else { throw Failure.mismatch("iCCP duplicate fixture insertion") }
    try duplicateBytes.write(to: duplicateICC)
    do {
        _ = try PreviewImageDecoder.decode(url: duplicateICC)
        throw Failure.mismatch("duplicate iCCP accepted")
    } catch PreviewImageError.invalidImage {}
      catch PreviewImageError.invalidICCProfile {}

    let badAncillary = scratch.appendingPathComponent("rgba8-bad-ancillary-crc.png")
    let basePNG = try Data(contentsOf: directory.appendingPathComponent("rgba8.png"))
    var ancillaryBytes = Data(basePNG.prefix(8))
    var baseOffset = 8
    let textChunk = Data([0, 0, 0, 6]) + Data("tEXt".utf8) + Data([110, 111, 116, 101, 0, 120]) + Data(repeating: 0, count: 4)
    var insertedText = false
    while baseOffset + 12 <= basePNG.count {
        let length = Int(basePNG[baseOffset]) << 24 |
            Int(basePNG[baseOffset + 1]) << 16 |
            Int(basePNG[baseOffset + 2]) << 8 | Int(basePNG[baseOffset + 3])
        let end = baseOffset + 12 + length
        guard length >= 0, end <= basePNG.count else { break }
        let type = Data(basePNG[(baseOffset + 4)..<(baseOffset + 8)])
        if type == Data("IEND".utf8), !insertedText {
            ancillaryBytes.append(textChunk)
            insertedText = true
        }
        ancillaryBytes.append(basePNG[baseOffset..<end])
        baseOffset = end
    }
    guard insertedText else { throw Failure.mismatch("ancillary CRC fixture insertion") }
    try ancillaryBytes.write(to: badAncillary)
    do {
        _ = try PreviewImageDecoder.decode(url: badAncillary)
        throw Failure.mismatch("bad ancillary PNG CRC accepted")
    } catch PreviewImageError.invalidImage {}
      catch PreviewImageError.invalidICCProfile {}

    let bad = scratch.appendingPathComponent("invalid.png")
    try Data("invalid image".utf8).write(to: bad)
    do {
        _ = try PreviewImageDecoder.decode(url: bad)
        throw Failure.mismatch("invalid image accepted")
    } catch PreviewImageError.invalidImage {}
    do {
        _ = try PreviewImageDecoder.decode(url: directory.appendingPathComponent("oversized-header.png"))
        throw Failure.mismatch("oversized dimensions accepted")
    } catch PreviewImageError.resourceLimit {}
    let sparse = scratch.appendingPathComponent("oversized-file.png")
    guard FileManager.default.createFile(atPath: sparse.path, contents: nil) else {
        throw Failure.mismatch("sparse file creation")
    }
    let sparseHandle = try FileHandle(forWritingTo: sparse)
    try sparseHandle.truncate(atOffset: UInt64(PreviewImageDecoder.maxFileBytes) + 1)
    try sparseHandle.close()
    do {
        _ = try PreviewImageDecoder.decode(url: sparse)
        throw Failure.mismatch("oversized file accepted")
    } catch PreviewImageError.resourceLimit {}
    let link = scratch.appendingPathComponent("linked.png")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory.appendingPathComponent("rgba8.png"))
    do {
        _ = try PreviewImageDecoder.decode(url: link)
        throw Failure.mismatch("symbolic link accepted")
    } catch PreviewImageError.invalidImage {}
    print("H13 ImageIO 原始样本通过：PNG 8/16-bit、嵌入 ICC 原始字节与头部校验、非嵌入元数据判别、TIFF 16-bit、JPEG 8-bit、预乘 alpha、方向 1–8、资源预算与链接拒绝；无损夹具整数码值归一化误差 0")
} catch {
    fputs("LUTImageChecks: \(error)\n", stderr)
    exit(1)
}
