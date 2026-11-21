#!/bin/bash
# <xbar.title>gh0stwriter</xbar.title>
# <xbar.desc>Start and stop gh0stwriter recordings from the menu bar, and open the transcripts.</xbar.desc>
# <xbar.dependencies>gh0stwriter,sox</xbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
#
# SwiftBar plugin for gh0stwriter. It only calls the gh0stwriter CLI and reads
# the run folders; it never touches sox itself. The ".5s" in the file name makes
# SwiftBar refresh it every five seconds.

# SwiftBar starts plugins with a minimal PATH.
export PATH="${GH0STWRITER_INSTALL_DIR:-$HOME/.local/bin}:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

RUNS="${GH0STWRITER_HOME:-$HOME/gh0stwriter}"
STATE="$HOME/Library/Caches/gh0stwriter-swiftbar"
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
mkdir -p "$STATE" && chmod 700 "$STATE"

# --- helpers ---------------------------------------------------------------

notify() { # title, message
  osascript -e 'on run argv' -e 'display notification (item 2 of argv) with title (item 1 of argv)' -e 'end run' "$1" "$2" >/dev/null 2>&1
}

alert() { # title, message
  osascript -e 'on run argv' -e 'display alert (item 1 of argv) message (item 2 of argv) as critical' -e 'end run' "$1" "$2" >/dev/null 2>&1
}

# Run folders, newest first (names start with YYYY-MM-DD-HHMMSS, so they sort).
run_dirs() {
  [ -d "$RUNS" ] || return 0
  ls -1 "$RUNS" 2>/dev/null | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}' | sort -r | while read -r d; do
    [ -d "$RUNS/$d" ] && echo "$RUNS/$d"
  done
}

# Prints the run folder whose sox is still alive, if any.
recording_dir() {
  local d pid
  d=$(run_dirs | head -1)
  [ -n "$d" ] && [ -f "$d/sox.pid" ] || return 1
  pid=$(grep -Eo '[0-9]+' "$d/sox.pid" | head -1)
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || return 1
  ps -p "$pid" -o comm= 2>/dev/null | grep -q sox || return 1
  echo "$d"
}

# True while a background "stop" started from this menu is still running.
transcribing() {
  local pid
  [ -f "$STATE/stop.pid" ] || return 1
  pid=$(cat "$STATE/stop.pid" 2>/dev/null)
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

run_label() { # folder -> "2026-11-21 18:17  weekly sync"
  local n="${1##*/}"
  local t="${n:18}"; t="${t#-}"
  echo "${n:0:10} ${n:11:2}:${n:13:2}  ${t:-untitled}"
}

elapsed() { # folder -> MM:SS since the recording started
  local start now s
  start=$(stat -f %m "$1/sox.pid" 2>/dev/null) || return
  now=$(date +%s); s=$((now - start)); [ $s -lt 0 ] && s=0
  if [ $s -ge 3600 ]; then printf '%d:%02d:%02d' $((s/3600)) $((s%3600/60)) $((s%60))
  else printf '%02d:%02d' $((s/60)) $((s%60)); fi
}

# --- actions (SwiftBar calls the script again with an argument) ------------

case "$1" in
  start)
    title=$(osascript \
      -e 'try' \
      -e 'text returned of (display dialog "Title for this recording:" default answer "" with title "gh0stwriter" buttons {"Cancel", "Record"} default button "Record")' \
      -e 'on error number -128' -e 'return "__cancel__"' -e 'end try' 2>/dev/null)
    [ "$title" = "__cancel__" ] && exit 0
    args=(record)
    [ -n "$title" ] && args+=(--title "$title")
    err=$(gh0stwriter "${args[@]}" 2>&1 >/dev/null); code=$?
    if [ $code -ne 0 ]; then
      case $code in
        3) hint="sox was not found. Install it with: brew install sox" ;;
        4) hint="If the input gave only silence, SwiftBar may not have microphone access yet: allow it in System Settings > Privacy & Security > Microphone, or unmute the microphone." ;;
        *) hint="" ;;
      esac
      alert "Could not start recording (exit $code)" "$err${hint:+

