#!/bin/sh
# Installs gh0stwriter, which records a call on your Mac and transcribes it.
#   curl -fsSL https://raw.githubusercontent.com/datashard-ai/gh0stwriter/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/datashard-ai/gh0stwriter/main/install.sh | sh -s -- [--engine assemblyai|local] [--no-model]
# --engine says which engine transcribes your calls (AssemblyAI, or the local one on this Mac) and saves it; without it, a terminal is
# asked once, and anything else leaves the engine as it is. --no-model keeps the local engine's 2.3 GiB speech model and its 102 MiB speaker model from being downloaded.
# Only releases that carry the local engine (mlx.metallib) have this step. A release that splits the call's speakers also carries
# NVIDIA's libraries, in gh0stwriter-lib/, which are installed beside the program, replacing the folder of an earlier release whole:
# the program does not start without that folder. The new program is tried where it was unpacked, with its folder beside it,
# before anything in the install folder is touched, and the old program, kernels and folder are put back if a step fails.
# GH0STWRITER_VERSION pins a version (for example 0.1.1). Releases after 0.1.1 need macOS 14.0 or later; 0.1.1 and earlier run on
# macOS 11 or later.
# GH0STWRITER_INSTALL_DIR sets the folder (default: ~/.local/bin).
set -eu

REPO="datashard-ai/gh0stwriter"
DIR="${GH0STWRITER_INSTALL_DIR:-$HOME/.local/bin}"
# The oldest macOS the releases after LAST_VERSION_FOR_OLD_MACOS run on. It is MACOS_MINIMUM in scripts/release.sh, which builds them
# for it: a test in scripts/test/release.bats fails when the two differ. Release 0.1.1 and earlier were built for macOS 11.
MACOS_MINIMUM="14.0"
LAST_VERSION_FOR_OLD_MACOS="0.1.1"

say() { printf '%s\n' "$*"; }
fail() {
  printf 'gh0stwriter: %s\n' "$*" >&2
  exit 1
}

# is_version V: status 0 when V is numbers separated by single dots, such as 14, 14.0 or 0.1.1. One longer than 18 characters is
# too long for the shell to compare.
is_version() {
  case $1 in
    "" | *[!0-9.]* | .* | *. | *..*) return 1 ;;
  esac
  [ "${#1}" -le 18 ]
}

# version_ge A B: status 0 when version A is B or newer. Both pass is_version; the first three numbers count, and a missing one is 0.
# A subshell, so that its names are no one else's.
version_ge() (
  a=$1
  b=$2
  for _ in 1 2 3; do
    x=${a%%.*}
    y=${b%%.*}
    [ "$x" -gt "$y" ] && exit 0
    [ "$x" -lt "$y" ] && exit 1
    case $a in *.*) a=${a#*.} ;; *) a=0 ;; esac
    case $b in *.*) b=${b#*.} ;; *) b=0 ;; esac
  done
  exit 0
)

USAGE="usage: sh -s -- [--engine assemblyai|local] [--no-model]"

# ask_engine: asks which engine to use, on the terminal, and sets choice to assemblyai, local or nothing (leave it as it is).
ask_engine() {
  {
    printf '\nWhich engine should transcribe your calls?\n'
    printf '  1) AssemblyAI: the audio is sent to AssemblyAI (the default)\n'
    printf '  2) Local: on this Mac, nothing is sent anywhere (downloads a 2.3 GiB speech model and a 102 MiB speaker model, once)\n'
    printf 'Type 1 or 2, or press Enter to leave it as it is: '
  } >/dev/tty
  answer=""
  read -r answer </dev/tty || answer=""
  case $answer in
    1) choice=assemblyai ;;
    2) choice=local ;;
    "") choice="" ;;
    *)
      say "'$answer' is not 1 or 2: the engine stays as it is."
      choice=""
      ;;
  esac
}

# saved_engine_is_local: status 0 when the config file of the program (~/.config/gh0stwriter/config.toml) says engine = "local".
saved_engine_is_local() {
  grep -qs '^engine[[:space:]]*=[[:space:]]*"local"' "${HOME:-/nonexistent}/.config/gh0stwriter/config.toml"
}

# get_models: runs `gh0stwriter model`, which downloads what the local engine needs and is not here yet (the speech model and the
# speaker model, both needed for every recording), and does nothing for what is. It never fails the install.
get_models() {
  if [ "$no_model" = yes ]; then
    say "Not downloading the speech model (--no-model). Before you use the local engine, run: gh0stwriter model"
  else
    "$DIR/gh0stwriter" model ||
      say "The speech model was not downloaded. The install is done; run this to try again, it carries on: gh0stwriter model"
  fi
}

