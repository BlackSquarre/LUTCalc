"""只验证全量发布证据清单的结构和引用存在；内容仍需人工审阅。"""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "docs/native-validation/full-scope-acceptance.json"


def evidence_item(value, label):
    if not isinstance(value, dict) or value.get("status") != "verified":
        raise ValueError(f"{label}: status 必须为 verified")
    paths = value.get("evidence")
    if not isinstance(paths, list) or not paths:
        raise ValueError(f"{label}: 缺少证据文件")
    for item in paths:
        if not isinstance(item, str) or not item or item.startswith("/") or ".." in Path(item).parts:
            raise ValueError(f"{label}: 非法证据路径")
        path = ROOT / item
        if not path.is_file():
            raise ValueError(f"{label}: 证据文件不存在：{item}")


def main():
    if not MANIFEST.is_file():
        raise ValueError("缺少全量发布验收清单 docs/native-validation/full-scope-acceptance.json")
    data = json.loads(MANIFEST.read_text())
    if data.get("blockedCapabilities") != []:
        raise ValueError("仍有算法或功能阻塞")
    work = data.get("workPackages")
    if not isinstance(work, dict):
        raise ValueError("缺少工作包状态")
    for number in range(1, 15):
        key = f"H{number:02d}"
        evidence_item(work.get(key), key)
    platforms = data.get("platforms")
    if not isinstance(platforms, dict):
        raise ValueError("缺少平台状态")
    for key in ["macOS", "iOS", "iPadOS"]:
        evidence_item(platforms.get(key), key)
    for key in ["algorithmOnlyAudit", "precisionReport", "coverageReport", "userGuide"]:
        evidence_item(data.get(key), key)
    print("全量发布清单结构和引用存在性通过；证据真实性与内容仍需人工审阅。")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"发布证据检查未通过：{error}")
        raise SystemExit(2)
