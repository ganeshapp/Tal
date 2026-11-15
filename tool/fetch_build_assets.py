#!/usr/bin/env python3
"""Restore checksum-pinned build inputs; never used by the running app."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tarfile
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, help='Use an already downloaded archive')
    parser.add_argument('--destination', type=Path, default=ROOT)
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((ROOT / 'tool/build_assets_manifest.json').read_text())
    destination = args.destination.resolve()
    files = manifest['files']
    missing = [name for name, item in files.items()
               if not (destination / name).is_file()
               or digest(destination / name) != item['sha256']]
    if not missing:
        print(f'All {len(files)} build assets verified.')
        return
    if args.verify_only:
        raise SystemExit('Missing or changed build assets: ' + ', '.join(missing)
                         + '\nRun python3 tool/fetch_build_assets.py first.')
    with tempfile.TemporaryDirectory(prefix='tal-assets-') as temp:
        archive = args.archive
        if archive is None:
            archive = Path(temp) / manifest['archive']['name']
            print('Downloading pinned build assets from the Tal release…', flush=True)
            request = urllib.request.Request(manifest['archive']['url'],
                                             headers={'User-Agent': 'Tal-build-assets'})
            with urllib.request.urlopen(request, timeout=120) as source, archive.open('wb') as target:
                shutil.copyfileobj(source, target)
        if digest(archive) != manifest['archive']['sha256']:
            raise SystemExit('Build-assets archive checksum mismatch; nothing installed.')
        with tarfile.open(archive, 'r:gz') as bundle:
            members = bundle.getmembers()
            if len(members) != len(files) or {m.name for m in members} != set(files):
                raise SystemExit('Unexpected build-assets archive contents.')
            for member in members:
                if not member.isfile():
                    raise SystemExit('Only regular files are allowed in build assets.')
                item = files[member.name]
                target = (destination / member.name).resolve()
                if not target.is_relative_to(destination) or member.size != item['bytes']:
                    raise SystemExit('Invalid build-asset path or size.')
                staged = Path(temp) / 'asset'
                with bundle.extractfile(member) as source, staged.open('wb') as output:
                    shutil.copyfileobj(source, output)
                if digest(staged) != item['sha256']:
                    raise SystemExit(f'Checksum mismatch: {member.name}')
                target.parent.mkdir(parents=True, exist_ok=True)
                local_temp = target.with_name(target.name + '.part')
                shutil.copyfile(staged, local_temp)
                local_temp.replace(target)
        print(f'Restored and verified {len(files)} build assets.')


if __name__ == '__main__':
    main()
