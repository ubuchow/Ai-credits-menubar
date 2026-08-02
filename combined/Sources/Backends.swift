import AppKit
import AVFoundation
import Foundation

// Combined AI Credits menubar — Grok + Codex stacked in one status item.

enum MenuBarPercentFont {
    static func font(size: CGFloat = 11) -> NSFont {
        for name in ["Times New Roman", "TimesNewRomanPSMT", "TimesNewRomanPS-BoldMT", "Times"] {
            if let f = NSFont(name: name, size: size) { return f }
        }
        return NSFont.systemFont(ofSize: size)
    }
    static func bold(size: CGFloat) -> NSFont {
        for name in ["TimesNewRomanPS-BoldMT", "Times New Roman Bold", "Times-Bold", "TimesNewRomanPSMT"] {
            if let f = NSFont(name: name, size: size) { return f }
        }
        return NSFont.systemFont(ofSize: size, weight: .bold)
    }
}

struct GrokInfo {
    var remainingPercent: Double?
    var resetsAt: Date?
    var nextSubscriptionAt: Date?
    var subscriptionAutoRenew: Bool?
    /// Local log-based token totals (sum of prompt+completion per inference).
    var tokensToday: Int?
    var tokensMonth: Int?
    var email: String?
    var fromCache: Bool
    var error: String?

    var remainingText: String {
        if let p = remainingPercent {
            let s = String(format: "%.1f", p).replacingOccurrences(of: "\\.0$", with: "", options: .regularExpression)
            return "\(s)%"
        }
        return "—"
    }

    var resetText: String {
        guard let d = resetsAt else { return "未知" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: d)
    }

    /// Next subscription renewal / period end as a calendar day.
    var nextSubscriptionText: String {
        guard let d = nextSubscriptionAt else { return "—" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        let cal = Calendar.current
        if cal.component(.year, from: d) == cal.component(.year, from: Date()) {
            f.dateFormat = "M月d日"
        } else {
            f.dateFormat = "yyyy年M月d日"
        }
        return f.string(from: d)
    }

    var nextSubscriptionMenuTitle: String {
        guard nextSubscriptionAt != nil else { return "下次订阅: —" }
        if subscriptionAutoRenew == false {
            return "订阅到期: \(nextSubscriptionText)"
        }
        return "下次订阅: \(nextSubscriptionText)"
    }

    /// Chinese units: 万 / 亿 (e.g. 10万、312万、1.4亿)
    static func formatTokens(_ n: Int?) -> String {
        guard let n else { return "—" }
        if n < 0 { return "—" }
        if n < 10_000 {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.locale = Locale(identifier: "zh_CN")
            return f.string(from: NSNumber(value: n)) ?? "\(n)"
        }
        if n < 100_000_000 {
            let wan = Double(n) / 10_000.0
            if wan >= 100 {
                return "\(Int(wan.rounded()))万"
            }
            if wan == floor(wan) {
                return "\(Int(wan))万"
            }
            return String(format: "%.1f万", wan).replacingOccurrences(of: ".0万", with: "万")
        }
        // ≥ 1 亿：100 亿以下保留一位小数（18.7亿、30.1亿），避免 18.69→19 的误导
        let yi = Double(n) / 100_000_000.0
        if yi >= 100 {
            return "\(Int(yi.rounded()))亿"
        }
        if yi == floor(yi) {
            return "\(Int(yi))亿"
        }
        return String(format: "%.1f亿", yi).replacingOccurrences(of: ".0亿", with: "亿")
    }

    var tokensTodayText: String { Self.formatTokens(tokensToday) }
    var tokensMonthText: String { Self.formatTokens(tokensMonth) }

    /// Compact menu bar text: just the percentage (G mark is the icon).
    var menuBarTitle: String {
        if remainingPercent == nil {
            return "?"
        }
        return remainingText
    }
}

/// Monoline circle + G (blue accent, matches product mock). Images cached for low RAM.


enum GrokFetcher {
    /// Resolve `grok-credits` helper: env → common install paths → PATH.
    static var grokCreditsPath: String? {
        if let env = ProcessInfo.processInfo.environment["GROK_CREDITS_BIN"], !env.isEmpty {
            let p = (env as NSString).expandingTildeInPath
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        let home = NSHomeDirectory() as NSString
        let candidates = [
            home.appendingPathComponent(".local/bin/grok-credits"),
            home.appendingPathComponent(".grok/bin/grok-credits"),
            home.appendingPathComponent("bin/grok-credits"),
            "/usr/local/bin/grok-credits",
            "/opt/homebrew/bin/grok-credits",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        // which
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = ["grok-credits"]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        try? proc.run()
        proc.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    static func fetch(forceLive: Bool) -> GrokInfo {
        // Local token totals — independent of network / credits helper
        let tokenStats = GrokTokenStats.collect()

        guard let bin = grokCreditsPath else {
            return GrokInfo(
                remainingPercent: nil, resetsAt: nil, nextSubscriptionAt: nil,
                subscriptionAutoRenew: nil,
                tokensToday: tokenStats.today, tokensMonth: tokenStats.month,
                email: nil, fromCache: false,
                error: "未找到 grok-credits（请先 install 或设置 GROK_CREDITS_BIN）"
            )
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = forceLive ? ["--json", "--no-cache"] : ["--json"]
        proc.environment = ProcessInfo.processInfo.environment.merging([
            "HOME": NSHomeDirectory(),
            "GROK_HOME": (NSHomeDirectory() as NSString).appendingPathComponent(".grok"),
            "PATH": "\((NSHomeDirectory() as NSString).appendingPathComponent(".grok/bin")):/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
        ]) { _, new in new }

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return GrokInfo(
                remainingPercent: nil, resetsAt: nil, nextSubscriptionAt: nil,
                subscriptionAutoRenew: nil,
                tokensToday: tokenStats.today, tokensMonth: tokenStats.month,
                email: nil, fromCache: false,
                error: error.localizedDescription
            )
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        if proc.terminationStatus != 0 {
            let err = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "exit \(proc.terminationStatus)"
            return GrokInfo(
                remainingPercent: nil, resetsAt: nil, nextSubscriptionAt: nil,
                subscriptionAutoRenew: nil,
                tokensToday: tokenStats.today, tokensMonth: tokenStats.month,
                email: nil, fromCache: false,
                error: String(err.prefix(120))
            )
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return GrokInfo(
                remainingPercent: nil, resetsAt: nil, nextSubscriptionAt: nil,
                subscriptionAutoRenew: nil,
                tokensToday: tokenStats.today, tokensMonth: tokenStats.month,
                email: nil, fromCache: false,
                error: "JSON 解析失败"
            )
        }

        let remaining = json["monthly_remaining_percent"] as? Double
        let email = json["email"] as? String
        let fromCache = json["from_cache"] as? Bool ?? false
        var resets: Date?
        if let iso = json["resets_at"] as? String {
            resets = parseISO(iso)
        }
        var nextSub: Date?
        if let iso = json["next_subscription_at"] as? String {
            nextSub = parseISO(iso)
        }
        let autoRenew = json["subscription_auto_renew"] as? Bool

        return GrokInfo(
            remainingPercent: remaining,
            resetsAt: resets,
            nextSubscriptionAt: nextSub,
            subscriptionAutoRenew: autoRenew,
            tokensToday: tokenStats.today,
            tokensMonth: tokenStats.month,
            email: email,
            fromCache: fromCache,
            error: nil
        )
    }

    private static func parseISO(_ iso: String) -> Date? {
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFrac.date(from: iso) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: iso)
    }
}

// MARK: - Local token usage (~/.grok/logs/unified.jsonl)

/// Sum of `prompt_tokens + completion_tokens` per `shell.turn.inference_done`
/// from Grok Build's local unified log (no network).
enum GrokTokenStats {
    private static var grokHome: URL {
        if let env = ProcessInfo.processInfo.environment["GROK_HOME"], !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath)
        }
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".grok")
    }

