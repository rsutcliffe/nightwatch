#!/bin/zsh
# Runs the PhoneCore tests on the Mac, capped at four build jobs so the machine stays usable.
set -euo pipefail
cd "$(dirname "$0")/.."
PLUGINS=/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
ARGS=()
[ -d "$PLUGINS" ] && ARGS=(-Xswiftc -plugin-path -Xswiftc "$PLUGINS")
exec swift test -j 4 "${ARGS[@]}" "$@"
