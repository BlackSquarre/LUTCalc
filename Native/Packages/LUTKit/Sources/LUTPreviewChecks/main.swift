import Foundation
import LUTCore
import LUTPreview

private enum Failure: Error { case mismatch(String) }

private func close(_ actual: Double, _ expected: Double, _ label: String) throws {
    guard abs(actual - expected) <= 2e-12 * max(1, abs(expected)) else {
        throw Failure.mismatch("\(label): \(actual) vs \(expected)")
    }
}

do {
    let settings = TransformSettings(
        inputTransfer: .linearScene, outputTransfer: .linearScene,
        inputSpace: .srgb, outputSpace: .srgb,
        inputRange: .data, outputRange: .data, exposureStops: 1
    )
    let plan = try TransformPlan(settings: settings)
    let documentID = UUID(uuidString: "DAF6823D-B373-48B6-ACAB-005925F7741A")!
    let requestID = UUID(uuidString: "34DAA78F-6332-45D5-9C70-0D3037212026")!
    let identity = PreviewIdentity(documentID: documentID, revision: 7,
                                   requestID: requestID, planVersion: plan.planVersion)
    let pixels = try [
        RGBA64(rgb: RGB64(0.09, 0.18, -0.09), alpha: 1),
        RGBA64(rgb: RGB64(0.045, 0.09, -0.045), alpha: 0.5),
        RGBA64(rgb: RGB64(100, -100, 50), alpha: 0),
    ]
    let request = try PreviewRequest(plan: plan, width: 3, height: 1, pixels: pixels,
        inputAlpha: .premultiplied, outputAlpha: .straight, identity: identity)
    let output = try CPUPreview.render(request)
    guard output.identity == identity, output.pixels.count == 3,
          output.inputAlpha == .premultiplied, output.outputAlpha == .straight,
          try output.sample(x: 0, y: 0).source == pixels[0] else {
        throw Failure.mismatch("metadata or source sample")
    }
    for index in 0..<2 {
        let sample = try output.sample(x: index, y: 0)
        try close(sample.output.rgb.r, 0.18, "red \(index)")
        try close(sample.output.rgb.g, 0.36, "green \(index)")
        try close(sample.output.rgb.b, -0.18, "blue \(index)")
        try close(sample.output.alpha, pixels[index].alpha, "alpha \(index)")
    }
    let hidden = try output.sample(x: 2, y: 0)
    guard hidden.output.rgb == (try RGB64(0, 0, 0)), hidden.output.alpha == 0 else {
        throw Failure.mismatch("alpha zero hidden color")
    }
    let logPlan = try TransformPlan(settings: TransformSettings(
        inputTransfer: .djiDLog2, outputTransfer: .linearScene,
        inputSpace: .djiDGamut2, outputSpace: .acesAP0,
        inputRange: .data, outputRange: .data, exposureStops: 0
    ))
    let transparentLog = try PreviewRequest(plan: logPlan, width: 1, height: 1,
        pixels: [RGBA64(rgb: RGB64(0.4, 0.5, 0.6), alpha: 0)],
        inputAlpha: .premultiplied, outputAlpha: .straight,
        identity: PreviewIdentity(documentID: documentID, revision: 9,
                                  requestID: UUID(), planVersion: logPlan.planVersion))
    guard try CPUPreview.render(transparentLog).sample(x: 0, y: 0).output.rgb == RGB64(0, 0, 0) else {
        throw Failure.mismatch("transparent log pixel leaked hidden RGB")
    }
    let premultiplied = try CPUPreview.render(PreviewRequest(
        plan: plan, width: 3, height: 1, pixels: pixels,
        inputAlpha: .premultiplied, outputAlpha: .premultiplied,
        identity: PreviewIdentity(documentID: documentID, revision: 8,
                                  requestID: requestID, planVersion: plan.planVersion)
    ))
    let middle = try premultiplied.sample(x: 1, y: 0)
    try close(middle.output.rgb.r, 0.09, "repremultiplied red")
    try close(middle.output.rgb.g, 0.18, "repremultiplied green")
    let latest = PreviewIdentityGate(expected: premultiplied.identity, active: true)
    guard latest.accepts(output) == false, latest.accepts(premultiplied),
          latest.accepts(identity: output.identity) == false,
          PreviewIdentityGate(expected: premultiplied.identity, active: false).accepts(premultiplied) == false,
          PreviewIdentityGate(expected: PreviewIdentity(documentID: UUID(), revision: 8,
              requestID: requestID, planVersion: plan.planVersion), active: true).accepts(premultiplied) == false,
          PreviewIdentityGate(expected: PreviewIdentity(documentID: documentID, revision: 8,
              requestID: UUID(), planVersion: plan.planVersion), active: true).accepts(premultiplied) == false,
          PreviewIdentityGate(expected: PreviewIdentity(documentID: documentID, revision: 8,
              requestID: requestID, planVersion: "different-plan"), active: true).accepts(premultiplied) == false else {
        throw Failure.mismatch("stale preview identity accepted")
    }
    do {
        _ = try PreviewRequest(plan: plan, width: 3, height: 1, pixels: pixels,
            inputAlpha: .straight, outputAlpha: .straight,
            identity: PreviewIdentity(documentID: documentID, revision: 8,
                requestID: requestID, planVersion: "different-plan"))
        throw Failure.mismatch("mismatched plan version accepted")
    } catch PreviewError.invalidIdentity {}
    do {
        _ = try PreviewRequest(plan: plan, width: Int.max, height: 2, pixels: [],
            inputAlpha: .straight, outputAlpha: .straight, identity: identity)
        throw Failure.mismatch("overflow size accepted")
    } catch PreviewError.invalidDimensions {}
    do {
        _ = try RGBA64(rgb: RGB64(0, 0, 0), alpha: 1.1)
        throw Failure.mismatch("invalid alpha accepted")
    } catch PreviewError.invalidAlpha {}
    let session = PreviewSession(documentID: documentID)
    let slow = try await session.begin(revision: 11, planVersion: plan.planVersion)
    let fast = try await session.begin(revision: 11, planVersion: plan.planVersion)
    guard slow.requestID != fast.requestID,
          await session.accepts(slow) == false,
          await session.accepts(fast),
          await session.accepts(PreviewIdentity(documentID: UUID(), revision: 11,
              requestID: fast.requestID, planVersion: fast.planVersion)) == false else {
        throw Failure.mismatch("out-of-order preview accepted")
    }
    do {
        _ = try await session.begin(revision: 10, planVersion: plan.planVersion)
        throw Failure.mismatch("older revision replaced current request")
    } catch PreviewError.invalidIdentity {}
    await session.close()
    guard await session.accepts(fast) == false else {
        throw Failure.mismatch("closed preview session accepted late result")
    }
    do {
        _ = try await session.begin(revision: 12, planVersion: plan.planVersion)
        throw Failure.mismatch("closed preview session restarted")
    } catch PreviewError.invalidIdentity {}
    print("H13 CPU 取样契约通过：Double 负值/超白、alpha 处理、文档/修订/请求/计划身份与关闭状态门控")
} catch {
    fputs("LUTPreviewChecks: \(error)\n", stderr)
    exit(1)
}
