# Changelog

All notable changes to gh0stwriter are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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
- **Both sides of a call.** `--device NAME`, or `device` in `~/.config/gh0stwriter/config.toml`, records
  from a named input such as an aggregate device built on BlackHole, so a call is recorded with the other
  person's voice as well as yours.
- **Transcripts with speaker labels**, from AssemblyAI's EU API with the `universal-2` model, written to
  `transcript.md` and printed unless you pass `--quiet`.
- **A wait that scales with the audio**: 10 minutes plus half the length of the recording, checking every
  3 seconds. A few failed checks in a row (a network error, a timeout, an HTTP 5xx or 429 reply) no longer
  abandon a job that AssemblyAI is already working on.
- `gh0stwriter config` saves your AssemblyAI API key from standard input (`pbpaste | gh0stwriter config`)
  to a file only you can read; `ASSEMBLYAI_API_KEY` overrides it.
- **Safe handling of the recording process.** gh0stwriter only signals a process it has confirmed is its own
  sox, and refuses to start a second recording or to transcribe a recording that may still be running.

[Unreleased]: https://github.com/datashard-ai/gh0stwriter/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/datashard-ai/gh0stwriter/releases/tag/v0.1.0
