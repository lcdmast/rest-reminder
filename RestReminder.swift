import Cocoa
import CoreGraphics
import QuartzCore

struct DayWindow: Codable, Equatable {
    var weekday: Int
    var enabled: Bool
    var startMinutes: Int
    var endMinutes: Int

    static func defaultWindow(weekday: Int) -> DayWindow {
        let weekend = weekday == 1 || weekday == 7
        return DayWindow(
            weekday: weekday,
            enabled: true,
            startMinutes: (weekend ? 10 : 9) * 60,
            endMinutes: 22 * 60
        )
    }

    var startLabel: String { Self.label(startMinutes) }
    var endLabel: String { Self.label(endMinutes) }

    static func label(_ minutes: Int) -> String {
        if minutes >= 24 * 60 { return "24:00" }
        let clamped = max(0, min(23 * 60 + 59, minutes))
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    func contains(_ date: Date) -> Bool {
        guard enabled else { return false }
        let calendar = Calendar.current
        guard calendar.component(.weekday, from: date) == weekday else { return false }
        let now = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        if startMinutes == endMinutes { return true }
        if startMinutes < endMinutes {
            return now >= startMinutes && now < endMinutes
        }
        return now >= startMinutes || now < endMinutes
    }
}

final class Settings {
    static let workKey = "rest.workMinutes"
    static let snoozeKey = "rest.snoozeMinutes"
    static let scheduleKey = "rest.weekSchedule"
    static let intervalChoices = [15, 20, 25, 30, 45, 60, 90]
    static let snoozeChoices = [3, 5, 10, 15]
    static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]
    static let weekdayNames = [2: "周一", 3: "周二", 4: "周三", 5: "周四", 6: "周五", 7: "周六", 1: "周日"]

    var workMinutes: Double
    var snoozeMinutes: Double
    var days: [DayWindow]
    var showOnStart = false

    init() {
        let defaults = UserDefaults.standard
        workMinutes = defaults.object(forKey: Self.workKey) as? Double ?? 30
        snoozeMinutes = defaults.object(forKey: Self.snoozeKey) as? Double ?? 5
        days = Self.loadDays(from: defaults)

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

    func window(for weekday: Int) -> DayWindow {
        days.first { $0.weekday == weekday } ?? DayWindow.defaultWindow(weekday: weekday)
    }

    func updateDay(_ window: DayWindow) {
        if let index = days.firstIndex(where: { $0.weekday == window.weekday }) {
            days[index] = window
        } else {
            days.append(window)
        }
        persist()
    }

    func isInActiveWindow(_ date: Date = Date()) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return window(for: weekday).contains(date)
    }

    func todaySummary(at date: Date = Date()) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        let item = window(for: weekday)
        let name = Self.weekdayNames[weekday] ?? ""
        if !item.enabled { return "\(name)不提醒" }
        return "\(name) \(item.startLabel)–\(item.endLabel)"
    }

    func persist() {
        UserDefaults.standard.set(workMinutes, forKey: Self.workKey)
        UserDefaults.standard.set(snoozeMinutes, forKey: Self.snoozeKey)
        if let data = try? JSONEncoder().encode(days) {
            UserDefaults.standard.set(data, forKey: Self.scheduleKey)
        }
    }

    private static func loadDays(from defaults: UserDefaults) -> [DayWindow] {
        if let data = defaults.data(forKey: scheduleKey),
           let saved = try? JSONDecoder().decode([DayWindow].self, from: data),
           saved.count == 7 {
            return (1...7).map { weekday in
                saved.first { $0.weekday == weekday } ?? DayWindow.defaultWindow(weekday: weekday)
            }
        }
        return (1...7).map { DayWindow.defaultWindow(weekday: $0) }
    }
}

struct RestTip {
    let line: String
    let action: String
}

let restTips: [RestTip] = [
    RestTip(line: "把视线从屏幕上拿开一会儿", action: "看看远处，慢慢眨几下眼"),
    RestTip(line: "近处看久了，换个焦距会轻松一些", action: "望向窗外，停大约二十秒"),
    RestTip(line: "肩膀可以放下了，让脖子歇一歇", action: "轻轻左右看看，不必用力"),
    RestTip(line: "坐直一点，把胸打开，深吸一口气", action: "双手轻轻后展，再慢慢放下"),
    RestTip(line: "站起来走两步，换个姿势就好", action: "离开座位，走一小圈"),
    RestTip(line: "松开鼠标，让手指也休息一下", action: "转转手腕，把手张开再合上"),
    RestTip(line: "忙也没关系，先把气吸满再慢慢吐", action: "闭眼，平稳呼吸三次"),
    RestTip(line: "去倒杯水，顺便离开屏幕一会儿", action: "站起来，走到窗边待片刻"),
]

