# Changelog

All notable changes to gh0stwriter are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **A menu bar app for gh0stwriter.** `ui/` holds gh0stwriter Menu, a small macOS app that starts and stops
  recordings, shows how long the current one has run, and opens the latest and recent transcripts. Build it with
  `ui/build.sh --install` (see [ui/README.md](ui/README.md)).

## [0.4.2] - 2026-11-20

### Changed

- **`record` reminds you to tell everyone on the call that it is being recorded.**

## [0.4.1] - 2026-11-19

### Changed

- **A recording of one track has its speakers told apart.** With the local engine, a recording made without a
  `call_device`, and an audio file given to `transcribe`, now have the speakers found on your Mac, and how many there are,
  as the call's track of a two-track recording has: they are labelled `Speaker 1`, `Speaker 2` and so on, under a list of
  them, and `gh0stwriter speakers` names them. There is no `You` on one track, since nothing tells your voice from the
  rest, and one voice is `Speaker 1`, not `Others`. Before, such a transcript had no speaker labels. A 3-hour recording of
  one track peaked at 6.29 GB of memory on an Apple M5 Ultra; the check on a 16 GB Mac is still to be done.
- **Every local recording needs the speaker model: run `gh0stwriter model` after upgrading if you have only the speech
  model.** `stop` and `transcribe` exit with code 2, naming `gh0stwriter model`, when it is missing, for one track as for
  two, before anything is stopped, made, read or sent, and `record` and `config --engine local` warn, for every
  recording with the local engine, when it is not there yet. `doctor` fails, with the local engine chosen, when it is missing, where it only warned. The
  AssemblyAI engine is unchanged and needs no speaker model.
- **A split that fails on one track does not lose the transcript.** The transcript is the plain one the last release
  made, timed lines with no speakers, one line on standard error says that the speakers could not be told apart, and the
  exit code is 0.

## [0.4.0] - 2026-11-19

### Changed

- **The call's speakers are found, not counted.** With the local engine, every two-track recording has the call's
  track split into its speakers on your Mac, and the number of speakers is found by the model (up to 8); you no longer
  say how many. NVIDIA's Nemotron 3 Diarization, run by NVIDIA's NeMo-Speech.cpp, replaces the earlier split. When it
  finds one speaker, the call's track is `Others`. On the public meeting ES2004a it gave 86.6% of the words of the
  call's track to the right speaker, where the earlier split gave 72.9%, and found the right number of speakers on the
  meeting's official mix. A 3-hour two-track call peaked at 6.28 GB of memory on an Apple M5 Ultra; the check on a
  16 GB Mac is still to be done.
- **`--others N` is no longer needed.** `stop` and `transcribe` still accept it where the last release did, with the
  local engine on a two-track recording, ignore the number and say so in one line. Where it was refused (AssemblyAI, a
  recording with one track, an audio file) it is still refused.
- **A two-track recording needs the speaker model: run `gh0stwriter model` after upgrading.** `stop` and `transcribe`
  exit with code 2, naming `gh0stwriter model`, when it is missing, before anything is stopped, read or sent, and `record`
  warns, with a `call_device` set, when it is not there yet. The installer runs `gh0stwriter model` itself when the engine
  is already local. The command also checks the model file against its published checksum, and downloads it again,
  keeping the old folder beside it, when it is not that file.
- **A split that fails does not lose the transcript.** If the split of the call's track fails while it runs, the call's
  track is labelled `Others`, one line on standard error says why, and the exit code is 0.
- **`gh0stwriter model` downloads one speaker model, 102 MiB, in place of two (44 MiB).** `doctor` names it. The folder of
  the old speaker models, `speakers-9403a690-0743f301`, in `~/.local/share/gh0stwriter/models/`, is not used any more and
  not removed: delete it by hand if you want the space.
- **NVIDIA's libraries ship in a folder, `gh0stwriter-lib/`, beside the program, which does not start without it.**
  The installer puts it there and replaces it whole on each install; it tries the new program before it replaces the
  old one, and puts the old one back if the new one does not run. ONNX Runtime and sherpa-onnx are gone from the program; the third-party notices
  list what NVIDIA's libraries carry.

## [0.3.0] - 2026-11-16

### Added

