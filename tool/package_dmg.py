#!/usr/bin/env python3
"""Create and verify the Apple Silicon drag-to-Applications installer."""
from pathlib import Path
import hashlib
import json
import plistlib
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
version = re.search(r'^version: ([^+\s]+)', (ROOT / 'pubspec.yaml').read_text(), re.M)[1]
app = ROOT / 'build/distribution/Tal.app'
dmg = ROOT / f'build/Tal-{version}-arm64.dmg'
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)

# Use a private, non-browsable mount instead of hdiutil's automatic /Volumes
# mount. Finder/Spotlight can hold the latter open during source-folder copies.
with tempfile.TemporaryDirectory(prefix='tal-dmg-') as workspace:
    temp = Path(workspace)
    raw = temp / 'staging.dmg'
    mount = temp / 'volume'
    mount.mkdir()
    app_bytes = sum(p.stat().st_size for p in app.rglob('*') if p.is_file() and not p.is_symlink())
    megabytes = max(320, (app_bytes + 1048575) // 1048576 + 64)
    subprocess.run(['hdiutil', 'create', '-size', f'{megabytes}m', '-fs', 'HFS+',
                    '-volname', 'Tal', str(raw)], check=True)
    attached = plistlib.loads(subprocess.check_output([
        'hdiutil', 'attach', '-readwrite', '-nobrowse', '-noautoopen',
        '-mountpoint', str(mount), '-plist', str(raw)]))
    device = next(e['dev-entry'] for e in attached['system-entities'] if 'dev-entry' in e)
    try:
        (mount / '.metadata_never_index').touch()
        shutil.copytree(app, mount / app.name, symlinks=True)
        (mount / 'Applications').symlink_to('/Applications')
        (mount / 'Install.txt').write_text(
            f'Tal {version} — Apple Silicon, macOS 12 or later\n\n'
            'Drag Tal to Applications, then open it.\n'
            'This build is locally signed and is not Apple-notarized.\n'
            'All engines and puzzles are included; no download or sign-in is needed.\n\n'
            'Source and releases: https://github.com/ganeshapp/Tal\n'
            'The application is AGPL-3.0-or-later. Matching source and build-assets\n'
            'archives are available on the release page. Component notices are\n'
            'in the app Resources directory.\n')
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(mount / app.name)], check=True)
    finally:
        for attempt in range(10):
            result = subprocess.run(['hdiutil', 'detach', device], capture_output=True, text=True)
            if result.returncode == 0:
                break
            time.sleep(1)
        else:
            # Only this script's temporary image; all copying has finished.
            subprocess.run(['hdiutil', 'detach', '-force', device], check=True)
    subprocess.run(['hdiutil', 'convert', str(raw), '-format', 'UDZO', '-ov', '-o', str(dmg)], check=True)
subprocess.run(['hdiutil', 'verify', str(dmg)], check=True)
sha = hashlib.sha256(dmg.read_bytes()).hexdigest()
dmg.with_suffix('.dmg.sha256').write_text(f'{sha}  {dmg.name}\n')
print(json.dumps({'path': str(dmg), 'bytes': dmg.stat().st_size, 'sha256': sha}))
