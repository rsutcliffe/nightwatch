# Nightwatch

Silent macOS menu-bar app: tells you when tonight is clear enough for a long imaging session, and what to point at.

## Build and install (any Mac, macOS 14+, no Xcode needed)

    xcode-select --install        # Command Line Tools, once
    git clone https://github.com/rsutcliffe/nightwatch.git && cd nightwatch
    scripts/fetch-data.sh         # catalogue and constellation data, once
    scripts/build-app.sh          # builds, signs ad hoc, installs to /Applications, launches

## Tests

    scripts/test.sh
