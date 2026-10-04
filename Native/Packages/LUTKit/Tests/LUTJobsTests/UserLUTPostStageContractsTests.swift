import XCTest
import LUTCore
import LUTFormats
import LUTJobs

final class UserLUTPostStageContractsTests: XCTestCase {
    private func plan(output: SignalNormalization = .data, exposure: Double = 0) throws -> TransformPlan {
        try TransformPlan(settings: TransformSettings(inputTransfer: .linearScene, outputTransfer: .linearScene,
            inputSpace: .acesAP0, outputSpace: .acesAP0, inputRange: .data, outputRange: output,
            exposureStops: exposure))
    }
    private func curve() throws -> CubeLUT {
        try CubeLUT(dimension: .one, size: 3, domain: .unit,
            samples: [RGB64(0,0,0),RGB64(0.25,0.25,0.25),RGB64(1,1,1)])
    }
    // Independent Hermite expansion for the three quadratic samples, including
    // the documented zero-slope replacement at the first endpoint.
    private func reference(_ x: Double) -> Double {
        if x <= 0 { return 2*x*0.00375 }
        if x >= 1 { return 1+(2*x-2) }
        if x >= 0.5 { return x*x }
        let t = 2*x
        return 0.00375*t*t*t + 0.2425*t*t + 0.00375*t
    }
    func testFull33And65GridsUseFrozenCubicSnapshotAcrossWorkers() async throws {
        let settings = UserLUTPostStageSettings(interpolation: .tricubicLegacyV1, outside: .reject)
        var maximum = 0.0
        for size in [33,65] {
            var baseline: [RGB64]?
            for workers in [1,4] {
                let request = try LUTGenerationRequest(plan: plan(), size: size, domain: .unit,
                    blockNodes: 997, workerCount: workers, postLUT: curve(), postLUTSettings: settings)
                let sink = InMemoryCubeSink()
                _ = try await GenerationCoordinator().generate(request, sink: sink)
                let actual = await sink.samples
                let grid = try Grid3D(size: size, domain: .unit)
                XCTAssertEqual(actual.count, grid.nodeCount)
                for i in 0..<actual.count {
                    let p = try grid.coordinate(at: i)
                    for c in 0..<3 {
                        let error = abs(actual[i][c]-reference(p[c]))
                        maximum = max(maximum,error)
                        XCTAssertLessThanOrEqual(error, 2e-12)
                    }
                }
                if let baseline { XCTAssertEqual(actual,baseline) } else { baseline = actual }
            }
        }
        print("用户 cubic 33³/65³ 全节点独立参照与 1/4 worker 一致；最大绝对误差 \(maximum)")
    }
    func testCombinedShaperCubicAndCoupled3DRunAfterOutputNormalization() async throws {
        let grid = try Grid3D(size: 4, domain: .unit)
        let samples = try (0..<grid.nodeCount).map { i -> RGB64 in
            let p = try grid.coordinate(at:i)
            return try RGB64(0.1+p.r+2*p.g+3*p.b, p.r-p.g, p.b+0.5*p.r)
        }
        let shaper = try CubeShaper(size: 3, domain: .unit, samples: curve().samples)
        let combined = try CubeLUT(dimension: .three, size: 4, domain: .unit, samples: samples, shaper: shaper)
        let domain = try LUTDomain(min: RGB64(64.0/1023,64.0/1023,64.0/1023),
                                   max: RGB64(940.0/1023,940.0/1023,940.0/1023))
        let request = try LUTGenerationRequest(plan: plan(output: .video), size: 17, domain: domain,
            postLUT: combined, postLUTSettings: .init(interpolation: .tricubicLegacyV1, outside: .reject))
        let sink = InMemoryCubeSink()
        _ = try await GenerationCoordinator().generate(request, sink: sink)
        let actual = await sink.samples
        let inputGrid = try Grid3D(size: 17, domain: domain)
        var maximum = 0.0
        for i in 0..<actual.count {
            let input = try inputGrid.coordinate(at:i)
            let q = (0..<3).map { reference((input[$0]*1023-64)/876) }
            let expected = [0.1+q[0]+2*q[1]+3*q[2],q[0]-q[1],q[2]+0.5*q[0]]
            for c in 0..<3 {
                maximum = max(maximum,abs(actual[i][c]-expected[c]))
                XCTAssertEqual(actual[i][c], expected[c], accuracy: 2e-12)
            }
        }
        print("用户 shaper→耦合 3D 在输出 video 归一化之后应用；最大绝对误差 \(maximum)")
        XCTAssertThrowsError(try LUT1DGenerationRequest(plan: plan(), size: 17, domain: .unit,
            postLUT: combined, postLUTSettings: request.postLUTSettings)) {
            XCTAssertEqual(($0 as? SPI1DFailure)?.category, .lossyRepresentation)
        }
    }
    func testOutsideConfigurationIsValidatedAndFailedGenerationAborts() async throws {
        let lut = try curve()
        XCTAssertThrowsError(try LUTGenerationRequest(plan: plan(), size: 3, domain: .unit,
            postLUT: lut, postLUTSettings: .init(interpolation: .trilinear, outside: .legacyExtensionV1)))
        let reject = try LUTGenerationRequest(plan: plan(exposure: 1), size: 3, domain: .unit,
            postLUT: lut, postLUTSettings: .init(interpolation: .tricubicLegacyV1, outside: .reject))
        let sink = InMemoryCubeSink()
        do { _ = try await GenerationCoordinator().generate(reject, sink: sink); XCTFail("Expected outside rejection") }
        catch { XCTAssertEqual(error as? VolumeError, .outsideDomain) }
        let state = await sink.state
        XCTAssertEqual(state, .aborted)
        for (outside,expected) in [(LUTOutsidePolicy.clampToDomain,1.0),(.legacyExtensionV1,3.0)] {
            let request = try LUTGenerationRequest(plan: plan(exposure: 1), size: 3, domain: .unit,
                postLUT: lut, postLUTSettings: .init(interpolation: .tricubicLegacyV1, outside: outside))
            let output = InMemoryCubeSink()
            _ = try await GenerationCoordinator().generate(request,sink:output)
            let values = await output.samples
            XCTAssertEqual(values.last?.r,expected)
        }
        XCTAssertThrowsError(try LUTGenerationRequest(plan: plan(), size: 3, domain: .unit,
            postLUTSettings: .init(interpolation: .tricubicLegacyV1, outside: .reject)))
    }
}
