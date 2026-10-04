import Foundation
import XCTest
import LUTCore
import LUTProject
import LUTCatalog

final class ASCCDLProjectContractsTests: XCTestCase {
    private func manifest(_ cdl: ASCCDLSettings? = nil) -> ProjectManifest {
        ProjectManifest(settings: TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.sonySGamut3Cine,outputSpace:.sonySGamut3Cine,inputRange:.data,outputRange:.data,
            exposureStops:0,ascCDL:cdl),cubeSize:33,domain:.unit)
    }
    func testSchema4ExactPersistenceHistoryAndSnapshot() throws {
        let catalog=try AlgorithmCatalog.builtIn()
        let cdl=try ASCCDLSettings(slope:RGB64(1.125,0.75,1.25),offset:RGB64(-0.0,0.0625,-0.125),
            power:RGB64(2,1,0.5),saturation:1.25)
        let m=manifest(cdl), bytes=try ProjectCodec.encode(m,catalog:catalog)
        XCTAssertEqual(m.schemaVersion,ProjectManifest.currentSchema)
        XCTAssertEqual(m.algorithmVersions["ascCDL"],ASCCDLAlgorithm.lutcalcWorkingLinearV1.rawValue)
        let decoded=try ProjectCodec.decode(bytes,catalog:catalog)
        XCTAssertEqual(decoded,m)
        XCTAssertEqual(decoded.settings.ascCDL?.offset.r.bitPattern,(-0.0 as Double).bitPattern)
        var session=try ProjectEditingSession(new:m,catalog:catalog)
        let snapshot=try TransformPlan(settings:session.current.settings)
        try session.apply(ProjectManifest(id:m.id,settings:m.settings.withASCCDL(nil),cubeSize:m.cubeSize,domain:m.domain))
        XCTAssertTrue(session.undo()); XCTAssertEqual(session.current.settings.ascCDL,cdl)
        XCTAssertTrue(session.redo()); XCTAssertNil(session.current.settings.ascCDL)
        XCTAssertEqual(snapshot.settings.ascCDL,cdl)
        let settings=m.settings
        for updated in [settings.withInputRange(.video),settings.withOutputRange(.video),
            settings.withExposureStops(0.75),settings.withRangeBitDepth(12),settings.withAdaptation(.bradford),
            settings.withInput(transfer:.srgbW3CExtended,space:.srgb),
            settings.withOutput(transfer:.srgbW3CExtended,space:.srgb)] {
            XCTAssertEqual(updated.ascCDL,cdl)
        }
    }
    func testOldSchemasUnknownFieldsAndAlgorithmMismatchAreRejected() throws {
        let catalog=try AlgorithmCatalog.builtIn()
        let oldBytes=try ProjectCodec.encode(manifest(),catalog:catalog)
        for schema in [1,2,3] {
            var raw=try JSONSerialization.jsonObject(with:oldBytes) as! [String:Any]
            raw["schemaVersion"]=schema
            if schema==1 { raw.removeValue(forKey:"assetRoles") }
            let migrated=try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)
            XCTAssertEqual(migrated.schemaVersion,ProjectManifest.currentSchema);XCTAssertNil(migrated.settings.ascCDL)
        }
        let bytes=try ProjectCodec.encode(manifest(ASCCDLSettings()),catalog:catalog)
        var raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        for schema in [1,2,3] {
            raw["schemaVersion"]=schema
            XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog))
            XCTAssertThrowsError(try JSONDecoder().decode(ProjectManifest.self,from:JSONSerialization.data(withJSONObject:raw)))
        }
        raw["schemaVersion"]=4
        var settings=raw["settings"] as! [String:Any], cdl=settings["ascCDL"] as! [String:Any]
        cdl["mystery"]=true;settings["ascCDL"]=cdl;raw["settings"]=settings
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)) {
            XCTAssertEqual($0 as? ProjectError,.unknownField("settings.ascCDL.mystery"))
        }
        cdl.removeValue(forKey:"mystery");var slope=cdl["slope"] as! [String:Any];slope["extra"]=0
        cdl["slope"]=slope;settings["ascCDL"]=cdl;raw["settings"]=settings
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog))
        raw=try JSONSerialization.jsonObject(with:bytes) as! [String:Any]
        var versions=raw["algorithmVersions"] as! [String:String];versions["ascCDL"]="unverified"
        raw["algorithmVersions"]=versions
        XCTAssertThrowsError(try ProjectCodec.decode(JSONSerialization.data(withJSONObject:raw),catalog:catalog)) {
            XCTAssertEqual($0 as? ProjectError,.algorithmMismatch)
        }
    }
}
