# gh0stwriter Menu

A small macOS menu bar app that starts and stops gh0stwriter recordings and opens their transcripts. It only runs the `gh0stwriter` CLI and reads the run folders, so everything the CLI does (one recording at a time, never deleting audio, exit codes) still applies.

It is an app of its own, rather than a script in a menu bar tool, because macOS gives the microphone to the app that starts a recording, and only to an app that declares it uses the microphone. This one does, so macOS asks once and then lists it under System Settings > Privacy & Security > Microphone.

## Build and install

You need gh0stwriter installed (see the main [README](../README.md#quick-start)), macOS 14 or later, and the Command Line Tools (`xcode-select --install`); Xcode itself is not needed.

```sh
ui/build.sh --install
```

This compiles `ui/Sources/`, puts `gh0stwriter Menu.app` in `ui/build/`, copies it to `~/Applications` and opens it. Without `--install` it only builds. The first time you start a recording, macOS asks whether gh0stwriter Menu may use the microphone: allow it.

The app is signed ad hoc, which is enough to run it on the Mac that built it. Because that signature changes with each build, macOS may ask for the microphone again after a rebuild. Sharing the app with others would need a Developer ID signature and notarization.

To remove it, choose **Quit gh0stwriter Menu**, turn off **Open at Login** first if you turned it on, and delete `~/Applications/gh0stwriter Menu.app`.

## The menu

| State | Menu bar | Menu |
| --- | --- | --- |
| Idle | waveform icon | **Start Recording…** (asks for a title, optional) |
| Recording | red dot and the elapsed time | **Stop & Transcribe** |
| Transcribing | "Transcribing…" | the transcript opens in your text editor when it is ready |
| Failed | warning icon | **Retry Transcription** (runs `gh0stwriter transcribe` on the same run; the audio is kept) |

Always there: **Latest Transcript**, **Recent** (the last 8 transcripts), **Open Recordings Folder**, **Doctor** (shows `gh0stwriter doctor`), **Open at Login** and **Quit**.

- **Start Recording…** runs `gh0stwriter record [--title TITLE]`. If it fails, an alert shows what the CLI printed and the exit code; for exit 4 (only silence), check the microphone permission above, or unmute the microphone.
- **Stop & Transcribe** runs `gh0stwriter stop <run> --quiet` and waits for it, which can take minutes. If it fails, an alert shows the last lines the CLI printed.
- A recording counts as running when the newest run folder has a `sox.pid` whose process is alive and is `sox`. A recording started in the terminal shows up in the menu too, and can be stopped there; one stopped in the terminal, or by `--minutes`, leaves the menu by itself.

## Settings

The app looks for the CLI in `~/.local/bin` and the recordings in `~/gh0stwriter`. Apps started from the Finder do not see your shell's variables, so `GH0STWRITER_INSTALL_DIR` and `GH0STWRITER_HOME` apply only when they are in the app's environment (for example, when it is started with `open` from a shell that sets them). It adds `/opt/homebrew/bin` and `/usr/local/bin` to the PATH it gives the CLI, so that the CLI finds sox.

## Files

| File | What it is |
| --- | --- |
| `Sources/Gh0stwriterMenu.swift` | The whole app: SwiftUI `MenuBarExtra`, the run-folder reading, the CLI calls |
| `Info.plist` | The bundle's settings: menu bar only (`LSUIElement`), the microphone usage text |
| `build.sh` | Compiles with `swiftc`, assembles the bundle, signs it ad hoc, and with `--install` installs and opens it |
