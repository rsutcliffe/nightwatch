#!/bin/zsh
# Prints the GitHub release notes for a version: "What's new", from that version's row in the product overview's release
# history (docs/product-overview.md), then how to install. release.sh --publish uses it; it fails when the row is missing,
# so a release cannot go out without its notes.
# usage: scripts/release-notes.sh <version>
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - "${1:?usage: scripts/release-notes.sh <version>}" <<'PY'
import sys
v = sys.argv[1]
for line in open('docs/product-overview.md', encoding='utf-8'):
    cells = [c.strip() for c in line.strip().strip('|').split('|')]
    if len(cells) >= 4 and cells[0] == v:
        name, contents = cells[1], '|'.join(cells[3:])
        print(f'## What\'s new in {v} "{name}"\n')
        for item in (i.strip() for i in contents.split(';')):
            if item: print(f'- {item[0].upper() + item[1:]}')
        print(f'''
## Install

Download `Nightwatch-{v}.dmg` below, open it and drag Nightwatch to Applications. It is signed with a Developer ID and notarised by Apple. The first time you open it, macOS asks whether to open an app downloaded from the internet: choose Open. Its SHA-256 checksum is in `Nightwatch-{v}.dmg.sha256`.

From 0.6.7 on, Nightwatch checks once a day for a newer version and says so in its popover. Questions and ideas: [Discussions](https://github.com/rsutcliffe/nightwatch/discussions). Problems: [Issues](https://github.com/rsutcliffe/nightwatch/issues).''')
        sys.exit(0)
sys.exit(f'release-notes: no row for {v} in the release history of docs/product-overview.md')
PY
