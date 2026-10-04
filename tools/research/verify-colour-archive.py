#!/usr/bin/env python3
"""Validate archived bytes and CUBE payloads without executing vendor code."""
import hashlib
import json
import math
from pathlib import Path
import zipfile

base = Path(__file__).resolve().parents[2] / 'research/colour/2026-09-23'
downloads = json.loads((base / 'download-manifest.json').read_text())
extracted = json.loads((base / 'extraction-manifest.json').read_text())
entries = [x for x in downloads if x['status'] == 'downloaded'] + extracted
report = {'date': '2026-09-23', 'checked_files': 0, 'cube_checks': [], 'unavailable': [x['id'] for x in downloads if x['status'] != 'downloaded'], 'scope': '检查下载与解包完整性、文件签名、LUT 尺寸/有限数值；不证明颜色算法准确或参考资料互相一致。'}
for entry in entries:
    p = base / entry['path']
    data = p.read_bytes()
    assert len(data) == entry['bytes'], p
    assert hashlib.sha256(data).hexdigest() == entry['sha256'], p
    assert entry['runtime_allowed'] is False, p
    if p.suffix == '.pdf':
        assert data.startswith(b'%PDF-'), p
    if p.suffix == '.zip':
        with zipfile.ZipFile(p) as z:
            assert z.testzip() is None, p
    if p.suffix == '.cube':
        sizes = []
        count = 0
        for line in data.decode('utf-8-sig').splitlines():
            parts = line.strip().split()
            if not parts or parts[0].startswith('#'):
                continue
            if parts[0] in ('LUT_1D_SIZE', 'LUT_3D_SIZE'):
                n = int(parts[1]); sizes.append(n if parts[0] == 'LUT_1D_SIZE' else n**3)
            elif parts[0][0] in '+-.0123456789':
                assert len(parts) == 3, (p, line)
                assert all(math.isfinite(float(x)) for x in parts), (p, line)
                count += 1
        assert sizes and count == sum(sizes), (p, count, sizes)
        report['cube_checks'].append({'path': entry['path'], 'rows': count, 'status': 'passed'})
    report['checked_files'] += 1
report['status'] = 'passed'
(base / 'archive-validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'checked_files': report['checked_files'], 'cube_files': len(report['cube_checks']), 'unavailable_sources': len(report['unavailable']), 'status': report['status']}))
