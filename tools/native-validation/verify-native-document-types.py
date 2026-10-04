#!/usr/bin/env python3
"""核对两个原生 App 的项目包文档类型声明。"""

import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IDENTIFIER = "org.lutcalc.project"
LUT_TYPES = {
    "cube": "com.lutcalc.cube", "spi3d": "com.lutcalc.spi3d",
    "spi1d": "com.lutcalc.spi1d", "3dl": "com.lutcalc.3dl",
    "ilut": "com.lutcalc.ilut", "olut": "com.lutcalc.olut",
    "lut": "com.lutcalc.lut", "vlt": "com.lutcalc.vlt",
}


def check(path: Path, ios: bool) -> None:
    with path.open("rb") as source:
        plist = plistlib.load(source)
    exports = [item for item in plist.get("UTExportedTypeDeclarations", [])
               if item.get("UTTypeIdentifier") == IDENTIFIER]
    if len(exports) != 1:
        raise SystemExit(f"项目包导出类型缺失或重复：{path}")
    for extension, identifier in LUT_TYPES.items():
        matches = [item for item in plist.get("UTExportedTypeDeclarations", [])
                   if item.get("UTTypeIdentifier") == identifier]
        if len(matches) != 1 or "public.data" not in matches[0].get("UTTypeConformsTo", []) \
                or matches[0].get("UTTypeTagSpecification", {}).get("public.filename-extension") != [extension]:
            raise SystemExit(f"LUT 导出类型缺失或扩展名错误：{path} {extension}")
    exported = exports[0]
    if ("com.apple.package" not in exported.get("UTTypeConformsTo", [])
            or "public.content" not in exported.get("UTTypeConformsTo", [])
            or "lutcalc" not in exported.get("UTTypeTagSpecification", {}).get("public.filename-extension", [])):
        raise SystemExit(f"项目包继承或扩展名不正确：{path}")
    documents = [item for item in plist.get("CFBundleDocumentTypes", [])
                 if IDENTIFIER in item.get("LSItemContentTypes", [])]
    if len(documents) != 1 or documents[0].get("CFBundleTypeRole") != "Editor" \
            or documents[0].get("LSTypeIsPackage") is not True:
        raise SystemExit(f"项目包编辑类型声明不正确：{path}")
    if ios and plist.get("LSSupportsOpeningDocumentsInPlace") is not True:
        raise SystemExit("iOS 未声明在原位置打开系统文档")
    if ios:
        phone_orientations = {
            "UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft",
            "UIInterfaceOrientationLandscapeRight",
        }
        pad_orientations = phone_orientations | {"UIInterfaceOrientationPortraitUpsideDown"}
        if set(plist.get("UISupportedInterfaceOrientations", [])) != phone_orientations:
            raise SystemExit("iPhone 横竖屏声明不完整")
        if set(plist.get("UISupportedInterfaceOrientations~ipad", [])) != pad_orientations:
            raise SystemExit("iPad 多任务横竖屏声明不完整")
        if not isinstance(plist.get("UILaunchScreen"), dict):
            raise SystemExit("iOS 缺少系统启动屏配置")


def main() -> None:
    check(ROOT / "Native/Apps/macOS/Info.plist", ios=False)
    check(ROOT / "Native/Apps/iOS/Info.plist", ios=True)
    print("双端 org.lutcalc.project exported package 与系统文档编辑类型声明通过")


if __name__ == "__main__":
    main()
