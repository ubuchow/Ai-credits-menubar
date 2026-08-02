import AppKit
import AVFoundation
import Foundation

/// Native menu bar app: remaining Grok Build credits + reset time.
/// Shells out to ~/.grok/bin/grok-credits --json

/// Percentage text in the menu bar uses Times New Roman.
enum MenuBarPercentFont {
    static func font(size: CGFloat = 12) -> NSFont {
        let names = [
            "Times New Roman",
            "TimesNewRomanPSMT",
            "TimesNewRomanPS-BoldMT",
            "Times",
        ]
        for name in names {
            if let f = NSFont(name: name, size: size) {
                return f
            }
        }
        return NSFont.systemFont(ofSize: size)
    }
}

struct CreditsInfo {
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
enum MenuBarGMark {
    private static var cache: [String: NSImage] = [:]
    // Deeper blue so it reads clearly on both light and dark menu bars
    private static let accent = NSColor(calibratedRed: 0.18, green: 0.42, blue: 0.92, alpha: 1)
    private static let warn = NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.20, alpha: 1)

    /// - showLetter: false draws only the ring (blink-off; ring stays put).
    static func image(
        pointSize: CGFloat = 16,
        lowWarning: Bool = false,
        showLetter: Bool = true
    ) -> NSImage {
        let key = "\(Int(pointSize * 10))-\(lowWarning)-\(showLetter)"
        if let hit = cache[key] { return hit }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let img = rasterized(
            pointSize: pointSize, scale: scale, lowWarning: lowWarning, showLetter: showLetter
        )
        cache[key] = img
        return img
    }

    private static func rasterized(
        pointSize: CGFloat,
        scale: CGFloat,
        lowWarning: Bool,
        showLetter: Bool
    ) -> NSImage {
        let px = Int(ceil(pointSize * scale))
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: px,
            pixelsHigh: px,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = NSSize(width: pointSize, height: pointSize)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let rect = NSRect(x: 0, y: 0, width: pointSize, height: pointSize)
        NSColor.clear.setFill()
        rect.fill()
        drawMonogram(in: rect, lowWarning: lowWarning, showLetter: showLetter)
        NSGraphicsContext.restoreGraphicsState()

        let img = NSImage(size: NSSize(width: pointSize, height: pointSize))
        img.addRepresentation(rep)
        img.isTemplate = false // keep blue accent
        img.cacheMode = .always
        return img
    }

    private static func drawMonogram(in rect: NSRect, lowWarning: Bool, showLetter: Bool) {
        let ink = lowWarning ? warn : accent
        // Slight inset for clean monoline ring
        let pad = rect.insetBy(dx: 1.0, dy: 1.0)
        let ring = NSBezierPath(ovalIn: pad)
        ink.setStroke()
        ring.lineWidth = max(1.35, pad.width * 0.085)
        ring.lineCapStyle = .round
        ring.stroke()

        guard showLetter else { return }

        let fontSize = pad.height * 0.58
        let font = bestGFont(size: fontSize)
        let g = "G" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: ink,
        ]
        let gSize = g.size(withAttributes: attrs)
        let origin = NSPoint(
            x: pad.midX - gSize.width * 0.50 - pad.width * 0.01,
            y: pad.midY - gSize.height * 0.50 + pad.height * 0.02
        )
        g.draw(at: origin, withAttributes: attrs)
    }

    private static func bestGFont(size: CGFloat) -> NSFont {
        // Times New Roman Bold (same family as percentage text)
        let candidates = [
            "TimesNewRomanPS-BoldMT",
            "Times New Roman Bold",
            "Times-Bold",
            "TimesNewRomanPSMT",
            "Times New Roman",
        ]
        for name in candidates {
            if let f = NSFont(name: name, size: size) { return f }
        }
        return NSFont.systemFont(ofSize: size, weight: .bold)
    }
}

enum CreditsFetcher {
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

