# 2026-09-27 iPhone 11 SPI3D 文件保存、导入与项目重开验收

## 范围

本轮只用实体 iPhone 11（UDID `00008030-001015101ABA802E`，iOS 26.5）、Xcode 27.0、Swift 6.4、`xcodebuild`、XCTest 与 `xcrun devicectl`。没有使用 iPhone Air、镜像或模拟器作为真机证据。App 数值内核、格式实现和旧测试夹具未改；只新增常规 UI 契约 `testSaveGeneratedSPI3DAndReadBackOnDevice`，临时设备预置夹具测试在验收后已移除。

## SPI3D 生成与 Files 保存

- 命令：`xcodebuild -quiet -project Native/LUTCalc.xcodeproj -scheme LUTCalcIOS -configuration Debug -destination 'id=00008030-001015101ABA802E' -derivedDataPath /tmp/LUTCalcDeviceUITestDD DEVELOPMENT_TEAM=DD4V6SJ9XL CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES -allowProvisioningUpdates -only-testing:LUTCalcIOSUITests/LUTCalcIOSUITests/testSaveGeneratedSPI3DAndReadBackOnDevice test`。退出码 0；结果包 `/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_05-34-40-+0800.xcresult` 报 `Passed`，设备为上述 iPhone 11。日志 `/tmp/lutcalc-spi3d-files-local-20260927.log`，SHA-256 `aabba3d4543f40a011346890166d379c440a43ee869d8a76bb07e583223cb1f8`。
- XCTest 在 SwiftUI 选择 SPI3D，确认生成按钮标签包含 `SPI3D`、生成成功、系统保存面板选择“我的iPhone”并提交 `LUTCalc-spi3d-FCA4AEE5.spi3d`。App 显示“文件已保存并回读核对”，其实现对保存回调 URL 与生成文稿字节逐字节比较。随后启动独立 Files App，要求当前根为 `com.apple.FileProvider.LocalStorage` 且 `File View` 文件单元格包含本次 `.spi3d`；附件显示该单元格，约 315 KB。
- 结果包附件 `/tmp/lutcalc-spi3d-files-local-attachments/D513787A-4C62-4CEF-B426-FBEF29572323.txt`（App 回读，SHA-256 `48e599f549afdbd64015cd95d324961449b7e2f53aff53294f94dae41a413d06`）及 `/tmp/lutcalc-spi3d-files-local-attachments/4EADF8EE-6263-406D-8AD6-64C6D9871843.txt`（独立 Files 列表，SHA-256 `70a006211823bc7d8108b7c48686c5ae011f03ae777a35ff51d42fe09fbcac35`）。

## 从 Files 主动导入与项目资源持久化

