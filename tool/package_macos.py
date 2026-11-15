#!/usr/bin/env python3
"""Package the ARM64 Flutter release with Apple command-line tools (no Xcode UI required)."""
from pathlib import Path
import subprocess, shutil, plistlib, json
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/macos_manual';APP=ROOT/'build/distribution/Tal.app'
def run(*args): subprocess.run([str(a) for a in args],check=True,cwd=ROOT)
for path in ['Contents/MacOS','Contents/Frameworks','Contents/Resources/engines']:(APP/path).mkdir(parents=True,exist_ok=True)
for name in ['App.framework','FlutterMacOS.framework']:
    dest=APP/'Contents/Frameworks'/name
    if dest.exists():shutil.rmtree(dest)
    shutil.copytree(OUT/name,dest,symlinks=True)
ort=APP/'Contents/Frameworks/libonnxruntime.1.15.1.dylib'
run('lipo',ROOT/'third_party/onnxruntime/macos/libonnxruntime.1.15.1.dylib','-thin','arm64','-output',ort)
shutil.copy2(ROOT/'build/mac_engines/tal-stockfish',APP/'Contents/Resources/engines/tal-stockfish')
# Package upstream licenses and source/build notes alongside the app.
for name in ['Stockfish-GPL.txt','Maia3-AGPL.txt']:
    source=ROOT/'assets/licenses'/name
    if source.exists():shutil.copy2(source,APP/'Contents/Resources'/name)
shutil.copy2(ROOT/'LICENSE',APP/'Contents/Resources/Tal-AGPL.txt')
shutil.copy2(ROOT/'THIRD_PARTY.md',APP/'Contents/Resources/THIRD_PARTY.md')
info={'CFBundleExecutable':'Tal','CFBundleIdentifier':'io.github.ganeshapp.tal','CFBundleName':'Tal','CFBundleDisplayName':'Tal','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.3.0','CFBundleVersion':'3','LSMinimumSystemVersion':'12.0','NSHighResolutionCapable':True,'NSSupportsAutomaticGraphicsSwitching':True,'CFBundleIconFile':'AppIcon'}
(APP/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
# Resolve only the dependencies pinned in this project's package configuration.
packages=json.loads((ROOT/'.dart_tool/package_config.json').read_text())['packages']
def package(name):
    from urllib.parse import urlparse,unquote
    return Path(unquote(urlparse(next(p['rootUri'] for p in packages if p['name']==name)).path))
sdk=subprocess.check_output(['xcrun','--sdk','macosx','--show-sdk-path'],text=True).strip()
modules=ROOT/'build/swift-modules';modules.mkdir(exist_ok=True)
common=['-O','-target','arm64-apple-macos12.0','-sdk',sdk,'-module-cache-path',ROOT/'build/swift-cache','-F',APP/'Contents/Frameworks','-framework','Cocoa','-framework','FlutterMacOS']
# Some CLT upgrades leave an obsolete duplicate SwiftBridging module map.
# Hide that duplicate for this invocation only; never alter the host toolchain.
old_map=Path('/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap')
new_map=old_map.with_name('bridging.modulemap')
if old_map.exists() and new_map.exists() and 'module SwiftBridging' in old_map.read_text():
    empty=ROOT/'build/empty.modulemap';empty.write_text('')
    overlay=ROOT/'build/swift-overlay.json'
    overlay.write_text(json.dumps({'version':0,'roots':[{'type':'file','name':str(old_map),'external-contents':str(empty)}]}))
    common.extend(['-vfsoverlay',overlay])
plugins=['path_provider_foundation','shared_preferences_foundation']
for name in plugins:
    sources=list((package(name)/f'darwin/{name}/Sources/{name}').glob('*.swift'))
    run('swiftc',*common,'-emit-library','-emit-module','-module-name',name,'-emit-module-path',modules/f'{name}.swiftmodule',
        '-Xlinker','-install_name','-Xlinker',f'@rpath/lib{name}.dylib',*sources,'-o',APP/f'Contents/Frameworks/lib{name}.dylib')
run('swiftc',*common,'-parse-as-library','-I',modules,'-L',APP/'Contents/Frameworks',*[f'-l{n}' for n in plugins],
    '-Xlinker','-rpath','-Xlinker','@executable_path/../Frameworks',ROOT/'tool/MacRunner.swift','-o',APP/'Contents/MacOS/Tal')
iconset=ROOT/'build/Tal.iconset';iconset.mkdir(exist_ok=True)
source=ROOT/'macos/Runner/Assets.xcassets/AppIcon.appiconset'
for size in [16,32,128,256,512]:
    for scale in [1,2]:
        dest=iconset/f'icon_{size}x{size}{"@2x" if scale==2 else ""}.png'
        run('sips','-z',size*scale,size*scale,ROOT/'assets/brand/icon.png','--out',dest)
run('iconutil','-c','icns',iconset,'-o',APP/'Contents/Resources/AppIcon.icns')
for target in [*[APP/f'Contents/Frameworks/lib{n}.dylib' for n in plugins],ort,APP/'Contents/Resources/engines/tal-stockfish',APP/'Contents/Frameworks/App.framework',APP/'Contents/Frameworks/FlutterMacOS.framework',APP]:
    run('codesign','--force','--sign','-','--timestamp=none',target)
run('codesign','--verify','--deep','--strict',APP)
print(APP)
