import Cocoa

final class Settings {
    static let workKey = "rest.workMinutes"
    static let snoozeKey = "rest.snoozeMinutes"
    static let intervalChoices = [15, 20, 25, 30, 45, 60, 90]
    static let snoozeChoices = [3, 5, 10, 15]

    var workMinutes: Double
    var snoozeMinutes: Double
    var showOnStart = false

    init() {
        let defaults = UserDefaults.standard
        workMinutes = defaults.object(forKey: Self.workKey) as? Double ?? 30
        snoozeMinutes = defaults.object(forKey: Self.snoozeKey) as? Double ?? 5

        let args = Array(CommandLine.arguments.dropFirst())
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--interval", "-i":
                i += 1
                if i < args.count, let value = Double(args[i]) {
                    workMinutes = min(180, max(1, value))
                }
            case "--snooze", "-s":
                i += 1
                if i < args.count, let value = Double(args[i]) {
                    snoozeMinutes = min(60, max(1, value))
                }
            case "--now":
                showOnStart = true
            default:
                break
            }
            i += 1
        }
        persist()
    }

    func persist() {
        UserDefaults.standard.set(workMinutes, forKey: Self.workKey)
        UserDefaults.standard.set(snoozeMinutes, forKey: Self.snoozeKey)
    }
}

let suggestions = [
    "抬起头看一会儿天花板，让眼睛离开屏幕。",
    "站起来走一走，活动一下腿和腰。",
    "望向窗外或房间另一头，给眼睛换个焦距。",
    "去倒杯水，顺便离开座位一会儿。",
    "闭上眼睛深呼吸几次，把肩膀松开。",
    "轻轻转转脖子，别一直僵着。",
]

final class CoffeeView: NSView {
    private var timer: Timer?
    private let born = CFAbsoluteTimeGetCurrent()

    override var intrinsicContentSize: NSSize { NSSize(width: 160, height: 196) }
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate()
        timer = nil
        guard window != nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    override func draw(_ dirtyRect: NSRect) {
        let t = CGFloat(CFAbsoluteTimeGetCurrent() - born)
        let cx = bounds.midX
        drawSteam(time: t, origin: NSPoint(x: cx, y: 108))
        drawCup(centerX: cx)
    }

    private func drawCup(centerX cx: CGFloat) {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
        shadow.shadowBlurRadius = 10
        shadow.shadowOffset = NSSize(width: 0, height: -2)

        NSGraphicsContext.saveGraphicsState()
        shadow.set()

        let saucer = NSBezierPath(ovalIn: NSRect(x: cx - 50, y: 14, width: 100, height: 18))
        NSColor(calibratedRed: 0.93, green: 0.90, blue: 0.85, alpha: 1).setFill()
        saucer.fill()

        let body = NSBezierPath()
        body.move(to: NSPoint(x: cx - 34, y: 96))
        body.line(to: NSPoint(x: cx + 34, y: 96))
        body.line(to: NSPoint(x: cx + 24, y: 32))
        body.curve(
            to: NSPoint(x: cx - 24, y: 32),
            controlPoint1: NSPoint(x: cx + 20, y: 22),
            controlPoint2: NSPoint(x: cx - 20, y: 22)
        )
        body.close()
        NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.93, alpha: 1).setFill()
        body.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor(calibratedRed: 0.82, green: 0.76, blue: 0.70, alpha: 1).setStroke()
        body.lineWidth = 1.2
        body.stroke()

