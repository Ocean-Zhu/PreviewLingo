#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift run PreviewLingoChecks
if [[ -d "$(xcode-select -p)/Platforms/MacOSX.platform" ]]; then
    swift test
else
    printf 'XCTest suite requires full Xcode; standalone checks passed with Command Line Tools.\n'
fi
