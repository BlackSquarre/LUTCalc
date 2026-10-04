#!/usr/bin/env python3
"""Extract selected reference files safely; never execute vendor code."""
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import zipfile

base = Path(__file__).resolve().parents[2] / 'research/colour/2026-09-23'
records = []
allowed = {'.pdf', '.ctl', '.clf', '.dctl', '.dctle', '.cube', '.txt'}
for item in json.loads((base / 'download-manifest.json').read_text()):
    if item['status'] != 'downloaded' or not item['path'].endswith('.zip'):
        continue
    with zipfile.ZipFile(base / item['path']) as archive:
        total = 0
        for index, entry in enumerate(archive.infolist()):
            name = PurePosixPath(entry.filename)
            if entry.is_dir() or '__MACOSX' in name.parts or name.name.startswith('.') or name.suffix.lower() not in allowed:
                continue
            if name.is_absolute() or '..' in name.parts:
                raise ValueError('Unsafe archive path')
            total += entry.file_size
            if total > 128 * 1024 * 1024 or entry.file_size > 64 * 1024 * 1024:
                raise ValueError('Archive extraction exceeds research limit')
            # Preserve the original member name in metadata; normalize local names.
            safe_name = ''.join(c if c.isascii() and (c.isalnum() or c in '.-_') else '_' for c in name.name)
            target = base / 'extracted' / item['id'] / f'{index:02d}-{safe_name}'
            data = archive.read(entry)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            records.append(dict(parent_id=item['id'], parent_sha256=item['sha256'], member=entry.filename, path=str(target.relative_to(base)), bytes=len(data), sha256=hashlib.sha256(data).hexdigest(), runtime_allowed=False))
(base / 'extraction-manifest.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
for pdf in sorted(base.rglob('*.pdf')):
    target = base / 'text' / pdf.relative_to(base).with_suffix('.txt')
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['pdftotext', '-layout', str(pdf), str(target)], check=True)
print(f'Extracted {len(records)} reference files; PDF text refreshed.')