        let handle = NSBezierPath()
        handle.appendOval(in: NSRect(x: cx + 22, y: 48, width: 30, height: 38))
        let handleHole = NSBezierPath(ovalIn: NSRect(x: cx + 29, y: 56, width: 16, height: 22))
        handle.append(handleHole)
        handle.windingRule = .evenOdd
        NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.93, alpha: 1).setFill()
        handle.fill()
        NSColor(calibratedRed: 0.82, green: 0.76, blue: 0.70, alpha: 1).setStroke()
        handle.lineWidth = 1.2
        handle.stroke()

        let coffee = NSBezierPath(ovalIn: NSRect(x: cx - 30, y: 82, width: 60, height: 18))
        NSColor(calibratedRed: 0.27, green: 0.15, blue: 0.07, alpha: 1).setFill()
        coffee.fill()

        let shine = NSBezierPath(ovalIn: NSRect(x: cx - 16, y: 90, width: 18, height: 6))
        NSColor.white.withAlphaComponent(0.16).setFill()
        shine.fill()

        let rim = NSBezierPath(ovalIn: NSRect(x: cx - 35, y: 90, width: 70, height: 20))
        NSColor(calibratedRed: 0.90, green: 0.86, blue: 0.80, alpha: 1).setStroke()
        rim.lineWidth = 3
        rim.stroke()
    }

    private func drawSteam(time: CGFloat, origin: NSPoint) {
        let wisps: [(x: CGFloat, delay: CGFloat, speed: CGFloat, amp: CGFloat, thick: CGFloat)] = [
            (-11, 0.0, 1.10, 6.5, 2.6),
            (1, 0.9, 1.38, 8.5, 3.1),
            (12, 0.45, 1.22, 6.0, 2.3),
        ]

        for wisp in wisps {
            let steps = 30
            let height: CGFloat = 68
            var points: [NSPoint] = []
            for i in 0...steps {
                let p = CGFloat(i) / CGFloat(steps)
                let y = origin.y + p * height
                let wave = sin((p * 3.4 + time * wisp.speed + wisp.delay) * .pi)
                let x = origin.x + wisp.x + wave * wisp.amp * (0.3 + p)
                points.append(NSPoint(x: x, y: y))
            }

            let pulse = 0.7 + 0.3 * sin(time * wisp.speed + wisp.delay)
            for i in 0..<steps {
                let p = CGFloat(i) / CGFloat(steps)
                let segment = NSBezierPath()
                segment.move(to: points[i])
                segment.line(to: points[i + 1])
                segment.lineCapStyle = .round
                segment.lineWidth = wisp.thick * (1 - p * 0.72)
                let alpha = (0.52 * (1 - p) * pulse)
                NSColor(calibratedRed: 0.62, green: 0.54, blue: 0.46, alpha: alpha).setStroke()
                segment.stroke()
            }
        }
    }
}

final class BreakCardView: NSView {
    let coffeeView = CoffeeView(frame: .zero)
    let titleLabel = NSTextField(labelWithString: "休息休息")
    let subtitleLabel = NSTextField(labelWithString: "")
    let detailLabel = NSTextField(wrappingLabelWithString: "")
    let restButton = NSButton(title: "好，休息", target: nil, action: nil)
    let snoozeButton = NSButton(title: "推迟 5 分钟", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 24
        layer?.masksToBounds = true

        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)

        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        titleLabel.alignment = .center

        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center

        detailLabel.font = .systemFont(ofSize: 15)
        detailLabel.textColor = .labelColor
        detailLabel.alignment = .center
        detailLabel.maximumNumberOfLines = 2

        restButton.bezelStyle = .rounded
        restButton.setButtonType(.momentaryPushIn)
        restButton.keyEquivalent = "\r"

        snoozeButton.bezelStyle = .rounded
        snoozeButton.setButtonType(.momentaryPushIn)
        snoozeButton.keyEquivalent = "\u{1b}"

