import XCTest
import LUTCatalog
import LUTCore

final class DisplayP3ContractsTests: XCTestCase {
    func testDisplayP3CatalogIdentityAndPublishedPrimaries() throws {
        let catalog = try AlgorithmCatalog.builtIn()
        let descriptor = try XCTUnwrap(catalog.colorSpace(named: "Display P3"))
        XCTAssertEqual(descriptor.id, .displayP3)
        XCTAssertTrue(descriptor.source.contains("displayp3"))

        let primaries = ColorPrimaries.displayP3
        XCTAssertEqual(primaries.red.x, 0.680, accuracy: 0)
        XCTAssertEqual(primaries.red.y, 0.320, accuracy: 0)
        XCTAssertEqual(primaries.green.x, 0.265, accuracy: 0)
        XCTAssertEqual(primaries.green.y, 0.690, accuracy: 0)
        XCTAssertEqual(primaries.blue.x, 0.150, accuracy: 0)
        XCTAssertEqual(primaries.blue.y, 0.060, accuracy: 0)
        XCTAssertEqual(primaries.white.x, 0.3127, accuracy: 0)
        XCTAssertEqual(primaries.white.y, 0.3290, accuracy: 0)
    }

    func testDisplayP3RGBToXYZUsesIndependentDecimalReference() throws {
        let actual = try ColorPrimaries.displayP3.rgbToXYZ()
        let reference: [Double] = [
            0.4865709486482163, 0.26566769316909295, 0.1982172852343625,
            0.22897456406974884, 0.6917385218365062, 0.079286914093745,
            0.0, 0.04511338185890258, 1.0439443689009758,
        ]
        for (value, expected) in zip(actual.rowMajor, reference) {
            XCTAssertEqual(value, expected, accuracy: 2e-15)
        }
    }

    func testDisplayP3ConversionRoundTripsWithoutChangingTransferIdentity() throws {
        let settings = TransformSettings(
            inputTransfer: .srgbW3CExtended, outputTransfer: .srgbW3CExtended,
            inputSpace: .displayP3, outputSpace: .displayP3,
            inputRange: .data, outputRange: .data, exposureStops: 0
        )
        let plan = try TransformPlan(settings: settings)
        let sample = try RGB64(0.25, 0.5, 0.75)
        let result = try plan.evaluate(sample)
        XCTAssertEqual(result.r, sample.r, accuracy: 2e-12)
        XCTAssertEqual(result.g, sample.g, accuracy: 2e-12)
        XCTAssertEqual(result.b, sample.b, accuracy: 2e-12)
    }

}