    private static var lastCollectAt: Date = .distantPast
    private static var lastResult: (today: Int, month: Int) = (0, 0)
    private static let softTTL: TimeInterval = 45
    /// Byte offset already counted in `lastResult` for the current day/month keys.
    private static var fileOffset: UInt64 = 0
    private static var fileSize: UInt64 = 0
    private static var cacheDayKey = ""
    private static var cacheMonthKey = ""

    static func collect() -> (today: Int, month: Int) {
        let now = Date()
        if now.timeIntervalSince(lastCollectAt) < softTTL, lastCollectAt != .distantPast {
            return lastResult
        }

        let logURL = grokHome.appendingPathComponent("logs/unified.jsonl")
        guard FileManager.default.fileExists(atPath: logURL.path) else {
            return (0, 0)
        }

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: now)
        var monthComps = cal.dateComponents([.year, .month], from: now)
        monthComps.day = 1
        let startOfMonth = cal.date(from: monthComps) ?? startOfDay
        let dayKey = String(format: "%04d-%02d-%02d",
                            cal.component(.year, from: now),
                            cal.component(.month, from: now),
                            cal.component(.day, from: now))
        let monthKey = String(format: "%04d-%02d",
                              cal.component(.year, from: now),
                              cal.component(.month, from: now))

        let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path)
        let size = UInt64((attrs?[.size] as? NSNumber)?.uint64Value ?? 0)

        // Day/month change or truncated log → full rescan
        if dayKey != cacheDayKey || monthKey != cacheMonthKey || size < fileOffset {
            fileOffset = 0
            lastResult = (0, 0)
            cacheDayKey = dayKey
            cacheMonthKey = monthKey
        }
        if size == fileSize, fileOffset >= size {
            lastCollectAt = now
            return lastResult
        }

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        isoPlain.formatOptions = [.withInternetDateTime]

