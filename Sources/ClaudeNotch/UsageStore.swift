import Foundation

struct UsageWindow: Equatable {
    var percent: Double
    var resetsAt: Date?
}

struct TokenStats: Equatable {
    var tokens: Int = 0
    var outputTokens: Int = 0
    var messages: Int = 0
}

struct ModelUsage: Equatable, Identifiable {
    var name: String
    var tokens: Int
    var share: Double
    var id: String { name }
}

struct LocalStats: Equatable {
    var today = TokenStats()
    var week = TokenStats()
    /// Modelli usati nella settimana, dal più usato.
    var models: [ModelUsage] = []
}

@MainActor
final class UsageStore: ObservableObject {
    @Published var session: UsageWindow?
    @Published var weekly: UsageWindow?
    @Published var weeklyOpus: UsageWindow?
    @Published var weeklySonnet: UsageWindow?
    @Published var local = LocalStats()
    @Published var error: String?
    @Published var lastUpdate: Date?

    /// L'endpoint è condiviso con /usage di Claude Code ed è molto sensibile al rate limit.
    private let pollInterval: TimeInterval = 180
    private var nextAllowedFetch = Date.distantPast
    private var consecutive429 = 0
    private var fetching = false
    private let localScanner = LocalLogScanner()
    private static let cacheKey = "lastUsageResponse"
    private static let cacheDateKey = "lastUsageDate"

    func start() {
        // Mostra subito l'ultimo valore noto, anche dopo un riavvio.
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey) {
            try? parse(data)
            lastUpdate = UserDefaults.standard.object(forKey: Self.cacheDateKey) as? Date
        }
        refreshLocal()
        Task { await fetchPlanUsage() }
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshLocal()
                await self?.fetchPlanUsage()
            }
        }
    }

    func refreshLocal() {
        // La settimana è quella del limite del piano (reset - 7 giorni), altrimenti gli ultimi 7 giorni.
        let weekStart = weekly?.resetsAt.map { $0.addingTimeInterval(-7 * 86400) } ?? Date().addingTimeInterval(-7 * 86400)
        Task.detached(priority: .utility) { [localScanner] in
            let stats = localScanner.scan(weekStart: weekStart)
            await MainActor.run { self.local = stats }
        }
    }

    // MARK: - Limiti del piano (stesso endpoint usato da /usage di Claude Code)

    private func fetchPlanUsage() async {
        guard !fetching, Date() >= nextAllowedFetch else { return }
        fetching = true
        defer { fetching = false }
        nextAllowedFetch = Date().addingTimeInterval(pollInterval)

        guard let token = Self.readAccessToken() else {
            error = "Login Claude Code non trovato"
            return
        }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let http = resp as? HTTPURLResponse
            switch http?.statusCode ?? 0 {
            case 200:
                try parse(data)
                consecutive429 = 0
                error = nil
                lastUpdate = Date()
                UserDefaults.standard.set(data, forKey: Self.cacheKey)
                UserDefaults.standard.set(lastUpdate, forKey: Self.cacheDateKey)
            case 401:
                error = "Token scaduto: apri Claude Code"
            case 429:
                consecutive429 += 1
                // Retry-After se presente, altrimenti backoff esponenziale: 5, 10, 20, 30 min.
                let retryAfter = http?.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                let backoff = min(1800, 300 * pow(2, Double(consecutive429 - 1)))
                nextAllowedFetch = Date().addingTimeInterval(max(retryAfter ?? 0, backoff))
                error = session == nil ? "Rate limit, riprovo alle \(nextAllowedFetch.formatted(date: .omitted, time: .shortened))" : nil
            case let status:
                error = "Errore HTTP \(status)"
            }
        } catch {
            self.error = "Offline"
        }
    }

    private func parse(_ data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        func window(_ key: String) -> UsageWindow? {
            guard let w = json[key] as? [String: Any], let u = w["utilization"] as? Double else { return nil }
            return UsageWindow(percent: u, resetsAt: (w["resets_at"] as? String).flatMap(Self.parseDate))
        }
        session = window("five_hour")
        weekly = window("seven_day")
        weeklyOpus = window("seven_day_opus")
        weeklySonnet = window("seven_day_sonnet")
    }

    /// Legge il token OAuth di Claude Code dal Portachiavi tramite /usr/bin/security,
    /// così è sempre quello aggiornato (Claude Code lo rinnova da solo).
    nonisolated static func readAccessToken() -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        p.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else { return nil }
        return token
    }

    nonisolated static func parseDate(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}

