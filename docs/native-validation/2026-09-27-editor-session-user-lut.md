# 2026-09-27 EditorSession 用户一维 LUT 生成后阶段验收

## 范围与修改

- `Native/Packages/LUTKit/Sources/LUTSharedUI/EditorSession.swift`：打开已保存项目后，从项目包资源重新读取用户 LUT，核对 SHA-256，仅接受单位域、无 shaper 的一维 LUT，作为 `LUTGenerationRequest.postLUT`。四种一维导出格式均透传该阶段。
- `Native/Packages/LUTKit/Sources/LUTSessionChecks/main.swift`：将旧“用户 LUT 必须拒绝”检查改为单位域一维生成、导出和状态检查；使用单位域恒等计划，避免把真实域外结果裁剪成通过。
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/SessionContractsTests.swift`：新增已保存项目生成请求包含一维用户 LUT 的契约。
- `Native/Packages/LUTKit/Tests/LUTSharedUITests/SPI1DServiceContractsTests.swift`：新增 SPI1D 输出末节点独立检查，确保一维格式没有丢掉 `postLUT`。

三维 LUT、非单位域和带 shaper 的用户 LUT 仍明确拒绝进入生成计划；没有推断任意三维逆变换或色域语义。用户导入的原始 LUT 仅保存在自己的项目资源中，不成为 App 内置 LUT。

## 实际验证

工具链：Xcode 27.0（27A266a）、Apple Swift 6.4。

- `swift test --package-path Native/Packages/LUTKit -c release`：在本阶段最初修改后退出码 0；新增 `SessionContractsTests` 通过。随后新增一维格式透传测试，第一次因 XCTest autoclosure 中直接 `await` 编译失败，修正测试写法后定向命令通过。
- `swift test --package-path Native/Packages/LUTKit -c release --filter SPI1DServiceContractsTests`：退出码 0，2 项通过。SPI1D 最后节点为 `(0.25, 0.5, 0.75)`，与用户 LUT 明确样本一致。
- 最终完整 `swift test --package-path Native/Packages/LUTKit -c release` 再次退出码 0，所有列出的 XCTest 均为零失败。日志 `/tmp/lutcalc-editor-userlut-swift-tests-20260927.log`，SHA-256 `8e2e7d2726c72b72c5b611339b11843540572bc1b244eb66c7355f95c1b97a21`。
- `swift run -c release --package-path Native/Packages/LUTKit LUTSessionChecks`：退出码 0；H09/H12 项目草稿会话、用户一维 LUT 和过期导出清理契约通过。
- `bash Scripts/verify-native-numerics.sh`：退出码 0；54 对 33³/65³ CUBE 生成与独立读回、H08/H09/H10/H12/H13 命令行契约通过。日志 `/tmp/lutcalc-editor-userlut-numerics-20260927.log`，SHA-256 `c746b601da932b9809647ff02f651bfa4c4d7d0ca0c9e1eae07e474ca850f253`。
- `xcodebuild -quiet -scheme LUTCalcIOS -project Native/LUTCalc.xcodeproj -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /tmp/LUTCalc-iPhone11 CODE_SIGNING_ALLOWED=NO build`：退出码 0。无输出日志 SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`。
- 实体 iPhone 11（UDID `00008030-001015101ABA802E`）通过开发者证书重签名后，`devicectl` 安装、启动与截图均成功。当前 App 可执行文件 SHA-256 `d2fb8b3ce7aedd59be7b27921dc41b9fbb3b42e3fa45d05e4e7ff89da4f7600c`；稳定首屏截图 `/tmp/lutcalc-iphone11-current-settled.png` 的 SHA-256 为 `8167a16b4ba0d30aabe05c082663b37ee201d017b198169d85fe2e471b20fce4`。

## 未覆盖

本次真机只验证新包安装、启动和首屏，不把命令行一维 LUT 数值契约冒充真机文件往返。Files 实际写入回查、项目包关闭重开、File Provider、iPad、多窗口、完整 ICC/显示色彩管理、任意 3D 反求和发布验收仍未完成。`full-scope-acceptance.json` 继续缺失，不能伪造通过。
