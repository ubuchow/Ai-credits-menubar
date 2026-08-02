import AppKit
import AVFoundation
import Foundation

// MARK: - Compact dual chip (one menubar slot)

/// Dense stacked layout:
/// ```
///  ⬤G 95     Grok  — light disc + dark G + black number
///  ⬤C 78     Codex — amber gold disc + dark C + gold number
/// ```
enum MenuBarChip {
    private static var cache: [String: NSImage] = [:]

    // Grok — monochrome
    private static let gDisc = NSColor(calibratedWhite: 0.96, alpha: 1)
    private static let gInk = NSColor(calibratedWhite: 0.08, alpha: 1)
    // Numbers: deep red — high contrast on dark menubar
    private static let gNum = NSColor(
        srgbRed: 0.72,
        green: 0.12,
        blue: 0.14,
        alpha: 1
    )
    private static let gRim = NSColor(calibratedWhite: 0.45, alpha: 0.65)
    // Codex — amber gold badge (distinct from G)
    private static let cDisc = NSColor(
        srgbRed: 0.92,
        green: 0.68,
        blue: 0.22,
        alpha: 1
    )
    private static let cInk = NSColor(calibratedWhite: 0.10, alpha: 1)
    private static let cNum = NSColor(
        srgbRed: 0.72,
        green: 0.12,
        blue: 0.14,
        alpha: 1
    )
    private static let warnFill = NSColor(calibratedRed: 0.78, green: 0.32, blue: 0.32, alpha: 1)
    private static let warnOn = NSColor.white

    private static let chipHeight: CGFloat = 18
    private static let badge: CGFloat = 9.0
    private static let rowGap: CGFloat = 0.8
    private static let badgeToNum: CGFloat = 2.0
    private static let numColMin: CGFloat = 14

    static func image(
        grokText: String,
        codexText: String,
        grokLow: Bool = false,
        codexLow: Bool = false,
        showG: Bool = true,
        showC: Bool = true
    ) -> NSImage {
        let key = "v5|\(grokText)|\(codexText)|\(grokLow)|\(codexLow)|\(showG)|\(showC)"
        if let hit = cache[key] { return hit }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let numFont = MenuBarPercentFont.bold(size: 9.0)
        let gSize = (grokText as NSString).size(withAttributes: [.font: numFont])
        let cSize = (codexText as NSString).size(withAttributes: [.font: numFont])
        let numW = max(numColMin, ceil(max(gSize.width, cSize.width)))
        let width = badge + badgeToNum + numW + 0.5
        let height = chipHeight

        let pxW = Int(ceil(width * scale))
        let pxH = Int(ceil(height * scale))
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pxW,
            pixelsHigh: pxH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        let blockH = badge * 2 + rowGap
        let blockY = (height - blockH) * 0.5
        let topRowY = blockY + badge + rowGap
        let botRowY = blockY

        // Top — Grok (mono)
        drawRow(
            letter: "G",
            text: grokText,
            low: grokLow,
            showLetter: showG,
            rowY: topRowY,
            numFont: numFont,
            disc: gDisc,
            letterColor: gInk,
            numColor: gNum,
            rim: gRim
        )
        // Bottom — Codex (green)
        drawRow(
            letter: "C",
            text: codexText,
            low: codexLow,
            showLetter: showC,
            rowY: botRowY,
            numFont: numFont,
            disc: cDisc,
            letterColor: cInk,
            numColor: cNum,
            rim: cDisc.blended(withFraction: 0.22, of: .black)
        )

        NSGraphicsContext.restoreGraphicsState()

        let img = NSImage(size: NSSize(width: width, height: height))
        img.addRepresentation(rep)
        img.isTemplate = false
        img.cacheMode = .always
        if cache.count > 80 { cache.removeAll(keepingCapacity: true) }
        cache[key] = img
        return img
    }

