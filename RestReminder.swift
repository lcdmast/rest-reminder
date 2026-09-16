import Cocoa
import CoreGraphics

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

struct HealthTip {
    let tag: String
    let harm: String
    let action: String
}

let healthTips: [HealthTip] = [
    HealthTip(
        tag: "眼睛",
        harm: "盯屏幕时眨眼会明显变少，泪膜容易破，出现干涩、发红、怕光。这是电脑视觉综合征里最常见的一组。",
        action: "刻意多眨几下眼，再看向 6 米外 20 秒。"
    ),
    HealthTip(
        tag: "眼睛",
        harm: "近处对焦过久，睫状肌一直绷着，容易视疲劳、发糊、头痛。美国视光协会建议用 20-20-20 护眼。",
        action: "每 20 分钟，看 20 英尺外（约 6 米）20 秒。"
    ),
    HealthTip(
        tag: "眼睛",
        harm: "屏幕过高或凑太近，眼睛和脖子会一起出力。电脑视觉综合征里，头痛、颈肩痛也很常见。",
        action: "把屏幕放到略低于视线，身体坐直，离屏约一臂。"
    ),
    HealthTip(
        tag: "颈椎",
        harm: "头往前探时，脖子像在扛额外重量。办公室人群里，颈痛是最常报的不适之一。",
        action: "收回下巴，轻轻左右看看，不要猛转或后甩。"
    ),
    HealthTip(
        tag: "肩颈",
        harm: "屏幕太高会逼着你仰头，太低又会低头。两种姿势都会让斜方肌和颈椎一直紧张。",
        action: "屏幕上沿略低于眼睛，双肩放下，不要耸着敲键盘。"
    ),
    HealthTip(
        tag: "腰椎",
        harm: "坐着时腰椎负担比站着更大，腰背肌长时间绷着，容易酸胀、劳损。",
        action: "站起来走一圈，把腰伸直，靠椅时让腰有支撑。"
    ),
    HealthTip(
        tag: "循环",
        harm: "久坐时小腿血液回流变慢，脚容易胀、发麻。把久坐换成任何强度的活动，都有好处。",
        action: "踮踮脚，或离开座位走两分钟。"
    ),
    HealthTip(
        tag: "代谢",
        harm: "世卫组织指出：坐得越多，心血管病和 2 型糖尿病风险越高。换成轻度活动也算数。",
        action: "去倒杯水，顺便活动一下，别在椅子上再续一局。"
    ),
    HealthTip(
        tag: "肩背",
        harm: "含胸对着屏幕，肩胛和上背会发紧，呼吸也变浅，时间长了肩就抬不下来。",
        action: "打开肩膀，双手后展，慢慢深吸一口气。"
    ),
    HealthTip(
        tag: "手腕",
        harm: "鼠标键盘姿势固定过久，手腕和前臂持续紧张，容易酸胀、发麻。",
        action: "松开鼠标，转转手腕，把手指全部张开再握拢。"
    ),
    HealthTip(
        tag: "髋部",
        harm: "久坐会让髋屈肌变短变紧，站起来时腰更容易往前顶，走路也发僵。",
        action: "站起来，脚在后、髋轻轻打开，左右各停几秒。"
    ),
    HealthTip(
        tag: "情绪",
        harm: "久坐不只伤身子。研究里，坐得久还和情绪低落等风险升高有关，动一动能换状态。",
        action: "去窗边站一会儿，看看远处，把视线从屏幕上拿开。"
    ),
]

enum HealthTipPicker {
    static let lastKey = "rest.lastHealthTip"

    static func next() -> HealthTip {
        let last = UserDefaults.standard.integer(forKey: lastKey)
        var index = Int.random(in: 0..<healthTips.count)
        if healthTips.count > 1 {
            var guardCount = 0
            while index == last, guardCount < 8 {
                index = Int.random(in: 0..<healthTips.count)
                guardCount += 1
            }
        }
        UserDefaults.standard.set(index, forKey: lastKey)
        return healthTips[index]
    }
}

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

