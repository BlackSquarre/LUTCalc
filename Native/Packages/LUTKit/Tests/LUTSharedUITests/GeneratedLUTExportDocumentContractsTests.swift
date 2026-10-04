import Foundation
import XCTest
@testable import LUTSharedUI

final class GeneratedLUTExportDocumentContractsTests: XCTestCase {
    func testGeneratedDocumentCapturesSourceBytesAndFilename() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("lutcalc-generated-document-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("generated.cube")
        let bytes = Data("TITLE \"Double\"\nLUT_1D_SIZE 2\n0 0 0\n1 1 1\n".utf8)
        try bytes.write(to: source)

        let document = try GeneratedLUTExportDocument(sourceURL: source,
                                                       suggestedFilename: "saved.cube")
        try Data("changed after generation".utf8).write(to: source)
        XCTAssertEqual(document.suggestedFilename, "saved.cube")
        XCTAssertEqual(document.contentType, LUTExportContentTypes.cube)
        XCTAssertTrue(GeneratedLUTExportDocument.writableContentTypes.contains(document.contentType))
        XCTAssertEqual(document.bytes, bytes)
        XCTAssertEqual(document.makeFileWrapper().regularFileContents, bytes)
    }

    func testGeneratedDocumentUsesDeclaredTypeForSPI3D() throws {
        let document = try GeneratedLUTExportDocument(bytes: Data("3D_TABLE\n".utf8),
                                                       suggestedFilename: "saved.spi3d")
        XCTAssertEqual(document.contentType, LUTExportContentTypes.spi3d)
        XCTAssertTrue(GeneratedLUTExportDocument.writableContentTypes.contains(document.contentType))
    }

    func testEveryGeneratedFormatHasItsOwnWritableType() throws {
        for format in ["cube", "spi3d", "spi1d", "3dl", "ilut", "olut", "lut", "vlt"] {
            let document = try GeneratedLUTExportDocument(
                bytes: Data("LUT".utf8), suggestedFilename: "saved.\(format)")
            XCTAssertEqual(document.contentType.identifier, "com.lutcalc.\(format)")
            XCTAssertNotEqual(document.contentType, .data)
            XCTAssertTrue(GeneratedLUTExportDocument.writableContentTypes.contains(document.contentType))
        }
    }

    func testGeneratedDocumentRejectsPathTraversalAndOversizedBytes() throws {
        XCTAssertThrowsError(try GeneratedLUTExportDocument(bytes: Data(),
                                                            suggestedFilename: "../saved.cube")) {
            XCTAssertEqual($0 as? GeneratedLUTExportDocumentError, .emptyFilename)
        }
        let oversized = Data(repeating: 0, count: GeneratedLUTExportDocument.maxBytes + 1)
        XCTAssertThrowsError(try GeneratedLUTExportDocument(bytes: oversized,
                                                            suggestedFilename: "saved.cube")) {
            XCTAssertEqual($0 as? GeneratedLUTExportDocumentError, .resourceLimit)
        }
    }
}
