#!/usr/bin/env python3
"""Download research-only sources and record integrity metadata."""
import concurrent.futures
import datetime
import hashlib
import gzip
import json
import pathlib
import re
import sys
import urllib.request

root = pathlib.Path(__file__).resolve().parents[2]
base = root / 'research/colour/2026-09-23'
sources = json.loads((base / 'sources.json').read_text())
manifest_path = base / 'download-manifest.json'
previous = {x['id']: x for x in json.loads(manifest_path.read_text())} if manifest_path.exists() else {}

def fetch(source):
    entry = dict(source)
    target = (base / source['path']).resolve()
    if base.resolve() not in target.parents:
        raise ValueError('Source path is outside the research directory')
    old = previous.get(source['id'])
    if old and old.get('status') == 'downloaded' and target.is_file():
        if old.get('url') == source['url'] and hashlib.sha256(target.read_bytes()).hexdigest() == old['sha256']:
            return old
    entry['retrieved_at_utc'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    entry['runtime_allowed'] = False
    try:
        request = urllib.request.Request(source['url'], headers={'User-Agent': 'Mozilla/5.0 (research archive)'})
        with urllib.request.urlopen(request, timeout=35) as response:
            data = response.read(64 * 1024 * 1024 + 1)
            if len(data) > 64 * 1024 * 1024:
                raise ValueError('Source exceeds 64 MiB research download limit')
            entry['resolved_url'] = response.url
            entry['content_type'] = response.headers.get('Content-Type', '')
            entry['content_encoding'] = response.headers.get('Content-Encoding', '')
        if entry['content_encoding'].lower() == 'gzip':
            data = gzip.decompress(data)
        suffix = target.suffix.lower()
        if suffix == '.pdf' and not data.startswith(b'%PDF-'):
            raise ValueError('Response is not a PDF')
        if suffix == '.zip' and not data.startswith(b'PK'):
            raise ValueError('Response is not a ZIP archive')
        if suffix == '.cube' and not re.search(rb'^LUT_[13]D_SIZE\s+\d+', data, re.M):
            raise ValueError('Response is not a CUBE LUT; a login page may have been returned')
        if not data:
            raise ValueError('Empty response')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        entry.update(status='downloaded', bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
    except Exception as error:
        entry.update(status='unavailable', error=str(error))
    return entry

if __name__ == '__main__':
    wanted = set(sys.argv[1:])
    selected = [s for s in sources if not wanted or s['id'] in wanted]
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
        for result in pool.map(fetch, selected):
            previous[result['id']] = result
            print(result['id'], result['status'], result.get('bytes', result.get('error')), flush=True)
    manifest_path.write_text(json.dumps(list(previous.values()), ensure_ascii=False, indent=2) + '\n')
