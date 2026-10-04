#!/usr/bin/env python3
"""独立核对本地 fingerprint 的设备／inode／SHA 和真实竞争后的文件。"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import stat


def verify(root):
    results = []
    expected = {
        "stable/empty.bin": b"", "stable/small.bin": b"abc", "stable/large.bin": b"A"*(3*1024*1024),
        "before-open/target.bin": b"abc", "after-open/target.bin": b"abc",
        "in-place/target.bin": b"B"*(1024*1024)+b"A"*(2*1024*1024),
        "truncated/target.bin": b"a", "close-on-error/target.bin": b"abc", "cross-process/target.bin": b"abc",
        "late-symlink/referent.bin": b"unrelated referent", "non-regular/target.bin": b"abc",
    }
    for relative, reference in expected.items():
        path = root/relative
        info = os.lstat(path)
        assert stat.S_ISREG(info.st_mode)
        actual = path.read_bytes(); assert actual == reference, f"{path}: 实际字节不符"
        sha = hashlib.sha256(actual).hexdigest()
        identity = f"{info.st_dev}:{info.st_ino}:{sha}"
        report_path = path.parent/"result.json"
        if report_path.exists():
            report = json.loads(report_path.read_text())
            reported = report[path.name] if path.parent.name == "stable" else report["after"]
            assert identity == reported, f"{path}: Python stat/hash 与 Swift 内容身份不一致"
            if path.parent.name in ["before-open", "after-open", "cross-process"]:
                before = report["before"].split(":")
                after = report["after"].split(":")
                assert before[2] == after[2] and before[:2] != after[:2]
            if path.parent.name == "in-place":
                before = report["before"].split(":")
                assert before[:2] == report["after"].split(":")[:2]
                assert before[2] == hashlib.sha256(b"A"*(3*1024*1024)).hexdigest() and before[2] != sha
            if path.parent.name == "cross-process":
                assert int(report["writerPID"]) > 0 and report["writerPID"] != report["parentPID"]
                assert report["writerExit"] == "0" and report["writerExecutable"] == "/bin/mv"
                assert not Path(report["writerSource"]).exists()
                assert Path(report["writerTarget"]).resolve() == path.resolve()
        results.append(dict(path=relative, bytes=len(actual), sha256=sha,
            fingerprint=identity, bytes_exact=True, maximum_byte_difference=0))
    linked = root/"late-symlink/target.bin"
    assert linked.is_symlink() and linked.resolve() == (root/"late-symlink/referent.bin").resolve()
    assert stat.S_ISFIFO(os.lstat(root/"non-regular/fifo").st_mode)
    assert (root/"non-regular/linked.bin").is_symlink()
    return dict(method="Python os.lstat与hashlib及独立合成字节；跨进程PID/exit/替换身份核对",
        files=results, file_count=len(results), byte_count=sum(x["bytes"] for x in results),
        fingerprints_match=True, maximum_byte_difference=0, real_provider_verified=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path); parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(); result = verify(args.root)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n")
    print(f"{result['file_count']}文件、{result['byte_count']}字节独立核对一致；跨进程替换身份分离；真实provider未验收")
