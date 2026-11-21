# gh0stwriter in the menu bar

A [SwiftBar](https://github.com/swiftbar/SwiftBar) plugin that starts and stops gh0stwriter recordings and opens their transcripts. It only calls the `gh0stwriter` CLI and reads the run folders, so everything the CLI does (one recording at a time, never deleting audio, exit codes) still applies.

## Install

You need gh0stwriter installed (see the main [README](../README.md#quick-start)), then:

```sh
brew install --cask swiftbar
mkdir -p ~/SwiftBar
ln -sfn "$PWD/ui/gh0stwriter.5s.sh" ~/SwiftBar/gh0stwriter.5s.sh   # run from the repo root
defaults write com.ameba.SwiftBar PluginDirectory "$HOME/SwiftBar"
open -a SwiftBar
```

The link keeps the menu bar on the repo's copy, so a `git pull` updates it. To use a fixed copy instead, `cp` the file and `chmod +x` it. If SwiftBar opens a folder picker on its first launch, choose `~/SwiftBar`. The `.5s` in the file name makes the menu refresh every five seconds.

To add SwiftBar to the apps that open at login, use its own Preferences, or System Settings > General > Login Items.

To remove it: delete `~/SwiftBar/gh0stwriter.5s.sh` (and `brew uninstall --cask swiftbar` if you no longer want SwiftBar). The plugin's state folder, `~/Library/Caches/gh0stwriter-swiftbar/`, can be deleted too.

## The menu

| State | Menu bar | Menu |
| --- | --- | --- |
| Idle | waveform icon | **Start recording…** (asks for a title), latest transcript, recent transcripts, recordings folder, doctor |
| Recording | red dot and elapsed time | **Stop & transcribe** |
| Transcribing | "Transcribing…" | — (the transcript opens by itself when it is ready) |
| Failed | waveform icon | **Retry transcription** (runs `gh0stwriter transcribe` on the same run; the audio is kept) |

`Stop & transcribe` runs `gh0stwriter stop <run> --quiet` in the background, detached from SwiftBar, because it can take minutes. When it finishes you get a notification and `transcript.md` opens in your text editor. If it fails, an alert shows the last lines of the CLI's output.

## Notes

- **Microphone access.** macOS asks for it on behalf of SwiftBar, not your terminal. If the first recording fails with exit 4 (silence), allow SwiftBar under System Settings > Privacy & Security > Microphone.
- A recording counts as running when the newest run folder has a `sox.pid` whose process is alive and is `sox`, so a recording started from the terminal shows up here too, and can be stopped here.
- `GH0STWRITER_HOME` and `GH0STWRITER_INSTALL_DIR` are honoured if SwiftBar's environment sets them. The plugin keeps its own small state (the background job's pid, log and exit code) in `~/Library/Caches/gh0stwriter-swiftbar/`.