enum RestTipPicker {
    static let lastKey = "rest.lastRestTip"

    static func next() -> RestTip {
        let last = UserDefaults.standard.integer(forKey: lastKey)
        var index = Int.random(in: 0..<restTips.count)
        if restTips.count > 1 {
            var guardCount = 0
            while index == last, guardCount < 8 {
                index = Int.random(in: 0..<restTips.count)
                guardCount += 1
            }
        }
        UserDefaults.standard.set(index, forKey: lastKey)
        return restTips[index]
    }
}

enum Theme {
    static let accent = NSColor(calibratedRed: 0.93, green: 0.80, blue: 0.55, alpha: 1)
    static let cream = NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.90, alpha: 1)
    static let ink = NSColor(calibratedRed: 0.14, green: 0.12, blue: 0.10, alpha: 1)
    static let dim = NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.06, alpha: 0.52)
}

final class QuietButton: NSButton {
    enum Kind { case primary, ghost }

    convenience init(title: String, kind: Kind) {
        self.init(title: title, target: nil, action: nil)
        bezelStyle = .inline
        isBordered = false
        focusRingType = .none
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.masksToBounds = true
        attributedTitle = Self.attributed(title, kind: kind)
        if kind == .primary {
            layer?.backgroundColor = Theme.cream.cgColor
        } else {
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
            layer?.borderWidth = 1
            layer?.borderColor = NSColor.white.withAlphaComponent(0.38).cgColor
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: max(108, super.intrinsicContentSize.width + 28), height: 36)
    }

    private static func attributed(_ title: String, kind: Kind) -> NSAttributedString {
        let color: NSColor = kind == .primary ? Theme.ink : NSColor.white
        return NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: color,
        ])
    }

    func setQuietTitle(_ title: String, kind: Kind) {
        attributedTitle = Self.attributed(title, kind: kind)
    }
}

final class CoffeeView: NSView {
    private var timer: Timer?
    private let born = CFAbsoluteTimeGetCurrent()

    override var intrinsicContentSize: NSSize { NSSize(width: 120, height: 148) }
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
        drawSteam(time: t, origin: NSPoint(x: cx, y: 86))
        drawCup(centerX: cx)
    }

    private func drawCup(centerX cx: CGFloat) {
        let saucer = NSBezierPath(ovalIn: NSRect(x: cx - 36, y: 16, width: 72, height: 10))
        NSColor.white.withAlphaComponent(0.14).setFill()
        saucer.fill()

        let body = NSBezierPath()
        body.move(to: NSPoint(x: cx - 24, y: 78))
        body.line(to: NSPoint(x: cx + 24, y: 78))
        body.line(to: NSPoint(x: cx + 17, y: 28))
        body.curve(
            to: NSPoint(x: cx - 17, y: 28),
            controlPoint1: NSPoint(x: cx + 14, y: 22),
            controlPoint2: NSPoint(x: cx - 14, y: 22)
        )
        body.close()
        NSColor.white.withAlphaComponent(0.92).setFill()
        body.fill()

        let handle = NSBezierPath()
        handle.appendArc(
            withCenter: NSPoint(x: cx + 24, y: 54),
            radius: 12,
            startAngle: -55,
            endAngle: 55
        )
        NSColor.white.withAlphaComponent(0.78).setStroke()
        handle.lineWidth = 2
        handle.lineCapStyle = .round
        handle.stroke()

        let coffee = NSBezierPath(ovalIn: NSRect(x: cx - 20, y: 68, width: 40, height: 12))
        NSColor(calibratedRed: 0.22, green: 0.14, blue: 0.09, alpha: 0.92).setFill()
        coffee.fill()

        let rim = NSBezierPath(ovalIn: NSRect(x: cx - 25, y: 74, width: 50, height: 12))
        NSColor.white.withAlphaComponent(0.55).setStroke()
        rim.lineWidth = 1.2
        rim.stroke()
    }

    private func drawSteam(time: CGFloat, origin: NSPoint) {
        let wisps: [(x: CGFloat, delay: CGFloat, speed: CGFloat, amp: CGFloat)] = [
            (-6, 0.0, 0.95, 4.2),
            (7, 1.1, 1.18, 5.0),
        ]
        for wisp in wisps {
            let steps = 24
            let height: CGFloat = 52
            var points: [NSPoint] = []
            for i in 0...steps {
                let p = CGFloat(i) / CGFloat(steps)
                let y = origin.y + p * height
                let wave = sin((p * 2.6 + time * wisp.speed + wisp.delay) * .pi)
                points.append(NSPoint(x: origin.x + wisp.x + wave * wisp.amp * (0.25 + p), y: y))
            }
            let pulse = 0.55 + 0.25 * sin(time * wisp.speed + wisp.delay)
            for i in 0..<steps {
                let p = CGFloat(i) / CGFloat(steps)
                let segment = NSBezierPath()
                segment.move(to: points[i])
                segment.line(to: points[i + 1])
                segment.lineCapStyle = .round
                segment.lineWidth = 1.15 * (1 - p * 0.65)
                NSColor.white.withAlphaComponent(0.42 * (1 - p) * pulse).setStroke()
                segment.stroke()
            }
        }
    }
}