final class FactBoxView: NSView {
    let tagLabel = NSTextField(labelWithString: "")
    let harmLabel = NSTextField(wrappingLabelWithString: "")
    let actionLabel = NSTextField(wrappingLabelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.10).cgColor

        tagLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        tagLabel.textColor = NSColor(calibratedRed: 0.85, green: 0.62, blue: 0.32, alpha: 1)
        tagLabel.alignment = .left

        harmLabel.font = .systemFont(ofSize: 14)
        harmLabel.textColor = .labelColor
        harmLabel.maximumNumberOfLines = 4
        harmLabel.alignment = .left

        actionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        actionLabel.textColor = NSColor(calibratedRed: 0.93, green: 0.84, blue: 0.68, alpha: 1)
        actionLabel.maximumNumberOfLines = 2
        actionLabel.alignment = .left

        let stack = NSStackView(views: [tagLabel, harmLabel, actionLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.setCustomSpacing(10, after: harmLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            tagLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            harmLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actionLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ tip: HealthTip) {
        tagLabel.stringValue = tip.tag
        harmLabel.stringValue = tip.harm
        actionLabel.stringValue = "现在：\(tip.action)"
    }
}

final class BreakCardView: NSView {
    let coffeeView = CoffeeView(frame: .zero)
    let titleLabel = NSTextField(labelWithString: "圣上保重龙体")
    let mottoLabel = NSTextField(labelWithString: "工作娱乐固重要，身体更重要")
    let timeLabel = NSTextField(labelWithString: "")
    let factBox = FactBoxView(frame: .zero)
    let restButton = NSButton(title: "已阅", target: nil, action: nil)
    let snoozeButton = NSButton(title: "再忙片刻", target: nil, action: nil)

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

        titleLabel.font = .systemFont(ofSize: 26, weight: .semibold)
        titleLabel.alignment = .center

        mottoLabel.font = .systemFont(ofSize: 13, weight: .regular)
        mottoLabel.textColor = .secondaryLabelColor
        mottoLabel.alignment = .center

        timeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        timeLabel.textColor = .tertiaryLabelColor
        timeLabel.alignment = .center

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
            coffeeView, titleLabel, mottoLabel, timeLabel, factBox, buttonRow
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.setCustomSpacing(2, after: coffeeView)
        stack.setCustomSpacing(10, after: timeLabel)
        stack.setCustomSpacing(16, after: factBox)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 26),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -26),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            factBox.widthAnchor.constraint(equalTo: stack.widthAnchor),
            timeLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            coffeeView.widthAnchor.constraint(equalToConstant: 160),
            coffeeView.heightAnchor.constraint(equalToConstant: 176),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(workMinutes: Int, snoozeMinutes: Int) {
        timeLabel.stringValue = "已经连续对着屏幕 \(workMinutes) 分钟了"
        factBox.apply(HealthTipPicker.next())
        snoozeButton.title = "再忙 \(snoozeMinutes) 分钟"
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
                        card.widthAnchor.constraint(equalToConstant: 460),
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

final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let settings: Settings
    private var window: NSWindow?
    var onChange: (() -> Void)?

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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
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
        let motto = label("工作娱乐固重要，身体更重要。圣上保重龙体。", font: .systemFont(ofSize: 13), color: .secondaryLabelColor)
        motto.maximumNumberOfLines = 2

        let intervalRow = labeledRow("提醒间隔", control: popup(Settings.intervalChoices.map { "\($0) 分钟" }, select: Int(settings.workMinutes.rounded()), tag: 100, action: #selector(intervalChanged(_:))))
        let snoozeRow = labeledRow("推迟时长", control: popup(Settings.snoozeChoices.map { "\($0) 分钟" }, select: Int(settings.snoozeMinutes.rounded()), tag: 101, action: #selector(snoozeChanged(_:))))

        let scheduleTitle = label("有效时段", font: .systemFont(ofSize: 15, weight: .semibold), color: .labelColor)
        let scheduleHint = label("只有勾选且处于该时段，才会累计专注时间并提醒休息。结束时间早于开始时间，表示跨过午夜。", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        scheduleHint.maximumNumberOfLines = 2

        let dayStack = NSStackView()
        dayStack.orientation = .vertical
        dayStack.spacing = 8
        dayStack.alignment = .leading
        dayStack.translatesAutoresizingMaskIntoConstraints = false
        for weekday in Settings.weekdayOrder {
            dayStack.addArrangedSubview(dayRow(weekday: weekday))
        }

        let presetRow = NSStackView(views: [
            presetButton("工作日 9–22", tag: 1),
            presetButton("每天 9–22", tag: 2),
            presetButton("仅工作日白天", tag: 3),
        ])
        presetRow.orientation = .horizontal
        presetRow.spacing = 8

        let stack = NSStackView(views: [
            title, motto, intervalRow, snoozeRow, scheduleTitle, scheduleHint, dayStack, presetRow
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(4, after: title)
        stack.setCustomSpacing(16, after: motto)
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
            motto.widthAnchor.constraint(equalTo: stack.widthAnchor),
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

    private func dayRow(weekday: Int) -> NSView {
        let item = settings.window(for: weekday)
        let check = NSButton(checkboxWithTitle: Settings.weekdayNames[weekday] ?? "", target: self, action: #selector(dayToggled(_:)))
        check.tag = weekday
        check.state = item.enabled ? .on : .off
        check.widthAnchor.constraint(equalToConstant: 56).isActive = true

        let start = timePicker(minutes: item.startMinutes, weekday: weekday, isStart: true)
        let to = label("至", font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
        let end = timePicker(minutes: item.endMinutes, weekday: weekday, isStart: false)

        let row = NSStackView(views: [check, start, to, end])
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.identifier = NSUserInterfaceItemIdentifier("day-\(weekday)")
        return row
    }

    private func timePicker(minutes: Int, weekday: Int, isStart: Bool) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = .hourMinute
        picker.locale = Locale(identifier: "zh_CN")
        picker.tag = weekday * 10 + (isStart ? 1 : 2)
        picker.dateValue = date(from: minutes)
        picker.target = self
        picker.action = #selector(timeChanged(_:))
        return picker
    }

    private func presetButton(_ title: String, tag: Int) -> NSButton {
        let button = NSButton(title: title, target: self, action: #selector(applyPreset(_:)))
        button.bezelStyle = .rounded
        button.tag = tag
        return button
    }

    private func date(from minutes: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: minutes / 60, minute: minutes % 60)) ?? Date()
    }

    private func minutes(from date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    private func reload() {
        guard let content = window?.contentView else { return }
        for weekday in Settings.weekdayOrder {
            let item = settings.window(for: weekday)
            if let check = findButton(in: content, tag: weekday) {
                check.state = item.enabled ? .on : .off
            }
            if let start = findPicker(in: content, tag: weekday * 10 + 1) {
                start.dateValue = date(from: item.startMinutes)
            }
            if let end = findPicker(in: content, tag: weekday * 10 + 2) {
                end.dateValue = date(from: item.endMinutes)
            }
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

    private func findPicker(in view: NSView, tag: Int) -> NSDatePicker? {
        if let picker = view as? NSDatePicker, picker.tag == tag { return picker }
        for child in view.subviews {
            if let found = findPicker(in: child, tag: tag) { return found }
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
        onChange?()
    }

    @objc private func timeChanged(_ sender: NSDatePicker) {
        let weekday = sender.tag / 10
        let isStart = sender.tag % 10 == 1
        var item = settings.window(for: weekday)
        let value = minutes(from: sender.dateValue)
        if isStart {
            item.startMinutes = value
        } else {
            item.endMinutes = value
        }
        settings.updateDay(item)
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
