import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog
import LUTSharedUI
import LUTFormats
import LUTJobs

@MainActor
final class ASCCDLDocumentContractsTests: XCTestCase {
    func testStoredDocumentSnapshotExportReadBackAndGammaPreservation() async throws {
        let cdl=try ASCCDLSettings(offset:RGB64(0.1,0.2,0.3),saturation:0)
        let settings=TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.sonySGamut3Cine,outputSpace:.sonySGamut3Cine,inputRange:.data,outputRange:.data,
            exposureStops:0,ascCDL:cdl)
        var document=try LUTProjectDocument(new:ProjectManifest(settings:settings,cubeSize:17,domain:.unit))
        let snapshot=try document.makeGenerationRequest()
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:folder)}
        let projectURL=folder.appendingPathComponent("graded.lutcalc")
        try document.makeFileWrapper().write(to:projectURL,options:.atomic,originalContentsURL:nil)
        let reopened=try LUTProjectDocument(fileWrapper:FileWrapper(url:projectURL))
        XCTAssertEqual(reopened.manifest.settings.ascCDL,cdl)
        let editor=EditorSession();try editor.openProject(at:projectURL)
        XCTAssertEqual(try editor.makeSnapshot().plan.settings.ascCDL,cdl)
        let cubeURL=folder.appendingPathComponent("graded.cube")
        _=try await NativeExportService().generate(snapshot,to:cubeURL)
        let cube=try CubeParser.parse(Data(contentsOf:cubeURL))
        let l=0.21507582011558750019*0.1+0.88506850174372831753*0.2-0.10014432185931581772*0.3
        for c in 0..<3 {XCTAssertEqual(cube.samples[0][c],l*0.9,accuracy:2e-12)}
        let spiURL=folder.appendingPathComponent("graded.spi1d")
        _=try await NativeExportService().generate(snapshot,to:spiURL)
        let spi=try SPI1DParser.parse(Data(contentsOf:spiURL))
        XCTAssertEqual(try XCTUnwrap(spi.lut.samples.first).r,0.09,accuracy:2e-12)
        XCTAssertEqual(try XCTUnwrap(spi.lut.samples.first).g,0.18,accuracy:2e-12)
        XCTAssertEqual(try XCTUnwrap(spi.lut.samples.first).b,0.27,accuracy:2e-12)
        try document.applyParameterizedGamma(ParameterizedGammaDraft(exponent:"2",linearSlope:"1",offset:"0",linearCut:"0",encodedCut:""),
            slot:.input,expectedRevision:document.revision)
        XCTAssertEqual(document.manifest.settings.ascCDL,cdl)
        XCTAssertTrue(document.undo());XCTAssertEqual(document.manifest.settings.ascCDL,cdl)
        XCTAssertTrue(document.redo());XCTAssertEqual(document.manifest.settings.ascCDL,cdl)
        XCTAssertEqual(snapshot.plan.settings.ascCDL,cdl)
    }
}
