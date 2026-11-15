#!/usr/bin/env python3
"""Build-time downloads only. The installed app never uses the network."""
import concurrent.futures, csv, hashlib, io, json, pathlib, subprocess, urllib.request
ROOT = pathlib.Path(__file__).resolve().parents[1]
BASE = 'https://raw.githubusercontent.com'
files = {}
for color in 'wb':
    for piece in 'KQRBNP':
        files[f'assets/pieces/{color}{piece}.svg'] = f'{BASE}/lichess-org/lila/master/public/piece/cburnett/{color}{piece}.svg'
files.update({
    'assets/fonts/Inter.ttf': f'{BASE}/google/fonts/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf',
    'assets/fonts/Lora.ttf': f'{BASE}/google/fonts/main/ofl/lora/Lora%5Bwght%5D.ttf',
    'assets/licenses/Inter-OFL.txt': f'{BASE}/google/fonts/main/ofl/inter/OFL.txt',
    'assets/licenses/Lora-OFL.txt': f'{BASE}/google/fonts/main/ofl/lora/OFL.txt',
    'assets/licenses/pieces.txt': f'{BASE}/lichess-org/lila/master/COPYING.md',
})
def fetch(item):
    name, url = item
    target = ROOT / name
    if not target.exists():
        with urllib.request.urlopen(url, timeout=90) as response:
            data = response.read()
        target.write_bytes(data)
    data = target.read_bytes()
    return {'path': name, 'url': url, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
    manifest = list(pool.map(fetch, files.items()))
(ROOT / 'assets/data/asset_manifest.json').write_text(json.dumps(manifest, indent=2))
print('Engine weights, pieces and fonts downloaded.', flush=True)
print('Puzzle pack: run tool/curate_puzzles.py with python-chess installed.')
print('Maia 3: see tool/export_maia3.py and assets/data/maia3_manifest.json.')
