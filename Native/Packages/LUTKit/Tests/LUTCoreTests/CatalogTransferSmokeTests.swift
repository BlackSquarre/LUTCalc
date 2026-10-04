import XCTest
@testable import LUTCore
import LUTCatalog

final class CatalogTransferSmokeTests: XCTestCase {
    func testEveryNonParameterizedCatalogTransferHasAFiniteSameSpaceRoundTrip() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        for descriptor in catalog.transfers where descriptor.id != .parameterizedGamma {
            let space = matchingSpace(for: descriptor.id)
            let settings = TransformSettings(
                inputTransfer: descriptor.id, outputTransfer: descriptor.id,
                inputSpace: space, outputSpace: space,
                inputRange: .data, outputRange: .data, exposureStops: 0,
                inputLogC: descriptor.id.requiresLogCSceneSettings ? try ARRILogCSceneSettings(
                    algorithm: descriptor.id == .arriLogCSUP2Scene ? .sup2Published : .sup3Published, exposureIndex: 800) : nil,
                outputLogC: descriptor.id.requiresLogCSceneSettings ? try ARRILogCSceneSettings(
                    algorithm: descriptor.id == .arriLogCSUP2Scene ? .sup2Published : .sup3Published, exposureIndex: 800) : nil)
            let plan = try TransformPlan(settings: settings)
            for value in [0.0, 0.18, 0.5, 1.0] {
                let input = try RGB64(value, value, value)
                do {
                    let output = try plan.evaluate(input)
                    XCTAssertTrue(output.r.isFinite && output.g.isFinite && output.b.isFinite,
                                  "\(descriptor.id.rawValue) produced non-finite output")
                    // ACESproxy uses a legal-range black pedestal. Values below
                    // the published low-linear threshold encode to the black
                    // code, so an arbitrary data-domain zero is intentionally
                    // not an identity point. Its exact black-code contract is
                    // covered by ACESProxyContractsTests.
                    let hasExactZeroRoundTrip = descriptor.id != .bbcWHP283400
                        && descriptor.id != .bbcWHP283800
                        && descriptor.id != .acesProxy10
                        && descriptor.id != .acesProxy12
                        // Canon's historical C-Log2 encoder retains its
                        // published pedestal at scene zero.
                        && descriptor.id != .canonCLog2LUTCalcLegacy
                        // GoPro Protune's zero-slope legacy encoder uses its
                        // fixed 1e-15 near-zero branch, so data zero is not
                        // an exact same-space round-trip point.
                        && descriptor.id != .goProProtuneLUTCalcLegacy
                    if hasExactZeroRoundTrip {
                        XCTAssertEqual(output.r, value, accuracy: 2e-12,
                                       "\(descriptor.id.rawValue) round trip at \(value)")
                        XCTAssertEqual(output.g, value, accuracy: 2e-12)
                        XCTAssertEqual(output.b, value, accuracy: 2e-12)
                    }
                } catch {
                    XCTFail("\(descriptor.id.rawValue) rejected same-space sample \(value): \(error)")
                }
            }
        }
    }

    private func matchingSpace(for transfer: TransferID) -> ColorSpaceID {
        switch transfer {
        case .djiDLog2: .djiDGamut2
        case .canonCLog2, .canonCLog2LUTCalcLegacy, .canonCLog3: .canonCinemaGamut
        case .sonySLog3, .sonySLog3LUTCalcLegacy: .sonySGamut3Cine
        case .arriLogC4: .arriWideGamut4
        case .panasonicVLog: .panasonicVGamut
        case .fujifilmFLog2, .fujifilmFLog2LUTCalcLegacy: .fujifilmFGamut
        case .acesCCT: .acesAP1
        case .insta360ILog, .xiaomiMiLog, .leicaLLog: .rec2020
        case .kineLog3: .kinefinityWideGamut
        case .appleLogOriginal: .rec2020
        case .appleLog2: .appleWideGamut
        case .proPhoto: .proPhoto
        default: .srgb
        }
    }
}
