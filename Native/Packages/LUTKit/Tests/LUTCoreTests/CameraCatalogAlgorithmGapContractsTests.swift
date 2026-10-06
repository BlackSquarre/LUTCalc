import XCTest
import LUTCore
import LUTCatalog

final class CameraCatalogAlgorithmGapContractsTests: XCTestCase {
    /// These profiles are deliberately not routed through a nearby transfer or
    /// gamut. Their names describe vendor-specific or sampled behaviour for
    /// which this package has no exact public formula and color-space pair.
    func testPublishedDefaultsKeepUnresolvedCameraAlgorithmsBlocked() throws {
        let expected: Set<String> = [
            "camera.sony.venice.v1", "camera.sony.venice-high-base.v1",
            "camera.red.epic-dragon.v1", "camera.canon.c300.v1",
            "camera.canon.c500.v1", "camera.blackmagic.pocket-cinema-6k.v1",
            "camera.blackmagic.pocket-cinema-6k-high-base.v1",
            "camera.blackmagic.pocket-cinema-4k.v1",
            "camera.blackmagic.pocket-cinema-4k-high-base.v1",
            "camera.fujifilm.mirrorless-f-log.v1", "camera.gopro.hero.v1",
            "camera.dji.4d-6k.v1", "camera.dji.4d-6k-high-base.v1",
            "camera.dji.4d-8k.v1", "camera.dji.4d-8k-high-base.v1",
            "camera.dji.mavic-2.v1", "camera.dji.mini-2.v1",
            "camera.dji.zenmuse-x9-6k.v1",
            "camera.dji.zenmuse-x9-6k-high-base.v1",
            "camera.dji.zenmuse-x9-8k.v1",
            "camera.dji.zenmuse-x9-8k-high-base.v1",
            "camera.dji.zenmuse-x7.v1", "camera.dji.zenmuse-x5s.v1",
            "camera.dji.zenmuse-x3.v1", "camera.nikon.d800.v1"
        ]
        let base = TransformSettings(inputTransfer: .linearScene,
                                     outputTransfer: .linearScene,
                                     inputSpace: .rec2020,
                                     outputSpace: .rec2020,
                                     inputRange: .data,
                                     outputRange: .data,
                                     exposureStops: 0)
        var blocked = Set<String>()
        for profile in CameraCatalog.profiles {
            let state = try CameraExposureSettings.selecting(
                profileID: profile.id, inputPolicy: .publishedAvailableDefaults)
            do {
                _ = try CameraPresetResolver.applying(state, to: base)
            } catch CameraExposureError.unsupportedDefaults {
                blocked.insert(profile.id)
            }
        }
        XCTAssertEqual(blocked, expected)
    }
}
