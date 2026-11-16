#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="$ROOT/dist/PreviewLingo.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

build_arch() {
    local triple="$1-apple-macosx13.0"
    swift build -c release --triple "$triple" \
        -Xswiftc -gnone \
        -Xswiftc -file-prefix-map -Xswiftc "$ROOT=."
    local bin
    bin="$(swift build -c release --triple "$triple" --show-bin-path)"
    cp "$bin/PreviewLingo" "$ROOT/dist/PreviewLingo-$1"
}

if [[ "${1:-}" == "--native" ]]; then
    ARCH="$(uname -m)"
    build_arch "$ARCH"
    cp "$ROOT/dist/PreviewLingo-$ARCH" "$APP/Contents/MacOS/PreviewLingo"
else
    build_arch arm64
    build_arch x86_64
    lipo -create "$ROOT/dist/PreviewLingo-arm64" "$ROOT/dist/PreviewLingo-x86_64" -output "$APP/Contents/MacOS/PreviewLingo"
fi
strip -S "$APP/Contents/MacOS/PreviewLingo"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
ICONSET="$ROOT/dist/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    twice=$((size * 2))
    sips -z "$twice" "$twice" "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --identifier io.github.ocean-zhu.PreviewLingo \
    --requirements '=designated => identifier "io.github.ocean-zhu.PreviewLingo"' "$APP"
codesign --verify --deep --strict "$APP"
printf 'Built: %s\n' "$APP"