// MARK: - Token di oggi e della settimana dai log locali (~/.claude/projects/**/*.jsonl)

final class LocalLogScanner: @unchecked Sendable {
    private struct Record { var timestamp: Date; var tokens: Int; var output: Int; var model: String? }
    /// Per ogni file: fin dove l'abbiamo letto e le risposte trovate (id messaggio → record).
    private struct FileState { var offset: UInt64; var since: Date; var records: [String: Record] }
    private var files: [String: FileState] = [:]
    private let lock = NSLock()

    func scan(weekStart: Date) -> LocalStats {
        lock.lock(); defer { lock.unlock() }
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let since = min(weekStart, startOfDay)
        guard let en = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return LocalStats()
        }

        var all: [String: Record] = [:]
        var seen = Set<String>()
        for case let url as URL in en where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let mtime = values.contentModificationDate, mtime >= since else { continue }
            let size = UInt64(values.fileSize ?? 0)
            seen.insert(url.path)

            // File nuovo, accorciato o letto da una data successiva: si rilegge da capo.
            var state = files[url.path] ?? FileState(offset: 0, since: since, records: [:])
            if size < state.offset || since < state.since { state = FileState(offset: 0, since: since, records: [:]) }
            if size > state.offset { read(url, into: &state, size: size) }
            files[url.path] = state
            all.merge(state.records) { a, _ in a }
        }
        files = files.filter { seen.contains($0.key) }

        var stats = LocalStats()
        var byModel: [String: Int] = [:]
        for r in all.values where r.timestamp >= weekStart {
            stats.week.tokens += r.tokens
            stats.week.outputTokens += r.output
            stats.week.messages += 1
            if let m = r.model { byModel[m, default: 0] += r.tokens }
        }
        for r in all.values where r.timestamp >= startOfDay {
            stats.today.tokens += r.tokens
            stats.today.outputTokens += r.output
            stats.today.messages += 1
        }
        let total = max(1, byModel.values.reduce(0, +))
        stats.models = byModel.map { ModelUsage(name: $0.key, tokens: $0.value, share: Double($0.value) / Double(total)) }
            .sorted { $0.tokens > $1.tokens }
        return stats
    }

    /// Legge solo le righe aggiunte dall'ultima volta.
    private func read(_ url: URL, into state: inout FileState, size: UInt64) {
        guard let h = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? h.close() }
        try? h.seek(toOffset: state.offset)
        guard let data = try? h.read(upToCount: Int(size - state.offset)),
              let lastNewline = data.lastIndex(of: UInt8(ascii: "\n")) else { return }
        state.offset += UInt64(lastNewline - data.startIndex + 1)

        let marker = Data("\"usage\"".utf8)
        for line in data[data.startIndex..<lastNewline].split(separator: UInt8(ascii: "\n")) where line.range(of: marker) != nil {
            guard let obj = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let ts = (obj["timestamp"] as? String).flatMap(UsageStore.parseDate), ts >= state.since,
                  let msg = obj["message"] as? [String: Any],
                  let usage = msg["usage"] as? [String: Any] else { continue }
            let id = (msg["id"] as? String) ?? UUID().uuidString
            let n = { (k: String) in (usage[k] as? Int) ?? 0 }
            // Le risposte in streaming vengono loggate più volte con lo stesso id: teniamo l'ultima.
            state.records[id] = Record(
                timestamp: ts,
                tokens: n("input_tokens") + n("output_tokens") + n("cache_creation_input_tokens") + n("cache_read_input_tokens"),
                output: n("output_tokens"),
                model: (msg["model"] as? String).flatMap(Self.displayName))
        }
    }

    /// "claude-opus-4-8" → "Opus 4.8", "claude-haiku-4-5-20251001" → "Haiku 4.5".
    static func displayName(_ id: String) -> String? {
        guard id.hasPrefix("claude-") else { return nil } // es. "<synthetic>"
        var parts = id.dropFirst("claude-".count).split(separator: "-").map(String.init)
        if let last = parts.last, last.count == 8, Int(last) != nil { parts.removeLast() }
        guard let family = parts.first else { return nil }
        let version = parts.dropFirst().joined(separator: ".")
        return version.isEmpty ? family.capitalized : "\(family.capitalized) \(version)"
    }
}
