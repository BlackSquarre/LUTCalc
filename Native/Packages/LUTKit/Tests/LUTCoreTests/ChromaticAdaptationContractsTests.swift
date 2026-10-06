import XCTest
@testable import LUTCore

final class ChromaticAdaptationContractsTests: XCTestCase {
    func testPublishedCATModelsMatchIndependentConeResponseMatrices() throws {
        let source = try Chromaticity(x: 0.3127, y: 0.3290)
        let destination = try Chromaticity(x: 0.3457, y: 0.3585)

        let models: [(ChromaticAdaptation, [Double])] = [
            (.cieCAT02, [
                0.7328, 0.4296, -0.1624,
                -0.7036, 1.6975, 0.0061,
                0.0030, 0.0136, 0.9834,
            ]),
            (.bradford, [
                0.8951, 0.2664, -0.1614,
                -0.7502, 1.7135, 0.0367,
                0.0389, -0.0685, 1.0296,
            ]),
            (.cieCAT97s, [
                0.8562, 0.3372, -0.1934,
                -0.8360, 1.8327, 0.0033,
                0.0357, -0.0469, 1.0112,
            ]),
            (.vonKries, [
                0.40024, 0.7076, -0.08081,
                -0.2263, 1.16532, 0.0457,
                0.0, 0.0, 0.91822,
            ]),
            (.sharp, [
                1.2694, -0.0988, -0.1706,
                -0.8364, 1.8006, 0.0357,
                0.0297, -0.0315, 1.0018,
            ]),
            (.cmccat2000, [
                0.7982, 0.3389, -0.1371,
                -0.5918, 1.5512, 0.0406,
                0.0008, 0.0239, 0.9753,
            ]),
            (.biancoBS, [
                0.8752, 0.2787, -0.1539,
                -0.8904, 1.8709, 0.0195,
                -0.0061, 0.0162, 0.9899,
            ]),
            (.biancoBSPC, [
                0.6489, 0.3915, -0.0404,
                -0.3775, 1.3055, 0.0720,
                -0.0271, 0.0888, 0.9383,
            ]),
            (.xyzScaling, [
                1.0, 0.0, 0.0,
                0.0, 1.0, 0.0,
                0.0, 0.0, 1.0,
            ]),
        ]
        let independentSample: [String: [Double]] = [
            "cieCAT02": [0.26771864661508808, 0.40418364096828004, 0.07451947654602913],
            "bradford": [0.26614196974797244, 0.40187334298772407, 0.07889874457738183],
            "cieCAT97s": [0.26864209271238377, 0.40512693061575542, 0.07748034628784944],
            "vonKries": [0.27095434005267509, 0.39961999344864622, 0.07576316333406124],
            "sharp": [0.26078986185927688, 0.39972816218929194, 0.07665344346978957],
            "cmccat2000": [0.26521027714740797, 0.40086203064530492, 0.07391023796354],
            "biancoBS": [0.26486111926748802, 0.40262342206397817, 0.07483369646211019],
            "biancoBSPC": [0.26008072156554349, 0.39665269443198791, 0.07074077280430480],
            "xyzScaling": [0.25364029224922270, 0.4, 0.07576316333406124],
        ]

        for (method, coneValues) in models {
            let expected = try independentAdaptation(
                from: source, to: destination, coneValues: coneValues
            )
            let actual = try method.matrix(from: source, to: destination)
            XCTAssertEqual(actual.rowMajor.count, 9)
            for (index, value) in actual.rowMajor.enumerated() {
                XCTAssertEqual(value, expected.rowMajor[index], accuracy: 2e-15,
                               "\(method.rawValue) matrix element \(index)")
            }

            let adapted = try actual.applying(to: source.xyz())
            let target = try destination.xyz()
            XCTAssertEqual(adapted.r, target.r, accuracy: 2e-15, method.rawValue)
            XCTAssertEqual(adapted.g, target.g, accuracy: 2e-15, method.rawValue)
            XCTAssertEqual(adapted.b, target.b, accuracy: 2e-15, method.rawValue)

            let sample = try actual.applying(to: RGB64(0.25, 0.4, 0.1))
            let expectedSample = try XCTUnwrap(independentSample[method.rawValue])
            XCTAssertEqual(sample.r, expectedSample[0], accuracy: 2e-15, method.rawValue)
            XCTAssertEqual(sample.g, expectedSample[1], accuracy: 2e-15, method.rawValue)
            XCTAssertEqual(sample.b, expectedSample[2], accuracy: 2e-15, method.rawValue)
        }
    }

    func testPublishedCATModelsUseIdentityForMatchingWhitesAndRoundTripCoding() throws {
        let white = try Chromaticity(x: 0.3127, y: 0.3290)
        let models: [ChromaticAdaptation] = [
            .cieCAT02, .bradford, .cieCAT97s, .vonKries, .sharp,
            .cmccat2000, .biancoBS, .biancoBSPC, .xyzScaling,
        ]

        for method in models {
            XCTAssertEqual(try method.matrix(from: white, to: white), .identity,
                           method.rawValue)
            let data = try JSONEncoder().encode(method)
            XCTAssertEqual(try JSONDecoder().decode(ChromaticAdaptation.self, from: data), method)
        }
    }

    private func independentAdaptation(
        from source: Chromaticity,
        to destination: Chromaticity,
        coneValues: [Double]
    ) throws -> Matrix3x3 {
        let cone = try Matrix3x3(rowMajor: coneValues)
        let sourceCone = try cone.applying(to: source.xyz())
        let destinationCone = try cone.applying(to: destination.xyz())
        let diagonal = try Matrix3x3(rowMajor: [
            destinationCone.r / sourceCone.r, 0, 0,
            0, destinationCone.g / sourceCone.g, 0,
            0, 0, destinationCone.b / sourceCone.b,
        ])
        return try cone.inverted().multiplied(by: diagonal).multiplied(by: cone)
    }
}
