# 实际 App 包资源审计阶段验收

日期：2026-09-24。状态：**macOS、iOS Simulator、iOS generic 三个 Release App 包与本轮 iPhone 开发签名 Debug 包的资源边界检查通过；完整“无等价采样表”审计仍未完成。** 此项补足此前仅检查原生源码目录的静态检查，不能替代公式来源审查。

先写受控假 App 契约，要求洁净包通过，含 `.labin`/`.js` 的包失败，指向包外的符号链接与缺失可执行文件失败。首次执行因审计器文件不存在而失败。新增纯 Python 的构建产物审计器：递归检查实际 `.app` 内 LUT 文件扩展名、JS/HTML/WASM/C/C++ 文件、越界符号链接、`Info.plist` 与可执行文件；对 Mach-O 主可执行文件用系统 `otool -L` 检查 WebKit/JavaScriptCore 直接链接。发布入口在三个 Release 构建成功后，读取 Xcode 实际 `TARGET_BUILD_DIR` 和 `FULL_PRODUCT_NAME`，审计对应 App 包。受控测试 3/3 通过，旧源文件审计继续执行。

实际运行：

```sh
python3 -m unittest tests/native_bundle_audit_test.py
python3 tools/native-validation/audit-native-bundles.py /tmp/lutcalc-device-derived/Build/Products/Debug-iphoneos/LUTCalcIOS.app
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer bash tools/native-validation/verify-native-release.sh
```

工具链 Xcode 27.0（27A266a）、Swift 6.4、本机 Python 3.14.6。签名 Debug 包单独审计退出码 0；发布入口内 9 项 Node 子集检查、3 项审计契约测试、34 项 XCTest、57 个 Swift 源文件静态检查及三个 Release 未签名构建通过。构建后的实际 App 包审计打印“3 个 App 包通过”；发布入口最终仍因缺少 `docs/native-validation/full-scope-acceptance.json` 退出码 2。这是预期的全量门槛，不能把资源检查局部通过写成发布通过。本机日志 `/tmp/lutcalc-bundle-audit-red-20260924.log` 与 `/tmp/lutcalc-bundle-audit-release-20260924.log` 仅作诊断，关键结果已留在本记录。

修改版本 SHA-256：`tools/native-validation/audit-native-bundles.py` 为 `34845bdddba59bdcd7a912bcf5359d289e3124edcee08d4ed57cc2c13023a15d`；`tools/native-validation/verify-native-release.sh` 为 `39575ead777aa92eb9f74c1ebd11d1dea1316635e3980ca8d7a5901269b04c05`；`tests/native_bundle_audit_test.py` 为 `ed97f9dcab7ab56ed4ffd78a78da8eb0f7fe8068153e21bf91a04653c0e470e1`；Xcode 工程文件为 `7120c086fc55d41357085f02f31a418f4050240aee7e2f9a02d0a799ce00223e`。本阶段未修改算法、数值夹具或阈值，没有新误差数据。

局限：文件后缀与主程序直接链接检查不能证明二进制内部没有等价采样数组、纹理或压缩数据，也不能覆盖运行时动态加载的系统组件、所有嵌入框架的间接依赖或完整许可审计。仍需逐项确认算法实现与源文件版本、最终签名包资源、发布渠道及完整验收清单；H14/REL-01 至 REL-04 未完成。
