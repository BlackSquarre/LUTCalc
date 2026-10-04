"""检查当前原生源码目录未纳入禁止的运行时或内置采样资产。"""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
NATIVE = ROOT / "Native"
SOURCES = [NATIVE / "Apps", NATIVE / "Packages/LUTKit/Sources"]
FORBIDDEN_ASSETS = {".cube", ".labin", ".3dl", ".csp", ".clf", ".ctf"}
FORBIDDEN_SYMBOLS = re.compile(r"\b(?:import\s+(?:WebKit|JavaScriptCore)|WKWebView|JSContext|JSVirtualMachine)\b")


def main():
    failures = []
    swift_files = []
    for root in SOURCES:
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            if path.suffix.lower() in FORBIDDEN_ASSETS:
                failures.append(f"bundled lookup asset: {path.relative_to(ROOT)}")
            if path.suffix == ".swift":
                swift_files.append(path)
                if FORBIDDEN_SYMBOLS.search(path.read_text()):
                    failures.append(f"forbidden runtime symbol: {path.relative_to(ROOT)}")
            elif path.suffix.lower() in {".js", ".html", ".c", ".cc", ".cpp", ".h", ".hpp"}:
                failures.append(f"non-Swift runtime source: {path.relative_to(ROOT)}")
    manifest = (NATIVE / "Packages/LUTKit/Package.swift").read_text()
    if re.search(r"\bresources\s*:", manifest):
        failures.append("Package.swift declares resources; manual asset audit required")
    if not swift_files:
        failures.append("no Swift sources found")
    if failures:
        for failure in failures:
            print(f"不通过：{failure}")
        raise SystemExit(1)
    print(f"静态原生边界检查通过：{len(swift_files)} 个 Swift 源文件，无所列禁止运行时/内置 LUT 文件或 Package resources 声明")
    print("此检查不能证明所有公式来源、间接采样依赖或最终 App 资源包完整合规。")


if __name__ == "__main__":
    main()