# choose_engine: the engine step of a release that has the local engine. The engine is the --engine option; else, when stdout is a
# terminal that /dev/tty can be opened from, the answer to one question; else nothing changes, except that an engine that is
# saved as local already has its models checked (an upgrade can need one that the last release did not). It never fails the
# install: the program is installed by now, and what it could not do is said, with the command to run.
choose_engine() {
  choice=$engine
  if [ -z "$choice" ] && [ -t 1 ] && ( : </dev/tty ) 2>/dev/null; then
    ask_engine
  fi
  case $choice in
    "")
      if saved_engine_is_local; then
        say ""
        say "The engine is local already: checking that its models are here."
        get_models
      fi
      return 0
      ;;
  esac
  say ""
  "$DIR/gh0stwriter" config --engine "$choice" ||
    say "gh0stwriter could not save the engine. Run this yourself: gh0stwriter config --engine $choice"
  if [ "$choice" = local ]; then
    get_models
  fi
}

# What to say when the macOS is too old: that nothing was changed, and how to install the last version that runs on it.
old_macos_hint() {
  printf 'Nothing was downloaded or changed, so a gh0stwriter you already have still works.\n'
  printf 'Version %s is the last one for older macOS. To install it, set GH0STWRITER_VERSION=%s:\n' "$LAST_VERSION_FOR_OLD_MACOS" "$LAST_VERSION_FOR_OLD_MACOS"
  printf '  curl -fsSL https://raw.githubusercontent.com/%s/main/install.sh | GH0STWRITER_VERSION=%s sh' "$REPO" "$LAST_VERSION_FOR_OLD_MACOS"
}

# place NAME: puts the staged $DIR/.NAME.new.PID in place as $DIR/NAME, with what was there moved aside as .NAME.old.PID; from the
# first move on, NAME is in `put`, so that a stop takes the new one out and puts the old one back (cleanup).
place() {
  name=$1
  if [ -e "$DIR/$name" ] || [ -L "$DIR/$name" ]; then
    mv "$DIR/$name" "$DIR/.$name.old.$$" || return 1
  fi
  put="$put $name"
  mv "$DIR/.$name.new.$$" "$DIR/$name"
}

# cleanup: the exit trap, whatever stopped the run (see main).
cleanup() {
  if [ "$committed" != yes ]; then
    for name in $put; do
      rm -rf "${DIR:?}/$name" || :
      if [ -e "$DIR/.$name.old.$$" ] || [ -L "$DIR/.$name.old.$$" ]; then
        mv "$DIR/.$name.old.$$" "$DIR/$name" || :
      fi
    done
  fi
  for name in gh0stwriter mlx.metallib gh0stwriter-lib; do
    rm -rf "${DIR:?}/.$name.new.$$" "${DIR:?}/.$name.old.$$" || :
  done
  rm -rf "$tmp" || :
}

# Everything runs inside main, which is called on the last line: a download that is cut off
# before that line defines functions and does nothing else.
main() {
  engine=""
  engine_given=no
  no_model=no
  while [ $# -gt 0 ]; do
    case $1 in
      --engine)
        [ $# -ge 2 ] || fail "--engine needs assemblyai or local.
$USAGE"
        engine=$2
        engine_given=yes
        shift 2
        ;;
      --engine=*)
        engine=${1#--engine=}
        engine_given=yes
        shift
        ;;
      --no-model)
        no_model=yes
        shift
        ;;
      -h | --help)
        say "$USAGE"
        exit 0
        ;;
      *) fail "unknown option '$1'.
$USAGE" ;;
    esac
  done
  # Before anything is downloaded.
  if [ "$engine_given" = yes ]; then
    case $engine in
      assemblyai | local) ;;
      *) fail "the engine is assemblyai or local, not '$engine'.
