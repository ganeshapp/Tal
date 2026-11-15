#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 tool/fetch_build_assets.py --verify-only
: "${FLUTTER_BIN:=flutter}"
: "${CMAKE_BIN:=cmake}"
: "${NINJA_BIN:=ninja}"
"$CMAKE_BIN" -S tool/mac_engines -B build/mac_engines -G Ninja \
  -DCMAKE_MAKE_PROGRAM="$NINJA_BIN" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0
"$CMAKE_BIN" --build build/mac_engines -j 6
"$FLUTTER_BIN" assemble -dTargetPlatform=darwin -dBuildMode=release -dDarwinArchs=arm64 \
  -dTargetFile=lib/main.dart --output=build/macos_manual release_macos_bundle_flutter_assets
python3 tool/package_macos.py
