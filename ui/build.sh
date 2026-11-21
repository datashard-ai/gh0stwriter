#!/bin/sh
# Builds "gh0stwriter Menu.app" into ui/build/. With --install, also copies it
# to ~/Applications and opens it. Needs only the Command Line Tools
# (xcode-select --install), not Xcode.
set -eu

cd "$(dirname "$0")"
APP="build/gh0stwriter Menu.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"

swiftc -O -parse-as-library -swift-version 5 \
  -target arm64-apple-macos14.0 \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/gh0stwriter-menu"

# Ad-hoc signature: enough to run on this Mac. macOS may ask for the
# microphone again after each rebuild, since the signature changes.
codesign --force --sign - --identifier ai.datashard.gh0stwriter.menu "$APP"
echo "built $PWD/$APP"

if [ "${1:-}" = "--install" ]; then
  DEST="$HOME/Applications/gh0stwriter Menu.app"
  pkill -x gh0stwriter-menu 2>/dev/null || true
  mkdir -p "$HOME/Applications"
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"
  open "$DEST"
  echo "installed $DEST"
fi
