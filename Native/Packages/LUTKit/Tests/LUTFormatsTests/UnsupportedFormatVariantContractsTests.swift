import Foundation
import XCTest
import LUTFormats

/// 厂商/版本扩展没有独立规范时必须保持拒绝，避免把近似语法当成兼容实现。
final class UnsupportedFormatVariantContractsTests: XCTestCase {
    func testSPI3DRejectsUnknownVersionAndNonRGBLayout() {
        let unknownVersion = "SPILUT 2.0\n3 3\n2 2 2\n"
        XCTAssertThrowsError(try SPI3DParser.parse(Data(unknownVersion.utf8))) {
            XCTAssertEqual(($0 as? SPI3DFailure)?.category, .unsupported)
        }
        let nonRGB = "SPILUT 1.0\n4 4\n2 2 2\n"
        XCTAssertThrowsError(try SPI3DParser.parse(Data(nonRGB.utf8))) {
            XCTAssertEqual(($0 as? SPI3DFailure)?.category, .unsupported)
        }
    }

    func testThreeDLRejectsLustreMarkersInPlainFlavor() throws {
        let source = "3DMESH\nMesh 1 4\n0 3\n" +
            Array(repeating: "0 0 0", count: 8).joined(separator: "\n") + "\nLUT8\ngamma 1.0\n"
        XCTAssertThrowsError(try ThreeDLParser.parse(Data(source.utf8), flavor: .flame)) {
            XCTAssertEqual(($0 as? ThreeDLFailure)?.category, .unsupported)
        }
        XCTAssertThrowsError(try ThreeDLParser.parse(Data(source.utf8), flavor: .kodak)) {
            XCTAssertEqual(($0 as? ThreeDLFailure)?.category, .unsupported)
        }
    }

    func testAssimilateRejectsUnknownChannelCount() {
        XCTAssertThrowsError(try AssimilateLUTParser.parse(Data("LUT: 2 3\n".utf8))) {
            XCTAssertEqual(($0 as? AssimilateLUTFailure)?.category, .unsupported)
        }
    }

    func testVLTRejectsNonPanasonicVersionAndGrid() {
        let version = "# panasonic vlt file version 2.0\n# source vlt file \"\"\nLUT_3D_SIZE 17\n"
        XCTAssertThrowsError(try VLTParser.parse(Data(version.utf8))) {
            XCTAssertEqual(($0 as? VLTFailure)?.category, .unsupported)
        }
        let grid = "# panasonic vlt file version 1.0\n# source vlt file \"\"\nLUT_3D_SIZE 33\n"
        XCTAssertThrowsError(try VLTParser.parse(Data(grid.utf8))) {
            XCTAssertEqual(($0 as? VLTFailure)?.category, .unsupported)
        }
    }
}
