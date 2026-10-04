import Foundation
import LUTAnalysis

@main
struct LUTAnalysisChecks {
    static func main() {
        let endpoint = RootSolver.bisect(target: 0, bracket: 0...2) { $0 * $0 }
        let noRoot = RootSolver.bisect(target: 0, bracket: -1...1) { _ in 1 }
        let flat = RootSolver.bisect(target: 1, bracket: 0...1) { _ in 1 }
        let nonFinite = RootSolver.bisect(target: 0, bracket: 0...1) { _ in .nan }
        let reference = RootSolver.bisect(target: 2, bracket: 0...2) { $0 * $0 }
        let accelerated = RootSolver.brent(target: 2, bracket: 0...2) { $0 * $0 }
        let maxIteration = RootSolver.bisect(target: 2, bracket: 0...2, tolerance: SolveTolerance(maxIterations: 0)) { $0 * $0 }
        let cancelled = RootSolver.brent(target: 2, bracket: 0...2) { _ in throw CancellationError() }
        let original = [0.0, 0.5, 0.5, 1.0]
        let curve = try? MonotonicCurve1D(values: original, domain: 0...1)
        let flatCurve = curve?.inverse(0.5)
        let uniqueCurve = curve?.inverse(0.75)
        guard endpoint.status == .converged, endpoint.value == 0,
              noRoot.status == .notBracketed, noRoot.value == nil,
              flat.status == .nonUnique, nonFinite.status == .nonFinite,
              maxIteration.status == .maxIterations, cancelled.status == .cancelled,
              reference.status == .converged, accelerated.status == .converged,
              let root = accelerated.value, abs(root - 2.squareRoot()) <= 1e-12,
              flatCurve?.status == .nonUnique, uniqueCurve?.status == .converged,
              let inverse = uniqueCurve?.value, abs(inverse - 5.0 / 6.0) <= 1e-12,
              original == [0, 0.5, 0.5, 1] else {
            fputs("H10 root contract failed\n", stderr)
            exit(1)
        }
        let functions: [(ClosedRange<Double>, Double, (Double) -> Double)] = [
            (0...10, 0.01, { $0 * $0 }),
            (0...10, 2, { $0 * $0 }),
            (0...10, 50, { $0 * $0 }),
            (-5...5, 0.25, { exp($0) }),
            (-5...5, 2, { exp($0) }),
            (-2...3, 2.25, { 5 - $0 }),
            (-2...3, 3.5, { 5 - $0 }),
        ]
        for (bracket, target, function) in functions {
            let slow = RootSolver.bisect(target: target, bracket: bracket, function: function)
            let fast = RootSolver.brent(target: target, bracket: bracket, function: function)
            guard slow.status == .converged, fast.status == .converged,
                  let slowValue = slow.value, let fastValue = fast.value,
                  abs(slowValue - fastValue) <= 2e-12,
                  abs(function(fastValue) - target) <= 3e-12 * max(1, abs(target)) else {
                fputs("H10 cross-check failed: target \(target), bisection \(slow.status), Brent \(fast.status)\n", stderr)
                exit(1)
            }
        }
        print("H10 根求解基础契约通过：端点根、无根、平段、非有限、未收敛、取消、二分与 Brent 对照及用户单调 1D 分析")
        print("H10 求解器交叉检查通过：7 个递增/递减非线性目标的 Brent 与二分结果一致")
    }
}