    static func fetch(forceLive: Bool) -> CreditsInfo {
        // Local token totals — independent of network / credits helper
        let tokenStats = TokenUsageStats.collect()

        guard let bin = grokCreditsPath else {
            return CreditsInfo(
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
            return CreditsInfo(
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
            return CreditsInfo(
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
            return CreditsInfo(
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

        return CreditsInfo(
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
enum TokenUsageStats {
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
enum ActivityDetector {
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

// MARK: - Task sound effects

/// Loop countdown while a turn is active; play end chime when it finishes.
/// Toggle via menu; preference stored in UserDefaults (default: on).
enum TaskSounds {
    private static let defaultsKey = "GrokCredits.soundEffectsEnabled"
    private static var runningPlayer: AVAudioPlayer?
    private static var endedPlayer: AVAudioPlayer?

    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: defaultsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: defaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
            if !newValue {
                stopRunning()
            }
        }
    }

    private static func resourceURL(_ name: String) -> URL? {
        if let u = Bundle.main.url(forResource: name, withExtension: "wav") {
            return u
        }
        // Fallback: Resources next to executable (dev / odd bundle layouts)
        let res = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/\(name).wav")
        return FileManager.default.fileExists(atPath: res.path) ? res : nil
    }

    /// Start or restart looping "task running" sound.
    static func startRunning() {
        guard isEnabled else { return }
        if let p = runningPlayer, p.isPlaying { return }
        stopRunning()
        endedPlayer?.stop()
        endedPlayer = nil
        guard let url = resourceURL("task-running") else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 1.0
            p.prepareToPlay()
            p.play()
            runningPlayer = p
        } catch {
            // Audio is optional; ignore load failures.
        }
    }

    static func stopRunning() {
        runningPlayer?.stop()
        runningPlayer = nil
    }

    /// Stop loop (if any) and play one-shot end sound.
    static func playEnded() {
        stopRunning()
        guard isEnabled else { return }
        endedPlayer?.stop()
        endedPlayer = nil
        guard let url = resourceURL("task-ended") else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = 0
            p.volume = 1.0
            p.prepareToPlay()
            p.play()
            endedPlayer = p
        } catch {
            // ignore
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var remainingItem: NSMenuItem!
    private var resetItem: NSMenuItem!
    private var subscriptionItem: NSMenuItem!
    private var tokensTodayItem: NSMenuItem!
    private var tokensMonthItem: NSMenuItem!
    private var detailItem: NSMenuItem!
    private var activityItem: NSMenuItem!
    private var soundItem: NSMenuItem!
    private var creditsTimer: Timer?
    private var activityTimer: Timer?
    private var blinkTimer: Timer?
    private var lastInfo = CreditsInfo(
        remainingPercent: nil, resetsAt: nil, nextSubscriptionAt: nil,
        subscriptionAutoRenew: nil, tokensToday: nil, tokensMonth: nil,
        email: nil, fromCache: false, error: nil
    )
    private var isTaskRunning = false
    private var blinkLit = true

    private func log(_ msg: String) {
        let dir = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Logs/GrokCreditsMenuBar")
        let path = (dir as NSString).appendingPathComponent("app.log")
        try? FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true
        )
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(msg)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: path) {
                if let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                    defer { try? h.close() }
                    h.seekToEndOfFile()
                    h.write(data)
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }
        fputs(line, stderr)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("applicationDidFinishLaunching bundle=\(Bundle.main.bundlePath)")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true

        if let button = statusItem.button {
            button.image = MenuBarGMark.image()
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
            button.title = "…"
            button.font = MenuBarPercentFont.font()
            button.toolTip = "Grok Build 用量"
            button.appearsDisabled = false
            // Tighten spacing between icon and percent
            button.setButtonType(.momentaryLight)
            log("status button configured title=\(button.title) image=\(button.image != nil)")
        } else {
            log("ERROR: statusItem.button is nil")
        }

        let menu = NSMenu()
        menu.autoenablesItems = false

        remainingItem = NSMenuItem(title: "余量: …", action: nil, keyEquivalent: "")
        remainingItem.isEnabled = false
        menu.addItem(remainingItem)

        resetItem = NSMenuItem(title: "重置: …", action: nil, keyEquivalent: "")
        resetItem.isEnabled = false
        menu.addItem(resetItem)

        subscriptionItem = NSMenuItem(title: "下次订阅: …", action: nil, keyEquivalent: "")
        subscriptionItem.isEnabled = false
        menu.addItem(subscriptionItem)

        tokensTodayItem = NSMenuItem(title: "今日 Token: —", action: nil, keyEquivalent: "")
        tokensTodayItem.isEnabled = false
        menu.addItem(tokensTodayItem)

        tokensMonthItem = NSMenuItem(title: "本月 Token: —", action: nil, keyEquivalent: "")
        tokensMonthItem.isEnabled = false
        menu.addItem(tokensMonthItem)

        detailItem = NSMenuItem(title: "更新: …", action: nil, keyEquivalent: "")
        detailItem.isEnabled = false
        menu.addItem(detailItem)

        activityItem = NSMenuItem(title: "任务: 空闲", action: nil, keyEquivalent: "")
        activityItem.isEnabled = false
        menu.addItem(activityItem)

        menu.addItem(.separator())

        let refresh = NSMenuItem(
            title: "立即刷新",
            action: #selector(refreshClicked),
            keyEquivalent: "r"
        )
        refresh.target = self
        menu.addItem(refresh)

        let openUsage = NSMenuItem(
            title: "在浏览器打开用量页",
            action: #selector(openUsage),
            keyEquivalent: ""
        )
        openUsage.target = self
        menu.addItem(openUsage)

        soundItem = NSMenuItem(
            title: TaskSounds.isEnabled ? "关闭音效" : "开启音效",
            action: #selector(toggleSound),
            keyEquivalent: ""
        )
        soundItem.target = self
        menu.addItem(soundItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "退出",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        statusItem.menu = menu
        log("menu attached isVisible=\(statusItem.isVisible)")

        refreshCredits(forceLive: true)
        pollActivity()

        // Usage: every 2 minutes (low CPU/RAM/network). Menu "立即刷新" for on-demand.
        creditsTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.refreshCredits(forceLive: false)
        }
        // Activity: 2s is enough for blink UX; avoids thrashing disk/process every second
        activityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollActivity()
        }
        // Blink only while busy (timer still fires but tickBlink returns immediately when idle)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tickBlink()
        }
        for t in [creditsTimer, activityTimer, blinkTimer].compactMap({ $0 }) {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    @objc private func refreshClicked() {
        refreshCredits(forceLive: true)
    }

    @objc private func openUsage() {
        if let url = URL(string: "https://grok.com/?_s=usage") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleSound() {
        TaskSounds.isEnabled.toggle()
        soundItem.title = TaskSounds.isEnabled ? "关闭音效" : "开启音效"
        if TaskSounds.isEnabled {
            if isTaskRunning {
                TaskSounds.startRunning()
            }
            log("sound enabled")
        } else {
            TaskSounds.stopRunning()
            log("sound disabled")
        }
    }

    private func refreshCredits(forceLive: Bool) {
        // Fetch off main thread; apply UI on main
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let info = CreditsFetcher.fetch(forceLive: forceLive)
            DispatchQueue.main.async {
                self?.apply(info)
            }
        }
    }

    private func pollActivity() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let ids = ActivityDetector.busySessionIds()
            DispatchQueue.main.async {
                self?.setTaskRunning(!ids.isEmpty, sessionIds: ids)
            }
        }
    }

    private func setTaskRunning(_ running: Bool, sessionIds: [String] = []) {
        let changed = running != isTaskRunning
        isTaskRunning = running
        if running {
            let n = sessionIds.count
            activityItem.title = n > 1 ? "任务: 运行中 ● (\(n))" : "任务: 运行中 ●"
        } else {
            activityItem.title = "任务: 空闲"
            blinkLit = true
        }
        if changed {
            if running {
                let short = sessionIds.map { String($0.prefix(8)) }.joined(separator: ",")
                log("task started — G blink sessions=[\(short)]")
                TaskSounds.startRunning()
            } else {
                log("task ended — G solid")
                TaskSounds.playEnded()
            }
        }
        updateStatusAppearance()
    }

    private func tickBlink() {
        guard isTaskRunning else { return }
        blinkLit.toggle()
        updateStatusAppearance()
    }

    private func apply(_ info: CreditsInfo) {
        // Token stats always come from local logs (independent of billing API).
        var merged = info
        merged.tokensToday = info.tokensToday ?? lastInfo.tokensToday
        merged.tokensMonth = info.tokensMonth ?? lastInfo.tokensMonth

        // Keep last good remaining % when live billing fails — never stick on '?' if we
        // previously had a successful fetch in this process.
        if merged.remainingPercent == nil, let prev = lastInfo.remainingPercent {
            merged.remainingPercent = prev
            merged.resetsAt = merged.resetsAt ?? lastInfo.resetsAt
            merged.nextSubscriptionAt = merged.nextSubscriptionAt ?? lastInfo.nextSubscriptionAt
            merged.subscriptionAutoRenew = merged.subscriptionAutoRenew ?? lastInfo.subscriptionAutoRenew
            merged.email = merged.email ?? lastInfo.email
            merged.fromCache = true
        }

        lastInfo = merged

        tokensTodayItem.title = "今日 Token: \(merged.tokensTodayText)"
        tokensMonthItem.title = "本月 Token: \(merged.tokensMonthText)"

        if let err = merged.error, merged.remainingPercent == nil {
            remainingItem.title = "余量: 获取失败"
            resetItem.title = "重置: —"
            subscriptionItem.title = "下次订阅: —"
            detailItem.title = "错误: \(String(err.prefix(40)))"
            log("fetch error: \(err) tokens_today=\(merged.tokensTodayText) tokens_month=\(merged.tokensMonthText)")
        } else {
            remainingItem.title = "余量: \(merged.remainingText)"
            resetItem.title = "重置: \(merged.resetText)"
            subscriptionItem.title = merged.nextSubscriptionMenuTitle
            let now = DateFormatter()
            now.dateFormat = "HH:mm:ss"
            let cache = merged.fromCache ? "缓存" : "实时"
            let warn = merged.error != nil ? " · 警告" : ""
            detailItem.title = "更新: \(now.string(from: Date())) (\(cache))\(warn)"
            if let err = merged.error {
                log("fetch warning (kept last remaining): \(err) remaining=\(merged.remainingText)")
            } else {
                log(
                    "updated remaining=\(merged.remainingText) reset=\(merged.resetText) sub=\(merged.nextSubscriptionText) tokens_today=\(merged.tokensTodayText) tokens_month=\(merged.tokensMonthText)"
                )
            }
        }
        updateStatusAppearance()
    }

    /// Refresh menu bar title + G icon (solid or blinking).
    private func updateStatusAppearance() {
        guard let button = statusItem.button else { return }
        let info = lastInfo
        let low = (info.remainingPercent ?? 100) <= 10 && info.remainingPercent != nil

        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.title = info.menuBarTitle
        button.font = MenuBarPercentFont.font()
        statusItem.isVisible = true

        // Blink only the letter G; ring + percent stay fixed
        let showG = !isTaskRunning || blinkLit
        button.image = MenuBarGMark.image(lowWarning: low, showLetter: showG)

        var tip = "Grok 余量 \(info.remainingText) · 重置 \(info.resetText)"
        if isTaskRunning {
            tip = "● 任务进行中\n" + tip
        }
        if let email = info.email, !email.isEmpty {
            tip = "\(email)\n\(tip)"
        }
        if let err = info.error {
            tip = "获取失败: \(err)"
        }
        button.toolTip = tip
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
