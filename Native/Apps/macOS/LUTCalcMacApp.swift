import SwiftUI
import LUTSharedUI

@main
struct LUTCalcMacApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: LUTProjectDocument()) { file in
            ProjectDocumentView(document: file.$document, fileURL: file.fileURL)
        }
    }
}
