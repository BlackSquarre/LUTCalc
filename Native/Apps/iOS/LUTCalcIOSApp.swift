import SwiftUI
import LUTSharedUI

@main
struct LUTCalcIOSApp: App {
    init() {
        let processInfo = ProcessInfo.processInfo
        let repeatedProbeRequested = processInfo.arguments.contains("-LUTCalcDevicePerformanceRepeatProbe") ||
            processInfo.environment["LUTCALC_DEVICE_PERFORMANCE_REPEAT"] == "1"
        let probeRequested = processInfo.arguments.contains("-LUTCalcDevicePerformanceProbe") ||
            processInfo.environment["LUTCALC_DEVICE_PERFORMANCE_PROBE"] == "1"
        guard repeatedProbeRequested || probeRequested else {
            return
        }
        DispatchQueue.global(qos: .utility).async {
            do {
                let repeated = repeatedProbeRequested
                let data = try repeated
                    ? DevicePerformanceProbe.encodedRepeatedJSON()
                    : DevicePerformanceProbe.encodedJSON()
                let documents = try FileManager.default.url(
                    for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                let name = repeated
                    ? "lutcalc-device-performance-repeat.json"
                    : "lutcalc-device-performance.json"
                try data.write(to: documents.appendingPathComponent(name),
                               options: .atomic)
            } catch {
                let message = Data(String(describing: error).utf8)
                if let documents = try? FileManager.default.url(
                    for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
                    let name = repeatedProbeRequested
                        ? "lutcalc-device-performance-repeat.error"
                        : "lutcalc-device-performance.error"
                    try? message.write(to: documents.appendingPathComponent(name),
                                      options: .atomic)
                }
            }
        }
    }

    var body: some Scene {
        DocumentGroup(newDocument: LUTProjectDocument()) { file in
            ProjectDocumentView(document: file.$document, fileURL: file.fileURL)
        }
    }
}
