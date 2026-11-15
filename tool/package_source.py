#!/usr/bin/env python3
"""Create a release source archive from a commit plus pinned Dart dependency sources."""
from pathlib import Path
import argparse
import gzip
import io
import json
import re
import subprocess
import tarfile
import urllib.parse

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--ref', default='HEAD')
args = parser.parse_args()
version = re.search(r'^version: ([^+\s]+)', (ROOT / 'pubspec.yaml').read_text(), re.M)[1]
prefix = f'Tal-{version}-source/'
output = ROOT / f'build/release/Tal-{version}-source.tar.gz'
output.parent.mkdir(parents=True, exist_ok=True)
commit = subprocess.check_output(['git', 'rev-parse', args.ref], cwd=ROOT, text=True).strip()
tracked = subprocess.check_output(['git', 'archive', '--format=tar', commit], cwd=ROOT)
packages = json.loads((ROOT / '.dart_tool/package_config.json').read_text())['packages']
dependencies = []
with output.open('wb') as raw, gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as compressed:
    with tarfile.open(fileobj=compressed, mode='w') as bundle:
        with tarfile.open(fileobj=io.BytesIO(tracked), mode='r:') as source:
            for entry in source:
                stream = source.extractfile(entry) if entry.isfile() else None
                entry.name = prefix + entry.name
                bundle.addfile(entry, stream)
        for package in packages:
            uri = urllib.parse.urlparse(package['rootUri'])
            if uri.scheme != 'file':
                continue  # Project and vendored dependencies are in git archive.
            path = Path(urllib.parse.unquote(uri.path))
            if '.pub-cache' not in path.parts:
                continue  # Flutter/Dart SDK sources are identified below.
            dependencies.append({'name': package['name'], 'directory': path.name})
            for item in sorted(path.rglob('*')):
                if not item.is_file() or item.is_symlink() or {'build', '.dart_tool', '.git', '__pycache__'}.intersection(item.parts):
                    continue
                entry = bundle.gettarinfo(str(item), prefix + 'dependency_sources/' + package['name'] + '/' + item.relative_to(path).as_posix())
                entry.uid = entry.gid = entry.mtime = 0
                entry.uname = entry.gname = ''
                with item.open('rb') as stream:
                    bundle.addfile(entry, stream)
        provenance = json.dumps({'commit': commit, 'version': version, 'dart_packages': dependencies,
            'flutter_version': '3.29.3', 'flutter_revision': 'ea121f8859e4b13e47a8f845e4586164519588bc',
            'flutter_source': 'https://github.com/flutter/flutter/tree/ea121f8859e4b13e47a8f845e4586164519588bc',
            'build_assets': 'tool/build_assets_manifest.json',
            'instructions': 'Follow README.md. dependency_sources retains the pinned pub package sources; normal builds use pubspec.lock. Restore the matching build-assets archive with tool/fetch_build_assets.py.'}, indent=2).encode()
        entry = tarfile.TarInfo(prefix + 'SOURCE_PROVENANCE.json')
        entry.size = len(provenance)
        bundle.addfile(entry, io.BytesIO(provenance))
print(json.dumps({'path': str(output), 'bytes': output.stat().st_size, 'commit': commit, 'dependency_packages': len(dependencies)}))