        guard let handle = try? FileHandle(forReadingFrom: logURL) else {
            return lastResult
        }
        defer { try? handle.close() }
        if fileOffset > 0 {
            try? handle.seek(toOffset: fileOffset)
        }

        var today = lastResult.today
        var month = lastResult.month
        let marker = Data("shell.turn.inference_done".utf8)
        var leftover = Data()
        var consumed = fileOffset

        while true {
            let chunk = handle.readData(ofLength: 256 * 1024)
            if chunk.isEmpty && leftover.isEmpty { break }
            let data: Data = leftover.isEmpty ? chunk : {
                var d = leftover; d.append(chunk); return d
            }()
            leftover = Data()

            var start = data.startIndex
            while let nl = data[start...].firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = data[start..<nl]
                let lineLen = data.distance(from: start, to: nl)
                start = data.index(after: nl)
                consumed += UInt64(lineLen) + 1
                guard lineLen > 40, lineData.range(of: marker) != nil else { continue }

                guard let obj = try? JSONSerialization.jsonObject(with: Data(lineData)) as? [String: Any],
                      obj["msg"] as? String == "shell.turn.inference_done",
                      let ctx = obj["ctx"] as? [String: Any]
                else { continue }

                let total = intValue(ctx["prompt_tokens"]) + intValue(ctx["completion_tokens"])
                guard total > 0, let tsStr = obj["ts"] as? String else { continue }
                let ts = isoFrac.date(from: tsStr) ?? isoPlain.date(from: tsStr)
                guard let ts, ts >= startOfMonth else { continue }
                month += total
                if ts >= startOfDay { today += total }
            }
            if start < data.endIndex {
                leftover = Data(data[start...])
                if leftover.count > 1_000_000 {
                    consumed += UInt64(leftover.count)
                    leftover = Data()
                }
            }
            if chunk.isEmpty { break }
        }

        fileOffset = size - UInt64(leftover.count)
        fileSize = size
        lastResult = (today, month)
        lastCollectAt = now
        return lastResult
    }

    private static func intValue(_ any: Any?) -> Int {
        if let i = any as? Int { return i }
        if let n = any as? NSNumber { return n.intValue }
        if let d = any as? Double { return Int(d) }
        if let s = any as? String, let i = Int(s) { return i }
        return 0
    }
}

// MARK: - Busy detection (Grok Build turn in progress)

/// Detects active Grok Build turns across **all** sessions under `~/.grok/sessions`
/// (not only `active_sessions.json`, which often omits plan/subagent/other windows).
///
/// A session is busy when `events.jsonl` has a `turn_started` with no later
/// `turn_ended`, and the file was written recently (avoids stale crash leftovers).
enum GrokActivity {
    /// Only consider event logs touched within this window.
    private static let recentWindowSecs: TimeInterval = 20 * 60
    private static let busyPhases: Set<String> = [
        "streaming_reasoning",
        "streaming_text",
        "tool_execution",
        "permission_prompt",
        "waiting_for_model",
    ]

