#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/PreviewLingo.app"
[[ -d "$APP" ]] || { printf 'Run scripts/build.sh first.\n' >&2; exit 1; }
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/PreviewLingo.app"
ln -s /Applications "$STAGING/Applications"
cp "$ROOT/LICENSE" "$STAGING/LICENSE.txt"
hdiutil create -volname PreviewLingo -srcfolder "$STAGING" -ov -format UDZO "$ROOT/dist/PreviewLingo-$VERSION-universal.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/PreviewLingo-$VERSION-universal.zip"
cd "$ROOT/dist"
shasum -a 256 "PreviewLingo-$VERSION-universal.dmg" "PreviewLingo-$VERSION-universal.zip" > SHA256SUMS.txt
