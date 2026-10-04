import Foundation
import XCTest
import LUTCore
import LUTFormats
import LUTPreview

final class UserLUTPostStagePreviewContractsTests: XCTestCase {
    func testCPUPreviewUsesCubicSettingsAndPreservesAlphaSemantics() throws {
        let plan = try TransformPlan(settings: .init(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.acesAP0,outputSpace:.acesAP0,inputRange:.data,outputRange:.data,exposureStops:0))
        let lut = try CubeLUT(dimension:.one,size:3,domain:.unit,
            samples:[RGB64(0,0,0),RGB64(0.25,0.25,0.25),RGB64(1,1,1)])
        let identity = PreviewIdentity(documentID:UUID(),revision:0,requestID:UUID(),planVersion:plan.planVersion)
        let request = try PreviewRequest(plan:plan,width:2,height:1,
            pixels:[RGBA64(rgb:RGB64(0.125,0.125,0.125),alpha:0.5),RGBA64(rgb:RGB64(1,1,1),alpha:0)],
            inputAlpha:.premultiplied,outputAlpha:.straight,identity:identity,postLUT:lut,
            postLUTSettings:.init(interpolation:.tricubicLegacyV1,outside:.reject))
        let result = try CPUPreview.render(request)
        XCTAssertEqual(try result.sample(x:0,y:0).planOutput.r,0.06296875,accuracy:2e-12)
        XCTAssertEqual(try result.sample(x:1,y:0).planOutput,try RGB64(0,0,0))
    }
}
