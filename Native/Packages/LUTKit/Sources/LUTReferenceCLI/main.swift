import Foundation
import LUTCore
import LUTCatalog
import LUTFormats

private enum CLIError: Error {
    case usage
    case targetExists
    case readbackMismatch
}

private func run() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard (arguments.count == 4 || arguments.count == 6),
          arguments[0] == "--size", let size = Int(arguments[1]),
          arguments[2] == "--output" else { throw CLIError.usage }
    let preset = arguments.count == 6 && arguments[4] == "--preset" ? arguments[5] : "dlog2-linear-ap0"
    guard arguments.count == 4 || arguments[4] == "--preset" else { throw CLIError.usage }
    let target = URL(fileURLWithPath: arguments[3]).standardizedFileURL
    guard !FileManager.default.fileExists(atPath: target.path) else { throw CLIError.targetExists }
    let presetID: String
    switch preset {
    case "dlog2-linear-ap0": presetID = "dji.dlog2-to-linear-ap0.v1"
    case "dlog2-srgb-w3c": presetID = "dji.dlog2-to-srgb-w3c.v1"
    case "rec709-legacy-exposure": presetID = "rec709.legacy-exposure-one.v1"
    case "rec2020-10bit-exposure": presetID = "rec2020.10bit-exposure-one.v1"
    case "rec2020-12bit-legacy-exposure": presetID = "rec2020.12bit-legacy-exposure-one.v1"
    case "cineon-exposure": presetID = "cineon.exposure-one.v1"
    case "cineon-legacy-exposure": presetID = "cineon.legacy-exposure-one.v1"
    case "nikon-nlog-exposure": presetID = "nikon.nlog-exposure-one.v1"
    case "slog3-sony-exposure": presetID = "sony.slog3-exposure-one.v1"
    case "slog3-legacy-exposure": presetID = "sony.slog3-legacy-exposure-one.v1"
    case "slog3-linear-ap0": presetID = "sony.slog3-to-linear-ap0.v1"
    case "slog3-sgamut3-linear-ap0": presetID = "sony.slog3-sgamut3-to-linear-ap0.v1"
    case "slog2-sony-exposure": presetID = "sony.slog2-exposure-one.v1"
    case "slog2-legacy-exposure": presetID = "sony.slog2-legacy-exposure-one.v1"
    case "slog-sony-exposure": presetID = "sony.slog-exposure-one.v1"
    case "slog-legacy-exposure": presetID = "sony.slog-legacy-exposure-one.v1"
    case "red-logfilm-exposure": presetID = "red.logfilm-exposure-one.v1"
    case "red-logfilm-legacy-exposure": presetID = "red.logfilm-legacy-exposure-one.v1"
    case "red-log3g10-legacy-exposure": presetID = "red.log3g10-legacy-exposure-one.v1"
    case "canon-clog-legacy-exposure": presetID = "canon.clog-legacy-exposure-one.v1"
    case "bmd-pocket-film-legacy-exposure": presetID = "blackmagic.pocket-film-legacy-exposure-one.v1"
    case "bmd-film-legacy-exposure": presetID = "blackmagic.film-legacy-exposure-one.v1"
    case "bmd-film4k-legacy-exposure": presetID = "blackmagic.film4k-legacy-exposure-one.v1"
    case "bmd-film46k-legacy-exposure": presetID = "blackmagic.film46k-legacy-exposure-one.v1"
    case "bolex-log-legacy-exposure": presetID = "bolex.log-legacy-exposure-one.v1"
    case "panalog-legacy-exposure": presetID = "panalog-legacy-exposure-one.v1"
    case "dji-x5-log-legacy-exposure": presetID = "dji.x5-log-legacy-exposure-one.v1"
    case "gopro-protune-legacy-exposure": presetID = "gopro.protune-legacy-exposure-one.v1"
    case "dji-x3-dlog-legacy-exposure": presetID = "dji.x3-dlog-legacy-exposure-one.v1"
    case "davinci-intermediate-legacy-exposure": presetID = "davinci.intermediate-legacy-exposure-one.v1"
    case "logc4-linear-ap0": presetID = "arri.logc4-to-linear-ap0.v1"
    case "vlog-linear-ap0": presetID = "panasonic.vlog-to-linear-ap0.v1"
    case "flog2-exposure": presetID = "fujifilm.flog2-exposure-one.v1"
    case "flog2c-exposure": presetID = "fujifilm.flog2c-exposure-one.v1"
    case "flog2-legacy-exposure": presetID = "fujifilm.flog2-legacy-exposure-one.v1"
    case "flog-legacy-exposure": presetID = "fujifilm.flog-legacy-exposure-one.v1"
    case "acescct-exposure": presetID = "aces.acescct-exposure-one.v1"
    case "acescc-exposure": presetID = "aces.acescc-exposure-one.v1"
    case "acesproxy10-exposure": presetID = "aces.acesproxy10-exposure-one.v1"
    case "acesproxy12-exposure": presetID = "aces.acesproxy12-exposure-one.v1"
    case "ilog-exposure": presetID = "insta360.ilog-exposure-one.v1"
    case "milog-exposure": presetID = "xiaomi.milog-exposure-one.v1"
    case "llog-exposure": presetID = "leica.llog-exposure-one.v1"
    case "kinelog3-exposure": presetID = "kinefinity.kinelog3-exposure-one.v1"
    case "applelog-linear-ap0": presetID = "apple.log-to-linear-ap0.v1"
    case "applelog2-linear-ap0": presetID = "apple.log2-to-linear-ap0.v1"
    case "cie-lstar-exposure": presetID = "cie.l-star-exposure-one.v1"
    case "prophoto-exposure": presetID = "romm.prophoto-exposure-one.v1"
    case "bbc-exposure": presetID = "bbc.gamma-batch-exposure-one.v1"
    case "bbc-whp283-400-exposure": presetID = "bbc.whp283-400-exposure-one.v1"
    case "bbc-whp283-800-exposure": presetID = "bbc.whp283-800-exposure-one.v1"
    case "itu-proposal-400-exposure": presetID = "itu.proposal-400-exposure-one-legacy.v1"
    case "itu-proposal-800-exposure": presetID = "itu.proposal-800-exposure-one-legacy.v1"
    default: presetID = preset
    }
    guard let settings = try AlgorithmCatalog.builtIn().preset(named: presetID)?.settings else {
        throw CLIError.usage
    }
    let plan = try TransformPlan(settings: settings)
    let cube = try CubeGenerator.generate3D(plan: plan, size: size, domain: .unit)
    let text = try CubeWriter.serialize(cube)
    let temporary = target.deletingLastPathComponent().appendingPathComponent(".lutcalc-\(UUID().uuidString).tmp")
    defer { try? FileManager.default.removeItem(at: temporary) }
    try Data(text.utf8).write(to: temporary, options: .atomic)
    let readback = try CubeParser.parse(url: temporary)
    guard readback == cube else { throw CLIError.readbackMismatch }
    guard !FileManager.default.fileExists(atPath: target.path) else { throw CLIError.targetExists }
    try FileManager.default.moveItem(at: temporary, to: target)
    print("已导出 \(cube.size)^3 CUBE：\(target.path)，\(cube.samples.count) 个 Double RGB 节点")
}

do {
    try run()
} catch {
    fputs("LUTReferenceCLI: \(error)\n用法：LUTReferenceCLI --size 17 --output /path/to/output.cube [--preset ...|red-log3g10-legacy-exposure]\n", stderr)
    exit(1)
}
