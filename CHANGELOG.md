# Changelog

All notable changes to gh0stwriter are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/datashard-ai/gh0stwriter/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/datashard-ai/gh0stwriter/releases/tag/v0.2.0
[0.1.1]: https://github.com/datashard-ai/gh0stwriter/releases/tag/v0.1.1
[0.1.0]: https://github.com/datashard-ai/gh0stwriter/releases/tag/v0.1.0