    private static func drawRow(
        letter: String,
        text: String,
        low: Bool,
        showLetter: Bool,
        rowY: CGFloat,
        numFont: NSFont,
        disc: NSColor,
        letterColor: NSColor,
        numColor: NSColor,
        rim: NSColor?
    ) {
        let fill = low ? warnFill : disc
        let letterCol = low ? warnOn : letterColor
        let numCol = low ? warnFill : numColor
        let rimCol = low ? warnFill.blended(withFraction: 0.2, of: .black) : rim
        drawBadge(
            letter: letter,
            fill: fill,
            letterColor: letterCol,
            rim: rimCol,
            showLetter: showLetter,
            badgeRect: NSRect(x: 0, y: rowY, width: badge, height: badge)
        )
        drawNumber(
            text,
            x: badge + badgeToNum,
            centerY: rowY + badge * 0.5,
            font: numFont,
            color: numCol
        )
    }

    private static func drawBadge(
        letter: String,
        fill: NSColor,
        letterColor: NSColor,
        rim: NSColor?,
        showLetter: Bool,
        badgeRect: NSRect
    ) {
        let inset = badgeRect.insetBy(dx: 0.2, dy: 0.2)
        if showLetter {
            fill.setFill()
            NSBezierPath(ovalIn: inset).fill()
            if let rim {
                rim.setStroke()
                let edge = NSBezierPath(ovalIn: inset)
                edge.lineWidth = 0.7
                edge.stroke()
            }
            let font = MenuBarPercentFont.bold(size: badge * 0.64)
            let text = letter as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: letterColor,
            ]
            let size = text.size(withAttributes: attrs)
            let origin = NSPoint(
                x: inset.midX - size.width * 0.5,
                y: inset.midY - size.height * 0.5 + 0.12
            )
            text.draw(at: origin, withAttributes: attrs)
        } else {
            fill.setStroke()
            let ring = NSBezierPath(ovalIn: inset.insetBy(dx: 0.55, dy: 0.55))
            ring.lineWidth = 1.4
            ring.stroke()
        }
    }

    private static func drawNumber(
        _ s: String,
        x: CGFloat,
        centerY: CGFloat,
        font: NSFont,
        color: NSColor
    ) {
        let text = s as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let size = text.size(withAttributes: attrs)
        let origin = NSPoint(x: x, y: centerY - size.height * 0.5)
        text.draw(at: origin, withAttributes: attrs)
    }
}

// MARK: - Task sounds (shared)

