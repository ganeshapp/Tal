#!/usr/bin/env python3
"""Package the current native build inputs and pin their release checksums."""
from pathlib import Path
import gzip
import hashlib
import json
import re
import tarfile

ROOT = Path(__file__).resolve().parents[1]
version = re.search(r'^version: ([^+\s]+)', (ROOT / 'pubspec.yaml').read_text(), re.M)[1]
paths = [ROOT / 'assets/weights/maia3-23m.onnx']
paths += list((ROOT / 'third_party/stockfish/networks').glob('*.nnue'))
paths += [p for p in (ROOT / 'third_party/onnxruntime').rglob('*')
          if p.is_file() and re.search(r'\.(so(\.[0-9.]+)?|dylib|dll)$', p.name)]
paths = sorted(set(paths))
output = ROOT / f'build/release/Tal-{version}-build-assets.tar.gz'
output.parent.mkdir(parents=True, exist_ok=True)
files = {}
with output.open('wb') as raw, gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as compressed:
    with tarfile.open(fileobj=compressed, mode='w') as bundle:
        for path in paths:
            name = path.relative_to(ROOT).as_posix()
            data = path.read_bytes()
            files[name] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
            entry = bundle.gettarinfo(str(path), arcname=name)
            entry.uid = entry.gid = entry.mtime = 0
            entry.uname = entry.gname = ''
            entry.mode = 0o644
            with path.open('rb') as stream:
                bundle.addfile(entry, stream)
manifest = {'version': version, 'archive': {
    'name': output.name,
    'url': f'https://github.com/ganeshapp/Tal/releases/download/v{version}/{output.name}',
    'bytes': output.stat().st_size,
    'sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
}, 'files': files}
(ROOT / 'tool/build_assets_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(manifest['archive'], indent=2))