        let buttonRow = NSStackView(views: [snoozeButton, restButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12
        buttonRow.alignment = .centerY
        buttonRow.distribution = .fillEqually

        let stack = NSStackView(views: [
            coffeeView, titleLabel, subtitleLabel, detailLabel, buttonRow
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.setCustomSpacing(4, after: coffeeView)
        stack.setCustomSpacing(14, after: detailLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            coffeeView.widthAnchor.constraint(equalToConstant: 160),
            coffeeView.heightAnchor.constraint(equalToConstant: 196),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(workMinutes: Int, snoozeMinutes: Int) {
        subtitleLabel.stringValue = "已经连续对着屏幕 \(workMinutes) 分钟了"
        detailLabel.stringValue = suggestions.randomElement() ?? suggestions[0]
        snoozeButton.title = "推迟 \(snoozeMinutes) 分钟"
    }
}

final class OverlayController {
    private var windows: [NSWindow] = []
    private var keyWindow: NSWindow?
    private var keyMonitor: Any?
    var onRest: (() -> Void)?
    var onSnooze: (() -> Void)?

    func show(workMinutes: Int, snoozeMinutes: Int) {
        hide()

        for screen in NSScreen.screens {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.08, blue: 0.05, alpha: 0.58)
            window.level = .screenSaver
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false
            window.alphaValue = 0

            if screen == NSScreen.main {
                let card = BreakCardView(frame: .zero)
                card.translatesAutoresizingMaskIntoConstraints = false
                card.apply(workMinutes: workMinutes, snoozeMinutes: snoozeMinutes)
                card.restButton.target = self
                card.restButton.action = #selector(restTapped)
                card.snoozeButton.target = self
                card.snoozeButton.action = #selector(snoozeTapped)
                window.contentView?.addSubview(card)
                if let content = window.contentView {
                    NSLayoutConstraint.activate([
                        card.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                        card.centerYAnchor.constraint(equalTo: content.centerYAnchor),
                        card.widthAnchor.constraint(equalToConstant: 400),
                    ])
                }
                keyWindow = window
            }

            window.orderFrontRegardless()
            windows.append(window)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                window.animator().alphaValue = 1
            }
        }

        NSApp.activate()
        keyWindow?.makeKeyAndOrderFront(nil)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.onSnooze?()
                return nil
            }
            return event
        }
    }

    func hide() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        let closing = windows
        windows.removeAll()
        keyWindow = nil
        for window in closing {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                window.animator().alphaValue = 0
            } completionHandler: {
                window.orderOut(nil)
            }
        }
    }

    @objc private func restTapped() {
        onRest?()
    }

    @objc private func snoozeTapped() {
        onSnooze?()
    }
}

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings: Settings
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var nextFireDate: Date?
    private var paused = false
    private let overlay = OverlayController()
    private var showingBreak = false

    init(settings: Settings) {
        self.settings = settings
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()

        overlay.onRest = { [weak self] in
            guard let self else { return }
            self.finishBreak()
            self.scheduleNext(minutes: self.settings.workMinutes)
        }
        overlay.onSnooze = { [weak self] in
            guard let self else { return }
            self.finishBreak()
            self.scheduleNext(minutes: self.settings.snoozeMinutes)
        }

        if settings.showOnStart {
            showBreak()
        } else {
            scheduleNext(minutes: settings.workMinutes)
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "休息提醒") {
            image.isTemplate = true
            item.button?.image = image
        } else {
            item.button?.title = "☕"
        }
        item.button?.toolTip = "休息提醒"
        statusItem = item
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let nextItem = NSMenuItem(title: nextTitle(), action: nil, keyEquivalent: "")
        nextItem.isEnabled = false
        menu.addItem(nextItem)
        menu.addItem(.separator())

        let intervalTitle = Int(settings.workMinutes.rounded())
        let intervalRoot = NSMenuItem(title: "提醒间隔：\(intervalTitle) 分钟", action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        for minutes in Settings.intervalChoices {
            let item = NSMenuItem(title: "\(minutes) 分钟", action: #selector(setInterval(_:)), keyEquivalent: "")
            item.tag = minutes
            item.state = Int(settings.workMinutes.rounded()) == minutes ? .on : .off
            item.target = self
            intervalMenu.addItem(item)
        }
        intervalMenu.addItem(.separator())
        let customInterval = NSMenuItem(title: customIntervalTitle(), action: #selector(chooseCustomInterval), keyEquivalent: "")
        customInterval.state = Settings.intervalChoices.contains(Int(settings.workMinutes.rounded())) ? .off : .on
        customInterval.target = self
        intervalMenu.addItem(customInterval)
        intervalRoot.submenu = intervalMenu
        menu.addItem(intervalRoot)

        let snoozeTitle = Int(settings.snoozeMinutes.rounded())
        let snoozeRoot = NSMenuItem(title: "推迟时长：\(snoozeTitle) 分钟", action: nil, keyEquivalent: "")
        let snoozeMenu = NSMenu()
        for minutes in Settings.snoozeChoices {
            let item = NSMenuItem(title: "\(minutes) 分钟", action: #selector(setSnooze(_:)), keyEquivalent: "")
            item.tag = minutes
            item.state = Int(settings.snoozeMinutes.rounded()) == minutes ? .on : .off
            item.target = self
            snoozeMenu.addItem(item)
        }
        snoozeRoot.submenu = snoozeMenu
        menu.addItem(snoozeRoot)

        menu.addItem(.separator())
        let nowItem = NSMenuItem(title: "现在休息", action: #selector(showNow), keyEquivalent: "")
        nowItem.target = self
        menu.addItem(nowItem)

        let pauseItem = NSMenuItem(
            title: paused ? "继续提醒" : "暂停提醒",
            action: #selector(togglePause),
            keyEquivalent: ""
        )
        pauseItem.target = self
        menu.addItem(pauseItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func customIntervalTitle() -> String {
        let minutes = Int(settings.workMinutes.rounded())
        if Settings.intervalChoices.contains(minutes) {
            return "自定义..."
        }
        return "自定义（\(minutes) 分钟）..."
    }

    private func nextTitle() -> String {
        if paused { return "已暂停" }
        if showingBreak { return "正在提醒休息" }
        guard let nextFireDate else { return "尚未安排下次提醒" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "下次提醒 \(formatter.string(from: nextFireDate))"
    }

    private func scheduleNext(minutes: Double) {
        timer?.invalidate()
        if paused { return }
        let interval = max(minutes * 60, 6)
        nextFireDate = Date().addingTimeInterval(interval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.showBreak()
        }
        RunLoop.main.add(timer!, forMode: .common)
        rebuildMenu()
    }

    private func showBreak() {
        if paused { return }
        showingBreak = true
        timer?.invalidate()
        overlay.show(
            workMinutes: Int(settings.workMinutes.rounded()),
            snoozeMinutes: Int(settings.snoozeMinutes.rounded())
        )
        rebuildMenu()
    }

    private func finishBreak() {
        showingBreak = false
        overlay.hide()
        rebuildMenu()
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        settings.workMinutes = Double(sender.tag)
        settings.persist()
        if !paused, !showingBreak {
            scheduleNext(minutes: settings.workMinutes)
        } else {
            rebuildMenu()
        }
    }

    @objc private func chooseCustomInterval() {
        let alert = NSAlert()
        alert.messageText = "设置提醒间隔"
        alert.informativeText = "每隔多少分钟提醒一次休息？（1–180）"
        let field = NSTextField(string: String(Int(settings.workMinutes.rounded())))
        field.frame = NSRect(x: 0, y: 0, width: 220, height: 24)
        field.placeholderString = "例如 40"
        alert.accessoryView = field
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        NSApp.activate()
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        let value = Double(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        guard value >= 1, value <= 180 else { return }
        settings.workMinutes = value.rounded()
        settings.persist()
        if !paused, !showingBreak {
            scheduleNext(minutes: settings.workMinutes)
        } else {
            rebuildMenu()
        }
    }

    @objc private func setSnooze(_ sender: NSMenuItem) {
        settings.snoozeMinutes = Double(sender.tag)
        settings.persist()
        rebuildMenu()
    }

    @objc private func showNow() {
        showBreak()
    }

    @objc private func togglePause() {
        paused.toggle()
        if paused {
            timer?.invalidate()
            nextFireDate = nil
            if showingBreak { finishBreak() }
        } else {
            scheduleNext(minutes: settings.workMinutes)
        }
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let settings = Settings()
let app = NSApplication.shared
let delegate = AppDelegate(settings: settings)
app.delegate = delegate
withExtendedLifetime(delegate) {
    app.run()
}