final class FactBoxView: NSView {
    let lineLabel = NSTextField(wrappingLabelWithString: "")
    let actionLabel = NSTextField(wrappingLabelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        configure(lineLabel, size: 17, weight: .regular, color: .white, lines: 2)
        configure(actionLabel, size: 14, weight: .medium, color: Theme.accent, lines: 2)

        let stack = NSStackView(views: [lineLabel, actionLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            lineLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actionLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ tip: RestTip) {
        lineLabel.attributedStringValue = centered(tip.line, size: 17, weight: .regular, color: .white, lineSpacing: 6)
        actionLabel.attributedStringValue = centered(tip.action, size: 14, weight: .medium, color: Theme.accent, lineSpacing: 3)
    }

    private func configure(_ field: NSTextField, size: CGFloat, weight: NSFont.Weight, color: NSColor, lines: Int) {
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.alignment = .center
        field.maximumNumberOfLines = lines
        field.lineBreakMode = .byWordWrapping
        field.setContentHuggingPriority(.required, for: .vertical)
    }

    private func centered(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, lineSpacing: CGFloat) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = lineSpacing
        style.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: style,
        ])
    }
}

final class BreakCardView: NSView {
    let coffeeView = CoffeeView(frame: .zero)
    let titleLabel = NSTextField(labelWithString: "休息一下")
    let timeLabel = NSTextField(labelWithString: "")
    let factBox = FactBoxView(frame: .zero)
    let restButton = QuietButton(title: "已阅", kind: .primary)
    let snoozeButton = QuietButton(title: "再忙片刻", kind: .ghost)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.cornerRadius = 28
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.28
        layer?.shadowRadius = 36
        layer?.shadowOffset = CGSize(width: 0, height: -6)

        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.appearance = NSAppearance(named: .darkAqua)
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 28
        blur.layer?.masksToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)

        let veil = NSView()
        veil.wantsLayer = true
        veil.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.42).cgColor
        veil.layer?.cornerRadius = 28
        veil.translatesAutoresizingMaskIntoConstraints = false
        addSubview(veil)

        let border = NSView()
        border.wantsLayer = true
        border.layer?.cornerRadius = 28
        border.layer?.borderWidth = 1
        border.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        addSubview(border)

        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.setContentHuggingPriority(.required, for: .vertical)

        timeLabel.font = .systemFont(ofSize: 12, weight: .regular)
        timeLabel.textColor = NSColor.white.withAlphaComponent(0.55)
        timeLabel.alignment = .center
        timeLabel.setContentHuggingPriority(.required, for: .vertical)

        restButton.keyEquivalent = "\r"
        snoozeButton.keyEquivalent = "\u{1b}"

        let heading = titleLabel

        let buttonRow = NSStackView(views: [snoozeButton, restButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12
        buttonRow.alignment = .centerY
        buttonRow.distribution = .fillEqually

        let stack = NSStackView(views: [
            coffeeView, heading, timeLabel, factBox, buttonRow
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 0
        stack.setCustomSpacing(8, after: coffeeView)
        stack.setCustomSpacing(16, after: heading)
        stack.setCustomSpacing(20, after: timeLabel)
        stack.setCustomSpacing(28, after: factBox)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            veil.leadingAnchor.constraint(equalTo: leadingAnchor),
            veil.trailingAnchor.constraint(equalTo: trailingAnchor),
            veil.topAnchor.constraint(equalTo: topAnchor),
            veil.bottomAnchor.constraint(equalTo: bottomAnchor),
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.trailingAnchor.constraint(equalTo: trailingAnchor),
            border.topAnchor.constraint(equalTo: topAnchor),
            border.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
            heading.widthAnchor.constraint(equalTo: stack.widthAnchor),
            factBox.widthAnchor.constraint(equalTo: stack.widthAnchor),
            timeLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            coffeeView.widthAnchor.constraint(equalToConstant: 108),
            coffeeView.heightAnchor.constraint(equalToConstant: 128),
            restButton.heightAnchor.constraint(equalToConstant: 36),
            snoozeButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(workMinutes: Int, snoozeMinutes: Int) {
        timeLabel.attributedStringValue = NSAttributedString(
            string: "连续看屏 \(workMinutes) 分钟",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: NSColor.white.withAlphaComponent(0.55),
            ]
        )
        factBox.apply(RestTipPicker.next())
        snoozeButton.setQuietTitle("再忙 \(snoozeMinutes) 分钟", kind: .ghost)
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
            window.backgroundColor = Theme.dim
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
                        card.widthAnchor.constraint(equalToConstant: 380),
                    ])
                }
                keyWindow = window
            }

            window.orderFrontRegardless()
            windows.append(window)
            if screen == NSScreen.main, let cardLayer = window.contentView?.subviews.first?.layer {
                cardLayer.transform = CATransform3DMakeScale(0.96, 0.96, 1)
                let scale = CABasicAnimation(keyPath: "transform.scale")
                scale.fromValue = 0.96
                scale.toValue = 1
                scale.duration = 0.38
                scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
                cardLayer.add(scale, forKey: "appear")
                cardLayer.transform = CATransform3DIdentity
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.32
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

final class TimeAxisView: NSView {
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 16) }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let pad: CGFloat = 8
        let inner = bounds.width - pad * 2
        let labels = [0, 6, 12, 18, 24]
        for hour in labels {
            let x = pad + CGFloat(hour) / 24 * inner
            let text = "\(hour)" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.tertiaryLabelColor,
            ]
            let size = text.size(withAttributes: attrs)
            var drawX = x - size.width / 2
            drawX = min(max(drawX, 0), bounds.width - size.width)
            text.draw(at: NSPoint(x: drawX, y: 1), withAttributes: attrs)
        }
    }
}