enum TaskSounds {
    private static let defaultsKey = "AICredits.soundEffectsEnabled"
    private static var runningPlayer: AVAudioPlayer?
    private static var endedPlayer: AVAudioPlayer?
    private static var anyTaskWasRunning = false

    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: defaultsKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: defaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
            if !newValue { stopRunning() }
        }
    }

    private static func resourceURL(_ name: String) -> URL? {
        if let u = Bundle.main.url(forResource: name, withExtension: "wav") { return u }
        let res = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(name).wav")
        return FileManager.default.fileExists(atPath: res.path) ? res : nil
    }

    static func sync(withAnyTaskRunning running: Bool) {
        if running {
            if !anyTaskWasRunning {
                anyTaskWasRunning = true
                startRunning()
            } else if isEnabled, runningPlayer?.isPlaying != true {
                startRunning()
            }
        } else if anyTaskWasRunning {
            anyTaskWasRunning = false
            playEnded()
        }
    }

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
        } catch {}
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
        } catch {}
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    // Grok menu
    private var gHeader: NSMenuItem!
    private var gRemaining: NSMenuItem!
    private var gReset: NSMenuItem!
    private var gSub: NSMenuItem!
    private var gToday: NSMenuItem!
    private var gMonth: NSMenuItem!
    private var gActivity: NSMenuItem!
    private var gDetail: NSMenuItem!

    // Codex menu
    private var cHeader: NSMenuItem!
    private var cRemaining: NSMenuItem!
    private var cReset: NSMenuItem!
    private var cWindow: NSMenuItem!
    private var cSecondary: NSMenuItem!
    private var cCredits: NSMenuItem!
    private var cResetCredits: NSMenuItem!
    private var cSub: NSMenuItem!
    private var cToday: NSMenuItem!
    private var cMonth: NSMenuItem!
    private var cActivity: NSMenuItem!
    private var cDetail: NSMenuItem!

    private var soundItem: NSMenuItem!

    private var creditsTimer: Timer?
    private var activityTimer: Timer?
    private var blinkTimer: Timer?

    private var grokInfo = GrokInfo(
        remainingPercent: nil, resetsAt: nil, nextSubscriptionAt: nil,
        subscriptionAutoRenew: nil, tokensToday: nil, tokensMonth: nil,
        email: nil, fromCache: false, error: nil
    )
    private var codexInfo = CodexInfo(
        remainingPercent: nil, usedPercent: nil, resetsAt: nil,
        windowLabel: nil, secondaryRemaining: nil, secondaryResetsAt: nil,
        secondaryWindowLabel: nil, creditsBalance: nil,
        resetCreditsAvailable: nil, nextSubscriptionAt: nil,
        subscriptionAutoRenew: nil, tokensToday: nil, tokensMonth: nil,
        planType: nil, email: nil, fromCache: false, error: nil
    )

    private var grokBusy = false
    private var codexBusy = false
    private var blinkLit = true
    private var stickyCodexUntil: Date = .distantPast

    private func log(_ msg: String) {
        let dir = (NSHomeDirectory() as NSString)
            .appendingPathComponent("Library/Logs/AICreditsMenuBar")
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
            button.image = MenuBarChip.image(grokText: "…", codexText: "…")
            button.imagePosition = .imageOnly
            button.imageHugsTitle = true
            button.title = ""
            button.toolTip = "Grok · Codex 用量"
        }

        let menu = NSMenu()
        menu.autoenablesItems = false

        // Section tints match menubar chip brand colors
        gHeader = section("Grok", tint: NSColor(calibratedWhite: 0.55, alpha: 1))
        menu.addItem(gHeader)
        gRemaining = disabled("余量: …"); menu.addItem(gRemaining)
        gReset = disabled("重置: …"); menu.addItem(gReset)
        gSub = disabled("下次订阅: …"); menu.addItem(gSub)
        gToday = disabled("今日 Token: —"); menu.addItem(gToday)
        gMonth = disabled("本月 Token: —"); menu.addItem(gMonth)
        gActivity = disabled("任务: 空闲"); menu.addItem(gActivity)
        gDetail = disabled("更新: …"); menu.addItem(gDetail)

        menu.addItem(.separator())

        cHeader = section(
            "Codex",
            tint: NSColor(srgbRed: 0.88, green: 0.64, blue: 0.18, alpha: 1)
        )
        menu.addItem(cHeader)
        cRemaining = disabled("余量: …"); menu.addItem(cRemaining)
        cReset = disabled("重置时间: …"); menu.addItem(cReset)
        cWindow = disabled("窗口: …"); menu.addItem(cWindow)
        cSecondary = disabled("副窗口: …"); menu.addItem(cSecondary)
        cCredits = disabled("Credits: …"); menu.addItem(cCredits)
        cResetCredits = disabled("重置次数: —"); menu.addItem(cResetCredits)
        cSub = disabled("下次订阅: …"); menu.addItem(cSub)
        cToday = disabled("今日 Token: —"); menu.addItem(cToday)
        cMonth = disabled("本月 Token: —"); menu.addItem(cMonth)
        cActivity = disabled("任务: 空闲"); menu.addItem(cActivity)
        cDetail = disabled("更新: …"); menu.addItem(cDetail)

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "立即刷新", action: #selector(refreshClicked), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        soundItem = NSMenuItem(
            title: TaskSounds.isEnabled ? "关闭音效" : "开启音效",
            action: #selector(toggleSound),
            keyEquivalent: ""
        )
        soundItem.target = self
        menu.addItem(soundItem)

        let openG = NSMenuItem(title: "打开 Grok 用量页", action: #selector(openGrok), keyEquivalent: "")
        openG.target = self
        menu.addItem(openG)
        let openC = NSMenuItem(title: "打开 Codex 用量页", action: #selector(openCodex), keyEquivalent: "")
        openC.target = self
        menu.addItem(openC)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "退出",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu

        refreshAll(forceLive: true)
        pollActivity()

        creditsTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.refreshAll(forceLive: false)
        }
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

    private func section(_ title: String, tint: NSColor) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let attr = NSMutableAttributedString(string: " ●  \(title)")
        attr.addAttributes([
            .font: font,
            .foregroundColor: tint,
        ], range: NSRange(location: 0, length: attr.length))
        item.attributedTitle = attr
        return item
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func refreshClicked() { refreshAll(forceLive: true) }

    @objc private func toggleSound() {
        TaskSounds.isEnabled.toggle()
        soundItem.title = TaskSounds.isEnabled ? "关闭音效" : "开启音效"
        if TaskSounds.isEnabled {
            if grokBusy || codexBusy { TaskSounds.startRunning() }
            log("sound enabled")
        } else {
            TaskSounds.stopRunning()
            log("sound disabled")
        }
    }

    @objc private func openGrok() {
        if let u = URL(string: "https://grok.com/?_s=usage") { NSWorkspace.shared.open(u) }
    }

    @objc private func openCodex() {
        if let u = URL(string: "https://chatgpt.com/codex/usage") { NSWorkspace.shared.open(u) }
    }

    private func refreshAll(forceLive: Bool) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let g = GrokFetcher.fetch(forceLive: forceLive)
            let c = CodexFetcher.fetch(forceLive: forceLive)
            DispatchQueue.main.async {
                self?.applyGrok(g)
                self?.applyCodex(c)
            }
        }
    }

    private func pollActivity() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let gBusy = !GrokActivity.busySessionIds().isEmpty
            let cRaw = CodexActivity.isTaskRunning()
            DispatchQueue.main.async {
                self?.applyActivity(grok: gBusy, codexRaw: cRaw)
            }
        }
    }

    private func applyActivity(grok: Bool, codexRaw: Bool) {
        let now = Date()
        if codexRaw { stickyCodexUntil = now.addingTimeInterval(5) }
        let cBusy = codexRaw || now < stickyCodexUntil

        let gChanged = grok != grokBusy
        let cChanged = cBusy != codexBusy
        grokBusy = grok
        codexBusy = cBusy

        gActivity.title = grokBusy ? "任务: 运行中 ●" : "任务: 空闲"
        cActivity.title = codexBusy ? "任务: 运行中 ●" : "任务: 空闲"

        if gChanged { log(grokBusy ? "grok task started" : "grok task ended") }
        if cChanged { log(codexBusy ? "codex task started" : "codex task ended") }

        TaskSounds.sync(withAnyTaskRunning: grokBusy || codexBusy)
        if !grokBusy && !codexBusy { blinkLit = true }
        updateStatusAppearance()
    }

    private func tickBlink() {
        guard grokBusy || codexBusy else { return }
        blinkLit.toggle()
        updateStatusAppearance()
    }

    private func applyGrok(_ info: GrokInfo) {
        var merged = info
        if merged.remainingPercent == nil, let prev = grokInfo.remainingPercent {
            merged.remainingPercent = prev
            merged.resetsAt = merged.resetsAt ?? grokInfo.resetsAt
            merged.nextSubscriptionAt = merged.nextSubscriptionAt ?? grokInfo.nextSubscriptionAt
            merged.subscriptionAutoRenew = merged.subscriptionAutoRenew ?? grokInfo.subscriptionAutoRenew
            merged.email = merged.email ?? grokInfo.email
            merged.fromCache = true
        }
        merged.tokensToday = info.tokensToday ?? grokInfo.tokensToday
        merged.tokensMonth = info.tokensMonth ?? grokInfo.tokensMonth
        grokInfo = merged

        gToday.title = "今日 Token: \(merged.tokensTodayText)"
        gMonth.title = "本月 Token: \(merged.tokensMonthText)"

        if let err = merged.error, merged.remainingPercent == nil {
            gRemaining.title = "余量: 获取失败"
            gReset.title = "重置: —"
            gSub.title = "下次订阅: —"
            gDetail.title = "错误: \(String(err.prefix(36)))"
            log("grok error: \(err)")
        } else {
            gRemaining.title = "余量: \(merged.remainingText)"
            gReset.title = "重置: \(merged.resetText)"
            gSub.title = merged.nextSubscriptionMenuTitle
            let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
            let cache = merged.fromCache ? "缓存" : "实时"
            let warn = merged.error != nil ? " · 警告" : ""
            gDetail.title = "更新: \(f.string(from: Date())) (\(cache))\(warn)"
            log("grok remaining=\(merged.remainingText)")
        }
        updateStatusAppearance()
    }

    private func applyCodex(_ info: CodexInfo) {
        var merged = info
        if merged.remainingPercent == nil, let prev = codexInfo.remainingPercent {
            merged.remainingPercent = prev
            merged.resetsAt = merged.resetsAt ?? codexInfo.resetsAt
            merged.nextSubscriptionAt = merged.nextSubscriptionAt ?? codexInfo.nextSubscriptionAt
            merged.resetCreditsAvailable = merged.resetCreditsAvailable ?? codexInfo.resetCreditsAvailable
            merged.fromCache = true
        }
        merged.tokensToday = info.tokensToday ?? codexInfo.tokensToday
        merged.tokensMonth = info.tokensMonth ?? codexInfo.tokensMonth
        codexInfo = merged

        cToday.title = "今日 Token: \(merged.tokensTodayText)"
        cMonth.title = "本月 Token: \(merged.tokensMonthText)"

        if let err = merged.error, merged.remainingPercent == nil {
            cRemaining.title = "余量: 获取失败"
            cReset.title = "重置时间: —"
            cWindow.title = "窗口: —"
            cSecondary.title = "副窗口: —"
            cCredits.title = "Credits: —"
            cResetCredits.title = "重置次数: —"
            cSub.title = "下次订阅: —"
            cDetail.title = "错误: \(String(err.prefix(36)))"
            log("codex error: \(err)")
        } else {
            cRemaining.title = "余量: \(merged.remainingText)"
            cReset.title = "重置时间: \(merged.resetText)"
            if let w = merged.windowLabel {
                cWindow.title = "窗口: \(w)"
            } else {
                cWindow.title = "窗口: 主限额"
            }
            if let sRem = merged.secondaryRemaining {
                let s = String(format: "%.0f%%", sRem)
                cSecondary.title = "副窗口: \(s) · \(merged.secondaryResetText)"
                    + (merged.secondaryWindowLabel.map { " (\($0))" } ?? "")
            } else {
                cSecondary.title = "副窗口: —"
            }
            if let bal = merged.creditsBalance {
                cCredits.title = "Credits: \(bal)"
            } else {
                cCredits.title = "Credits: —"
            }
            cResetCredits.title = "重置次数: \(merged.resetCreditsText)"
            cSub.title = merged.nextSubscriptionMenuTitle
            let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
            let cache = merged.fromCache ? "缓存" : "实时"
            let plan = merged.planType.map { " · \($0)" } ?? ""
            cDetail.title = "更新: \(f.string(from: Date())) (\(cache))\(plan)"
            log("codex remaining=\(merged.remainingText)")
        }
        updateStatusAppearance()
    }

    /// Compact integer percent for the stacked chip (no % sign — cleaner).
    private func compactPercent(_ p: Double?) -> String {
        guard let p else { return "—" }
        return "\(Int(p.rounded()))"
    }

    private func updateStatusAppearance() {
        guard let button = statusItem.button else { return }
        let gLow = (grokInfo.remainingPercent ?? 100) <= 10 && grokInfo.remainingPercent != nil
        let cLow = (codexInfo.remainingPercent ?? 100) <= 10 && codexInfo.remainingPercent != nil
        let showG = !grokBusy || blinkLit
        let showC = !codexBusy || blinkLit

        let gText = compactPercent(grokInfo.remainingPercent)
        let cText = compactPercent(codexInfo.remainingPercent)

        // Entire chip is one image: stacked rings + vertically stacked digits
        button.imagePosition = .imageOnly
        button.title = ""
        button.image = MenuBarChip.image(
            grokText: gText,
            codexText: cText,
            grokLow: gLow,
            codexLow: cLow,
            showG: showG,
            showC: showC
        )

        var tip = """
        Grok  \(grokInfo.remainingText)  ·  重置 \(grokInfo.resetText)
        Codex \(codexInfo.remainingText)  ·  重置 \(codexInfo.resetText)
        """
        if grokBusy || codexBusy {
            var parts: [String] = []
            if grokBusy { parts.append("Grok 运行中") }
            if codexBusy { parts.append("Codex 运行中") }
            tip = "● " + parts.joined(separator: " · ") + "\n" + tip
        }
        button.toolTip = tip
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