    private static var grokHome: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".grok")
    }

    static func isTaskRunning() -> Bool {
        !busySessionIds().isEmpty
    }

    /// Session IDs currently mid-turn (for menu / logging).
    static func busySessionIds() -> [String] {
        var busy: [String] = []
        for url in candidateEventFiles() {
            if turnInProgress(eventsURL: url) {
                busy.append(url.deletingLastPathComponent().lastPathComponent)
            }
        }
        return busy
    }

    /// Prefer recently-modified event logs; always include active_sessions targets.
    private static func candidateEventFiles() -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []

        func add(_ url: URL) {
            let path = url.path
            guard !seen.contains(path) else { return }
            guard FileManager.default.fileExists(atPath: path) else { return }
            seen.insert(path)
            result.append(url)
        }

        // 1) Everything listed as open (may be incomplete, but cheap)
        for session in listedActiveSessions() {
            if let url = eventsFile(sessionId: session.id, cwd: session.cwd) {
                add(url)
            }
        }

        // 2) All sessions with recent activity (covers plan mode / other windows)
        let root = grokHome.appendingPathComponent("sessions")
        let cutoff = Date().addingTimeInterval(-recentWindowSecs)
        if let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                guard url.lastPathComponent == "events.jsonl" else { continue }
                let values = try? url.resourceValues(forKeys: [
                    .contentModificationDateKey, .isRegularFileKey,
                ])
                guard values?.isRegularFile == true else { continue }
                if let mtime = values?.contentModificationDate, mtime >= cutoff {
                    add(url)
                }
            }
        }

        return result
    }

    private struct ListedSession {
        let id: String
        let cwd: String?
    }

    private static func listedActiveSessions() -> [ListedSession] {
        let path = grokHome.appendingPathComponent("active_sessions.json")
        guard
            let data = try? Data(contentsOf: path),
            let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            return []
        }
        var result: [ListedSession] = []
        for entry in arr {
            guard let id = entry["session_id"] as? String else { continue }
            if let pid = entry["pid"] as? Int, !processAlive(pid) {
                continue
            }
            result.append(ListedSession(id: id, cwd: entry["cwd"] as? String))
        }
        return result
    }

    private static func processAlive(_ pid: Int) -> Bool {
        kill(pid_t(pid), 0) == 0 || errno == EPERM
    }

    private static func turnInProgress(eventsURL: URL) -> Bool {
        // Stale open turns (crash without turn_ended): require recent writes
        let mtime = (try? eventsURL.resourceValues(forKeys: [.contentModificationDateKey]))
            .flatMap(\.contentModificationDate) ?? .distantPast
        let age = Date().timeIntervalSince(mtime)
        guard age <= recentWindowSecs else { return false }

        guard let tail = readTail(of: eventsURL, maxBytes: 128 * 1024) else {
            return false
        }

        var lastStart: String?
        var lastEnd: String?
        var lastPhase: String?
        var lastPhaseTs: String?

        for line in tail.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = obj["type"] as? String
            else { continue }
            let ts = obj["ts"] as? String ?? ""
            switch type {
            case "turn_started":
                lastStart = ts
            case "turn_ended":
                lastEnd = ts
            case "phase_changed":
                lastPhase = obj["phase"] as? String
                lastPhaseTs = ts
            default:
                break
            }
        }

        // Primary: open turn (start after end, or start with no end)
        if let start = lastStart {
            let open: Bool
            if let end = lastEnd {
                open = start > end
            } else {
                open = true
            }
            if open { return true }
        }

        // Fallback: very recent busy phase even if turn markers are missing/partial
        // (some modes emit phases more reliably than turn boundaries in the tail)
        if age <= 15, let phase = lastPhase, busyPhases.contains(phase) {
            // Only if phase is newer than last turn_ended (or no end seen)
            if let end = lastEnd, let pts = lastPhaseTs, pts <= end {
                return false
            }
            return true
        }

        return false
    }

    private static func eventsFile(sessionId: String, cwd: String?) -> URL? {
        let root = grokHome.appendingPathComponent("sessions")
        if let cwd {
            let encoded = percentEncodePath(cwd)
            let candidate = root
                .appendingPathComponent(encoded)
                .appendingPathComponent(sessionId)
                .appendingPathComponent("events.jsonl")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        guard
            let groups = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil
            )
        else { return nil }
        for group in groups where group.hasDirectoryPath {
            let candidate = group
                .appendingPathComponent(sessionId)
                .appendingPathComponent("events.jsonl")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    private static func percentEncodePath(_ path: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
    }

    private static func readTail(of url: URL, maxBytes: Int) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let size: UInt64
        do {
            size = try handle.seekToEnd()
        } catch {
            return nil
        }
        let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        do {
            try handle.seek(toOffset: start)
            guard let data = try handle.readToEnd() else { return nil }
            guard var text = String(data: data, encoding: .utf8) else { return nil }
            if start > 0, let nl = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: nl)...])
            }
            return text
        } catch {
            return nil
        }
    }
}


// MARK: - Models

struct CodexInfo {
    var remainingPercent: Double?
    var usedPercent: Double?
    var resetsAt: Date?
    var windowLabel: String?
    var secondaryRemaining: Double?
    var secondaryResetsAt: Date?
    var secondaryWindowLabel: String?
    var creditsBalance: String?
    /// Banked rate-limit reset credits (`available_count` from usage API).
    /// This is the number Codex UI shows as "N available resets".
    var resetCreditsAvailable: Int?
    var nextSubscriptionAt: Date?
    var subscriptionAutoRenew: Bool?
    /// Local log-based token totals (per-call last_token_usage by event time).
    var tokensToday: Int?
    var tokensMonth: Int?
    var planType: String?
    var email: String?
    var fromCache: Bool
    var error: String?

    var resetCreditsText: String {
        guard let n = resetCreditsAvailable else { return "—" }
        return "\(n) 次"
    }