- **Record you and the call as two tracks.** Send the call's sound to BlackHole (a Multi-Output device of your
  headphones and BlackHole as the Mac's output), set `call_device = "BlackHole 2ch"` in
  `~/.config/gh0stwriter/config.toml` (or pass `record --call-device`), and `record` records your microphone and the
  call's device side by side, in separate channels of one file. No Aggregate device is needed. `mic_channels` (1 by
  default) and `call_channels` (2 by default, right for BlackHole 2ch) are the two devices' channels; `record` stops
  with exit code 4 when the file has another count. Without `call_device` nothing changes: recording is one channel, as
  before. If the microphone's channel is silent, `record` warns that your side of the call is not being recorded and
  keeps recording. Wear headphones: over loudspeakers the microphone also hears the call, so the others' words appear
  a second time, labelled `You`. The local engine labels your words `You` and the call's `Others`, and skips a track
  that is silent throughout, saying so; the AssemblyAI engine is sent a mono mix in which both tracks weigh the same,
  and keeps its own speaker labels. This has not been tried yet on a real call.
- **`--others N` on `stop` and `transcribe`** says how many other people were on the call, and splits the call's track
  into that many speakers on your Mac, with the local engine (`Speaker 1`, `Speaker 2` and so on). The number is
  never guessed: without it the call is one speaker, `Others`. The split takes about 4 to 5 minutes for each hour
  of call, before the transcription starts, and fewer speakers than you asked for may come back.
- **`gh0stwriter speakers RUN`** lists a transcript's speakers with their first lines, and
  `gh0stwriter speakers RUN you=us:Alice 1=client:Bob` names each one with a side (`us`, `client` or `other`, in any
  case),
  in `transcript.md`, which now has a `## Speakers` list above the transcript. Run it again to change a name. Nothing
  about a voice is stored: the voices are compared only in memory, while one call is split, and no voiceprint is kept
  or compared across calls.
- **`gh0stwriter model` also downloads the two speaker models** (44 MiB, once), checked like the speech model, and
  `doctor` says when they are missing. The local engine still works without them; it just cannot split a call.

### Changed

- **The program is bigger: about 34 MB, where it was about 17 MB.** ONNX Runtime, which tells the speakers apart, is
  linked into it, so the download grows too. The third-party notices list what that adds.

## [0.2.0] - 2026-11-16

### Added

- **A second engine that transcribes on your Mac.** `gh0stwriter config --engine local` makes it the one used from
  now on, `--engine assemblyai|local` on `stop` and `transcribe` picks it for one run, and AssemblyAI stays the
  default, so an install that changes nothing works as before. The local engine runs NVIDIA's Parakeet model on your
  Mac's GPU: it needs no API key, sends nothing anywhere, and gives no speaker labels (the transcript has one
  `[MM:SS] <sentence>` paragraph per sentence and ends with `Speakers: 0`). It reads 16 kHz mono 16-bit WAV, which is
  what `record` writes; other audio is refused with the sox command that converts it. On a public 17-minute test
  meeting it took about 16 seconds and made roughly 19 mistakes per 100 words with filler sounds ignored. It stays
  within 6 GiB of memory.
- **`gh0stwriter model`** downloads the local engine's speech model (2.3 GiB) once, checks it against a published
  checksum, and carries on where it stopped if it is cut off.
- **`gh0stwriter doctor`** lists what this Mac has and lacks (sox, the engine in use, the API key, the speech model
  and the Metal kernels), with a `fix:` line under each problem, and exits 1 when something the chosen engine needs
  is missing. It changes nothing and never prints the key.
- **The installer asks which engine to use.** `install.sh` asks once on a terminal (1 for AssemblyAI, 2 for the local
  engine, Enter to leave it as it is); with the local engine it then downloads the speech model. For a script, pass
  `--engine assemblyai|local` and `--no-model`. Without a terminal and without options nothing about the engine
  changes.

### Changed

- **A call is limited to 3 hours.** `record` stops at 3 hours, and the local engine refuses a longer recording and
  keeps the audio; `--engine assemblyai` still takes it.
- **The download is bigger: about 42 MB, where 0.1.1's was 1.2 MB.** The release now carries the Metal kernels the
  local engine needs (`mlx.metallib`, installed beside the program).

