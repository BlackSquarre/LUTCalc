"""检查实际构建的 App 包是否包含禁止的查找资产与运行时。"""

import argparse
import plistlib
import subprocess
from pathlib import Path


FORBIDDEN_ASSETS = {".cube", ".labin", ".3dl", ".csp", ".clf", ".ctf", ".lut"}
FORBIDDEN_RUNTIME_FILES = {".js", ".html", ".wasm", ".c", ".cc", ".cpp", ".h", ".hpp"}
FORBIDDEN_FRAMEWORKS = ("JavaScriptCore.framework", "WebKit.framework")


def audit_bundle(app: Path) -> list[str]:
    failures: list[str] = []
    if not app.is_dir() or app.suffix != ".app":
        return [f"App 包不存在或后缀错误：{app}"]
    root = app.resolve()
    for path in app.rglob("*"):
        relative = path.relative_to(app)
        if path.is_symlink():
            if not path.resolve().is_relative_to(root):
                failures.append(f"App 包内符号链接越界：{relative}")
            continue
        if not path.is_file():
            continue
        suffix = path.suffix.lower()
        if suffix in FORBIDDEN_ASSETS:
            failures.append(f"App 包内查找资产：{relative}")
        if suffix in FORBIDDEN_RUNTIME_FILES:
            failures.append(f"App 包内非 Swift 运行时文件：{relative}")
        if any(framework in relative.parts for framework in FORBIDDEN_FRAMEWORKS):
            failures.append(f"App 包内禁止的框架：{relative}")

    plist_path = app / "Contents/Info.plist"
    if not plist_path.exists():
        plist_path = app / "Info.plist"
    try:
        with plist_path.open("rb") as handle:
            info = plistlib.load(handle)
        name = info.get("CFBundleExecutable")
        if not isinstance(name, str) or not name or "/" in name:
            raise ValueError("invalid executable name")
    except (OSError, ValueError, plistlib.InvalidFileException):
        return failures + [f"App 包 Info.plist 或 executable 声明无效：{app}"]
    executable = app / "Contents/MacOS" / name if (app / "Contents").is_dir() else app / name
    if not executable.is_file():
        return failures + [f"App 包 executable 缺失：{executable.relative_to(app)}"]

    identity = subprocess.run(["file", "-b", str(executable)], capture_output=True, text=True)
    if identity.returncode != 0:
        failures.append(f"无法识别 App executable：{executable.relative_to(app)}")
    elif "Mach-O" in identity.stdout:
        links = subprocess.run(["otool", "-L", str(executable)], capture_output=True, text=True)
        if links.returncode != 0:
            failures.append(f"无法核对 App framework 链接：{executable.relative_to(app)}")
        else:
            for framework in FORBIDDEN_FRAMEWORKS:
                if framework in links.stdout:
                    failures.append(f"App executable 链接禁止的框架：{framework}")
    return failures


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("apps", type=Path, nargs="+")
    arguments = parser.parse_args()
    failures = []
    for app in arguments.apps:
        failures.extend(audit_bundle(app))
    if failures:
        for failure in failures:
            print(f"不通过：{failure}")
        raise SystemExit(1)
    print(f"实际 App 包资源审计通过：{len(arguments.apps)} 个 App 包，无所列 LUT/脚本文件或 WebKit/JavaScriptCore 直接链接")
    print("此检查不能证明二进制不存在等价采样表；公式来源与构建产物仍需人工复核。")


if __name__ == "__main__":
    main()