final class TimeRangeBar: NSView {
    var startMinutes: Int = 9 * 60 {
        didSet { needsDisplay = true }
    }
    var endMinutes: Int = 22 * 60 {
        didSet { needsDisplay = true }
    }
    var onChange: ((Int, Int) -> Void)?

    private enum DragMode {
        case none
        case draw(anchor: Int)
        case start
        case end
        case move(grab: Int)
    }

    private var drag: DragMode = .none
    private let pad: CGFloat = 8

    override var isOpaque: Bool { false }
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 28) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let clicked = snap(minutes(at: convert(event.locationInWindow, from: nil).x))
        let startHit = abs(x(for: startMinutes) - convert(event.locationInWindow, from: nil).x) <= 8
        let endHit = abs(x(for: endMinutes) - convert(event.locationInWindow, from: nil).x) <= 8
        if startHit {
            drag = .start
        } else if endHit {
            drag = .end
        } else if containsMinutes(clicked), startMinutes < endMinutes {
            drag = .move(grab: clicked)
        } else {
            drag = .draw(anchor: clicked)
            startMinutes = clicked
            endMinutes = min(24 * 60, clicked + 15)
            emit()
        }

        var tracking = true
        while tracking {
            guard let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) else { break }
            switch next.type {
            case .leftMouseDragged:
                applyDrag(at: snap(minutes(at: convert(next.locationInWindow, from: nil).x)))
            default:
                finishDrag(at: snap(minutes(at: convert(next.locationInWindow, from: nil).x)))
                tracking = false
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let track = NSRect(x: pad, y: 6, width: bounds.width - pad * 2, height: 16)
        let trackPath = NSBezierPath(roundedRect: track, xRadius: 8, yRadius: 8)
        NSColor.labelColor.withAlphaComponent(0.08).setFill()
        trackPath.fill()

        for hour in stride(from: 0, through: 24, by: 3) {
            let tickX = x(for: hour * 60)
            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: tickX, y: 8))
            tick.line(to: NSPoint(x: tickX, y: 20))
            NSColor.labelColor.withAlphaComponent(hour % 6 == 0 ? 0.22 : 0.10).setStroke()
            tick.lineWidth = 1
            tick.stroke()
        }

        NSGraphicsContext.saveGraphicsState()
        trackPath.addClip()
        NSColor(calibratedRed: 0.78, green: 0.52, blue: 0.24, alpha: 0.92).setFill()
        if startMinutes == endMinutes {
            NSRect(x: track.minX, y: track.minY, width: track.width, height: track.height).fill()
        } else if startMinutes < endMinutes {
            fillRange(from: startMinutes, to: endMinutes, track: track)
        } else {
            fillRange(from: startMinutes, to: 24 * 60, track: track)
            fillRange(from: 0, to: endMinutes, track: track)
        }
        NSGraphicsContext.restoreGraphicsState()

        drawHandle(at: x(for: startMinutes))
        drawHandle(at: x(for: endMinutes))
    }

    private func fillRange(from start: Int, to end: Int, track: NSRect) {
        let left = x(for: start)
        let right = x(for: end)
        NSRect(x: left, y: track.minY, width: max(4, right - left), height: track.height).fill()
    }

    private func drawHandle(at xPos: CGFloat) {
        let rect = NSRect(x: xPos - 6, y: 5, width: 12, height: 18)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        NSColor.white.setFill()
        path.fill()
        NSColor(calibratedRed: 0.62, green: 0.40, blue: 0.18, alpha: 1).setStroke()
        path.lineWidth = 1.2
        path.stroke()
    }

    private func applyDrag(at minutes: Int) {
        switch drag {
        case .draw(let anchor):
            if minutes >= anchor {
                startMinutes = anchor
                endMinutes = max(anchor + 15, minutes)
            } else {
                startMinutes = minutes
                endMinutes = max(minutes + 15, anchor)
            }
        case .start:
            startMinutes = min(minutes, max(endMinutes - 15, 0))
            if startMinutes >= endMinutes { startMinutes = max(0, endMinutes - 15) }
        case .end:
            endMinutes = max(minutes, min(startMinutes + 15, 24 * 60))
            if endMinutes <= startMinutes { endMinutes = min(24 * 60, startMinutes + 15) }
        case .move(let grab):
            let duration = max(15, endMinutes - startMinutes)
            var nextStart = startMinutes + (minutes - grab)
            nextStart = max(0, min(24 * 60 - duration, nextStart))
            startMinutes = nextStart
            endMinutes = nextStart + duration
            drag = .move(grab: minutes)
        case .none:
            break
        }
        emit()
        needsDisplay = true
    }

    private func finishDrag(at minutes: Int) {
        applyDrag(at: minutes)
        if case .draw = drag, endMinutes - startMinutes < 15 {
            endMinutes = min(24 * 60, startMinutes + 60)
            emit()
        }
        drag = .none
        needsDisplay = true
    }

    private func containsMinutes(_ minutes: Int) -> Bool {
        if startMinutes == endMinutes { return true }
        if startMinutes < endMinutes {
            return minutes >= startMinutes && minutes <= endMinutes
        }
        return minutes >= startMinutes || minutes <= endMinutes
    }

    private func x(for minutes: Int) -> CGFloat {
        pad + CGFloat(minutes) / CGFloat(24 * 60) * (bounds.width - pad * 2)
    }

    private func minutes(at xPos: CGFloat) -> Int {
        let inner = max(1, bounds.width - pad * 2)
        let ratio = (xPos - pad) / inner
        return Int((min(1, max(0, Double(ratio))) * Double(24 * 60)).rounded())
    }

    private func snap(_ minutes: Int) -> Int {
        let stepped = Int((Double(minutes) / 15.0).rounded()) * 15
        return max(0, min(24 * 60, stepped))
    }

    private func emit() {
        onChange?(startMinutes, endMinutes)
    }
}