    /// Chinese units: 万 / 亿 (e.g. 10万、312万、1.4亿)
    static func formatTokens(_ n: Int?) -> String {
        guard let n else { return "—" }
        if n < 0 { return "—" }
        if n < 10_000 {
            // 不足 1 万：用千分位，如 3,122
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.locale = Locale(identifier: "zh_CN")
            return f.string(from: NSNumber(value: n)) ?? "\(n)"
        }
        if n < 100_000_000 {
            // 1 万～1 亿：以「万」为单位
            let wan = Double(n) / 10_000.0
            if wan >= 100 {
                // 100万及以上：整数万更清晰（100万、312万）
                return "\(Int(wan.rounded()))万"
            }
            if wan == floor(wan) {
                return "\(Int(wan))万"
            }
            // 10.5万 这类保留一位
            return String(format: "%.1f万", wan).replacingOccurrences(of: ".0万", with: "万")
        }
        // ≥ 1 亿：100 亿以下保留一位小数（18.7亿、30.1亿），避免 18.69→19 的误导
        let yi = Double(n) / 100_000_000.0
        if yi >= 100 {
            return "\(Int(yi.rounded()))亿"
        }
        if yi == floor(yi) {
            return "\(Int(yi))亿"
        }
        return String(format: "%.1f亿", yi).replacingOccurrences(of: ".0亿", with: "亿")
    }

    var tokensTodayText: String { Self.formatTokens(tokensToday) }
    var tokensMonthText: String { Self.formatTokens(tokensMonth) }

    var nextSubscriptionText: String {
        guard let d = nextSubscriptionAt else { return "—" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        let cal = Calendar.current
        if cal.component(.year, from: d) == cal.component(.year, from: Date()) {
            f.dateFormat = "M月d日"
        } else {
            f.dateFormat = "yyyy年M月d日"
        }
        return f.string(from: d)
    }

    var nextSubscriptionMenuTitle: String {
        guard nextSubscriptionAt != nil else { return "下次订阅: —" }
        if subscriptionAutoRenew == false {
            return "订阅到期: \(nextSubscriptionText)"
        }
        return "下次订阅: \(nextSubscriptionText)"
    }

    var remainingText: String {
        if let p = remainingPercent {
            let s = String(format: "%.0f", p)
            return "\(s)%"
        }
        return "—"
    }

    var resetText: String {
        guard let d = resetsAt else { return "未知" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: d)
    }

    var secondaryResetText: String {
        guard let d = secondaryResetsAt else { return "—" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: d)
    }

    var menuBarTitle: String {
        remainingPercent == nil ? "?" : remainingText
    }
}

// MARK: - C monogram icon

/// Monoline circle + C (orange accent, matches product mock). Images cached for low RAM.


// MARK: - Usage API

enum CodexFetcher {
    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private static let accountsURL = URL(
        string: "https://chatgpt.com/backend-api/accounts/check/v4-2023-04-27"
    )!
    private static let cacheTTL: TimeInterval = 100
    private static var cache: (date: Date, info: CodexInfo)?

