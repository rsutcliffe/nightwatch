#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
PLUGINS=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
ARGS=()
[ -d "$PLUGINS" ] && ARGS=(-Xswiftc -plugin-path -Xswiftc "$PLUGINS")
exec swift test "${ARGS[@]}" "$@"
