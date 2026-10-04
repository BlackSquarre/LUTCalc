import XCTest

final class LUTCalcIOSUITests: XCTestCase {
    private func createDocument(in app: XCUIApplication, slowExport: Bool = false) {
        if slowExport { app.launchArguments.append("-LUTCalcTestSlowExport") }
        app.launch()
        let create = app.buttons["创建文稿"]
        XCTAssertTrue(create.waitForExistence(timeout: 15))
        create.tap()
        Thread.sleep(forTimeInterval: 5)
    }

    private func selectPicker(_ identifier: String, option: String, in app: XCUIApplication) {
        let picker = app.buttons[identifier]
        for _ in 0..<6 where !picker.exists { app.swipeUp() }
        if !picker.exists {
            // Form cells may not materialize their accessibility identifier until visible.
            // Use the rendered Picker button as the fallback without relying on screen coordinates.
            let label = identifier == "exportFormatPicker" ? "导出格式" : "3D 尺寸"
            let renderedPicker = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
            XCTAssertTrue(renderedPicker.waitForExistence(timeout: 10), "缺少 Picker：\(identifier)")
            renderedPicker.tap()
        } else {
            picker.tap()
        }
        let choice = app.buttons[option].firstMatch
        if choice.waitForExistence(timeout: 10) {
            choice.tap()
        } else {
            let textChoice = app.staticTexts[option].firstMatch
            XCTAssertTrue(textChoice.waitForExistence(timeout: 10), "缺少选项：\(option)")
            textChoice.tap()
        }
    }

