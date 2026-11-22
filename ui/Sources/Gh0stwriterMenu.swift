// gh0stwriter Menu: start and stop gh0stwriter recordings from the menu bar.
//
// The app only runs the gh0stwriter CLI and reads its run folders. It exists as
// an app of its own so that macOS can give it the microphone: sox, started by
// `gh0stwriter record`, records on this app's behalf.

import AppKit
import Darwin
import ServiceManagement
import SwiftUI

@main
struct Gh0stwriterMenuApp: App {
    @StateObject private var model = Model()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.symbol)
                if let text = model.labelText { Text(text).monospacedDigit() }
            }
        }
    }
}

// MARK: - State

enum Phase: Equatable {
    case idle
    case starting
    case recording(run: URL, since: Date)
    case transcribing(run: URL)
    case failed(run: URL)
}

@MainActor
final class Model: ObservableObject {
    @Published var phase: Phase = .idle
    @Published var recent: [URL] = []
    @Published var now = Date()
    /// What `record` printed on standard error when it succeeded (a reminder or a warning).
    @Published var note: String?

    let runsDir: URL
    let cli: URL
    private var timer: Timer?

    init() {
        let env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser
        runsDir = env["GH0STWRITER_HOME"].map { URL(fileURLWithPath: $0) }
            ?? home.appendingPathComponent("gh0stwriter")
        let bin = env["GH0STWRITER_INSTALL_DIR"].map { URL(fileURLWithPath: $0) }
            ?? home.appendingPathComponent(".local/bin")
        cli = bin.appendingPathComponent("gh0stwriter")

        refresh()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // .common keeps the timer firing while the menu is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: Menu bar label

    var symbol: String {
        switch phase {
        case .idle, .starting: return "waveform.circle"
        case .recording: return "record.circle.fill"
        case .transcribing: return "waveform"
        case .failed: return "exclamationmark.triangle"
        }
    }

    var labelText: String? {
        switch phase {
        case .recording(_, let since): return Self.elapsed(from: since, to: now)
        case .transcribing: return "Transcribing…"
        default: return nil
        }
    }

    // MARK: Reading the run folders

    func refresh() {
        now = Date()
        recent = Array(runDirs().filter { hasTranscript($0) }.prefix(8))
        switch phase {
        case .starting, .transcribing:
            return // a CLI call of ours is in flight; it sets the phase when it ends
        default:
            break
        }
        if let live = liveRecording() {
            phase = .recording(run: live.run, since: live.since)
        } else if case .recording = phase {
            phase = .idle // stopped elsewhere, or sox ended by itself (--minutes)
            note = nil
        }
    }

    func runDirs() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: runsDir.path)) ?? []
        return names
            .filter { $0.range(of: #"^\d{4}-\d{2}-\d{2}-\d{6}"#, options: .regularExpression) != nil }
            .sorted(by: >)
            .map { runsDir.appendingPathComponent($0, isDirectory: true) }
            .filter { var isDir: ObjCBool = false
                return FileManager.default.fileExists(atPath: $0.path, isDirectory: &isDir) && isDir.boolValue }
    }

    func transcript(_ run: URL) -> URL { run.appendingPathComponent("transcript.md") }
    func hasTranscript(_ run: URL) -> Bool { FileManager.default.fileExists(atPath: transcript(run).path) }

    /// The newest run folder whose sox.pid names a live sox process.
    func liveRecording() -> (run: URL, since: Date)? {
        guard let run = runDirs().first else { return nil }
        let pidFile = run.appendingPathComponent("sox.pid")
        guard let text = try? String(contentsOf: pidFile, encoding: .utf8),
              let digits = text.split(whereSeparator: { !$0.isNumber }).first,
              let pid = pid_t(digits), pid > 0,
              kill(pid, 0) == 0,
              Self.processName(pid).contains("sox")
        else { return nil }
        let since = (try? FileManager.default.attributesOfItem(atPath: pidFile.path)[.modificationDate] as? Date) ?? Date()
        return (run, since)
    }

    static func processName(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        let n = proc_name(pid, &buffer, UInt32(buffer.count))
        return n > 0 ? String(cString: buffer) : ""
    }

    // MARK: Actions

    func start() {
        guard let title = askTitle() else { return }
        phase = .starting
        note = nil
        var args = ["record"]
        if !title.isEmpty { args += ["--title", title] }
        Task {
            let r = await CLI.run(cli, args)
            phase = .idle
            if r.code == 0 {
                let err = r.err.trimmingCharacters(in: .whitespacesAndNewlines)
                note = err.isEmpty ? nil : err
            } else {
                alert("Could not start recording (exit \(r.code))", r.err + Self.hint(for: r.code))
            }
            refresh()
        }
    }

    func stop() {
        guard case .recording(let run, _) = phase else { return }
        phase = .transcribing(run: run)
        note = nil
        Task { finish(run, await CLI.run(cli, ["stop", run.path, "--quiet"])) }
    }

    func retry() {
        guard case .failed(let run) = phase else { return }
        phase = .transcribing(run: run)
        Task { finish(run, await CLI.run(cli, ["transcribe", run.path, "--quiet"])) }
    }

    private func finish(_ run: URL, _ r: CLI.Result) {
        if r.code == 0 && hasTranscript(run) {
            phase = .idle
            open(transcript(run))
        } else {
            phase = .failed(run: run)
            alert("Transcription failed (exit \(r.code))",
                  Self.lastLines(r.err, 8) + "\n\nThe audio is kept. Use Retry Transcription in the menu.")
        }
        refresh()
    }

    func doctor() {
        Task {
            let r = await CLI.run(cli, ["doctor"])
            alert("gh0stwriter doctor", (r.out + r.err).trimmingCharacters(in: .whitespacesAndNewlines),
                  style: r.code == 0 ? .informational : .warning)
        }
    }

    func open(_ url: URL) {
        if url.pathExtension == "md" {
            // Open in the default text editor, like `open -t`.
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            p.arguments = ["-t", url.path]
            try? p.run()
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    var openAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                alert("Could not change Open at Login", error.localizedDescription)
            }
            objectWillChange.send()
        }
    }

    // MARK: Dialogs

    private func askTitle() -> String? {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Start recording"
        alert.informativeText = "Title for this recording (optional). Tell everyone on the call that it is being recorded."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "weekly sync"
        alert.accessoryView = field
        alert.addButton(withTitle: "Record")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func alert(_ title: String, _ message: String, style: NSAlert.Style = .warning) {
        NSApp.activate()
        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    // MARK: Formatting

    static func hint(for code: Int32) -> String {
        switch code {
        case 3: return "\n\nsox was not found. Install it with: brew install sox"
        case 4: return "\n\nIf the input gave only silence: allow gh0stwriter Menu in System Settings > Privacy & Security > Microphone, then try again. A muted microphone gives silence too."
        case 127: return "\n\nInstall gh0stwriter first (see the README), into ~/.local/bin."
        default: return ""
        }
    }

    static func lastLines(_ s: String, _ n: Int) -> String {
        s.split(separator: "\n", omittingEmptySubsequences: true).suffix(n).joined(separator: "\n")
    }

    static func elapsed(from: Date, to: Date) -> String {
        let s = max(0, Int(to.timeIntervalSince(from)))
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
            : String(format: "%02d:%02d", s / 60, s % 60)
    }

    /// "2026-11-21-181730-weekly-sync" -> "2026-11-21 18:17  weekly-sync"
    static func label(_ run: URL) -> String {
        let n = Array(run.lastPathComponent)
        guard n.count >= 17 else { return run.lastPathComponent }
        var title = String(n.dropFirst(17))
        if title.hasPrefix("-") { title.removeFirst() }
        return "\(String(n[0..<10])) \(String(n[11..<13])):\(String(n[13..<15]))  \(title.isEmpty ? "untitled" : title)"
    }
}

// MARK: - Menu

struct MenuContent: View {
    @ObservedObject var model: Model

    var body: some View {
        switch model.phase {
        case .idle:
            Button("Start Recording…") { model.start() }.keyboardShortcut("r")
        case .starting:
            Text("Starting…")
        case .recording(let run, _):
            Text("Recording: \(Model.label(run))")
            Button("Stop & Transcribe") { model.stop() }.keyboardShortcut("s")
        case .transcribing(let run):
            Text("Transcribing \(Model.label(run))…")
        case .failed(let run):
            Text("Transcription failed: \(Model.label(run))")
            Button("Retry Transcription") { model.retry() }
            Button("Start Recording…") { model.start() }.keyboardShortcut("r")
        }
        if let note = model.note {
            Text(note.split(separator: "\n").first.map(String.init) ?? note)
        }

        Divider()
        if let latest = model.recent.first {
            Button("Latest Transcript") { model.open(model.transcript(latest)) }.keyboardShortcut("t")
        }
        Menu("Recent") {
            if model.recent.isEmpty {
                Text("No transcripts yet")
            }
            ForEach(model.recent, id: \.self) { run in
                Button(Model.label(run)) { model.open(model.transcript(run)) }
            }
        }
        Button("Open Recordings Folder") { model.open(model.runsDir) }

        Divider()
        Button("Doctor") { model.doctor() }
        Toggle("Open at Login", isOn: Binding(get: { model.openAtLogin }, set: { model.openAtLogin = $0 }))
        Divider()
        Button("Quit gh0stwriter Menu") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

// MARK: - Running the CLI

enum CLI {
    struct Result { var code: Int32; var out: String; var err: String }

    /// Runs the CLI and waits for it. Output goes to temporary files rather than
    /// pipes: `record` leaves sox running, and sox may hold on to inherited pipes.
    static func run(_ exe: URL, _ args: [String]) async -> Result {
        await withCheckedContinuation { (cont: CheckedContinuation<Result, Never>) in
            let fm = FileManager.default
            let tmp = fm.temporaryDirectory
            let outURL = tmp.appendingPathComponent("gh0stwriter-menu-\(UUID().uuidString).out")
            let errURL = tmp.appendingPathComponent("gh0stwriter-menu-\(UUID().uuidString).err")
            fm.createFile(atPath: outURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
            fm.createFile(atPath: errURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
            guard let out = try? FileHandle(forWritingTo: outURL), let err = try? FileHandle(forWritingTo: errURL) else {
                cont.resume(returning: Result(code: 1, out: "", err: "Could not create temporary files."))
                return
            }
            let read: (URL) -> String = { url in
                defer { try? fm.removeItem(at: url) }
                return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            }

            let p = Process()
            p.executableURL = exe
            p.arguments = args
            var env = ProcessInfo.processInfo.environment
            // Apps start with a minimal PATH; gh0stwriter needs to find sox.
            env["PATH"] = [exe.deletingLastPathComponent().path, "/opt/homebrew/bin", "/usr/local/bin",
                           "/usr/bin", "/bin", env["PATH"] ?? ""].joined(separator: ":")
            p.environment = env
            p.standardInput = FileHandle.nullDevice
            p.standardOutput = out
            p.standardError = err
            p.terminationHandler = { p in
                try? out.close()
                try? err.close()
                cont.resume(returning: Result(code: p.terminationStatus, out: read(outURL), err: read(errURL)))
            }
            do {
                try p.run()
            } catch {
                try? out.close()
                try? err.close()
                _ = read(outURL); _ = read(errURL)
                cont.resume(returning: Result(code: 127, out: "", err: "Could not run \(exe.path): \(error.localizedDescription)"))
            }
        }
    }
}
