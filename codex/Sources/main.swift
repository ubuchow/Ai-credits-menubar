import AppKit
import AVFoundation
import Foundation

/// Native menu bar app for OpenAI Codex:
/// - remaining quota % + reset time
/// - circle "C" monogram (letter blinks while a Codex task is running)

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

// MARK: - Models

struct CreditsInfo {
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
enum MenuBarCMark {
    private static var cache: [String: NSImage] = [:]
    // Deeper orange so it reads clearly on the menu bar
    private static let accent = NSColor(calibratedRed: 0.88, green: 0.40, blue: 0.08, alpha: 1)
    private static let warn = NSColor(calibratedRed: 0.95, green: 0.35, blue: 0.18, alpha: 1)

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
        img.isTemplate = false // keep orange accent
        img.cacheMode = .always
        return img
    }

    private static func drawMonogram(in rect: NSRect, lowWarning: Bool, showLetter: Bool) {
        let ink = lowWarning ? warn : accent
        let pad = rect.insetBy(dx: 1.0, dy: 1.0)
        let ring = NSBezierPath(ovalIn: pad)
        ink.setStroke()
        ring.lineWidth = max(1.35, pad.width * 0.085)
        ring.lineCapStyle = .round
        ring.stroke()

        guard showLetter else { return }

        let fontSize = pad.height * 0.58
        let font = bestCFont(size: fontSize)
        let letter = "C" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: ink,
        ]
        let size = letter.size(withAttributes: attrs)
        let origin = NSPoint(
            x: pad.midX - size.width * 0.50,
            y: pad.midY - size.height * 0.50 + pad.height * 0.02
        )
        letter.draw(at: origin, withAttributes: attrs)
    }

    private static func bestCFont(size: CGFloat) -> NSFont {
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

// MARK: - Usage API

enum CreditsFetcher {
    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private static let accountsURL = URL(
        string: "https://chatgpt.com/backend-api/accounts/check/v4-2023-04-27"
    )!
    private static let cacheTTL: TimeInterval = 100
    private static var cache: (date: Date, info: CreditsInfo)?

    private static var codexHome: URL {
        if let env = ProcessInfo.processInfo.environment["CODEX_HOME"], !env.isEmpty {
            return URL(fileURLWithPath: (env as NSString).expandingTildeInPath)
        }
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex")
    }

    static func fetch(forceLive: Bool) -> CreditsInfo {
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
            return CreditsInfo(
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

    private static func fetchLive() throws -> CreditsInfo {
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
        let tokenStats = TokenUsageStats.collect()
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

    private static func parseUsage(_ json: [String: Any]) -> CreditsInfo {
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

        return CreditsInfo(
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
enum TokenUsageStats {
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
enum ActivityDetector {
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

// MARK: - Task sound effects

/// Loop countdown while a turn is active; play end chime when it finishes.
/// Toggle via menu; preference stored in UserDefaults (default: on).
enum TaskSounds {
    private static let defaultsKey = "CodexCredits.soundEffectsEnabled"
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
        let res = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/\(name).wav")
        return FileManager.default.fileExists(atPath: res.path) ? res : nil
    }

    static func startRunning() {
        guard isEnabled else { return }
        // Already looping the same clip — don't reload ~6MB into a new player.
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
            // optional
        }
    }

    static func stopRunning() {
        runningPlayer?.stop()
        runningPlayer = nil
    }

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
            // optional
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var remainingItem: NSMenuItem!
    private var resetItem: NSMenuItem!
    private var windowItem: NSMenuItem!
    private var secondaryItem: NSMenuItem!
    private var creditsItem: NSMenuItem!
    private var resetCreditsItem: NSMenuItem!
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
        remainingPercent: nil, usedPercent: nil, resetsAt: nil,
        windowLabel: nil, secondaryRemaining: nil, secondaryResetsAt: nil,
        secondaryWindowLabel: nil, creditsBalance: nil,
        resetCreditsAvailable: nil, nextSubscriptionAt: nil,
        subscriptionAutoRenew: nil, tokensToday: nil, tokensMonth: nil,
        planType: nil, email: nil, fromCache: false, error: nil
    )
    private var isTaskRunning = false
    private var blinkLit = true
    /// UI hysteresis: once busy, stay busy briefly even if one poll is false.
    private var stickyBusyUntil: Date = .distantPast

    private func log(_ msg: String) {
        let dir = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Logs/CodexCreditsMenuBar")
        let path = (dir as NSString).appendingPathComponent("app.log")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(msg)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: path),
               let h = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                defer { try? h.close() }
                h.seekToEndOfFile()
                h.write(data)
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
            button.image = MenuBarCMark.image()
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
            button.title = "…"
            button.font = MenuBarPercentFont.font()
            button.toolTip = "Codex 用量"
            button.appearsDisabled = false
            button.setButtonType(.momentaryLight)
        }

        let menu = NSMenu()
        menu.autoenablesItems = false

        remainingItem = NSMenuItem(title: "余量: …", action: nil, keyEquivalent: "")
        remainingItem.isEnabled = false
        menu.addItem(remainingItem)

        resetItem = NSMenuItem(title: "重置时间: …", action: nil, keyEquivalent: "")
        resetItem.isEnabled = false
        menu.addItem(resetItem)

        windowItem = NSMenuItem(title: "窗口: …", action: nil, keyEquivalent: "")
        windowItem.isEnabled = false
        menu.addItem(windowItem)

        secondaryItem = NSMenuItem(title: "副窗口: —", action: nil, keyEquivalent: "")
        secondaryItem.isEnabled = false
        menu.addItem(secondaryItem)

        creditsItem = NSMenuItem(title: "Credits: —", action: nil, keyEquivalent: "")
        creditsItem.isEnabled = false
        menu.addItem(creditsItem)

        resetCreditsItem = NSMenuItem(title: "重置次数: —", action: nil, keyEquivalent: "")
        resetCreditsItem.isEnabled = false
        menu.addItem(resetCreditsItem)

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

        let refresh = NSMenuItem(title: "立即刷新", action: #selector(refreshClicked), keyEquivalent: "r")
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

        refreshCredits(forceLive: true)
        pollActivity()

        // Usage: every 2 minutes (low CPU/RAM/network)
        creditsTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.refreshCredits(forceLive: false)
        }
        // Activity: 2s interval; avoid forking sqlite3 every second
        activityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollActivity()
        }
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
        if let url = URL(string: "https://chatgpt.com/codex/usage") {
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
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let info = CreditsFetcher.fetch(forceLive: forceLive)
            DispatchQueue.main.async {
                self?.apply(info)
            }
        }
    }

    private func pollActivity() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let raw = ActivityDetector.isTaskRunning()
            DispatchQueue.main.async {
                self?.applyActivity(rawBusy: raw)
            }
        }
    }

    private func applyActivity(rawBusy: Bool) {
        let now = Date()
        if rawBusy {
            // Short UI glue only — long gaps are handled in ActivityDetector grace
            stickyBusyUntil = now.addingTimeInterval(5)
        }
        let running = rawBusy || now < stickyBusyUntil
        setTaskRunning(running)
    }

    private func setTaskRunning(_ running: Bool) {
        let changed = running != isTaskRunning
        isTaskRunning = running
        if running {
            activityItem.title = "任务: 运行中 ●"
        } else {
            activityItem.title = "任务: 空闲"
            blinkLit = true
        }
        if changed {
            if running {
                log("task started — C will blink")
                TaskSounds.startRunning()
            } else {
                log("task ended — C solid")
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
        lastInfo = info

        if let err = info.error, info.remainingPercent == nil {
            remainingItem.title = "余量: 获取失败"
            resetItem.title = "重置时间: —"
            windowItem.title = "窗口: —"
            secondaryItem.title = "副窗口: —"
            creditsItem.title = "Credits: —"
            resetCreditsItem.title = "重置次数: —"
            subscriptionItem.title = "下次订阅: —"
            tokensTodayItem.title = "今日 Token: —"
            tokensMonthItem.title = "本月 Token: —"
            detailItem.title = "错误: \(String(err.prefix(40)))"
            log("fetch error: \(err)")
        } else {
            remainingItem.title = "余量: \(info.remainingText)"
            resetItem.title = "重置时间: \(info.resetText)"
            if let w = info.windowLabel {
                windowItem.title = "窗口: \(w)"
            } else {
                windowItem.title = "窗口: 主限额"
            }
            if let sRem = info.secondaryRemaining {
                let s = String(format: "%.0f%%", sRem)
                secondaryItem.title = "副窗口: \(s) · \(info.secondaryResetText)"
                    + (info.secondaryWindowLabel.map { " (\($0))" } ?? "")
            } else {
                secondaryItem.title = "副窗口: —"
            }
            if let bal = info.creditsBalance {
                creditsItem.title = "Credits: \(bal)"
            } else {
                creditsItem.title = "Credits: —"
            }
            resetCreditsItem.title = "重置次数: \(info.resetCreditsText)"
            subscriptionItem.title = info.nextSubscriptionMenuTitle
            tokensTodayItem.title = "今日 Token: \(info.tokensTodayText)"
            tokensMonthItem.title = "本月 Token: \(info.tokensMonthText)"
            let now = DateFormatter()
            now.dateFormat = "HH:mm:ss"
            let cache = info.fromCache ? "缓存" : "实时"
            let plan = info.planType.map { " · \($0)" } ?? ""
            detailItem.title = "更新: \(now.string(from: Date())) (\(cache))\(plan)"
            if let err = info.error {
                log("fetch warning (using cache): \(err)")
            } else {
                log(
                    "updated remaining=\(info.remainingText) tokens_today=\(info.tokensTodayText) tokens_month=\(info.tokensMonthText)"
                )
            }
        }
        updateStatusAppearance()
    }

    private func updateStatusAppearance() {
        guard let button = statusItem.button else { return }
        let info = lastInfo
        let low = (info.remainingPercent ?? 100) <= 10 && info.remainingPercent != nil

        button.imagePosition = .imageLeading
        button.imageHugsTitle = true
        button.title = info.menuBarTitle
        button.font = MenuBarPercentFont.font()
        statusItem.isVisible = true

        // Blink only the letter C; ring + percent stay fixed
        let showC = !isTaskRunning || blinkLit
        button.image = MenuBarCMark.image(lowWarning: low, showLetter: showC)

        var tip = "Codex 余量 \(info.remainingText) · 重置 \(info.resetText)"
        if isTaskRunning {
            tip = "● 任务进行中\n" + tip
        }
        if let email = info.email, !email.isEmpty {
            tip = "\(email)\n\(tip)"
        }
        if let err = info.error, info.remainingPercent == nil {
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