    func testCreateDocumentAndGenerateCube() throws {
        let app = XCUIApplication()
        createDocument(in: app)

        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 15))
        print("导航栏生成按钮：hittable=\(generate.isHittable), enabled=\(generate.isEnabled), frame=\(generate.frame)")
        XCTAssertTrue(generate.isHittable)
        generate.tap()

        let success = app.staticTexts["LUT 已生成，可分享或保存。"]
        let failure = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '生成失败：'"))
        var successFound = false
        for _ in 0..<8 {
            if success.exists || failure.count > 0 {
                successFound = success.exists
                break
            }
            app.swipeUp()
        }
        if !successFound {
            successFound = success.waitForExistence(timeout: 45)
        }
        if !successFound {
            print("真机导出后的 UI：\n\(app.debugDescription)")
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "iPhone 11 CUBE 导出结果"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertTrue(successFound, "未出现成功状态，失败状态数量：\(failure.count)")
        let save = app.buttons["保存到文件…"]
        for _ in 0..<4 where !save.exists { app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        let pickerCancel = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == '取消' OR label == 'Cancel'"))
            .firstMatch
        if !pickerCancel.waitForExistence(timeout: 10) {
            print("系统保存面板 UI：\n\(app.debugDescription)")
        }
        XCTAssertTrue(pickerCancel.exists, "未出现系统文件保存面板")
        pickerCancel.tap()
    }

    func testCreateDocumentAndGenerateSPI3D() throws {
        let app = XCUIApplication()
        createDocument(in: app)
        selectPicker("exportFormatPicker", option: "SPI3D", in: app)
        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        print("SPI3D 导出按钮标签：\(generate.label)")
        XCTAssertTrue(
            generate.label.localizedCaseInsensitiveContains("SPI3D"),
            "SPI3D 选择后导航栏按钮标签错误：\(generate.label)"
        )
        generate.tap()
        let success = app.staticTexts["LUT 已生成，可分享或保存。"]
        var successFound = false
        for _ in 0..<24 {
            if success.exists { successFound = true; break }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1)
        }
        XCTAssertTrue(successFound, "SPI3D 未出现成功状态")
        let save = app.buttons["保存到文件…"]
        for _ in 0..<6 where !save.exists { app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        let cancel = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == '取消' OR label == 'Cancel'"))
            .firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
    }

    func testCreateDocumentAndGenerateSPI1D() throws {
        let app = XCUIApplication()
        createDocument(in: app)
        let output = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '目标'")).firstMatch
        for _ in 0..<6 where !output.exists { app.swipeUp() }
        XCTAssertTrue(output.waitForExistence(timeout: 10))
        output.tap()
        let sameGamut = app.buttons["DJI D-Log2 / D-Gamut2"]
        XCTAssertTrue(sameGamut.waitForExistence(timeout: 10))
        sameGamut.tap()
        selectPicker("exportFormatPicker", option: "SPI1D", in: app)
        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        XCTAssertTrue(generate.label.localizedCaseInsensitiveContains("SPI1D"))
        generate.tap()
        let success = app.staticTexts["LUT 已生成，可分享或保存。"]
        for _ in 0..<8 where !success.exists { app.swipeUp() }
        if !success.exists { print("SPI1D 导出后的 UI：\n\(app.debugDescription)") }
        XCTAssertTrue(success.waitForExistence(timeout: 45), "SPI1D 未出现成功状态")
        let save = app.buttons["保存到文件…"]
        for _ in 0..<6 where !save.exists { app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        let cancel = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == '取消' OR label == 'Cancel'"))
            .firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "SPI1D 系统保存面板未出现")
        cancel.tap()
    }

    func testCancelLUTGenerationOnDevice() throws {
        let app = XCUIApplication()
        createDocument(in: app, slowExport: true)
        selectPicker("cubeSizePicker", option: "65³", in: app)
        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        generate.tap()
        let cancel = app.buttons.matching(identifier: "cancelLUTButton").firstMatch
        for _ in 0..<20 where !cancel.exists {
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTAssertTrue(cancel.exists, "生成任务未在界面上进入可取消状态")
        cancel.tap()
        let cancelled = app.staticTexts["生成已取消。"]
        for _ in 0..<8 where !cancelled.exists {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTAssertTrue(cancelled.waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["LUT 已生成，可分享或保存。"].exists)
    }

    func testDocumentViewSurvivesBackgroundAndForegroundOnDevice() throws {
        let app = XCUIApplication()
        createDocument(in: app)
        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        app.activate()
        XCTAssertTrue(generate.waitForExistence(timeout: 15))
        XCTAssertTrue(generate.isHittable)
    }

    func testBackgroundCancelsExportAndRecoversOnDevice() throws {
        let app = XCUIApplication()
        createDocument(in: app, slowExport: true)
        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        generate.tap()

        XCUIDevice.shared.press(.home)
        // Keep the app backgrounded long enough for iOS to deliver the
        // lifecycle boundary before bringing it forward again.
        Thread.sleep(forTimeInterval: 3)
        app.activate()

        let cancelled = app.staticTexts["生成已取消。"]
        // The export status is below the fold in the Form on iPhone 11. Force
        // the cell to materialize before asserting the state after reactivation.
        for _ in 0..<8 where !cancelled.exists {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertTrue(cancelled.waitForExistence(timeout: 15),
                      "后台恢复后未显示取消状态：\n\(app.debugDescription)")
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        generate.tap()

        let success = app.staticTexts["LUT 已生成，可分享或保存。"]
        for _ in 0..<8 where !success.exists {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertTrue(success.waitForExistence(timeout: 45),
                      "恢复后的重新导出未完成：\n\(app.debugDescription)")
    }

    func testDocumentViewSurvivesRotationOnDevice() throws {
        let app = XCUIApplication()
        createDocument(in: app)
        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(generate.waitForExistence(timeout: 15))
        XCTAssertTrue(generate.isHittable)
        XCUIDevice.shared.orientation = .portrait
    }

    func testCloseDocumentShowsSystemSaveBoundaryOnDevice() throws {
        let app = XCUIApplication()
        createDocument(in: app)
        let back = app.buttons["BackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        back.tap()
        Thread.sleep(forTimeInterval: 2)
        print("关闭文稿后的 UI：\n\(app.debugDescription)")
        XCTAssertTrue(app.buttons["创建文稿"].waitForExistence(timeout: 15))
    }

    func testSaveGeneratedCubeAndReadBackOnDevice() throws {
        let app = XCUIApplication()
        createDocument(in: app)
        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        generate.tap()
        let success = app.staticTexts["LUT 已生成，可分享或保存。"]
        for _ in 0..<8 where !success.exists { app.swipeUp() }
        XCTAssertTrue(success.waitForExistence(timeout: 45))
        let save = app.buttons["保存到文件…"]
        for _ in 0..<6 where !save.exists { app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        for _ in 0..<3 {
            let back = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists { back.tap() } else { break }
        }
        let local = app.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(local.waitForExistence(timeout: 10), "系统 Files 未列出本地位置")
        local.tap()
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Files 本地位置层级"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 10))
        filename.tap()
        let outputName = "LUTCalc-device-" + UUID().uuidString.prefix(8)
        let existingName = filename.value as? String ?? ""
        filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                 count: existingName.count) + outputName)
        XCTAssertEqual(filename.value as? String, outputName)
        let saveHere = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
            .buttons["保存"]
        XCTAssertTrue(saveHere.waitForExistence(timeout: 10))
        saveHere.tap()
        XCTAssertFalse(filename.waitForExistence(timeout: 5), "系统保存面板未关闭")
        let verified = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH '文件已保存并回读核对：'"))
            .firstMatch
        for _ in 0..<5 where !verified.exists { app.swipeUp() }
        XCTAssertTrue(verified.waitForExistence(timeout: 15), "App 未能回读核对 Files 导出")
        let afterSave = XCTAttachment(string: app.debugDescription)
        afterSave.name = "Files 保存后 App 层级"
        afterSave.lifetime = .keepAlways
        add(afterSave)
        let failure = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH '无法保存生成的 LUT：'"))
            .firstMatch
        XCTAssertFalse(failure.exists, "导出回调报告保存失败：\(failure.label)")
        let exportAgain = app.buttons["保存到文件…"]
        XCTAssertTrue(exportAgain.waitForExistence(timeout: 10))
        exportAgain.tap()
        for _ in 0..<3 where !app.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists { back.tap() } else { break }
        }
        let localAgain = app.cells["DOC.sidebar.item.我的iPhone"]
        if localAgain.exists { localAgain.tap() }
        let search = app.searchFields["搜索"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText(outputName)
        let listing = XCTAttachment(string: app.debugDescription)
        listing.name = "Files 本地保存后回查"
        listing.lifetime = .keepAlways
        add(listing)
        let savedFile = app.collectionViews["File View"].cells.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS 'cube'",
                        String(outputName))).firstMatch
        print("Files 搜索结果是否出现文件单元格：\(savedFile.waitForExistence(timeout: 10))")
        let cancel = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
            .buttons["取消"]
        if cancel.exists { cancel.tap() }
        let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        files.activate()
        for _ in 0..<3 where !files.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = files.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists {
                back.tap()
                if !files.cells["DOC.sidebar.item.我的iPhone"].waitForExistence(timeout: 2) {
                    files.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.08)).tap()
                }
            } else { break }
        }
        let localInFiles = files.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(localInFiles.waitForExistence(timeout: 10), "独立 Files 应用未列出本地位置")
        localInFiles.tap()
        let localRoot = files.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'com.apple.FileProvider.LocalStorage'"))
            .firstMatch
        XCTAssertTrue(localRoot.waitForExistence(timeout: 10), "独立 Files 应用未进入我的iPhone")
        let independentFile = files.collectionViews["File View"].cells.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS 'cube'",
                        String(outputName))).firstMatch
        XCTAssertTrue(independentFile.waitForExistence(timeout: 15),
                      "独立 Files 应用的本地文件列表未发现 \(outputName).cube")
        let filesHierarchy = XCTAttachment(string: files.debugDescription)
        filesHierarchy.name = "Files 应用本地文件列表与 CUBE 单元格"
        filesHierarchy.lifetime = .keepAlways
        add(filesHierarchy)
    }

    func testSaveGeneratedSPI3DAndReadBackOnDevice() throws {
        let app = XCUIApplication()
        createDocument(in: app)
        selectPicker("exportFormatPicker", option: "SPI3D", in: app)
        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        XCTAssertTrue(generate.label.localizedCaseInsensitiveContains("SPI3D"))
        generate.tap()
        let success = app.staticTexts["LUT 已生成，可分享或保存。"]
        for _ in 0..<10 where !success.exists { app.swipeUp() }
        XCTAssertTrue(success.waitForExistence(timeout: 45))
        let save = app.buttons["保存到文件…"]
        for _ in 0..<6 where !save.exists { app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        for _ in 0..<3 where !app.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists { back.tap() } else { break }
        }
        let local = app.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(local.waitForExistence(timeout: 10), "系统保存面板未列出我的iPhone")
        local.tap()
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 10))
        filename.tap()
        let outputName = "LUTCalc-spi3d-" + UUID().uuidString.prefix(8)
        let oldName = filename.value as? String ?? ""
        filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                 count: oldName.count) + outputName)
        XCTAssertEqual(filename.value as? String, outputName)
        let saveHere = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
            .buttons["保存"]
        XCTAssertTrue(saveHere.waitForExistence(timeout: 10))
        saveHere.tap()
        XCTAssertFalse(filename.waitForExistence(timeout: 5), "系统保存面板未关闭")
        let verified = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "文件已保存并回读核对：\(outputName).spi3d"))
            .firstMatch
        for _ in 0..<6 where !verified.exists { app.swipeUp() }
        XCTAssertTrue(verified.waitForExistence(timeout: 15), "App 未能回读 SPI3D 文件字节")
        let appHierarchy = XCTAttachment(string: app.debugDescription)
        appHierarchy.name = "SPI3D 保存回调字节回读"
        appHierarchy.lifetime = .keepAlways
        add(appHierarchy)

        let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        files.activate()
        for _ in 0..<3 where !files.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = files.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists {
                back.tap()
                if !files.cells["DOC.sidebar.item.我的iPhone"].waitForExistence(timeout: 2) {
                    files.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.08)).tap()
                }
            } else { break }
        }
        let localInFiles = files.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(localInFiles.waitForExistence(timeout: 10), "独立 Files 未列出我的iPhone")
        localInFiles.tap()
        let localRoot = files.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'com.apple.FileProvider.LocalStorage'"))
            .firstMatch
        XCTAssertTrue(localRoot.waitForExistence(timeout: 10), "独立 Files 未进入本地存储")
        let savedFile = files.collectionViews["File View"].cells.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS 'spi3d'",
                        String(outputName))).firstMatch
        XCTAssertTrue(savedFile.waitForExistence(timeout: 15),
                      "独立 Files 本地列表未发现 \(outputName).spi3d")
        let filesHierarchy = XCTAttachment(string: files.debugDescription)
        filesHierarchy.name = "SPI3D 独立 Files 本地列表"
        filesHierarchy.lifetime = .keepAlways
        add(filesHierarchy)
    }

    func testSaveGeneratedSPI1DAndReadBackOnDevice() throws {
        let app = XCUIApplication()
        createDocument(in: app)
        let output = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '目标'")).firstMatch
        for _ in 0..<6 where !output.exists { app.swipeUp() }
        XCTAssertTrue(output.waitForExistence(timeout: 10))
        output.tap()
        let sameGamut = app.buttons["DJI D-Log2 / D-Gamut2"]
        XCTAssertTrue(sameGamut.waitForExistence(timeout: 10))
        sameGamut.tap()
        selectPicker("exportFormatPicker", option: "SPI1D", in: app)
        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        XCTAssertTrue(generate.label.localizedCaseInsensitiveContains("SPI1D"))
        generate.tap()
        let success = app.staticTexts["LUT 已生成，可分享或保存。"]
        for _ in 0..<10 where !success.exists { app.swipeUp() }
        XCTAssertTrue(success.waitForExistence(timeout: 45))
        let save = app.buttons["保存到文件…"]
        for _ in 0..<6 where !save.exists { app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        for _ in 0..<3 where !app.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists { back.tap() } else { break }
        }
        let local = app.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(local.waitForExistence(timeout: 10), "系统保存面板未列出我的iPhone")
        local.tap()
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 10))
        filename.tap()
        let outputName = "LUTCalc-spi1d-" + UUID().uuidString.prefix(8)
        let oldName = filename.value as? String ?? ""
        filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                 count: oldName.count) + outputName)
        XCTAssertEqual(filename.value as? String, outputName)
        let saveHere = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
            .buttons["保存"]
        XCTAssertTrue(saveHere.waitForExistence(timeout: 10))
        saveHere.tap()
        XCTAssertFalse(filename.waitForExistence(timeout: 5), "系统保存面板未关闭")
        let verified = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "文件已保存并回读核对：\(outputName).spi1d"))
            .firstMatch
        for _ in 0..<6 where !verified.exists { app.swipeUp() }
        XCTAssertTrue(verified.waitForExistence(timeout: 15), "App 未能回读 SPI1D 文件字节")
        let appHierarchy = XCTAttachment(string: app.debugDescription)
        appHierarchy.name = "SPI1D 保存回调字节回读"
        appHierarchy.lifetime = .keepAlways
        add(appHierarchy)

        let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        files.activate()
        for _ in 0..<3 where !files.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = files.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists {
                back.tap()
                if !files.cells["DOC.sidebar.item.我的iPhone"].waitForExistence(timeout: 2) {
                    files.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.08)).tap()
                }
            } else { break }
        }
        let localInFiles = files.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(localInFiles.waitForExistence(timeout: 10), "独立 Files 未列出我的iPhone")
        localInFiles.tap()
        let localRoot = files.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'com.apple.FileProvider.LocalStorage'"))
            .firstMatch
        XCTAssertTrue(localRoot.waitForExistence(timeout: 10), "独立 Files 未进入本地存储")
        let savedFile = files.collectionViews["File View"].cells.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS 'spi1d'",
                        String(outputName))).firstMatch
        XCTAssertTrue(savedFile.waitForExistence(timeout: 15),
                      "独立 Files 本地列表未发现 \(outputName).spi1d")
        let filesHierarchy = XCTAttachment(string: files.debugDescription)
        filesHierarchy.name = "SPI1D 独立 Files 本地列表"
        filesHierarchy.lifetime = .keepAlways
        add(filesHierarchy)
    }

    func testSaveGeneratedThreeDLAndReadBackOnDevice() throws {
        let app = XCUIApplication()
        createDocument(in: app)
        let preset = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '转换预设'"))
            .firstMatch
        for _ in 0..<4 where !preset.exists { app.swipeUp() }
        XCTAssertTrue(preset.waitForExistence(timeout: 10))
        preset.tap()
        let choice = app.buttons["dji.dlog2-to-dlog2-identity.v1"].firstMatch
        if choice.waitForExistence(timeout: 10) {
            choice.tap()
        } else {
            let textChoice = app.staticTexts["dji.dlog2-to-dlog2-identity.v1"].firstMatch
            XCTAssertTrue(textChoice.waitForExistence(timeout: 10))
            textChoice.tap()
        }
        selectPicker("exportFormatPicker", option: "3DL Flame / Assimilate", in: app)
        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        XCTAssertTrue(generate.label.localizedCaseInsensitiveContains("3DL"))
        generate.tap()
        let success = app.staticTexts["LUT 已生成，可分享或保存。"]
        let failure = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '生成失败：'"))
            .firstMatch
        for _ in 0..<20 where !success.exists && !failure.exists {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1)
        }
        if !success.exists { print("3DL 生成 UI：\n\(app.debugDescription)") }
        XCTAssertTrue(success.exists, "3DL 生成未成功，失败状态：\(failure.label)")
        let save = app.buttons["保存到文件…"]
        for _ in 0..<6 where !save.exists { app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        for _ in 0..<3 where !app.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists { back.tap() } else { break }
        }
        let local = app.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(local.waitForExistence(timeout: 10), "系统保存面板未列出我的iPhone")
        local.tap()
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 10))
        filename.tap()
        let outputName = "LUTCalc-3dl-" + UUID().uuidString.prefix(8)
        let oldName = filename.value as? String ?? ""
        filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                 count: oldName.count) + outputName)
        XCTAssertEqual(filename.value as? String, outputName)
        let saveHere = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
            .buttons["保存"]
        XCTAssertTrue(saveHere.waitForExistence(timeout: 10))
        saveHere.tap()
        XCTAssertFalse(filename.waitForExistence(timeout: 5), "系统保存面板未关闭")
        let verified = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "文件已保存并回读核对：\(outputName).3dl"))
            .firstMatch
        for _ in 0..<6 where !verified.exists { app.swipeUp() }
        XCTAssertTrue(verified.waitForExistence(timeout: 15), "App 未能回读 3DL 文件字节")

        let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        files.activate()
        for _ in 0..<3 where !files.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = files.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists {
                back.tap()
                if !files.cells["DOC.sidebar.item.我的iPhone"].waitForExistence(timeout: 2) {
                    files.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.08)).tap()
                }
            } else { break }
        }
        let localInFiles = files.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(localInFiles.waitForExistence(timeout: 10), "独立 Files 未列出我的iPhone")
        localInFiles.tap()
        let localRoot = files.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'com.apple.FileProvider.LocalStorage'"))
            .firstMatch
        XCTAssertTrue(localRoot.waitForExistence(timeout: 10), "独立 Files 未进入本地存储")
        let savedFile = files.collectionViews["File View"].cells.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS '3dl'",
                        String(outputName))).firstMatch
        XCTAssertTrue(savedFile.waitForExistence(timeout: 15),
                      "独立 Files 本地列表未发现 \(outputName).3dl")
        let filesHierarchy = XCTAttachment(string: files.debugDescription)
        filesHierarchy.name = "3DL 独立 Files 本地列表"
        filesHierarchy.lifetime = .keepAlways
        add(filesHierarchy)
    }

    func testSaveGeneratedILUTAndReadBackOnDevice() throws {
        let app = XCUIApplication()
        createDocument(in: app)
        let preset = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '转换预设'"))
            .firstMatch
        for _ in 0..<4 where !preset.exists { app.swipeUp() }
        XCTAssertTrue(preset.waitForExistence(timeout: 10))
        preset.tap()
        let choice = app.buttons["dji.dlog2-to-dlog2-identity.v1"].firstMatch
        if choice.waitForExistence(timeout: 10) {
            choice.tap()
        } else {
            let textChoice = app.staticTexts["dji.dlog2-to-dlog2-identity.v1"].firstMatch
            XCTAssertTrue(textChoice.waitForExistence(timeout: 10))
            textChoice.tap()
        }
        selectPicker("exportFormatPicker", option: "ILUT Resolve 14-bit 1D", in: app)
        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        XCTAssertTrue(generate.label.localizedCaseInsensitiveContains("ILUT"))
        generate.tap()
        let success = app.staticTexts["LUT 已生成，可分享或保存。"]
        let failure = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '生成失败：'"))
            .firstMatch
        for _ in 0..<45 where !success.exists && !failure.exists {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1)
        }
        if !success.exists { print("ILUT 生成 UI：\n\(app.debugDescription)") }
        XCTAssertTrue(success.exists, "ILUT 生成未成功，失败状态：\(failure.label)")
        let save = app.buttons["保存到文件…"]
        for _ in 0..<8 where !save.exists { app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        for _ in 0..<3 where !app.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists { back.tap() } else { break }
        }
        let local = app.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(local.waitForExistence(timeout: 10), "系统保存面板未列出我的iPhone")
        local.tap()
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 10))
        filename.tap()
        let outputName = "LUTCalc-ilut-" + UUID().uuidString.prefix(8)
        let oldName = filename.value as? String ?? ""
        filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                 count: oldName.count) + outputName)
        XCTAssertEqual(filename.value as? String, outputName)
        let saveHere = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
            .buttons["保存"]
        XCTAssertTrue(saveHere.waitForExistence(timeout: 10))
        saveHere.tap()
        XCTAssertFalse(filename.waitForExistence(timeout: 5), "系统保存面板未关闭")
        let verified = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "文件已保存并回读核对：\(outputName).ilut"))
            .firstMatch
        for _ in 0..<8 where !verified.exists { app.swipeUp() }
        XCTAssertTrue(verified.waitForExistence(timeout: 20), "App 未能回读 ILUT 文件字节")

        let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        files.activate()
        for _ in 0..<3 where !files.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = files.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists {
                back.tap()
                if !files.cells["DOC.sidebar.item.我的iPhone"].waitForExistence(timeout: 2) {
                    files.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.08)).tap()
                }
            } else { break }
        }
        let localInFiles = files.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(localInFiles.waitForExistence(timeout: 10), "独立 Files 未列出我的iPhone")
        localInFiles.tap()
        let localRoot = files.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'com.apple.FileProvider.LocalStorage'"))
            .firstMatch
        XCTAssertTrue(localRoot.waitForExistence(timeout: 10), "独立 Files 未进入本地存储")
        let savedFile = files.collectionViews["File View"].cells.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS 'ilut'",
                        String(outputName))).firstMatch
        XCTAssertTrue(savedFile.waitForExistence(timeout: 15),
                      "独立 Files 本地列表未发现 \(outputName).ilut")
        let filesHierarchy = XCTAttachment(string: files.debugDescription)
        filesHierarchy.name = "ILUT 独立 Files 本地列表"
        filesHierarchy.lifetime = .keepAlways
        add(filesHierarchy)
    }

    func testSaveGeneratedOLUTAndReadBackOnDevice() throws {
        let app = XCUIApplication()
        createDocument(in: app)
        let preset = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '转换预设'"))
            .firstMatch
        for _ in 0..<4 where !preset.exists { app.swipeUp() }
        XCTAssertTrue(preset.waitForExistence(timeout: 10))
        preset.tap()
        let choice = app.buttons["dji.dlog2-to-dlog2-identity.v1"].firstMatch
        if choice.waitForExistence(timeout: 10) {
            choice.tap()
        } else {
            let textChoice = app.staticTexts["dji.dlog2-to-dlog2-identity.v1"].firstMatch
            XCTAssertTrue(textChoice.waitForExistence(timeout: 10))
            textChoice.tap()
        }
        selectPicker("exportFormatPicker", option: "OLUT Resolve 12-bit 1D", in: app)
        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        XCTAssertTrue(generate.label.localizedCaseInsensitiveContains("OLUT"))
        generate.tap()
        let success = app.staticTexts["LUT 已生成，可分享或保存。"]
        let failure = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '生成失败：'"))
            .firstMatch
        for _ in 0..<25 where !success.exists && !failure.exists {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1)
        }
        if !success.exists { print("OLUT 生成 UI：\n\(app.debugDescription)") }
        XCTAssertTrue(success.exists, "OLUT 生成未成功，失败状态：\(failure.label)")
        let save = app.buttons["保存到文件…"]
        for _ in 0..<8 where !save.exists { app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        for _ in 0..<3 where !app.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists { back.tap() } else { break }
        }
        let local = app.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(local.waitForExistence(timeout: 10), "系统保存面板未列出我的iPhone")
        local.tap()
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 10))
        filename.tap()
        let outputName = "LUTCalc-olut-" + UUID().uuidString.prefix(8)
        let oldName = filename.value as? String ?? ""
        filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                 count: oldName.count) + outputName)
        XCTAssertEqual(filename.value as? String, outputName)
        let saveHere = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
            .buttons["保存"]
        XCTAssertTrue(saveHere.waitForExistence(timeout: 10))
        saveHere.tap()
        XCTAssertFalse(filename.waitForExistence(timeout: 5), "系统保存面板未关闭")
        let verified = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "文件已保存并回读核对：\(outputName).olut"))
            .firstMatch
        for _ in 0..<8 where !verified.exists { app.swipeUp() }
        XCTAssertTrue(verified.waitForExistence(timeout: 20), "App 未能回读 OLUT 文件字节")

        let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        files.activate()
        for _ in 0..<3 where !files.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = files.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists {
                back.tap()
                if !files.cells["DOC.sidebar.item.我的iPhone"].waitForExistence(timeout: 2) {
                    files.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.08)).tap()
                }
            } else { break }
        }
        let localInFiles = files.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(localInFiles.waitForExistence(timeout: 10), "独立 Files 未列出我的iPhone")
        localInFiles.tap()
        let localRoot = files.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'com.apple.FileProvider.LocalStorage'"))
            .firstMatch
        XCTAssertTrue(localRoot.waitForExistence(timeout: 10), "独立 Files 未进入本地存储")
        let savedFile = files.collectionViews["File View"].cells.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS 'olut'",
                        String(outputName))).firstMatch
        XCTAssertTrue(savedFile.waitForExistence(timeout: 15),
                      "独立 Files 本地列表未发现 \(outputName).olut")
        let filesHierarchy = XCTAttachment(string: files.debugDescription)
        filesHierarchy.name = "OLUT 独立 Files 本地列表"
        filesHierarchy.lifetime = .keepAlways
        add(filesHierarchy)
    }

    func testSaveGeneratedAssimilateLUTAndReadBackOnDevice() throws {
        let app = XCUIApplication()
        createDocument(in: app)
        let preset = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '转换预设'"))
            .firstMatch
        for _ in 0..<4 where !preset.exists { app.swipeUp() }
        XCTAssertTrue(preset.waitForExistence(timeout: 10))
        preset.tap()
        let choice = app.buttons["dji.dlog2-to-dlog2-identity.v1"].firstMatch
        if choice.waitForExistence(timeout: 10) {
            choice.tap()
        } else {
            let textChoice = app.staticTexts["dji.dlog2-to-dlog2-identity.v1"].firstMatch
            XCTAssertTrue(textChoice.waitForExistence(timeout: 10))
            textChoice.tap()
        }
        selectPicker("exportFormatPicker", option: "Assimilate LUT 1D", in: app)
        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        XCTAssertTrue(generate.label.localizedCaseInsensitiveContains("LUT"))
        generate.tap()
        let success = app.staticTexts["LUT 已生成，可分享或保存。"]
        let failure = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '生成失败：'"))
            .firstMatch
        for _ in 0..<25 where !success.exists && !failure.exists {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1)
        }
        if !success.exists { print("Assimilate LUT 生成 UI：\n\(app.debugDescription)") }
        XCTAssertTrue(success.exists, "Assimilate LUT 生成未成功，失败状态：\(failure.label)")
        let save = app.buttons["保存到文件…"]
        for _ in 0..<8 where !save.exists { app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        for _ in 0..<3 where !app.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists { back.tap() } else { break }
        }
        let local = app.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(local.waitForExistence(timeout: 10), "系统保存面板未列出我的iPhone")
        local.tap()
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 10))
        filename.tap()
        let outputName = "LUTCalc-assimilate-" + UUID().uuidString.prefix(8)
        let oldName = filename.value as? String ?? ""
        filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                 count: oldName.count) + outputName)
        XCTAssertEqual(filename.value as? String, outputName)
        let saveHere = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
            .buttons["保存"]
        XCTAssertTrue(saveHere.waitForExistence(timeout: 10))
        saveHere.tap()
        XCTAssertFalse(filename.waitForExistence(timeout: 5), "系统保存面板未关闭")
        let verified = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "文件已保存并回读核对：\(outputName).lut"))
            .firstMatch
        for _ in 0..<8 where !verified.exists { app.swipeUp() }
        XCTAssertTrue(verified.waitForExistence(timeout: 20), "App 未能回读 Assimilate LUT 文件字节")

        let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        files.activate()
        for _ in 0..<3 where !files.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = files.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists {
                back.tap()
                if !files.cells["DOC.sidebar.item.我的iPhone"].waitForExistence(timeout: 2) {
                    files.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.08)).tap()
                }
            } else { break }
        }
        let localInFiles = files.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(localInFiles.waitForExistence(timeout: 10), "独立 Files 未列出我的iPhone")
        localInFiles.tap()
        let localRoot = files.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'com.apple.FileProvider.LocalStorage'"))
            .firstMatch
        XCTAssertTrue(localRoot.waitForExistence(timeout: 10), "独立 Files 未进入本地存储")
        let savedFile = files.collectionViews["File View"].cells.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS 'lut'",
                        String(outputName))).firstMatch
        XCTAssertTrue(savedFile.waitForExistence(timeout: 15),
                      "独立 Files 本地列表未发现 \(outputName).lut")
        let filesHierarchy = XCTAttachment(string: files.debugDescription)
        filesHierarchy.name = "Assimilate LUT 独立 Files 本地列表"
        filesHierarchy.lifetime = .keepAlways
        add(filesHierarchy)
    }

    func testSaveGeneratedVLTIdentityPresetAndReadBackOnDevice() throws {
        let app = XCUIApplication()
        createDocument(in: app)
        let preset = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '转换预设'"))
            .firstMatch
        for _ in 0..<4 where !preset.exists { app.swipeUp() }
        XCTAssertTrue(preset.waitForExistence(timeout: 10))
        preset.tap()
        let choice = app.buttons["dji.dlog2-to-dlog2-identity.v1"].firstMatch
        if choice.waitForExistence(timeout: 10) {
            choice.tap()
        } else {
            let textChoice = app.staticTexts["dji.dlog2-to-dlog2-identity.v1"].firstMatch
            XCTAssertTrue(textChoice.waitForExistence(timeout: 10))
            textChoice.tap()
        }
        selectPicker("exportFormatPicker", option: "VLT Varicam 17³", in: app)
        let generate = app.buttons["toolbarGenerateLUTButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10))
        XCTAssertTrue(generate.label.localizedCaseInsensitiveContains("VLT"))
        generate.tap()
        let success = app.staticTexts["LUT 已生成，可分享或保存。"]
        let failure = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '生成失败：'"))
            .firstMatch
        for _ in 0..<20 where !success.exists && !failure.exists {
            app.swipeUp()
            Thread.sleep(forTimeInterval: 1)
        }
        if !success.exists { print("VLT 生成 UI：\n\(app.debugDescription)") }
        XCTAssertTrue(success.exists, "VLT 生成未成功，失败状态：\(failure.label)")
        let save = app.buttons["保存到文件…"]
        for _ in 0..<6 where !save.exists { app.swipeUp() }
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
        for _ in 0..<3 where !app.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists { back.tap() } else { break }
        }
        let local = app.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(local.waitForExistence(timeout: 10), "系统保存面板未列出我的iPhone")
        local.tap()
        let filename = app.textFields["DOCPicker.filenameTextField"]
        XCTAssertTrue(filename.waitForExistence(timeout: 10))
        filename.tap()
        let outputName = "LUTCalc-vlt-" + UUID().uuidString.prefix(8)
        let oldName = filename.value as? String ?? ""
        filename.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                                 count: oldName.count) + outputName)
        XCTAssertEqual(filename.value as? String, outputName)
        let saveHere = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
            .buttons["保存"]
        XCTAssertTrue(saveHere.waitForExistence(timeout: 10))
        saveHere.tap()
        XCTAssertFalse(filename.waitForExistence(timeout: 5), "系统保存面板未关闭")
        let verified = app.staticTexts.matching(
            NSPredicate(format: "label == %@", "文件已保存并回读核对：\(outputName).vlt"))
            .firstMatch
        for _ in 0..<6 where !verified.exists { app.swipeUp() }
        XCTAssertTrue(verified.waitForExistence(timeout: 15), "App 未能回读 VLT 文件字节")
        let files = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        files.activate()
        for _ in 0..<3 where !files.cells["DOC.sidebar.item.我的iPhone"].exists {
            let back = files.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
                .buttons["BackButton"]
            if back.exists {
                back.tap()
                if !files.cells["DOC.sidebar.item.我的iPhone"].waitForExistence(timeout: 2) {
                    files.coordinate(withNormalizedOffset: CGVector(dx: 0.10, dy: 0.08)).tap()
                }
            } else { break }
        }
        let localInFiles = files.cells["DOC.sidebar.item.我的iPhone"]
        XCTAssertTrue(localInFiles.waitForExistence(timeout: 10), "独立 Files 未列出我的iPhone")
        localInFiles.tap()
        let localRoot = files.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'com.apple.FileProvider.LocalStorage'"))
            .firstMatch
        XCTAssertTrue(localRoot.waitForExistence(timeout: 10), "独立 Files 未进入本地存储")
        let savedFile = files.collectionViews["File View"].cells.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS 'vlt'",
                        String(outputName))).firstMatch
        XCTAssertTrue(savedFile.waitForExistence(timeout: 15),
                      "独立 Files 本地列表未发现 \(outputName).vlt")
    }





}