- **The next release needs macOS 14 or later.** On an older Mac the installer now stops before it downloads
  anything and leaves the gh0stwriter you have where it is. Version 0.1.1 and earlier run on macOS 11 or
  later; to install 0.1.1 on an older Mac, run the installer with `GH0STWRITER_VERSION=0.1.1`.

## [0.1.1] - 2026-11-13

### Fixed

- **A recording no longer comes back as an empty transcript when the terminal app is not allowed the
  microphone.** macOS gives such an app silence instead of an error, so a whole call used to be recorded,
  uploaded and transcribed to nothing. `record` now listens to the first second: if the default input gave
  only silence it stops sox and exits with code 4, naming the setting to change and, for a muted
  microphone, the way out (unmute it, or name the input with `--device` to record anyway). A silent
  `--device` only gets a warning, because a loopback device such as BlackHole is silent until something
  plays; for an aggregate device that includes a microphone, the warning says your side of the call
  may be missing. An input that sends no audio within 10 seconds also only gets a warning, since macOS may still be
  asking whether to allow the microphone. `stop` and `transcribe` refuse a silent 16-bit WAV before
  anything is uploaded (exit code 4) and keep the audio. Audio in any other format is sent as before.

## [0.1.0] - 2026-11-06

### Added

- **A recording that outlives the command that started it.** `gh0stwriter record` starts sox in its own
  process group and returns at once; `gh0stwriter stop` ends it with SIGINT, so sox finishes the audio
  file, and then transcribes it. A recording started from a shell call that ends is still running when you
  come back to stop it.
- **A fixed folder for every recording**, `~/gh0stwriter/<date-time>-<title>/` (or under
  `GH0STWRITER_HOME`), with the audio, the transcript and sox's log. Folders are mode 0700 and files 0600.
- **The audio is never deleted.** A failed upload, a failed transcription or a crash leaves the recording
  where it is, and `gh0stwriter transcribe <folder>` tries again. It also takes an audio file.
- **A named input to record from.** `--device NAME`, or `device` in `~/.config/gh0stwriter/config.toml`,
  records from a named input, such as an aggregate device built on BlackHole, so that a call can be
  recorded from both sides. The name reaches sox as `-t coreaudio NAME`. This has not been tried yet with
  a real BlackHole setup: the recordings checked so far used a stand-in for the microphone.
- **Transcripts with speaker labels**, from AssemblyAI's EU API with the `universal-2` model, written to
  `transcript.md` and printed unless you pass `--quiet`. Where AssemblyAI stores uploads made through its
  EU endpoint is not confirmed, and AssemblyAI documents exceptions to EU residency: see Privacy in the
  README before you use gh0stwriter for audio that must stay in the EU.
- **A wait that scales with the audio**: 10 minutes plus half the length of the recording, checking every
  3 seconds. A few failed checks in a row (a network error, a timeout, an HTTP 5xx or 429 reply) do not
  abandon a job that AssemblyAI is already working on.
- `gh0stwriter config` saves your AssemblyAI API key from standard input (`pbpaste | gh0stwriter config`)
  to a file only you can read; `ASSEMBLYAI_API_KEY` overrides it.
- **Safe handling of the recording process.** gh0stwriter only signals a process it has confirmed is its own
  sox, and refuses to start a second recording or to transcribe a recording that may still be running.

[Unreleased]: https://github.com/datashard-ai/gh0stwriter/compare/v0.4.2...HEAD
[0.4.2]: https://github.com/datashard-ai/gh0stwriter/releases/tag/v0.4.2
[0.4.1]: https://github.com/datashard-ai/gh0stwriter/releases/tag/v0.4.1
[0.4.0]: https://github.com/datashard-ai/gh0stwriter/releases/tag/v0.4.0
[0.3.0]: https://github.com/datashard-ai/gh0stwriter/releases/tag/v0.3.0
[0.2.0]: https://github.com/datashard-ai/gh0stwriter/releases/tag/v0.2.0
[0.1.1]: https://github.com/datashard-ai/gh0stwriter/releases/tag/v0.1.1
[0.1.0]: https://github.com/datashard-ai/gh0stwriter/releases/tag/v0.1.0
