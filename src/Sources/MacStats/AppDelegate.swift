import AppKit
import SwiftUI
import ServiceManagement
import WidgetKit
import UserNotifications
import MacStatsCore

/// 一个桌面小组件实例：一块独立的面板，尺寸/位置/版式互不影响。
@MainActor
final class WidgetInstance {
    let id: String
    let panel: WidgetPanel
    let hosting: NSHostingView<WidgetView>
    let isPrimary: Bool

    init(id: String, panel: WidgetPanel, hosting: NSHostingView<WidgetView>, isPrimary: Bool) {
        self.id = id
        self.panel = panel
        self.hosting = hosting
        self.isPrimary = isPrimary
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum Key {
        static let frame = "panelFrame"
        static let extraWidgets = "extraWidgets"
        static let floating = "floatingLevel"
        static let clickThrough = "clickThrough"
        static let interval = "refreshInterval"
        static let visible = "panelVisible"
        static let cleanupWhitelist = "cleanupWhitelist"
        static let appLanguage = "appLanguage"
        static let appearanceMode = "appearanceMode"
        static let accentTint = "accentTint"
        static let smoothingWindow = "smoothingWindow"
        static let startHidden = "startHidden"
        static let notifyOnCleanup = "notifyOnCleanup"
        static let soundEffects = "soundEffects"
        static let memoryAlert = "memoryAlert"
        static let cleanupMinimumIdle = "cleanupMinimumIdle"
        static let cleanupMinMemoryMB = "cleanupMinMemoryMB"
        static let topProcessesCount = "topProcessesCount"
        static let processSort = "processSort"
        static let showMenuBarStats = "showMenuBarStats"
        static let historyEnabled = "historyEnabled"
        static let historyRetentionDays = "historyRetentionDays"
        static let thresholdAlerts = "thresholdAlerts"
    }

    private let defaults = UserDefaults.standard
    private let sampler = SystemSampler(config: SamplerConfig(processLimit: 24, processInterval: 3))
    private let cleaner = ProcessCleaner()
    private let viewModel = WidgetViewModel()

    // 清理候选靠「多久没干活」判断，所以要周期性观察进程表；1 秒一次没必要，30 秒一够。
    private var lastCleanupObservation = Date.distantPast
    private static let cleanupObservationInterval: TimeInterval = 30

    private var instances: [WidgetInstance] = []
    private var statusItem: NSStatusItem?
    private var tickTask: Task<Void, Never>?
    private var warmUpTask: Task<Void, Never>?
    private var isSampling = false

    // 活动监视器默认每 5 秒刷新，速率类指标按同样长度的滑动窗口平均后展示。
    var smoothingWindow = 5
    private var cpuUserRing = MetricRing(capacity: 5)
    private var cpuSystemRing = MetricRing(capacity: 5)

    // 写给系统小组件（WidgetKit）的快照。显示的数值有变化时最快 30 秒推一次，
    // 长时间不变则 60 秒心跳一次；没装小组件时一步都不做（见 publishWidgetFeed）。
    private var memoryRing = MetricRing(capacity: 60)
    private var lastWidgetReload = Date.distantPast
    private var lastWidgetSignature: WidgetFeedSignature?
    private static let widgetPublishInterval: TimeInterval = 30
    private static let widgetHeartbeatInterval: TimeInterval = 60
    private var lastMemoryAlert = Date.distantPast

    // 历史：每秒采样在内存里按分钟聚合，跨分钟才写一行 JSONL。
    private var historyStore: HistoryStore?
    private let thresholdEvaluator = ThresholdAlertEvaluator()

    private var interval: TimeInterval = 1
    private var isFloating = false
    private var isClickThrough = false
    private var isVisible = true

    var appLanguage: AppLanguage = .system
    var appearanceMode: AppAppearance = .system
    var accentTint: AccentTintColor = .vibrant
    var startHidden = false
    var notifyOnCleanupEnabled = true
    var soundEffectsEnabled = true
    var memoryAlertEnabled = false
    var cleanupMinimumIdle: TimeInterval = 600
    var cleanupMinMemoryMB: Int = 20
    var topProcessesCount: Int = 5
    /// 进程榜口径：内存（默认）或 CPU。存在偏好里，重开面板沿用上次的榜。
    var processSort: ProcessSort = .memory
    var showMenuBarStats = true
    var historyEnabled = true
    var historyRetentionDays = 30
    var thresholdAlertsEnabled = false

    private var visibleItem: NSMenuItem?
    private var removeAllItem: NSMenuItem?

    // 设置窗口：状态镜像在 SettingsModel 里，窗口只在需要时创建。
    private lazy var settingsModel = SettingsModel(app: self)
    private var settingsWindow: NSWindow?

    private var primary: WidgetInstance? { instances.first(where: { $0.isPrimary }) }
    private var extras: [WidgetInstance] { instances.filter { !$0.isPrimary } }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let icon = AppIcon.image {
            NSApp.applicationIconImage = icon
        }
        loadPreferences()
        setupMainMenu()
        setupStatusItem()
        setupWidgets()
        setupNotifications()
        warmUp()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        historyStore?.flush()
        persist()
        warmUpTask?.cancel()
        tickTask?.cancel()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        let wsCenter = NSWorkspace.shared.notificationCenter
        wsCenter.addObserver(
            self,
            selector: #selector(systemWillSleep(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        wsCenter.addObserver(
            self,
            selector: #selector(systemDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func screenParametersDidChange(_ note: Notification) {
        for instance in instances {
            let currentFrame = instance.panel.frame
            let validFrame = sanitized(currentFrame)
            if validFrame != currentFrame {
                instance.panel.setFrame(validFrame, display: true)
            }
        }
        persist()
    }

    @objc private func systemWillSleep(_ note: Notification) {
        warmUpTask?.cancel()
        warmUpTask = nil
        tickTask?.cancel()
        tickTask = nil
    }

    @objc private func systemDidWake(_ note: Notification) {
        sampler.resetBaseline()
        warmUp()
    }

    private func loadPreferences() {
        if defaults.object(forKey: Key.interval) != nil {
            interval = max(0.5, defaults.double(forKey: Key.interval))
        }
        isFloating = defaults.bool(forKey: Key.floating)
        isClickThrough = defaults.bool(forKey: Key.clickThrough)
        if defaults.object(forKey: Key.visible) != nil {
            isVisible = defaults.bool(forKey: Key.visible)
        }
        cleaner.updateWhitelist(Set(defaults.stringArray(forKey: Key.cleanupWhitelist) ?? []))

        if let langStr = defaults.string(forKey: Key.appLanguage), let lang = AppLanguage(rawValue: langStr) {
            appLanguage = lang
            L10n.shared.setLanguage(lang)
        } else {
            appLanguage = .system
            L10n.shared.setLanguage(.system)
        }

        if let modeStr = defaults.string(forKey: Key.appearanceMode), let mode = AppAppearance(rawValue: modeStr) {
            appearanceMode = mode
            applyAppearance(mode)
        }

        if let tintStr = defaults.string(forKey: Key.accentTint), let tint = AccentTintColor(rawValue: tintStr) {
            accentTint = tint
            Theme.accentStyle = tint
        }

        if defaults.object(forKey: Key.smoothingWindow) != nil {
            smoothingWindow = max(1, defaults.integer(forKey: Key.smoothingWindow))
        }
        cpuUserRing = MetricRing(capacity: smoothingWindow)
        cpuSystemRing = MetricRing(capacity: smoothingWindow)

        if defaults.object(forKey: Key.startHidden) != nil {
            startHidden = defaults.bool(forKey: Key.startHidden)
            if startHidden {
                isVisible = false
            }
        }

        if defaults.object(forKey: Key.notifyOnCleanup) != nil {
            notifyOnCleanupEnabled = defaults.bool(forKey: Key.notifyOnCleanup)
        }
        if defaults.object(forKey: Key.soundEffects) != nil {
            soundEffectsEnabled = defaults.bool(forKey: Key.soundEffects)
        }
        if defaults.object(forKey: Key.memoryAlert) != nil {
            memoryAlertEnabled = defaults.bool(forKey: Key.memoryAlert)
        }

        if defaults.object(forKey: Key.cleanupMinimumIdle) != nil {
            cleanupMinimumIdle = max(60, defaults.double(forKey: Key.cleanupMinimumIdle))
        }
        cleaner.updateMinimumIdle(cleanupMinimumIdle)

        if defaults.object(forKey: Key.cleanupMinMemoryMB) != nil {
            cleanupMinMemoryMB = max(0, defaults.integer(forKey: Key.cleanupMinMemoryMB))
        }
        cleaner.updateMinimumMemory(UInt64(cleanupMinMemoryMB) * 1024 * 1024)

        if defaults.object(forKey: Key.topProcessesCount) != nil {
            topProcessesCount = max(1, defaults.integer(forKey: Key.topProcessesCount))
        }
        // 缺失或旧版本写坏时回落内存榜，不因偏好异常让面板空掉。
        processSort = ProcessSort.stored(defaults.string(forKey: Key.processSort))

        if defaults.object(forKey: Key.showMenuBarStats) != nil {
            showMenuBarStats = defaults.bool(forKey: Key.showMenuBarStats)
        }
        if defaults.object(forKey: Key.historyEnabled) != nil {
            historyEnabled = defaults.bool(forKey: Key.historyEnabled)
        }
        if defaults.object(forKey: Key.historyRetentionDays) != nil {
            historyRetentionDays = max(1, defaults.integer(forKey: Key.historyRetentionDays))
        }
        if defaults.object(forKey: Key.thresholdAlerts) != nil {
            thresholdAlertsEnabled = defaults.bool(forKey: Key.thresholdAlerts)
        }
        setupHistoryStore()

        viewModel.data.refreshInterval = interval
        viewModel.data.processSort = processSort
    }

    // MARK: - Menu bar

    func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L10n.t(.menuAbout), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        let settings = NSMenuItem(title: L10n.t(.menuSettings), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: L10n.t(.menuQuit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "gauge.with.needle", accessibilityDescription: L10n.t(.widgetTitle))
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.title = "—"
            button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked() {
        let isSecondary = NSApp.currentEvent?.type == .rightMouseUp
            || (NSApp.currentEvent?.modifierFlags.contains(.control) == true)
        if isSecondary {
            showMenu()
        } else {
            togglePanel()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let visibility = NSMenuItem(title: isVisible ? L10n.t(.menuHideWidget) : L10n.t(.menuShowWidget), action: #selector(togglePanelAction), keyEquivalent: "")
        visibility.target = self
        menu.addItem(visibility)
        visibleItem = visibility

        // 极简条状与标准面板之间的一键切换：标题按当前形态写，点一下就换。
        if let primary {
            let isStrip = WidgetLayout.resolve(primary.panel.frame.size) == .micro
            let switchItem = NSMenuItem(
                title: isStrip ? L10n.t(.menuExpandToStandard) : L10n.t(.menuCollapseToMicro),
                action: #selector(toggleLayout(_:)),
                keyEquivalent: ""
            )
            switchItem.target = self
            switchItem.representedObject = primary.id
            menu.addItem(switchItem)
        }

        let addItem = NSMenuItem(title: L10n.t(.menuAddWidget), action: nil, keyEquivalent: "")
        let addMenu = NSMenu()
        for layout in WidgetLayout.allCases {
            let size = layout.presetSize
            let entry = NSMenuItem(
                title: "\(layout.localizedName)　\(Int(size.width))×\(Int(size.height))",
                action: #selector(addWidget(_:)),
                keyEquivalent: ""
            )
            entry.target = self
            entry.representedObject = layout.rawValue
            addMenu.addItem(entry)
        }
        addMenu.addItem(NSMenuItem.separator())
        let removeAll = NSMenuItem(title: L10n.t(.menuRemoveAllWidgets), action: #selector(removeAllWidgets), keyEquivalent: "")
        removeAll.target = self
        removeAll.isEnabled = !extras.isEmpty
        addMenu.addItem(removeAll)
        removeAllItem = removeAll
        addItem.submenu = addMenu
        menu.addItem(addItem)

        menu.addItem(NSMenuItem.separator())

        let cleanup = NSMenuItem(title: L10n.t(.menuRunCleanup), action: #selector(runCleanup), keyEquivalent: "")
        cleanup.target = self
        menu.addItem(cleanup)
        menu.addItem(cleanupWhitelistMenuItem())

        menu.addItem(NSMenuItem.separator())

        let open = NSMenuItem(title: L10n.t(.menuOpenActivityMonitor), action: #selector(openActivityMonitor), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let settingsItem = NSMenuItem(title: L10n.t(.menuSettings), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: L10n.t(.menuQuit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    func menuWillOpen(_ menu: NSMenu) {
        visibleItem?.title = isVisible ? L10n.t(.menuHideWidget) : L10n.t(.menuShowWidget)
        removeAllItem?.isEnabled = !extras.isEmpty
    }

    // MARK: - Widgets

    private func setupWidgets() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        // 新装默认是极简条状：四个数一行，贴在菜单栏下面当指示灯，开销也最小。
        // 想展开成完整面板，右键菜单里一下就能切（"展开为标准面板"）。
        let strip = WidgetLayout.micro.presetSize

        let primaryFrame: NSRect
        if let saved = defaults.string(forKey: Key.frame), !saved.isEmpty {
            primaryFrame = NSRectFromString(saved)
        } else {
            primaryFrame = NSRect(
                x: screen.maxX - strip.width - 28,
                y: screen.maxY - strip.height - 12,
                width: strip.width,
                height: strip.height
            )
        }
        let main = makeInstance(id: "main", frame: sanitized(primaryFrame), isPrimary: true)
        instances.append(main)
        if isVisible {
            main.panel.orderFrontRegardless()
        }

        for record in storedExtras() {
            let frame = NSRectFromString(record.frame)
            guard frame.width > 0, frame.height > 0 else { continue }
            let instance = makeInstance(id: record.id, frame: sanitized(frame), isPrimary: false)
            instances.append(instance)
            if isVisible {
                instance.panel.orderFrontRegardless()
            }
        }

        logDebug()
    }

    /// 屏幕布局变了（拔掉外接屏、改分辨率）时，旧坐标可能落在屏幕外；
    /// 中心点不在任何可见区域内的，挪回主屏右下角，并保证尺寸与位置均在有效区域内。
    private func sanitized(_ frame: NSRect) -> NSRect {
        let screens = NSScreen.screens.map(\.visibleFrame)
        let center = NSPoint(x: frame.midX, y: frame.midY)
        if screens.contains(where: { $0.contains(center) }) { return frame }
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width = min(frame.width, screen.width)
        let height = min(frame.height, screen.height)
        let x = min(max(screen.minX + 12, screen.maxX - width - 28), screen.maxX - width)
        let y = min(max(screen.minY + 12, screen.minY + 28), screen.maxY - height)
        return NSRect(
            x: x,
            y: y,
            width: width,
            height: height
        )
    }

    private func makeInstance(id: String, frame: NSRect, isPrimary: Bool) -> WidgetInstance {
        let bounds = NSRect(origin: .zero, size: frame.size)
        let hosting = NSHostingView(rootView: makeView())
        hosting.frame = bounds
        hosting.autoresizingMask = [.width, .height]

        // NSHostingView 每次重设 rootView 都会重建自己的子视图，
        // 所以缩放柄不能直接挂在它上面，得用一层容器托住。
        let container = NSView(frame: bounds)
        container.autoresizesSubviews = true
        container.addSubview(hosting)

        let panel = WidgetPanel(contentRect: bounds)
        panel.contentView = container
        panel.setContentSize(frame.size)
        panel.setFrame(frame, display: false)
        panel.ignoresMouseEvents = isClickThrough
        applyLevel(to: panel)
        attachGrip(to: container)
        panel.contextMenuProvider = { [weak self] in
            self?.widgetMenu(id: id, isPrimary: isPrimary) ?? NSMenu()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidChangeFrame(_:)),
            name: NSWindow.didMoveNotification,
            object: panel
        )

        return WidgetInstance(id: id, panel: panel, hosting: hosting, isPrimary: isPrimary)
    }

    private func attachGrip(to container: NSView) {
        let side: CGFloat = 22
        let grip = ResizeGripView(frame: NSRect(x: container.bounds.width - side, y: 0, width: side, height: side))
        grip.autoresizingMask = [.minXMargin, .maxYMargin]
        grip.minimumSize = WidgetLayout.minimumSize
        grip.onResize = { [weak self] _ in self?.persist() }
        container.addSubview(grip)
    }

    @objc private func panelDidChangeFrame(_ note: Notification) {
        persist()
    }

    private func makeView() -> WidgetView {
        WidgetView(
            model: viewModel,
            onRefresh: { [weak self] in self?.triggerTick() },
            onOpenActivityMonitor: { Self.openActivityMonitor() },
            onCleanup: { [weak self] in self?.runCleanup() },
            // 点进程行：看详情、退出或强制退出。WidgetKit 扩展没这个权限，
            // 所以只有宿主应用的面板会传回调。
            onProcessTap: { [weak self] process in
                NSApp.activate()
                ProcessDialogs.showProcess(process) { [weak self] in
                    self?.playSoundEffect()
                    self?.triggerTick()
                }
            },
            // 标题旁的小开关切换口径：立即写偏好并刷新共享模型，
            // 不等下一次采样，多个面板同步。
            onProcessSortChange: { [weak self] sort in self?.setProcessSort(sort) }
        )
    }

    /// 把某个实例调整到预设尺寸，保持左上角不动。
    private func apply(layout: WidgetLayout, to id: String) {
        guard let instance = instances.first(where: { $0.id == id }) else { return }
        let screen = instance.panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        let size = screen.map { layout.clamped(to: $0) } ?? layout.presetSize
        var frame = instance.panel.frame
        frame.origin.y = frame.maxY - size.height
        frame.size = size
        if let screen {
            frame.origin.x = min(max(screen.minX + 12, frame.origin.x), screen.maxX - frame.width - 12)
            frame.origin.y = min(max(screen.minY + 12, frame.origin.y), screen.maxY - frame.height - 12)
        }
        instance.panel.setFrame(frame, display: true)
        persist()
    }

    @objc private func addWidget(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let layout = WidgetLayout(rawValue: raw) else { return }
        addWidget(layout: layout)
    }

    private func addWidget(layout: WidgetLayout) {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        let size = layout.clamped(to: screen)
        let anchor = primary?.panel.frame ?? NSRect(
            x: screen.maxX - size.width - 28,
            y: screen.minY + 28,
            width: size.width,
            height: size.height
        )
        let step = CGFloat(extras.count + 1) * 28
        var origin = NSPoint(x: anchor.minX - step, y: anchor.minY + step)
        origin.x = min(max(screen.minX + 12, origin.x), screen.maxX - size.width - 12)
        origin.y = min(max(screen.minY + 12, origin.y), screen.maxY - size.height - 12)

        let instance = makeInstance(id: UUID().uuidString, frame: NSRect(origin: origin, size: size), isPrimary: false)
        instances.append(instance)
        instance.panel.orderFrontRegardless()
        persist()
    }

    private func duplicate(id: String) {
        guard let source = instances.first(where: { $0.id == id }), let screen = source.panel.screen?.visibleFrame else { return }
        var frame = source.panel.frame
        frame.origin.x = min(frame.origin.x + 28, screen.maxX - frame.width - 12)
        frame.origin.y = max(frame.origin.y - 28, screen.minY + 12)
        let instance = makeInstance(id: UUID().uuidString, frame: frame, isPrimary: false)
        instances.append(instance)
        instance.panel.orderFrontRegardless()
        persist()
    }

    private func remove(id: String) {
        guard let index = instances.firstIndex(where: { $0.id == id }), !instances[index].isPrimary else { return }
        instances[index].panel.orderOut(nil)
        instances.remove(at: index)
        persist()
    }

    @objc private func removeAllWidgets() {
        for instance in extras {
            instance.panel.orderOut(nil)
        }
        instances.removeAll { !$0.isPrimary }
        persist()
    }

    // MARK: - Persistence

    private func storedExtras() -> [(id: String, frame: String)] {
        guard let raw = defaults.array(forKey: Key.extraWidgets) as? [[String: String]] else { return [] }
        return raw.compactMap { entry in
            guard let id = entry["id"], let frame = entry["frame"] else { return nil }
            return (id, frame)
        }
    }

    private func persist() {
        if let primary {
            defaults.set(NSStringFromRect(primary.panel.frame), forKey: Key.frame)
            let layout = WidgetLayout.resolve(primary.panel.frame.size)
            settingsModel.panelLayout = layout
            settingsModel.isStrip = layout == .micro
        }
        let records: [[String: String]] = extras.map { ["id": $0.id, "frame": NSStringFromRect($0.panel.frame)] }
        defaults.set(records, forKey: Key.extraWidgets)
    }

    // MARK: - Widget context menu

    private func widgetMenu(id: String, isPrimary: Bool) -> NSMenu {
        let menu = NSMenu()
        let current = instances.first(where: { $0.id == id }).map { WidgetLayout.resolve($0.panel.frame.size) }

        let refresh = NSMenuItem(title: L10n.t(.menuRefreshNow), action: #selector(refreshNow), keyEquivalent: "")
        refresh.target = self
        menu.addItem(refresh)

        let cleanup = NSMenuItem(title: L10n.t(.menuRunCleanup), action: #selector(runCleanup), keyEquivalent: "")
        cleanup.target = self
        menu.addItem(cleanup)

        let open = NSMenuItem(title: L10n.t(.openActivityMonitor), action: #selector(openActivityMonitor), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let settings = NSMenuItem(title: L10n.t(.menuSettings), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let sizeItem = NSMenuItem(title: L10n.t(.menuSize), action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for (index, layout) in WidgetLayout.allCases.enumerated() {
            let item = NSMenuItem(title: layout.localizedName, action: #selector(setLayoutPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = id
            item.tag = index
            item.state = layout == current ? .on : .off
            sizeMenu.addItem(item)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let switchItem = NSMenuItem(
            title: current == .micro ? L10n.t(.menuExpandToStandard) : L10n.t(.menuCollapseToMicro),
            action: #selector(toggleLayout(_:)),
            keyEquivalent: ""
        )
        switchItem.target = self
        switchItem.representedObject = id
        menu.addItem(switchItem)

        // 进程榜口径：不必瞄准卡片标题旁的小开关，右键也能切。菜单每次打开时重建，
        // 勾选状态直接读当前偏好。
        let rankingItem = NSMenuItem(title: L10n.t(.menuProcessRanking), action: nil, keyEquivalent: "")
        let rankingMenu = NSMenu()
        for sort in ProcessSort.allCases {
            let item = NSMenuItem(
                title: sort.title,
                action: #selector(setProcessSortFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = sort.rawValue
            item.state = sort == processSort ? .on : .off
            rankingMenu.addItem(item)
        }
        rankingItem.submenu = rankingMenu
        menu.addItem(rankingItem)

        let copy = NSMenuItem(title: L10n.t(.menuDuplicateWidget), action: #selector(duplicateWidget(_:)), keyEquivalent: "")
        copy.target = self
        copy.representedObject = id
        menu.addItem(copy)

        let level = NSMenuItem(
            title: isFloating ? L10n.t(.menuPinToDesktop) : L10n.t(.menuAlwaysOnTop),
            action: #selector(toggleFloating),
            keyEquivalent: ""
        )
        level.target = self
        level.state = isFloating ? .on : .off
        menu.addItem(level)

        menu.addItem(.separator())
        if isPrimary {
            let hide = NSMenuItem(title: L10n.t(.menuHideWidget), action: #selector(hidePrimary), keyEquivalent: "")
            hide.target = self
            menu.addItem(hide)
        } else {
            let remove = NSMenuItem(title: L10n.t(.menuRemoveWidget), action: #selector(removeWidgetAction(_:)), keyEquivalent: "")
            remove.target = self
            remove.representedObject = id
            menu.addItem(remove)
        }
        menu.addItem(withTitle: L10n.t(.menuQuit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        return menu
    }

    @objc private func refreshNow() { triggerTick() }

    @objc private func setProcessSortFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        setProcessSort(ProcessSort.stored(raw))
    }

    @objc private func hidePrimary() { hidePanel() }

    @objc private func setLayoutPreset(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              sender.tag >= 0, sender.tag < WidgetLayout.allCases.count else { return }
        apply(layout: WidgetLayout.allCases[sender.tag], to: id)
    }

    /// 在极简条状与标准面板之间切换；非极简档一律收成条，极简档展开成标准面板。
    @objc private func toggleLayout(_ sender: NSMenuItem) {
        guard let id = (sender.representedObject as? String) ?? primary?.id,
              let instance = instances.first(where: { $0.id == id }) else { return }
        apply(layout: WidgetLayout.toggled(WidgetLayout.resolve(instance.panel.frame.size)), to: id)
    }

    @objc private func duplicateWidget(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        duplicate(id: id)
    }

    @objc private func removeWidgetAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        remove(id: id)
    }

    // MARK: - Level

    private func applyLevel() {
        for instance in instances {
            applyLevel(to: instance.panel)
        }
    }

    private func applyLevel(to panel: WidgetPanel) {
        if isFloating {
            panel.level = .floating
        } else {
            // 桌面图标层之上、普通窗口之下：像系统小组件一样贴在桌面。
            let desktopIconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
            panel.level = NSWindow.Level(rawValue: desktopIconLevel + 1)
        }
        panel.ignoresMouseEvents = isClickThrough
    }

    private func logDebug() {
        guard ProcessInfo.processInfo.environment["MACSTATS_DEBUG"] != nil else { return }
        for instance in instances {
            let panel = instance.panel
            let line = "widget \(instance.id) primary=\(instance.isPrimary) frame=\(panel.frame) "
                + "layout=\(WidgetLayout.resolve(panel.frame.size)) level=\(panel.level.rawValue)\n"
            FileHandle.standardError.write(Data(line.utf8))
        }
    }

    // MARK: - Actions

    @objc private func togglePanelAction() { togglePanel() }

    private func togglePanel() {
        if isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        isVisible = true
        defaults.set(true, forKey: Key.visible)
        for instance in instances {
            instance.panel.orderFrontRegardless()
        }
        startTicking()
        triggerTick()
    }

    private func hidePanel() {
        isVisible = false
        defaults.set(false, forKey: Key.visible)
        for instance in instances {
            instance.panel.orderOut(nil)
        }
        startTicking()
    }

    @objc private func toggleFloating() { setFloatingLevel(!isFloating) }

    // MARK: - 设置窗口背后的读写口

    /// 设置里的每一条都落到实情上；窗口关闭/重开时靠这几个 getter 同步。
    var isPanelVisible: Bool { isVisible }
    var isFloatingLevel: Bool { isFloating }
    var isPassThrough: Bool { isClickThrough }
    var refreshInterval: Double { interval }
    var isStripMode: Bool {
        guard let primary else { return true }
        return WidgetLayout.resolve(primary.panel.frame.size) == .micro
    }
    var cleanupWhitelist: Set<String> { cleaner.rules.whitelist }
    var launchAtLoginEnabled: Bool { loginItemEnabled }
    var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    func setPanelVisible(_ on: Bool) {
        if on { showPanel() } else { hidePanel() }
    }

    func setFloatingLevel(_ on: Bool) {
        guard isFloating != on else { return }
        isFloating = on
        defaults.set(on, forKey: Key.floating)
        applyLevel()
    }

    func setPassThrough(_ on: Bool) {
        guard isClickThrough != on else { return }
        isClickThrough = on
        defaults.set(on, forKey: Key.clickThrough)
        applyLevel()
    }

    func setRefreshInterval(_ value: TimeInterval) {
        interval = max(0.5, value)
        defaults.set(interval, forKey: Key.interval)
        viewModel.data.refreshInterval = interval
        startTicking()
        triggerTick()
    }

    /// 只切主面板；极简条 ↔ 标准面板，其它档位一律先收成条（与右键菜单一致）。
    func setStripMode(_ strip: Bool) {
        guard let id = primary?.id, let instance = instances.first(where: { $0.id == id }) else { return }
        let current = WidgetLayout.resolve(instance.panel.frame.size)
        let target: WidgetLayout = strip ? .micro : .standard
        guard current != target else { return }
        apply(layout: target, to: id)
    }

    var primaryLayout: WidgetLayout {
        guard let primary else { return .micro }
        return WidgetLayout.resolve(primary.panel.frame.size)
    }

    func setPrimaryLayout(_ layout: WidgetLayout) {
        guard let primary else { return }
        apply(layout: layout, to: primary.id)
    }

    func setShowMenuBarStats(_ on: Bool) {
        showMenuBarStats = on
        defaults.set(on, forKey: Key.showMenuBarStats)
        if let button = statusItem?.button {
            if !on {
                button.title = ""
            } else {
                triggerTick()
            }
        }
    }

    @objc func openSettings() {
        settingsModel.sync()
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: settingsModel))
            let window = NSWindow(contentViewController: hosting)
            window.title = L10n.t(.settings)
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.tabbingMode = .disallowed
            window.center()
            settingsWindow = window
        } else {
            settingsWindow?.title = L10n.t(.settings)
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - 语种与外观设置

    func setLanguage(_ lang: AppLanguage) {
        appLanguage = lang
        defaults.set(lang.rawValue, forKey: Key.appLanguage)
        L10n.shared.setLanguage(lang)
        setupMainMenu()
        statusItem?.button?.image?.accessibilityDescription = L10n.t(.widgetTitle)
        settingsWindow?.title = L10n.t(.settings)
        triggerTick()
    }

    func applyAppearance(_ mode: AppAppearance) {
        switch mode {
        case .system:
            NSApp.appearance = nil
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        }
    }

    func setAppearance(_ mode: AppAppearance) {
        appearanceMode = mode
        defaults.set(mode.rawValue, forKey: Key.appearanceMode)
        applyAppearance(mode)
    }

    func setAccentTint(_ tint: AccentTintColor) {
        accentTint = tint
        defaults.set(tint.rawValue, forKey: Key.accentTint)
        Theme.accentStyle = tint
        triggerTick()
    }

    // MARK: - 采样与监控设置

    func setSmoothingWindow(_ window: Int) {
        smoothingWindow = max(1, window)
        defaults.set(smoothingWindow, forKey: Key.smoothingWindow)
        cpuUserRing = MetricRing(capacity: smoothingWindow)
        cpuSystemRing = MetricRing(capacity: smoothingWindow)
        triggerTick()
    }

    func setTopProcessesCount(_ count: Int) {
        topProcessesCount = max(1, count)
        defaults.set(topProcessesCount, forKey: Key.topProcessesCount)
        triggerTick()
    }

    func setProcessSort(_ sort: ProcessSort) {
        guard processSort != sort else { return }
        processSort = sort
        defaults.set(sort.rawValue, forKey: Key.processSort)
        viewModel.data.processSort = sort
    }

    // MARK: - 启动与通知设置

    func setStartHidden(_ on: Bool) {
        startHidden = on
        defaults.set(on, forKey: Key.startHidden)
    }

    func setSoundEffects(_ on: Bool) {
        soundEffectsEnabled = on
        defaults.set(on, forKey: Key.soundEffects)
    }

    func setNotifyOnCleanup(_ on: Bool) {
        notifyOnCleanupEnabled = on
        defaults.set(on, forKey: Key.notifyOnCleanup)
        if on {
            requestNotificationPermission()
        }
    }

    func setMemoryAlert(_ on: Bool) {
        memoryAlertEnabled = on
        defaults.set(on, forKey: Key.memoryAlert)
        if on {
            requestNotificationPermission()
        }
    }

    // MARK: - 历史与阈值告警

    func setHistoryEnabled(_ on: Bool) {
        historyEnabled = on
        defaults.set(on, forKey: Key.historyEnabled)
        if on {
            setupHistoryStore()
        } else {
            historyStore?.flush()
            historyStore = nil
            viewModel.data.history = []
        }
    }

    func setHistoryRetentionDays(_ days: Int) {
        historyRetentionDays = max(1, days)
        defaults.set(historyRetentionDays, forKey: Key.historyRetentionDays)
        historyStore?.setRetentionDays(historyRetentionDays)
    }

    func setThresholdAlerts(_ on: Bool) {
        thresholdAlertsEnabled = on
        defaults.set(on, forKey: Key.thresholdAlerts)
        thresholdEvaluator.reset()
        if on {
            requestNotificationPermission()
        }
    }

    func clearHistory() {
        historyStore?.clear()
        viewModel.data.history = []
    }

    func historyUsageBytes() -> Int64 {
        historyStore?.diskUsageBytes() ?? 0
    }

    // MARK: - 清理策略

    func setCleanupMinimumIdle(_ seconds: TimeInterval) {
        cleanupMinimumIdle = max(60, seconds)
        defaults.set(cleanupMinimumIdle, forKey: Key.cleanupMinimumIdle)
        cleaner.updateMinimumIdle(cleanupMinimumIdle)
    }

    func setCleanupMinMemoryMB(_ mb: Int) {
        cleanupMinMemoryMB = max(0, mb)
        defaults.set(cleanupMinMemoryMB, forKey: Key.cleanupMinMemoryMB)
        cleaner.updateMinimumMemory(UInt64(cleanupMinMemoryMB) * 1024 * 1024)
    }

    func resetAllPreferences() {
        setLanguage(.system)
        setAppearance(.system)
        setAccentTint(.vibrant)
        setFloatingLevel(false)
        setPassThrough(false)
        setRefreshInterval(1)
        setSmoothingWindow(5)
        setTopProcessesCount(5)
        setProcessSort(.memory)
        setStartHidden(false)
        setSoundEffects(true)
        setNotifyOnCleanup(true)
        setMemoryAlert(false)
        setShowMenuBarStats(true)
        setHistoryEnabled(true)
        setHistoryRetentionDays(30)
        setThresholdAlerts(false)
        setCleanupMinimumIdle(600)
        setCleanupMinMemoryMB(20)
        clearCleanupWhitelist()
        if loginItemEnabled {
            setLaunchAtLogin(false)
        }
        if let primary, let screen = NSScreen.main?.visibleFrame {
            let strip = WidgetLayout.micro.presetSize
            let defaultFrame = NSRect(
                x: screen.maxX - strip.width - 28,
                y: screen.maxY - strip.height - 12,
                width: strip.width,
                height: strip.height
            )
            primary.panel.setFrame(sanitized(defaultFrame), display: true)
        }
        if !isVisible {
            showPanel()
        }
        let keys = [
            Key.frame, Key.interval, Key.floating, Key.clickThrough, Key.visible,
            Key.cleanupWhitelist, Key.appLanguage, Key.appearanceMode,
            Key.accentTint, Key.smoothingWindow, Key.startHidden,
            Key.notifyOnCleanup, Key.soundEffects, Key.memoryAlert,
            Key.cleanupMinimumIdle, Key.cleanupMinMemoryMB, Key.topProcessesCount,
            Key.processSort, Key.showMenuBarStats, Key.historyEnabled,
            Key.historyRetentionDays, Key.thresholdAlerts
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - 音效与系统通知

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func playSoundEffect() {
        guard soundEffectsEnabled else { return }
        if let sound = NSSound(named: "Glass") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    func sendNotification(title: String, body: String, subtitle: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let subtitle, !subtitle.isEmpty {
            content.subtitle = subtitle
        }
        if soundEffectsEnabled {
            content.sound = .default
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func checkMemoryAlert(_ snapshot: MetricSnapshot) {
        guard memoryAlertEnabled else { return }
        let memoryFraction = snapshot.memory.total > 0
            ? Double(snapshot.memory.used) / Double(snapshot.memory.total)
            : 0
        let isCritical = snapshot.memory.pressure == .critical || memoryFraction >= 0.90
        guard isCritical else { return }
        let now = Date()
        guard now.timeIntervalSince(lastMemoryAlert) >= 300 else { return }
        lastMemoryAlert = now

        let usedStr = ByteFormat.memory(snapshot.memory.used)
        let totalStr = ByteFormat.memory(snapshot.memory.total)
        let percentStr = PercentFormat.percent(memoryFraction)
        let title = L10n.t(.memoryAlert)
        let body = "\(L10n.t(.memory)): \(usedStr) / \(totalStr) (\(percentStr))"
        sendNotification(title: title, body: body)
    }

    // MARK: - 清理后台闲置进程

    private var foregroundPID: Int32? { NSWorkspace.shared.frontmostApplication?.processIdentifier }

    /// 一键清理：先算候选、列清单确认，再发 SIGTERM。
    @objc private func runCleanup() {
        let plan = cleaner.evaluate(foregroundPID: foregroundPID)
        NSApp.activate()

        guard !plan.candidates.isEmpty else {
            ProcessDialogs.showNothingToClean(scanned: plan.scanned, skipped: plan.skipped)
            return
        }
        guard ProcessDialogs.confirm(plan) else { return }

        let result = cleaner.terminate(plan.candidates)
        playSoundEffect()
        ProcessDialogs.showResult(result)
        if notifyOnCleanupEnabled {
            let notificationBody: String = result.survived.isEmpty
                ? L10n.format(.resultTerminatedOnly, result.terminated.count)
                : L10n.format(.resultTerminatedAndRunning, result.terminated.count, result.survived.count)
            sendNotification(
                title: L10n.t(.cleanupResult),
                body: notificationBody
            )
        }
        triggerTick()
    }

    // MARK: - 诊断自检

    func runSelfCheck() async -> (passed: Bool, report: String) {
        // 采样包含一次进程表扫描，点「运行诊断」时也不能卡住设置窗口。
        let sample = await Task.detached(priority: .userInitiated) {
            SystemSampler(config: .init(processLimit: 10, processInterval: 0)).sample()
        }.value
        var items: [(Bool, String)] = []
        items.append((sample.cpu.total >= 0 && sample.cpu.total <= 1, "CPU Invariant (0...100%)"))
        items.append((!sample.cpu.cores.isEmpty, "CPU Multi-core Invariant"))
        items.append((sample.memory.total > 0 && sample.memory.used <= sample.memory.total, "Memory Invariant (hw.memsize)"))
        items.append((sample.disk.capacity > 0, "Disk Invariant (Capacity > 0)"))
        items.append((sample.network.interfaceCount > 0, "Network Invariant (Interfaces > 0)"))
        items.append((sample.energy.watts == nil || (sample.energy.watts ?? 0) >= 0, "Energy Invariant (Watts >= 0)"))
        items.append((!sample.processes.isEmpty, "Process Sampling (Active)"))
        if let gpu = sample.gpu {
            items.append((gpu.utilization >= 0 && gpu.utilization <= 1, "GPU Utilization Invariant (0...100%)"))
        }

        let allPassed = items.allSatisfy(\.0)
        let lang = L10n.shared.resolvedLanguage
        let title = allPassed
            ? (lang == .zhHans ? "所有系统与硬件采样项检查通过" : "All system & metric samplers passed")
            : (lang == .zhHans ? "部分采样项异常" : "Some samplers reported issues")
        let details = items.map { ($0.0 ? "✓ " : "✗ ") + $0.1 }.joined(separator: "\n")
        return (allPassed, "\(title)\n\n\(details)")
    }

    /// 设置里「可以保护哪些进程」的名单：和清理候选同一套身份筛查，
    /// 所以列出来的都是真有可能被清的；每条附一段人话说明（它是什么 / 结束会怎样）。
    func whitelistOptions() async -> [ProcessOption] {
        // 扫进程表并逐条读 argv 都是 libproc 调用，放到工具线程，设置窗口打开时不掉帧。
        let rules = cleaner.rules
        let foreground = foregroundPID
        let lang = L10n.shared.resolvedLanguage
        let (runningRows, seen) = await Task.detached(priority: .userInitiated) { () -> ([ProcessOption], Set<String>) in
            let locals = ProcessCleaner(rules: rules)
            let candidates = locals.protectableProcesses(in: ProcessInventory.scan(), foregroundPID: foreground)
            var seen = Set<String>()
            var rows: [ProcessOption] = []

            for process in candidates.sorted(by: { $0.memoryBytes > $1.memoryBytes }) {
                let title = ProcessInventory.processTitle(pid: process.pid) ?? ""
                let display = ProcessGlossary.displayName(name: process.name, title: title)
                guard seen.insert(display.lowercased()).inserted else { continue }
                let explanation = ProcessGlossary.explain(name: process.name, title: title, path: process.path, language: lang)
                rows.append(ProcessOption(
                    name: display,
                    summary: explanation.summary,
                    impact: explanation.impact,
                    isRunning: true
                ))
            }
            return (rows, seen)
        }.value

        var rows = runningRows
        // 白名单里保存过、但当前没在跑的，也要列出来，否则永远取消不掉。
        for saved in cleaner.rules.whitelist where !seen.contains(saved.lowercased()) {
            let explanation = ProcessGlossary.explain(name: saved, language: lang)
            rows.append(ProcessOption(
                name: saved,
                summary: explanation.summary,
                impact: explanation.impact,
                isRunning: false
            ))
        }
        return rows.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// 白名单的可勾选名单：当前能辨认的后台进程 + 已保护但一时扫不到的。
    /// 菜单和设置窗口共用，避免两处排序/去重规则跑偏。
    func cleanupNameRows() -> [String] {
        let names = cleaner.protectableNames(foregroundPID: foregroundPID)
        // 已保护但当前扫不到的（进程退出了，或当初记的是 argv[0]）也要能取消。
        let protectedElsewhere = cleaner.rules.whitelist
            .filter { saved in !names.contains { $0.caseInsensitiveCompare(saved) == .orderedSame } }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return names + protectedElsewhere
    }

    /// 白名单子菜单：列出当前可保护的后台进程，点一下切换。
    private func cleanupWhitelistMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: L10n.t(.menuCleanupWhitelist), action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let names = cleanupNameRows()

        if names.isEmpty {
            let empty = NSMenuItem(title: L10n.t(.menuNoProtectableProcesses), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        } else {
            for name in names {
                let entry = NSMenuItem(title: name, action: #selector(toggleCleanupWhitelist(_:)), keyEquivalent: "")
                entry.target = self
                entry.representedObject = name
                entry.state = cleaner.rules.isWhitelisted(name) ? .on : .off
                submenu.addItem(entry)
            }
        }

        if !cleaner.rules.whitelist.isEmpty {
            submenu.addItem(.separator())
            let clear = NSMenuItem(title: L10n.t(.menuClearWhitelist), action: #selector(clearCleanupWhitelist), keyEquivalent: "")
            clear.target = self
            submenu.addItem(clear)
        }
        item.submenu = submenu
        return item
    }

    @objc private func toggleCleanupWhitelist(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        setWhitelisted(name, !cleaner.rules.isWhitelisted(name))
    }

    func setWhitelisted(_ name: String, _ on: Bool) {
        var list = cleaner.rules.whitelist
        if on {
            list.insert(name)
        } else if let existing = list.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            list.remove(existing)
        }
        applyWhitelist(list)
    }

    @objc func clearCleanupWhitelist() {
        applyWhitelist([])
    }

    private func applyWhitelist(_ names: Set<String>) {
        cleaner.updateWhitelist(names)
        if names.isEmpty {
            defaults.removeObject(forKey: Key.cleanupWhitelist)
        } else {
            defaults.set(Array(names).sorted(), forKey: Key.cleanupWhitelist)
        }
    }

    @objc func openActivityMonitor() { Self.openActivityMonitor() }

    private static func openActivityMonitor() {
        let bundleID = "com.apple.ActivityMonitor"
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: - Login item

    private var loginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ on: Bool) {
        let service = SMAppService.mainApp
        guard (service.status == .enabled) != on else { return }
        do {
            if on {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            ProcessDialogs.showError(
                title: L10n.t(.loginItemErrorTitle),
                message: L10n.t(.loginItemErrorMessage),
                details: error.localizedDescription
            )
        }
    }

    // MARK: - Sampling

    private func triggerTick() {
        Task { [weak self] in
            await self?.tick()
        }
    }

    private func warmUp() {
        // CPU / 磁盘 / 网络的速率需要相邻两次采样做差分，先在后台预热让首屏就有数据。
        // 全程异步执行，不阻塞 @MainActor 启动。
        warmUpTask?.cancel()
        warmUpTask = Task { [weak self] in
            guard let self else { return }
            await Task.detached(priority: .utility) { [sampler = self.sampler] in
                _ = sampler.sample(includeProcesses: false)
            }.value
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            await self.tick()
            self.startTicking()
        }
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let hasVisible = self.isVisible && self.instances.contains { $0.panel.isVisible }
                let currentInterval = hasVisible ? self.interval : max(3.0, self.interval * 3)
                try? await Task.sleep(for: .seconds(currentInterval))
                if Task.isCancelled { return }
                await self.tick()
            }
        }
    }

    private func tick() async {
        guard !isSampling else { return }
        isSampling = true
        defer { isSampling = false }

        let hasVisible = isVisible && instances.contains { $0.panel.isVisible }
        let shouldIncludeProcesses = hasVisible
        let now = Date()
        let shouldObserveCleanup = hasVisible && now.timeIntervalSince(lastCleanupObservation) >= Self.cleanupObservationInterval

        // Mach / libproc / sysctl 采样与进程表扫描移到后台工具线程执行，避免占用 @MainActor
        let (snapshot, cleanupProcesses) = await Task.detached(priority: .utility) { [sampler = self.sampler] in
            let snap = sampler.sample(includeProcesses: shouldIncludeProcesses)
            let procs = shouldObserveCleanup ? ProcessInventory.scan() : []
            return (snap, procs)
        }.value

        if shouldObserveCleanup {
            lastCleanupObservation = now
            cleaner.observe(processes: cleanupProcesses, now: now)
        }

        autoreleasepool {
            applySnapshot(snapshot, hasVisiblePanels: hasVisible)
        }
    }

    private func applySnapshot(_ snapshot: MetricSnapshot, hasVisiblePanels: Bool) {
        var currentData = viewModel.data
        currentData.cpu.append(snapshot.cpu.total)
        if let gpu = snapshot.gpu {
            currentData.gpu.append(gpu.utilization)
        }
        currentData.energy.append(snapshot.energy.watts ?? 0)
        currentData.diskRead.append(snapshot.disk.readBytesPerSecond)
        currentData.diskWrite.append(snapshot.disk.writeBytesPerSecond)
        currentData.networkIn.append(snapshot.network.bytesInPerSecond)
        currentData.networkOut.append(snapshot.network.bytesOutPerSecond)
        cpuUserRing.append(snapshot.cpu.user)
        cpuSystemRing.append(snapshot.cpu.system)

        let memoryFraction = snapshot.memory.total > 0
            ? Double(snapshot.memory.used) / Double(snapshot.memory.total)
            : 0
        memoryRing.append(memoryFraction)

        let window = smoothingWindow
        let averages = WindowAverages(
            cpuTotal: currentData.cpu.mean(last: window) ?? snapshot.cpu.total,
            cpuUser: cpuUserRing.mean(last: window) ?? snapshot.cpu.user,
            cpuSystem: cpuSystemRing.mean(last: window) ?? snapshot.cpu.system,
            energyWatts: currentData.energy.mean(last: window) ?? 0,
            diskRead: currentData.diskRead.mean(last: window) ?? 0,
            diskWrite: currentData.diskWrite.mean(last: window) ?? 0,
            networkIn: currentData.networkIn.mean(last: window) ?? 0,
            networkOut: currentData.networkOut.mean(last: window) ?? 0,
            sampleCount: currentData.cpu.values.count
        )
        currentData.snapshot = snapshot.applying(averages)
        currentData.refreshInterval = interval
        currentData.topProcessesCount = topProcessesCount
        currentData.processSort = processSort

        // 细粒度更新 Observable 模型：不替换 NSHostingView.rootView，
        // SwiftUI 自动按需刷新依赖属性的子视图。
        viewModel.data = currentData

        checkMemoryAlert(snapshot)
        recordHistory(snapshot)
        checkThresholdAlerts(snapshot)
        updateStatusTitle(currentData.snapshot)
        publishWidgetFeed(currentData.snapshot)
    }

    // MARK: - 历史与阈值

    private func setupHistoryStore() {
        guard historyEnabled else {
            historyStore = nil
            viewModel.data.history = []
            return
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacStats/history", isDirectory: true)
        let store = HistoryStore(configuration: .init(directory: base, retentionDays: historyRetentionDays))
        historyStore = store
        viewModel.data.history = store.recent24h()
    }

    private func recordHistory(_ snapshot: MetricSnapshot) {
        guard historyEnabled, let store = historyStore else { return }
        let memoryFraction = snapshot.memory.total > 0
            ? Double(snapshot.memory.used) / Double(snapshot.memory.total)
            : 0
        let flushed = store.record(
            cpu: snapshot.cpu.total,
            memory: memoryFraction,
            gpu: snapshot.gpu?.utilization,
            diskUsed: snapshot.disk.usedFraction,
            // topCPU 是采样层在按内存截断之前算好的；历史分钟点最多留 3 条。
            topProcesses: Array(snapshot.topCPU.prefix(3)),
            at: snapshot.timestamp
        )
        if flushed {
            viewModel.data.history = store.recent24h(now: snapshot.timestamp)
        }
    }

    private func checkThresholdAlerts(_ snapshot: MetricSnapshot) {
        guard thresholdAlertsEnabled else { return }
        let memoryFraction = snapshot.memory.total > 0
            ? Double(snapshot.memory.used) / Double(snapshot.memory.total)
            : 0
        // CPU 元凶用采样层的 topCPU；内存元凶必须显式按 .memory 排名，不能复用 CPU 第一名。
        let topMemory = ProcessRanking.attributions(
            from: snapshot.processes,
            limit: 1,
            by: .memory
        ).first
        guard let event = thresholdEvaluator.evaluate(
            cpu: snapshot.cpu.total,
            memory: memoryFraction,
            diskUsed: snapshot.disk.usedFraction,
            topCPU: snapshot.topCPU.first,
            topMemory: topMemory,
            at: snapshot.timestamp
        ) else { return }

        let title: String
        switch event.kind {
        case .cpu: title = L10n.t(.alertCPU)
        case .memory: title = L10n.t(.alertMemory)
        case .disk: title = L10n.t(.alertDisk)
        }
        sendNotification(
            title: title,
            body: AlertNotificationText.body(for: event),
            subtitle: AlertNotificationText.subtitle(for: event)
        )
    }

    /// 把当前采样递到 `~/Library/Application Support/MacStats/widget-feed.json`，
    /// 顺手叫醒系统小组件。三道闸门，避免为了看不见的变化反复写盘、唤醒扩展：
    /// 1. 最短 30 秒一次——原始浮点数每秒都在抖，但组件显示的是取整后的值；
    /// 2. 扩展容器不存在（没添加过这个小组件）时直接跳过；
    /// 3. 显示的数字没变样，就只在 60 秒心跳时推一次。
    private func publishWidgetFeed(_ snapshot: MetricSnapshot) {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastWidgetReload)
        guard elapsed >= Self.widgetPublishInterval else { return }
        lastWidgetReload = now
        guard WidgetFeedStore.hasExtensionContainer else { return }

        let feed = WidgetFeed(
            snapshot: snapshot,
            cpuHistory: Array(viewModel.data.cpu.values.suffix(40)),
            memoryHistory: Array(memoryRing.values.suffix(40)),
            networkInHistory: Array(viewModel.data.networkIn.values.suffix(40)),
            networkOutHistory: Array(viewModel.data.networkOut.values.suffix(40))
        )

        let signature = WidgetFeedSignature(feed: feed)
        guard signature != lastWidgetSignature || elapsed >= Self.widgetHeartbeatInterval else { return }
        lastWidgetSignature = signature

        Task.detached(priority: .utility) {
            WidgetFeedStore.write(feed)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func updateStatusTitle(_ snapshot: MetricSnapshot) {
        guard let button = statusItem?.button else { return }
        let cpu = PercentFormat.percent(snapshot.cpu.total)
        let memory = PercentFormat.percent(
            snapshot.memory.total > 0 ? Double(snapshot.memory.used) / Double(snapshot.memory.total) : 0
        )
        // 取整后每秒大概率一样，无改动就别写：状态栏每次改标题都要重算宽度、重排。
        let title = showMenuBarStats ? "\(cpu) · \(memory)" : ""
        if button.title != title {
            button.title = title
        }
        let toolTip = L10n.format(
            .statusToolTip,
            cpu,
            memory,
            snapshot.energy.watts.map { EnergyFormat.watts($0) } ?? "—"
        )
        if button.toolTip != toolTip {
            button.toolTip = toolTip
        }
    }
}