- 用前一轮本地项目清单创建独立研发夹具 `/tmp/LUTCalc-spi3d-import-20260927.lutcalc`，仅变更 UUID 为 `BC61DDD6-83DD-40E9-9743-A0AF718B4F08`；初始清单 SHA-256 `d37fd9ecb9c9e69d507498c3e277b65c34233507f9a7a51c2f2f8979754fff37`，schema v2、曝光 `2.75`、无资产。使用 `xcrun devicectl device copy to --device 00008030-001015101ABA802E --domain-type appDataContainer --domain-identifier org.lutcalc.native.dev.ios --source /tmp/LUTCalc-spi3d-import-20260927.lutcalc --destination Documents/LUTCalc-spi3d-import-20260927.lutcalc` 放入 App 数据容器，退出码 0；设备当次返回的容器 UUID 为 `5E5B08DA-7C75-45F8-BD80-BD994D420393`。研发夹具不进入 App 包。
- 使用 `xcrun devicectl device process launch --device 00008030-001015101ABA802E --terminate-existing --payload-url 'file:///private/var/mobile/Containers/Data/Application/5E5B08DA-7C75-45F8-BD80-BD994D420393/Documents/LUTCalc-spi3d-import-20260927.lutcalc' org.lutcalc.native.dev.ios` 打开该项目，退出码 0。以相同 `xcodebuild` 参数只运行临时 `testSPI3DUserImportDiagnosticOnDevice`，退出码 0；结果包 `/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_05-37-55-+0800.xcresult` 报 `Passed`。系统导入面板的 `File View` 单元格为本次 `LUTCalc-spi3d-FCA4AEE5.spi3d`；点选后 App 显示“格式与尺寸、spi3d，3D，17”和项目资源。日志 `/tmp/lutcalc-spi3d-import-device1.log`，SHA-256 `83f11a4a0219eb69813a57e6b2fcd2a6fca485188676d815acf5171e2f78c9af`。
- 使用 `xcrun devicectl device copy from --device 00008030-001015101ABA802E --domain-type appDataContainer --domain-identifier org.lutcalc.native.dev.ios --source Documents/LUTCalc-spi3d-import-20260927.lutcalc --destination /tmp/lutcalc-spi3d-import-after-device` 只读回项目包，退出码 0。项目 ID、schema 和曝光保持；`Resources/user-9a647e15-43fd-447e-a34f-605b5c3c2fb8.spi3d` 为 `userLUT`，原字节 314,850，实际 SHA-256 `3be602340ee14790104bfeb3d85a84920d54906b293085908a523eeea64bef2c` 与清单一致。回读清单 SHA-256 `06fae87fcad79a8c62530fb01da0fac90e936309b59a852a136eec88d6074ed4`。
- 再次以上述 `--payload-url` 启动，运行临时 `testStoredSPI3DReopenDiagnosticOnDevice`。首次探索要求“格式与尺寸”标签立即出现，失败于该 UI 可见性断言；项目名与 `.spi3d` 资源断言已通过。修正为重开持久化契约后重跑退出码 0，结果包 `/tmp/LUTCalcDeviceUITestDD/Logs/Test/Test-LUTCalcIOS-2026.09.27_05-41-08-+0800.xcresult` 报 `Passed`；日志 `/tmp/lutcalc-spi3d-reopen-device2.log`，SHA-256 `c893bd3faa69202ae45ad52181dda9c01ca5553d423c6b2a02986f8e6dd48ef1`；层级附件 `/tmp/lutcalc-spi3d-reopen-attachments/98B03055-6292-4C9B-9F08-B82D8A97405C.txt`，SHA-256 `c015c0838676648919feb0fa8080ae67d0656d393f6df879764552a2c53565e7`。

设备预置夹具的导入与重开测试依赖外部文件及具体文件名，验收后从常规测试源码移除，结果包保留当次执行记录。最终 UI 测试源码 SHA-256 `3d55ca187940bb441904b23872d8429a04c76a707e1070918359efd6ba31cb5d`。

## 设备取回文件的独立数值比对

本次项目资源文件是从 iPhone 11 上通过 Files 选入、随后从该设备项目包取回的原字节，SHA-256 `3be602340ee14790104bfeb3d85a84920d54906b293085908a523eeea64bef2c`。实际命令：`python3 tools/native-validation/verify-first-chain-spi3d.py /tmp/lutcalc-spi3d-import-after-device/Resources/user-9a647e15-43fd-447e-a34f-605b5c3c2fb8.spi3d --expected-size 17`，退出码 0。比较器 SHA-256 `a130e13c7e33014781dc62a84e343e5abe438b1268061c04a83c1e6b80697d9f`；冻结 `tests/fixtures/dlog2-reference.json` SHA-256 `1f90b116bdd507f9142547dbb1fdf757fec1e3d2c9e22a77057e08a05eb5ab91`。

比较器按 SPI3D 的显式整数 RGB 坐标读取全部 4,913 个节点，以独立 DJI D-Log2 解码与冻结 D-Gamut2→AP0 矩阵计算参照。结果为 `maxScaledError=3.064215547965432e-14`、`rmsScaledError=2.308979789801905e-15`、`p99ScaledError=1.343135364070174e-14`；最大误差位置 `[16,15,5]` 的第 2 通道。沿用既有阈值 `2e-12`，没有降网格、改插值、改位宽或放宽门槛。该文件 SHA-256 与 2026-09-24 iPhone Air 容器文件相同，但本次 iPhone 11 的 Files 导入、项目包回读和独立比较均由本轮实际命令重新取得，未把历史设备证据冒认为新测试。

## 未覆盖

本轮证明本地 SPI3D 保存回调字节回读、独立 Files 列表发现、用户主动导入解析、项目资源重开及从设备项目包取回文件的全节点独立数值比对。未做第三方调色软件导入；没有从 Files 应用独立复制文件到 Mac，而是通过用户导入后的 App 项目包取得同一文件字节。iCloud/File Provider 权限失效、目标替换竞争、iPad 多窗口、macOS Finder 和完整发布验收仍未覆盖。用户导入的 SPI3D 仍不视为内置转换公式或任意 3D 可逆模型。
