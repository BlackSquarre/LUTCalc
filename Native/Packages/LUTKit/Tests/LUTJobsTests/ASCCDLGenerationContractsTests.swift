import XCTest
import LUTCore
import LUTJobs
import LUTFormats

final class ASCCDLGenerationContractsTests: XCTestCase {
    func testIndependent1DMatchesLegacySOPWithoutSaturationAndIsDeterministic() async throws {
        let cdl=try ASCCDLSettings(slope:RGB64(1.25,0.75,1.5),offset:RGB64(-0.125,0.0625,-0.25),
                                  power:RGB64(2,1,2),saturation:0)
        let plan=try TransformPlan(settings:TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.acesAP0,outputSpace:.acesAP0,inputRange:.data,outputRange:.data,exposureStops:1,ascCDL:cdl))
        var baseline:[RGB64]?
        for workers in [1,4] {
            let request=try LUT1DGenerationRequest(plan:plan,size:1024,domain:.unit,blockNodes:31,workerCount:workers)
            let sink=InMemoryOneDSink()
            _=try await OneDGenerationCoordinator().generate(request,sink:sink)
            let samples=await sink.samples
            for i in 0..<samples.count {
                let x=Double(i)/1023*2/0.9
                let q=[1.25*x-0.125,0.75*x+0.0625,1.5*x-0.25]
                for c in 0..<3 {
                    let expected=(q[c]<0 || c==1 ? q[c] : q[c]*q[c])*0.9
                    XCTAssertEqual(samples[i][c],expected,accuracy:2e-12)
                }
            }
            if let baseline { XCTAssertEqual(samples,baseline) } else {baseline=samples}
        }
    }
    func test3DCouplingAndFailedGenerationAbort() async throws {
        let cdl=try ASCCDLSettings(saturation:0)
        let plan=try TransformPlan(settings:TransformSettings(inputTransfer:.linearScene,outputTransfer:.linearScene,
            inputSpace:.sonySGamut3Cine,outputSpace:.sonySGamut3Cine,inputRange:.data,outputRange:.data,exposureStops:0,ascCDL:cdl))
        var baseline:[RGB64]?
        for workers in [1,4] {
            let request=try LUTGenerationRequest(plan:plan,size:33,domain:.unit,blockNodes:997,workerCount:workers)
            let sink=InMemoryCubeSink();_=try await GenerationCoordinator().generate(request,sink:sink)
            let samples=await sink.samples
            XCTAssertEqual(samples[1].r,samples[1].g);XCTAssertEqual(samples[1].r,samples[1].b)
            XCTAssertEqual(samples[1].r,0.21507582011558750019/32,accuracy:2e-12)
            if let baseline {XCTAssertEqual(samples,baseline)} else {baseline=samples}
        }
        let bad=try ASCCDLSettings(power:RGB64(-1,1,1))
        let invalid=try TransformPlan(settings:plan.settings.withASCCDL(bad))
        let sink=InMemoryCubeSink()
        do {_=try await GenerationCoordinator().generate(LUTGenerationRequest(plan:invalid,size:17,domain:.unit),sink:sink);XCTFail("Expected singular power")}
        catch {XCTAssertEqual(error as? PlanError,.numeric(stageID:8,sampleIndex:0))}
        let state=await sink.state;XCTAssertEqual(state,.aborted)
    }
}

private actor InMemoryOneDSink: OneDBlockSink {
    private(set) var samples: [RGB64] = []
    func prepare(size:Int,domain:LUTDomain,title:String) { samples=[] }
    func append(blockIndex:Int,samples:[RGB64]) { self.samples.append(contentsOf:samples) }
    func validate(expectedNodes:Int) throws {
        guard samples.count==expectedNodes else {throw JobFailure.rowCountMismatch}
    }
    func commit() {}
    func abort() {samples=[]}
}