    private static var codexHome: URL {
        if let env = ProcessInfo.processInfo.environment["CODEX_HOME"], !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath)
        }
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex")
    }

    static func fetch(forceLive: Bool) -> CodexInfo {
        if !forceLive, let cached = cache, Date().timeIntervalSince(cached.date) < cacheTTL {
            var info = cached.info
            info.fromCache = true
            return info
        }
        do {
            let info = try fetchLive()
            cache = (Date(), info)
            return info
        } catch {
            if let cached = cache {
                var info = cached.info
                info.fromCache = true
                info.error = error.localizedDescription
                return info
            }
            return CodexInfo(
                remainingPercent: nil, usedPercent: nil, resetsAt: nil,
                windowLabel: nil, secondaryRemaining: nil, secondaryResetsAt: nil,
                secondaryWindowLabel: nil, creditsBalance: nil,
                resetCreditsAvailable: nil, nextSubscriptionAt: nil,
                subscriptionAutoRenew: nil, tokensToday: nil, tokensMonth: nil,
                planType: nil, email: nil, fromCache: false,
                error: error.localizedDescription
            )
        }
    }

    private static func fetchLive() throws -> CodexInfo {
        let authPath = codexHome.appendingPathComponent("auth.json")
        guard let data = try? Data(contentsOf: authPath),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = root["tokens"] as? [String: Any],
              let access = tokens["access_token"] as? String, !access.isEmpty
        else {
            throw NSError(
                domain: "CodexCredits", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "未找到 Codex 登录态，请先登录 Codex / ChatGPT"]
            )
        }
        let accountId = tokens["account_id"] as? String ?? ""

        let usageJSON = try httpJSON(
            url: usageURL, access: access, accountId: accountId, accept: "application/json"
        )
        var info = parseUsage(usageJSON)

        // Subscription renewal day (optional — don't fail usage if this endpoint errs)
        if let accountsJSON = try? httpJSON(
            url: accountsURL,
            access: access,
            accountId: accountId,
            accept: "*/*",
            referer: "https://chatgpt.com/codex"
        ) {
            let sub = parseSubscription(accountsJSON, accountId: accountId)
            info.nextSubscriptionAt = sub.date
            info.subscriptionAutoRenew = sub.autoRenew
        }

        // Local token totals from Codex logs (no network)
        let tokenStats = CodexTokenStats.collect()
        info.tokensToday = tokenStats.today
        info.tokensMonth = tokenStats.month

        return info
    }

    private static func httpJSON(
        url: URL,
        access: String,
        accountId: String,
        accept: String,
        referer: String? = nil
    ) throws -> [String: Any] {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
        request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        request.setValue("CodexCreditsMenuBar/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        if let referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
            request.setValue("https://chatgpt.com", forHTTPHeaderField: "Origin")
        }

        let sem = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultError: Error?
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error { resultError = error }
            else if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                resultError = NSError(
                    domain: "CodexCredits", code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body.prefix(120))"]
                )
            } else {
                resultData = data
            }
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 16)

        if let resultError { throw resultError }
        guard let resultData,
              let json = try JSONSerialization.jsonObject(with: resultData) as? [String: Any]
        else {
            throw NSError(
                domain: "CodexCredits", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "接口响应无效"]
            )
        }
        return json
    }

    private static func parseSubscription(
        _ json: [String: Any], accountId: String
    ) -> (date: Date?, autoRenew: Bool?) {
        guard let accounts = json["accounts"] as? [String: Any] else {
            return (nil, nil)
        }
        let entry = (accounts[accountId] as? [String: Any])
            ?? (accounts["default"] as? [String: Any])
        guard let entitlement = entry?["entitlement"] as? [String: Any] else {
            return (nil, nil)
        }
        // Prefer renews_at (next billing), fall back to expires_at
        let dateISO = (entitlement["renews_at"] as? String)
            ?? (entitlement["expires_at"] as? String)
        let date = dateISO.flatMap { parseFlexibleISO($0) }

        var autoRenew: Bool? = nil
        if entitlement["cancels_at"] is NSNull || entitlement["cancels_at"] == nil {
            if let last = entry?["last_active_subscription"] as? [String: Any],
               let will = last["will_renew"] as? Bool {
                autoRenew = will
            } else {
                autoRenew = true
            }
        } else {
            autoRenew = false
        }
        return (date, autoRenew)
    }

    private static func parseFlexibleISO(_ iso: String) -> Date? {
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFrac.date(from: iso) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: iso) { return d }
        // Some timestamps include +00:00 without fractional seconds already covered
        return plain.date(from: iso.replacingOccurrences(of: "Z", with: "+00:00"))
    }

    private static func parseUsage(_ json: [String: Any]) -> CodexInfo {
        let rate = json["rate_limit"] as? [String: Any] ?? [:]
        let primary = rate["primary_window"] as? [String: Any]
        let secondary = rate["secondary_window"] as? [String: Any]
        let credits = json["credits"] as? [String: Any]

        // Prefer the tighter remaining of primary/secondary for the menu-bar number
        let pUsed = primary?["used_percent"] as? Double
            ?? (primary?["used_percent"] as? Int).map(Double.init)
        let sUsed = secondary?["used_percent"] as? Double
            ?? (secondary?["used_percent"] as? Int).map(Double.init)

        let pRem = pUsed.map { max(0, min(100, 100 - $0)) }
        let sRem = sUsed.map { max(0, min(100, 100 - $0)) }

        // Menu bar shows primary; if secondary exists and is lower remaining, prefer secondary
        // (5h window is usually the one you care about first when present).
        let useSecondaryAsMain: Bool = {
            guard let sRem, let pRem else { return secondary != nil && primary == nil }
            return sRem < pRem
        }()

        let mainUsed = useSecondaryAsMain ? sUsed : pUsed
        let mainRem = useSecondaryAsMain ? sRem : pRem
        let mainWin = useSecondaryAsMain ? secondary : primary
        let otherWin = useSecondaryAsMain ? primary : secondary
        let otherRem = useSecondaryAsMain ? pRem : sRem

        let mainReset = parseReset(mainWin)
        let otherReset = parseReset(otherWin)

        var balance: String?
        if let bal = credits?["balance"] as? String {
            if let d = Double(bal) {
                balance = String(format: "%.0f", d)
            } else {
                balance = bal
            }
        } else if let bal = credits?["balance"] as? Double {
            balance = String(format: "%.0f", bal)
        }

        // Official Codex UI uses available_count as "N available resets".
        // applicable_available_count is a separate product flag (often 0 when not
        // at limit) and must NOT be shown as "cannot use now".
        let resetPack = json["rate_limit_reset_credits"] as? [String: Any]
        let resetAvail = intAny(resetPack?["available_count"])

        return CodexInfo(
            remainingPercent: mainRem,
            usedPercent: mainUsed,
            resetsAt: mainReset,
            windowLabel: windowLabel(seconds: intField(mainWin, "limit_window_seconds")),
            secondaryRemaining: otherRem,
            secondaryResetsAt: otherReset,
            secondaryWindowLabel: windowLabel(seconds: intField(otherWin, "limit_window_seconds")),
            creditsBalance: balance,
            resetCreditsAvailable: resetAvail,
            nextSubscriptionAt: nil,
            subscriptionAutoRenew: nil,
            tokensToday: nil,
            tokensMonth: nil,
            planType: json["plan_type"] as? String,
            email: json["email"] as? String,
            fromCache: false,
            error: nil
        )
    }

    private static func intAny(_ value: Any?) -> Int? {
        if let v = value as? Int { return v }
        if let v = value as? Double { return Int(v) }
        if let v = value as? String, let n = Int(v) { return n }
        return nil
    }

    private static func intField(_ window: [String: Any]?, _ key: String) -> Int? {
        guard let window else { return nil }
        if let v = window[key] as? Int { return v }
        if let v = window[key] as? Double { return Int(v) }
        return nil
    }

    private static func parseReset(_ window: [String: Any]?) -> Date? {
        guard let window else { return nil }
        if let resetAt = window["reset_at"] as? Double {
            return Date(timeIntervalSince1970: resetAt)
        }
        if let resetAt = window["reset_at"] as? Int {
            return Date(timeIntervalSince1970: TimeInterval(resetAt))
        }
        if let after = window["reset_after_seconds"] as? Double {
            return Date().addingTimeInterval(after)
        }
        if let after = window["reset_after_seconds"] as? Int {
            return Date().addingTimeInterval(TimeInterval(after))
        }
        return nil
    }

    private static func windowLabel(seconds: Int?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        if seconds == 5 * 3600 { return "5 小时" }
        if seconds == 7 * 24 * 3600 { return "1 周" }
        if seconds % 86400 == 0 { return "\(seconds / 86400) 天" }
        if seconds % 3600 == 0 { return "\(seconds / 3600) 小时" }
        return "\(seconds)s"
    }
}