$hint}"
    else
      [ -n "$err" ] && notify "gh0stwriter recording (warning)" "$err" || notify "gh0stwriter" "Recording${title:+: $title}"
    fi
    exit 0 ;;

  stop)
    d=$(recording_dir) || { notify "gh0stwriter" "No recording is running."; exit 0; }
    transcribing && exit 0
    # Detach the long-running stop from SwiftBar so it survives this action ending.
    nohup "$SELF" _stopjob "$d" >/dev/null 2>&1 </dev/null &
    echo $! > "$STATE/stop.pid"
    exit 0 ;;

  _stopjob)
    d="$2"
    echo "$d" > "$STATE/stop.run"
    gh0stwriter stop "$d" --quiet >"$STATE/stop.log" 2>&1; code=$?
    echo "$code" > "$STATE/stop.status"
    rm -f "$STATE/stop.pid"
    if [ $code -eq 0 ] && [ -f "$d/transcript.md" ]; then
      notify "gh0stwriter" "Transcript ready: $(run_label "$d")"
      open -t "$d/transcript.md"
    else
      alert "Transcription failed (exit $code)" "$(tail -5 "$STATE/stop.log")

The audio is kept. Use \"Retry transcription\" in the menu."
    fi
    exit 0 ;;

  retry)
    d=$(cat "$STATE/stop.run" 2>/dev/null)
    [ -n "$d" ] && [ -d "$d" ] || exit 0
    transcribing && exit 0
    rm -f "$STATE/stop.status"
    # Same detached job; gh0stwriter stop on a finished recording would refuse, so use transcribe.
    nohup /bin/bash -c '
      d="$1"; state="$2"
      gh0stwriter transcribe "$d" --quiet >"$state/stop.log" 2>&1; echo $? >"$state/stop.status"
      rm -f "$state/stop.pid"
      if [ -f "$d/transcript.md" ] && [ "$(cat "$state/stop.status")" = 0 ]; then open -t "$d/transcript.md"; fi
    ' _ "$d" "$STATE" >/dev/null 2>&1 </dev/null &
    echo $! > "$STATE/stop.pid"
    exit 0 ;;

  doctor)
    out=$(gh0stwriter doctor 2>&1)
    osascript -e 'on run argv' -e 'display dialog (item 1 of argv) with title "gh0stwriter doctor" buttons {"OK"} default button "OK"' -e 'end run' "$out" >/dev/null 2>&1
    exit 0 ;;
esac

# --- menu ------------------------------------------------------------------

if ! command -v gh0stwriter >/dev/null 2>&1; then
  echo "gh0st ⚠︎ | sfimage=exclamationmark.triangle"
  echo "---"
  echo "gh0stwriter not found in ~/.local/bin"
  exit 0
fi

rec=$(recording_dir)
if [ -n "$rec" ]; then
  echo "$(elapsed "$rec") | sfimage=record.circle.fill sfcolor=#ea0026"
elif transcribing; then
  echo "Transcribing… | sfimage=waveform"
else
  echo " | sfimage=waveform.circle"
fi

echo "---"
if [ -n "$rec" ]; then
  echo "Recording: $(run_label "$rec") | disabled=true"
  echo "Stop & transcribe | bash=\"$SELF\" param1=stop terminal=false refresh=true sfimage=stop.circle"
elif transcribing; then
  echo "Transcribing $(run_label "$(cat "$STATE/stop.run" 2>/dev/null)")… | disabled=true"
else
  echo "Start recording… | bash=\"$SELF\" param1=start terminal=false refresh=true sfimage=record.circle"
  if [ "$(cat "$STATE/stop.status" 2>/dev/null)" != "" ] && [ "$(cat "$STATE/stop.status")" != 0 ]; then
    echo "Retry transcription | bash=\"$SELF\" param1=retry terminal=false refresh=true sfimage=arrow.clockwise"
  fi
fi

latest=""
while read -r d; do
  [ -f "$d/transcript.md" ] && { latest="$d"; break; }
done < <(run_dirs)

echo "---"
if [ -n "$latest" ]; then
  echo "Latest transcript | bash=/usr/bin/open param1=-t param2=\"$latest/transcript.md\" terminal=false sfimage=doc.text"
fi
echo "Recent"
n=0
while read -r d; do
  [ -f "$d/transcript.md" ] || continue
  echo "--$(run_label "$d") | bash=/usr/bin/open param1=-t param2=\"$d/transcript.md\" terminal=false"
  n=$((n + 1)); [ $n -ge 8 ] && break
done < <(run_dirs)
[ $n -eq 0 ] && echo "--No transcripts yet | disabled=true"
echo "Open recordings folder | bash=/usr/bin/open param1=\"$RUNS\" terminal=false sfimage=folder"
echo "---"
echo "Doctor | bash=\"$SELF\" param1=doctor terminal=false sfimage=stethoscope"
