import LUTCore

public enum CubeGenerationFailure: Error, Equatable, Sendable {
    case memoryBudgetExceeded
}

public enum CubeGenerator {
    public static func generate3D(plan: TransformPlan, size: Int, domain: LUTDomain) throws -> CubeLUT {
        let grid = try Grid3D(size: size, domain: domain)
        guard grid.rgbDoubleBytes <= CubeParser.maxDecodedBytes else {
            throw CubeGenerationFailure.memoryBudgetExceeded
        }
        var samples: [RGB64] = []
        samples.reserveCapacity(grid.nodeCount)
        for index in 0..<grid.nodeCount {
            samples.append(try plan.evaluate(grid.coordinate(at: index), sampleIndex: index))
        }
        return try CubeLUT(
            dimension: .three, size: size, domain: domain,
            samples: samples,
            title: "LUTCalc native \(plan.planVersion)"
        )
    }
}