final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let settings: Settings
    private var window: NSWindow?
    var onChange: (() -> Void)?
    private var rangeBars: [Int: TimeRangeBar] = [:]
    private var timeLabels: [Int: NSTextField] = [:]

    init(settings: Settings) {
        self.settings = settings
        super.init()
    }

    func show() {
        if window == nil {
            window = buildWindow()
        }
        reload()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "专注休息 · 设置"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        let content = NSView(frame: window.contentView!.bounds)
        content.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = content

        let title = label("专注休息", font: .systemFont(ofSize: 22, weight: .semibold), color: .labelColor)

        let intervalRow = labeledRow("提醒间隔", control: popup(Settings.intervalChoices.map { "\($0) 分钟" }, select: Int(settings.workMinutes.rounded()), tag: 100, action: #selector(intervalChanged(_:))))
        let snoozeRow = labeledRow("推迟时长", control: popup(Settings.snoozeChoices.map { "\($0) 分钟" }, select: Int(settings.snoozeMinutes.rounded()), tag: 101, action: #selector(snoozeChanged(_:))))

        let scheduleTitle = label("有效时段", font: .systemFont(ofSize: 15, weight: .semibold), color: .labelColor)
        let scheduleHint = label("在时间轴上按住拖一下就能选出时段，吸附到 15 分钟。拖两端微调，拖中间可整体平移。", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        scheduleHint.maximumNumberOfLines = 2

        let dayStack = NSStackView()
        dayStack.orientation = .vertical
        dayStack.spacing = 6
        dayStack.alignment = .leading
        dayStack.translatesAutoresizingMaskIntoConstraints = false
        dayStack.addArrangedSubview(axisRow())
        for weekday in Settings.weekdayOrder {
            dayStack.addArrangedSubview(dayRow(weekday: weekday))
        }
        for view in dayStack.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: dayStack.widthAnchor).isActive = true
        }

        let presetRow = NSStackView(views: [
            presetButton("工作日 9–22", tag: 1),
            presetButton("每天 9–22", tag: 2),
            presetButton("仅工作日白天", tag: 3),
        ])
        presetRow.orientation = .horizontal
        presetRow.spacing = 8

        let stack = NSStackView(views: [
            title, intervalRow, snoozeRow, scheduleTitle, scheduleHint, dayStack, presetRow
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(16, after: title)
        stack.setCustomSpacing(14, after: snoozeRow)
        stack.setCustomSpacing(4, after: scheduleTitle)
        stack.setCustomSpacing(12, after: scheduleHint)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20),
            intervalRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            snoozeRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            dayStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scheduleHint.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])

        return window
    }

    private func label(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = font
        field.textColor = color
        field.lineBreakMode = .byWordWrapping
        return field
    }

    private func labeledRow(_ title: String, control: NSView) -> NSStackView {
        let titleField = label(title, font: .systemFont(ofSize: 13), color: .labelColor)
        titleField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let row = NSStackView(views: [titleField, control])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        return row
    }

    private func popup(_ items: [String], select value: Int, tag: Int, action: Selector) -> NSPopUpButton {
        let button = NSPopUpButton()
        button.addItems(withTitles: items)
        button.tag = tag
        button.target = self
        button.action = action
        if tag == 100, let index = Settings.intervalChoices.firstIndex(of: value) {
            button.selectItem(at: index)
        } else if tag == 101, let index = Settings.snoozeChoices.firstIndex(of: value) {
            button.selectItem(at: index)
        }
        return button
    }

    private func axisRow() -> NSView {
        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.widthAnchor.constraint(equalToConstant: 56).isActive = true

        let axis = TimeAxisView()
        axis.translatesAutoresizingMaskIntoConstraints = false
        axis.setContentHuggingPriority(.init(1), for: .horizontal)
        axis.setContentCompressionResistancePriority(.init(1), for: .horizontal)

        let right = NSView()
        right.translatesAutoresizingMaskIntoConstraints = false
        right.widthAnchor.constraint(equalToConstant: 78).isActive = true

        let row = NSStackView(views: [spacer, axis, right])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        axis.heightAnchor.constraint(equalToConstant: 16).isActive = true
        return row
    }

    private func dayRow(weekday: Int) -> NSView {
        let item = settings.window(for: weekday)
        let check = NSButton(checkboxWithTitle: Settings.weekdayNames[weekday] ?? "", target: self, action: #selector(dayToggled(_:)))
        check.tag = weekday
        check.state = item.enabled ? .on : .off
        check.widthAnchor.constraint(equalToConstant: 56).isActive = true

        let bar = TimeRangeBar()
        bar.startMinutes = item.startMinutes
        bar.endMinutes = item.endMinutes
        bar.alphaValue = item.enabled ? 1 : 0.4
        bar.setContentHuggingPriority(.init(1), for: .horizontal)
        bar.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        bar.onChange = { [weak self] start, end in
            guard let self else { return }
            var next = self.settings.window(for: weekday)
            next.startMinutes = start
            next.endMinutes = end
            self.settings.updateDay(next)
            self.timeLabels[weekday]?.stringValue = "\(DayWindow.label(start))–\(DayWindow.label(end))"
            self.onChange?()
        }
        rangeBars[weekday] = bar

        let timeLabel = label("\(item.startLabel)–\(item.endLabel)", font: .monospacedDigitSystemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor)
        timeLabel.alignment = .right
        timeLabel.widthAnchor.constraint(equalToConstant: 78).isActive = true
        timeLabels[weekday] = timeLabel

        let row = NSStackView(views: [check, bar, timeLabel])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.identifier = NSUserInterfaceItemIdentifier("day-\(weekday)")
        bar.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return row
    }

    private func presetButton(_ title: String, tag: Int) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(applyPreset(_:)))
        button.bezelStyle = .rounded
        button.tag = tag
        return button
    }

    private func reload() {
        for weekday in Settings.weekdayOrder {
            let item = settings.window(for: weekday)
            if let check = window?.contentView.flatMap({ findButton(in: $0, tag: weekday) }) {
                check.state = item.enabled ? .on : .off
            }
            rangeBars[weekday]?.startMinutes = item.startMinutes
            rangeBars[weekday]?.endMinutes = item.endMinutes
            rangeBars[weekday]?.alphaValue = item.enabled ? 1 : 0.4
            timeLabels[weekday]?.stringValue = "\(item.startLabel)–\(item.endLabel)"
        }
    }

    private func findButton(in view: NSView, tag: Int) -> NSButton? {
        if let button = view as? NSButton, button.tag == tag, button.action == #selector(dayToggled(_:)) {
            return button
        }
        for child in view.subviews {
            if let found = findButton(in: child, tag: tag) { return found }
        }
        return nil
    }

    @objc private func intervalChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard Settings.intervalChoices.indices.contains(index) else { return }
        settings.workMinutes = Double(Settings.intervalChoices[index])
        settings.persist()
        onChange?()
    }

    @objc private func snoozeChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard Settings.snoozeChoices.indices.contains(index) else { return }
        settings.snoozeMinutes = Double(Settings.snoozeChoices[index])
        settings.persist()
        onChange?()
    }

    @objc private func dayToggled(_ sender: NSButton) {
        var item = settings.window(for: sender.tag)
        item.enabled = sender.state == .on
        settings.updateDay(item)
        rangeBars[sender.tag]?.alphaValue = item.enabled ? 1 : 0.4
        onChange?()
    }

    @objc private func applyPreset(_ sender: NSButton) {
        switch sender.tag {
        case 1:
            for weekday in 1...7 {
                let weekend = weekday == 1 || weekday == 7
                settings.updateDay(DayWindow(weekday: weekday, enabled: !weekend, startMinutes: 9 * 60, endMinutes: 22 * 60))
            }
        case 2:
            for weekday in 1...7 {
                settings.updateDay(DayWindow(weekday: weekday, enabled: true, startMinutes: 9 * 60, endMinutes: 22 * 60))
            }
        default:
            for weekday in 1...7 {
                let weekend = weekday == 1 || weekday == 7
                settings.updateDay(DayWindow(weekday: weekday, enabled: !weekend, startMinutes: 9 * 60, endMinutes: 18 * 60))
            }
        }
        reload()
        onChange?()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings: Settings
    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var scheduleWatch: Timer?
    private var nextFireDate: Date?
    private var remaining: TimeInterval = 0
    private var tickingFrom: Date?
    private var paused = false
    private var isLocked = false
    private var isSleeping = false
    private var isSessionInactive = false
    private let overlay = OverlayController()
    private var showingBreak = false
    private var settingsWindow: SettingsWindowController?

    private var canTick: Bool {
        !paused && !showingBreak && !isLocked && !isSleeping && !isSessionInactive && remaining > 0 && settings.isInActiveWindow()
    }

    init(settings: Settings) {
        self.settings = settings
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        isLocked = Self.screenCurrentlyLocked()
        setupStatusItem()
        observeLockAndSleep()
        startScheduleWatch()

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
            showBreak(force: true)
        } else {
            scheduleNext(minutes: settings.workMinutes)
        }
    }

    private func startScheduleWatch() {
        let watch = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.syncWithSchedule()
        }
        RunLoop.main.add(watch, forMode: .common)
        scheduleWatch = watch
    }

    private func syncWithSchedule() {
        if canTick {
            if tickingFrom == nil {
                resumeCountdownIfPossible()
            }
        } else if tickingFrom != nil {
            freezeCountdown()
            rebuildMenu()
        } else {
            rebuildMenu()
        }
    }

    private func observeLockAndSleep() {
        let dist = DistributedNotificationCenter.default()
        dist.addObserver(self, selector: #selector(screenLocked), name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        dist.addObserver(self, selector: #selector(screenUnlocked), name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        workspace.addObserver(self, selector: #selector(sessionResignActive), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspace.addObserver(self, selector: #selector(sessionBecomeActive), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    }

    private static func screenCurrentlyLocked() -> Bool {
        guard let info = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (info["CGSSessionScreenIsLocked"] as? Bool) == true
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "专注休息") {
            image.isTemplate = true
            item.button?.image = image
        } else {
            item.button?.title = "☕"
        }
        item.button?.toolTip = "专注休息"
        statusItem = item
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let nextItem = NSMenuItem(title: nextTitle(), action: nil, keyEquivalent: "")
        nextItem.isEnabled = false
        menu.addItem(nextItem)

        let todayItem = NSMenuItem(title: settings.todaySummary(), action: nil, keyEquivalent: "")
        todayItem.isEnabled = false
        menu.addItem(todayItem)
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

        let settingsItem = NSMenuItem(title: "设置有效时段…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

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
        if isLocked || isSleeping || isSessionInactive { return "锁屏中，计时已暂停" }
        if showingBreak { return "正在提醒休息" }
        if !settings.isInActiveWindow() { return "不在有效时段" }
        guard let nextFireDate else { return "尚未安排下次提醒" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "下次提醒 \(formatter.string(from: nextFireDate))"
    }

    private func freezeCountdown() {
        if let tickingFrom {
            remaining -= Date().timeIntervalSince(tickingFrom)
            remaining = max(remaining, 1)
            self.tickingFrom = nil
        }
        timer?.invalidate()
        timer = nil
        nextFireDate = nil
    }

    private func resumeCountdownIfPossible() {
        guard canTick else {
            rebuildMenu()
            return
        }
        guard tickingFrom == nil else { return }
        tickingFrom = Date()
        nextFireDate = Date().addingTimeInterval(remaining)
        timer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            self?.countdownFired()
        }
        RunLoop.main.add(timer!, forMode: .common)
        rebuildMenu()
    }

    private func scheduleNext(minutes: Double) {
        freezeCountdown()
        remaining = max(minutes * 60, 6)
        resumeCountdownIfPossible()
    }

    private func countdownFired() {
        tickingFrom = nil
        remaining = 0
        timer = nil
        nextFireDate = nil
        if isLocked || isSleeping || isSessionInactive || paused || !settings.isInActiveWindow() { return }
        showBreak()
    }

    private func showBreak(force: Bool = false) {
        if !force, paused || isLocked || isSleeping || isSessionInactive || !settings.isInActiveWindow() { return }
        showingBreak = true
        freezeCountdown()
        remaining = 0
        overlay.show(
            workMinutes: Int(settings.workMinutes.rounded()),
            snoozeMinutes: Int(settings.snoozeMinutes.rounded())
        )
        rebuildMenu()
    }

    @objc private func screenLocked() {
        DispatchQueue.main.async { [weak self] in
            self?.isLocked = true
            self?.freezeCountdown()
            self?.rebuildMenu()
        }
    }

    @objc private func screenUnlocked() {
        DispatchQueue.main.async { [weak self] in
            self?.isLocked = false
            self?.resumeCountdownIfPossible()
        }
    }

    @objc private func systemWillSleep() {
        DispatchQueue.main.async { [weak self] in
            self?.isSleeping = true
            self?.freezeCountdown()
            self?.rebuildMenu()
        }
    }

    @objc private func systemDidWake() {
        DispatchQueue.main.async { [weak self] in
            self?.isSleeping = false
            self?.isLocked = Self.screenCurrentlyLocked()
            self?.resumeCountdownIfPossible()
        }
    }

    @objc private func sessionResignActive() {
        DispatchQueue.main.async { [weak self] in
            self?.isSessionInactive = true
            self?.freezeCountdown()
            self?.rebuildMenu()
        }
    }

    @objc private func sessionBecomeActive() {
        DispatchQueue.main.async { [weak self] in
            self?.isSessionInactive = false
            self?.isLocked = Self.screenCurrentlyLocked()
            self?.resumeCountdownIfPossible()
        }
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

    @objc private func openSettings() {
        if settingsWindow == nil {
            let controller = SettingsWindowController(settings: settings)
            controller.onChange = { [weak self] in
                guard let self else { return }
                if !self.paused, !self.showingBreak {
                    self.freezeCountdown()
                    self.resumeCountdownIfPossible()
                } else {
                    self.rebuildMenu()
                }
            }
            settingsWindow = controller
        }
        settingsWindow?.show()
    }

    @objc private func showNow() {
        showBreak(force: true)
    }

    @objc private func togglePause() {
        paused.toggle()
        if paused {
            freezeCountdown()
            if showingBreak { finishBreak() }
            rebuildMenu()
        } else {
            if remaining <= 1 {
                remaining = max(settings.workMinutes * 60, 6)
            }
            resumeCountdownIfPossible()
        }
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