// MARK: - Local token usage (session rollouts)

/// Precise 今日 / 本月 token totals from Codex session rollouts.
///
/// Scanning multi‑GB rollouts in-process fragmented malloc and ballooned RSS
/// past 1GB. Counting is delegated to a short-lived Python helper
/// (`codex/scripts/codex-usage-stats`) that:
/// - streams files with tiny buffers
/// - keeps an on-disk offset cache under ~/Library/Caches/CodexCreditsMenuBar/
/// - exits so all scan memory is reclaimed
///
/// Metric: sum of `last_token_usage.total_tokens` per `token_count` event,
/// attributed by event timestamp.
enum CodexTokenStats {
    private static var lastCollectAt: Date = .distantPast
    private static var lastResult: (today: Int, month: Int) = (0, 0)
    private static let softTTL: TimeInterval = 45

    private static var helperPath: String? {
        if let env = ProcessInfo.processInfo.environment["CODEX_USAGE_STATS_BIN"], !env.isEmpty {
            let p = (env as NSString).expandingTildeInPath
            if FileManager.default.isReadableFile(atPath: p) { return p }
        }
        let home = NSHomeDirectory() as NSString
        let paths = [
            // Bundled next to the app (preferred)
            Bundle.main.bundlePath + "/Contents/Resources/codex-usage-stats",
            home.appendingPathComponent(".local/bin/codex-usage-stats"),
            home.appendingPathComponent("Documents/Ai-credits-menubar/codex/scripts/codex-usage-stats"),
            (FileManager.default.currentDirectoryPath as NSString)
                .appendingPathComponent("codex/scripts/codex-usage-stats"),
        ]
        for p in paths where FileManager.default.isReadableFile(atPath: p) {
            return p
        }
        return nil
    }

    static func collect() -> (today: Int, month: Int) {
        let now = Date()
        if now.timeIntervalSince(lastCollectAt) < softTTL, lastCollectAt != .distantPast {
            return lastResult
        }
        guard let script = helperPath else {
            return lastResult
        }

        let proc = Process()
        // Prefer python3 shebang execution; fall back to explicit interpreter.
        if FileManager.default.isExecutableFile(atPath: script) {
            proc.executableURL = URL(fileURLWithPath: script)
            proc.arguments = []
        } else {
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            proc.arguments = [script]
        }
        proc.environment = ProcessInfo.processInfo.environment.merging([
            "HOME": NSHomeDirectory(),
            "CODEX_HOME": (NSHomeDirectory() as NSString).appendingPathComponent(".codex"),
            "PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin",
        ]) { _, new in new }

        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        do {
            try proc.run()
        } catch {
            return lastResult
        }
        // Hard cap so a stuck helper never freezes credit refresh forever.
        let deadline = Date().addingTimeInterval(20)
        while proc.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if proc.isRunning {
            proc.terminate()
            return lastResult
        }
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return lastResult }

        let data = out.fileHandleForReading.readDataToEndOfFile()
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return lastResult }

        let today: Int = {
            if let i = json["today"] as? Int { return i }
            if let n = json["today"] as? NSNumber { return n.intValue }
            return 0
        }()
        let month: Int = {
            if let i = json["month"] as? Int { return i }
            if let n = json["month"] as? NSNumber { return n.intValue }
            return 0
        }()

        lastResult = (max(0, today), max(0, month))
        lastCollectAt = now
        return lastResult
    }
}

