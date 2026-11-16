#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/dist/PreviewLingo.app"
[[ -d "$SOURCE" ]] || { printf 'Run scripts/build.sh first.\n' >&2; exit 1; }
if [[ -w /Applications ]]; then
    DEST=/Applications/PreviewLingo.app
else
    mkdir -p "$HOME/Applications"
    DEST="$HOME/Applications/PreviewLingo.app"
fi
LEGACY="$HOME/Library/Services/Qwen Preview Translator.app"
DOMAIN="gui/$(id -u)"
launchctl bootout "$DOMAIN/com.zhuhai.qwen-preview-translator" 2>/dev/null || true
pkill -x QwenPreviewTranslator 2>/dev/null || true
pkill -x PreviewLingo 2>/dev/null || true
sleep 0.5
if [[ -d "$LEGACY" ]]; then
    BACKUP="$HOME/Library/Application Support/PreviewLingo/Legacy"
    mkdir -p "$BACKUP"
    ditto "$LEGACY" "$BACKUP/Qwen Preview Translator.app"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$LEGACY" || true
    mv "$LEGACY" "$BACKUP/Qwen Preview Translator-previous.app"
fi
LEGACY_AGENT="$HOME/Library/LaunchAgents/com.zhuhai.qwen-preview-translator.plist"
if [[ -f "$LEGACY_AGENT" ]]; then
    mkdir -p "$HOME/Library/Application Support/PreviewLingo/Legacy"
    mv "$LEGACY_AGENT" "$HOME/Library/Application Support/PreviewLingo/Legacy/"
fi
ditto "$SOURCE" "$DEST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST"
/System/Library/CoreServices/pbs -update
open "$DEST" --args --migrate-login
printf 'Installed: %s\n' "$DEST"
