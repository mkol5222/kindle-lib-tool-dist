#!/usr/bin/env bash
# Installs or upgrades Kindle Library on macOS. Personal use only.
#   curl -fsSL https://raw.githubusercontent.com/mkol5222/kindle-lib-tool-dist/main/install.sh | bash
set -euo pipefail
BASE=https://github.com/mkol5222/kindle-lib-tool-dist/releases/latest/download
[ "$(uname -s)" = Darwin ] || { echo "This script is for macOS. On Windows use install.ps1." >&2; exit 1; }
case "$(uname -m)" in
  arm64) ARCH=arm64 ;;
  x86_64) ARCH=x64 ;;
  *) echo "Unsupported Mac: $(uname -m)" >&2; exit 1 ;;
esac
NAME="kindle-library-mac-$ARCH.zip"

# Upgrade in place; new installs go to /Applications when writable, otherwise ~/Applications.
if [ -n "${KINDLE_LIBRARY_DIR:-}" ]; then
  DEST=$KINDLE_LIBRARY_DIR
elif [ -d "/Applications/Kindle Library.app" ] || { [ ! -d "$HOME/Applications/Kindle Library.app" ] && [ -w /Applications ]; }; then
  DEST=/Applications
else
  DEST="$HOME/Applications"
fi
APP="$DEST/Kindle Library.app"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo "Downloading Kindle Library for $ARCH…"
curl -fL --progress-bar -o "$TMP/$NAME" "$BASE/$NAME"
curl -fsSL -o "$TMP/SHA256SUMS" "$BASE/SHA256SUMS"
(cd "$TMP" && grep "  $NAME\$" SHA256SUMS | shasum -a 256 -c - >/dev/null) || { echo "Checksum mismatch, nothing installed." >&2; exit 1; }

osascript -e 'quit app "Kindle Library"' >/dev/null 2>&1 || true
ditto -x -k "$TMP/$NAME" "$TMP/app"
mkdir -p "$DEST"
rm -rf "$APP"
mv "$TMP/app/Kindle Library.app" "$APP"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
echo "Installed Kindle Library $(defaults read "$APP/Contents/Info" CFBundleShortVersionString) in $DEST"
if ! command -v mtp-files >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/mtp-files ] && [ ! -x /usr/local/bin/mtp-files ]; then
  echo "Kindles from 2021 on (e.g. the current Paperwhite) also need: brew install libmtp"
fi
open "$APP"
