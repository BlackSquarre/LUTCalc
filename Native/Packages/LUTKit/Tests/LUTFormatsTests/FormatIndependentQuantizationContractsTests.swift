import Foundation
import XCTest
import LUTCore
import LUTFormats

/// 独立核对公开格式的整数编码和节点顺序，不把 parser/writer 彼此回读当作参照。
final class FormatIndependentQuantizationContractsTests: XCTestCase {
    func testVLTWriterUsesIndependentRFastTwelveBitReferenceForEveryNode() throws {
        let size = VLTParser.size
        let maxCode = VLTParser.codeMax
        let samples: [RGB64] = try (0..<(size * size * size)).map { index in
            let red = Double((index * 17 + 1) % (maxCode + 1)) / Double(maxCode)
            let green = Double((index * 29 + 7) % (maxCode + 1)) / Double(maxCode)
            let blue = Double((index * 43 + 13) % (maxCode + 1)) / Double(maxCode)
            return try RGB64(red, green, blue)
        }
        let lut = try CubeLUT(dimension: .three, size: size, domain: .unit, samples: samples)
        let text = try VLTWriter.serialize(lut)
        let rows = text.split(separator: "\n", omittingEmptySubsequences: true)
            .filter { !$0.hasPrefix("#") && !$0.hasPrefix("LUT_3D_SIZE") }
        XCTAssertEqual(rows.count, size * size * size)

        for blue in 0..<size {
            for green in 0..<size {
                for red in 0..<size {
                    let index = blue * size * size + green * size + red
                    let expected = (0..<3).map { axis in
                        let value = samples[index][axis]
                        return Int((value * Double(maxCode)).rounded(.toNearestOrAwayFromZero))
                    }.map(String.init).joined(separator: " ")
                    XCTAssertEqual(String(rows[index]), expected, "node \(index)")
                }
            }
        }
    }
}