$USAGE" ;;
    esac
  fi

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

  # A release after LAST_VERSION_FOR_OLD_MACOS is built for macOS MACOS_MINIMUM or later, and on an older Mac it would replace a
  # program that works with one that cannot start. So this stops before anything is downloaded or installed. A pinned version up to
  # LAST_VERSION_FOR_OLD_MACOS runs on older macOS and is not checked (sw_vers is not even asked). The latest release is checked, and so
  # is a pin that is no version, which would not download anyway.
  pinned=${GH0STWRITER_VERSION:-}
  pinned=${pinned#v}
  if ! { is_version "$pinned" && version_ge "$LAST_VERSION_FOR_OLD_MACOS" "$pinned"; }; then
    mac=$(sw_vers -productVersion 2>/dev/null) || mac=""
    is_version "$mac" ||
      fail "cannot read the macOS version of this Mac (sw_vers -productVersion says '$mac'), so it cannot tell whether gh0stwriter runs here. gh0stwriter needs macOS $MACOS_MINIMUM or later.
$(old_macos_hint)"
    version_ge "$mac" "$MACOS_MINIMUM" ||
      fail "this Mac has macOS $mac, and gh0stwriter needs macOS $MACOS_MINIMUM or later.
$(old_macos_hint)"
  fi

  command -v curl >/dev/null 2>&1 || fail "curl is required."
  command -v shasum >/dev/null 2>&1 || fail "shasum is required."

  asset="gh0stwriter-$target.tar.gz"
  if [ -n "${GH0STWRITER_VERSION:-}" ]; then
    url="https://github.com/$REPO/releases/download/v${GH0STWRITER_VERSION#v}/$asset"
  else
    url="https://github.com/$REPO/releases/latest/download/$asset"
  fi

  tmp=$(mktemp -d)
  # What a stop leaves: while committed is not yes, every name in `put` is taken out of $DIR and the one that was there is put
  # back (moved aside as .NAME.old.PID, and never deleted before the new program runs); the staged copies (.NAME.new.PID) and
  # the unpacked files go either way.
  committed=no
  put=""
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  say "Downloading $asset"
  curl -fsSL --proto '=https' --tlsv1.2 -o "$tmp/$asset" "$url" \
    || fail "the download failed: $url"
  curl -fsSL --proto '=https' --tlsv1.2 -o "$tmp/$asset.sha256" "$url.sha256" \
    || fail "the checksum download failed: $url.sha256"
  (cd "$tmp" && shasum -a 256 -c "$asset.sha256" >/dev/null 2>&1) \
    || fail "the checksum does not match: the download is not the published file."
  # A release made for the local speech engine carries mlx.metallib, its compiled Metal kernels, which belongs beside the
  # program. An older release has none: it installs as it always did. A release that splits the call's speakers carries the
  # libraries of NVIDIA's NeMo-Speech.cpp in a folder, gh0stwriter-lib/, which belongs beside the program too: the program
  # finds it through @loader_path, and does not start without it.
  members=$(tar -tzf "$tmp/$asset" 2>/dev/null) || fail "could not read $asset."
  wanted="gh0stwriter"
  metallib=no
  libs=no
  if printf '%s\n' "$members" | grep -qx 'mlx.metallib'; then
    metallib=yes
    wanted="$wanted mlx.metallib"
  fi
  if printf '%s\n' "$members" | grep -q '^gh0stwriter-lib/'; then
    libs=yes
    wanted="$wanted gh0stwriter-lib"
  fi
  # shellcheck disable=SC2086  # the names have no spaces
  tar -xzf "$tmp/$asset" -C "$tmp" $wanted || fail "could not unpack $asset."
  # The new program is tried where it was unpacked, with its folder beside it, before anything in the install folder is
  # touched: a program that does not start there would not start there either.
  "$tmp/gh0stwriter" --version >/dev/null 2>&1 \
    || fail "the downloaded program does not start, even beside the files that came with it. Nothing was installed or changed."

  mkdir -p "$DIR"
  # Everything is staged in the install folder first (so that each rename below is within one folder), then put in place, the
  # kernels and the libraries first, so that an installed program is never without them. The old ones are kept until the new
  # program has run from its place.
  if [ "$metallib" = yes ]; then
    install -m 0644 "$tmp/mlx.metallib" "$DIR/.mlx.metallib.new.$$" || fail "could not stage mlx.metallib in $DIR."
  fi
  if [ "$libs" = yes ]; then
    mv "$tmp/gh0stwriter-lib" "$DIR/.gh0stwriter-lib.new.$$" || fail "could not stage the libraries in $DIR."
  fi
  install -m 0755 "$tmp/gh0stwriter" "$DIR/.gh0stwriter.new.$$" || fail "could not stage the program in $DIR."
  if [ "$metallib" = yes ]; then
    place mlx.metallib || fail "could not put mlx.metallib in $DIR: what was there is back."
  fi
  if [ "$libs" = yes ]; then
    # The folder is replaced whole: a library of an earlier release that this one does not carry is not left among the new ones.
    place gh0stwriter-lib || fail "could not put gh0stwriter-lib in $DIR: what was there is back."
  fi
  place gh0stwriter || fail "could not put the program in $DIR: what was there is back."
  version=$("$DIR/gh0stwriter" --version 2>/dev/null) || fail "the installed program does not run: what was there is back."
  committed=yes

  say "Installed $version in $DIR"
  choice=""
  if [ "$metallib" = yes ]; then
    choose_engine
  elif [ "$engine_given" = yes ]; then
    say "This release has no local engine, so --engine is ignored: it transcribes with AssemblyAI."
  fi
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
  if [ "$choice" != local ]; then
    say "  pbpaste | gh0stwriter config      (saves your AssemblyAI API key from the clipboard)"
  fi
  if [ "$metallib" = yes ]; then
    say "  gh0stwriter doctor                (checks that this Mac is ready to record and transcribe)"
  fi
  say "  gh0stwriter record --title \"my call\""
  say ""
  say "gh0stwriter is proprietary software. Use is subject to its licence:"
  say "  https://github.com/$REPO/blob/main/LICENSE.md"
}

main "$@"
