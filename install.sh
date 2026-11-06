#!/bin/sh
# Installs gh0stwriter, which records a call on your Mac and transcribes it.
#   curl -fsSL https://raw.githubusercontent.com/datashard-ai/gh0stwriter/main/install.sh | sh
# GH0STWRITER_VERSION pins a version (for example 0.1.0).
# GH0STWRITER_INSTALL_DIR sets the folder (default: ~/.local/bin).
set -eu

REPO="datashard-ai/gh0stwriter"
DIR="${GH0STWRITER_INSTALL_DIR:-$HOME/.local/bin}"

say() { printf '%s\n' "$*"; }
fail() {
  printf 'gh0stwriter: %s\n' "$*" >&2
  exit 1
}

os=$(uname -s)
arch=$(uname -m)
case "$os/$arch" in
  Darwin/arm64) target="aarch64-apple-darwin" ;;
  Darwin/x86_64)
    # A Terminal running under Rosetta reports x86_64 on Apple silicon.
    if [ "$(sysctl -in sysctl.proc_translated 2>/dev/null || true)" = "1" ]; then
      target="aarch64-apple-darwin"
    else
      fail "Intel Macs are not supported yet. gh0stwriter needs a Mac with Apple silicon."
    fi
    ;;
  *) fail "$os on $arch is not supported yet. gh0stwriter runs on Macs with Apple silicon." ;;
esac

command -v curl >/dev/null 2>&1 || fail "curl is required."
command -v shasum >/dev/null 2>&1 || fail "shasum is required."

asset="gh0stwriter-$target.tar.gz"
if [ -n "${GH0STWRITER_VERSION:-}" ]; then
  url="https://github.com/$REPO/releases/download/v${GH0STWRITER_VERSION#v}/$asset"
else
  url="https://github.com/$REPO/releases/latest/download/$asset"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

say "Downloading $asset"
curl -fsSL --proto '=https' --tlsv1.2 -o "$tmp/$asset" "$url" \
  || fail "the download failed: $url"
curl -fsSL --proto '=https' --tlsv1.2 -o "$tmp/$asset.sha256" "$url.sha256" \
  || fail "the checksum download failed: $url.sha256"
(cd "$tmp" && shasum -a 256 -c "$asset.sha256" >/dev/null 2>&1) \
  || fail "the checksum does not match: the download is not the published file."
tar -xzf "$tmp/$asset" -C "$tmp" gh0stwriter || fail "could not unpack $asset."

mkdir -p "$DIR"
install -m 0755 "$tmp/gh0stwriter" "$DIR/gh0stwriter"
version=$("$DIR/gh0stwriter" --version 2>/dev/null) || fail "the installed program does not run."

say "Installed $version in $DIR"
case ":$PATH:" in
  *":$DIR:"*) ;;
  *)
    say ""
    say "$DIR is not on your PATH. Add it, then open a new terminal:"
    say "  echo 'export PATH=\"$DIR:\$PATH\"' >> ~/.zshrc"
    ;;
esac
say ""
say "Next:"
if ! command -v sox >/dev/null 2>&1; then
  say "  brew install sox                  (recording needs it; gh0stwriter does not install it)"
fi
say "  pbpaste | gh0stwriter config      (saves your AssemblyAI API key from the clipboard)"
say "  gh0stwriter record --title \"my call\""
say ""
say "gh0stwriter is proprietary software. Use is subject to its licence:"
say "  https://github.com/$REPO/blob/main/LICENSE.md"
