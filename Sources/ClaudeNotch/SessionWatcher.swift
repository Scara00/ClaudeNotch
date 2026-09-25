import Foundation
import CoreServices

struct SessionAlert: Identifiable, Equatable, Sendable {
    let id = UUID()
    let project: String
    let title: String?
    let duration: TimeInterval
    let branch: String?
}

/// Osserva i log di Claude Code (~/.claude/projects/**/*.jsonl) e avvisa
/// quando una sessione finisce un turno (evento `system/turn_duration`).
final class SessionWatcher: @unchecked Sendable {
    /// Chiamato sul main thread.
    var onTurnFinished: (@MainActor (SessionAlert) -> Void)?
    static let enabledKey = "sessionNotificationsEnabled"
    /// I turni più brevi non vengono notificati: stavi probabilmente guardando.
    private let minDuration: TimeInterval = 15

    private let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
    private let queue = DispatchQueue(label: "ClaudeNotch.SessionWatcher", qos: .utility)
    private var stream: FSEventStreamRef?
    private var offsets: [String: UInt64] = [:]
    private var titles: [String: String] = [:]

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    func start() {
        queue.async { [self] in
            // Partiamo dalla fine dei file esistenti: niente notifiche per turni già conclusi.
            if let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let url as URL in en where isSessionLog(url.path) {
                    offsets[url.path] = UInt64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                }
            }
            startStream()
        }
    }

    private func isSessionLog(_ path: String) -> Bool {
        path.hasSuffix(".jsonl") && !path.contains("/subagents/")
    }

    private func startStream() {
        var ctx = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                       retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, paths, _, _ in
            guard let info else { return }
            let me = Unmanaged<SessionWatcher>.fromOpaque(info).takeUnretainedValue()
            let list = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
            for path in Set(list) where me.isSessionLog(path) { me.readNew(path) }
        }
        let flags = kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer
        guard let s = FSEventStreamCreate(nil, callback, &ctx, [root.path] as CFArray,
                                          FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 1.0,
                                          FSEventStreamCreateFlags(flags)) else { return }
        FSEventStreamSetDispatchQueue(s, queue)
        FSEventStreamStart(s)
        stream = s
    }

    /// Legge solo le righe aggiunte dall'ultima volta (file nuovi: dall'inizio).
    private func readNew(_ path: String) {
        guard let h = FileHandle(forReadingAtPath: path) else { offsets[path] = nil; return }
        defer { try? h.close() }
        let size = (try? h.seekToEnd()) ?? 0
        var start = offsets[path] ?? 0
        if size < start { start = 0 } // file riscritto
        guard size > start else { return }
        try? h.seek(toOffset: start)
        guard let data = try? h.read(upToCount: Int(size - start)),
              let lastNewline = data.lastIndex(of: UInt8(ascii: "\n")) else { return }
        // Le righe incomplete restano per il prossimo giro.
        offsets[path] = start + UInt64(lastNewline - data.startIndex + 1)

        for line in data[data.startIndex..<lastNewline].split(separator: UInt8(ascii: "\n")) {
            if line.range(of: Data("\"ai-title\"".utf8)) != nil,
               let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
               let title = obj["aiTitle"] as? String {
                titles[path] = title
            } else if line.range(of: Data("\"turn_duration\"".utf8)) != nil,
                      let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                      obj["subtype"] as? String == "turn_duration",
                      obj["isSidechain"] as? Bool != true {
                turnFinished(obj, path: path)
            }
        }
    }

    private func turnFinished(_ obj: [String: Any], path: String) {
        let duration = ((obj["durationMs"] as? Double) ?? 0) / 1000
        guard Self.isEnabled, duration >= minDuration else { return }

        let project = (obj["cwd"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Claude Code"
        let title = titles[path] ?? lastTitle(in: path)
        titles[path] = title
        let branch = (obj["gitBranch"] as? String).flatMap { $0.isEmpty || $0 == "HEAD" ? nil : $0 }
        let alert = SessionAlert(project: project, title: title, duration: duration, branch: branch)
        DispatchQueue.main.async { [onTurnFinished] in
            MainActor.assumeIsolated { onTurnFinished?(alert) }
        }
    }

    /// Titolo della sessione quando non l'abbiamo visto passare (sessione iniziata prima dell'app).
    private func lastTitle(in path: String) -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) else { return nil }
        let marker = Data("\"ai-title\"".utf8)
        for line in data.split(separator: UInt8(ascii: "\n")).reversed() where line.range(of: marker) != nil {
            if let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
               let title = obj["aiTitle"] as? String { return title }
        }
        return nil
    }

    static func format(_ s: TimeInterval) -> String {
        let s = Int(s), h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(sec)s" }
        return "\(sec)s"
    }
}