// MARK: - Busy detection via ~/.codex/logs_2.sqlite

/// Detect active **user turns**.
///
/// When the user stops a turn, Codex logs `op.dispatch.interrupt` /
/// `turn/interrupt`. Any activity older than the latest interrupt is ignored.
///
/// Busy when there is recent user-turn activity **after** the latest interrupt
/// (or no interrupt yet), within a short grace window.
enum CodexActivity {
    /// Quiet window after last user-turn log before showing idle (covers tool gaps).
    private static let activityGraceSecs: TimeInterval = 35
    private static let scanLookbackSecs: TimeInterval = 10 * 60

    private static var codexHome: URL {
        if let env = ProcessInfo.processInfo.environment["CODEX_HOME"], !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath)
        }
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex")
    }

    static func isTaskRunning() -> Bool {
        let logs = codexHome.appendingPathComponent("logs_2.sqlite")
        guard FileManager.default.fileExists(atPath: logs.path) else {
            return false
        }
        let now = Int(Date().timeIntervalSince1970)
        let lookback = now - Int(scanLookbackSecs)
        let graceCutoff = now - Int(activityGraceSecs)

        // Col1: latest user-turn activity
        // Col2: latest interrupt / stop
        // Col3: latest needs_follow_up body (session turn only)
        // Col4: timestamp of that needs_follow_up row
        let sql = """
        SELECT
          (SELECT MAX(ts) FROM logs
           WHERE ts >= \(lookback)
             AND feedback_log_body LIKE '%session_loop%'
             AND feedback_log_body LIKE '%submission_dispatch%'
             AND feedback_log_body LIKE '%op.dispatch.user_input%'
             AND feedback_log_body NOT LIKE '%startup_prewarm%'
             AND feedback_log_body NOT LIKE '%thread_spawn%'
             AND feedback_log_body NOT LIKE '%op.dispatch.interrupt%'
             AND feedback_log_body NOT LIKE '%list_models%'
             AND feedback_log_body NOT LIKE '%account/read%'
             AND feedback_log_body NOT LIKE '%app/list%'
             AND feedback_log_body NOT LIKE '%getAuthStatus%'
             AND feedback_log_body NOT LIKE '%fs/changed%'
          ),
          (SELECT MAX(ts) FROM logs
           WHERE ts >= \(lookback)
             AND (
               feedback_log_body LIKE '%op.dispatch.interrupt%'
               OR feedback_log_body LIKE '%codex.op="interrupt"%'
               OR feedback_log_body LIKE '%turn/interrupt%'
               OR feedback_log_body LIKE '%op: Interrupt%'
             )
          ),
          (SELECT feedback_log_body FROM logs
           WHERE ts >= \(lookback)
             AND feedback_log_body LIKE '%needs_follow_up=%'
             AND feedback_log_body LIKE '%session_loop%'
             AND feedback_log_body LIKE '%op.dispatch.user_input%'
             AND feedback_log_body NOT LIKE '%startup_prewarm%'
           ORDER BY ts DESC LIMIT 1
          ),
          (SELECT ts FROM logs
           WHERE ts >= \(lookback)
             AND feedback_log_body LIKE '%needs_follow_up=%'
             AND feedback_log_body LIKE '%session_loop%'
             AND feedback_log_body LIKE '%op.dispatch.user_input%'
             AND feedback_log_body NOT LIKE '%startup_prewarm%'
           ORDER BY ts DESC LIMIT 1
          );
        """

        guard let row = runSqlite(db: logs.path, sql: sql) else {
            return false
        }
        let parts = row.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        let maxUserTs = Int(parts.count > 0 ? parts[0] : "") ?? 0
        let maxInterruptTs = Int(parts.count > 1 ? parts[1] : "") ?? 0
        let followBody = parts.count > 2 ? parts[2] : ""
        let followTs = Int(parts.count > 3 ? parts[3] : "") ?? 0

        // User stopped: interrupt is the latest signal → idle immediately
        if maxInterruptTs > 0, maxInterruptTs >= maxUserTs {
            return false
        }

        // Recent user-turn activity after any older interrupt
        if maxUserTs >= graceCutoff, maxUserTs > maxInterruptTs {
            return true
        }

        // Open multi-step turn only if still "true" AND after interrupt AND still fresh
        if followTs >= graceCutoff,
           followTs > maxInterruptTs,
           followBody.contains("needs_follow_up=true") {
            return true
        }

        return false
    }

    private static func runSqlite(db: String, sql: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        proc.arguments = ["-separator", "|", db, sql]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return nil
        }
        guard proc.terminationStatus == 0 else { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
}

// MARK: - App

