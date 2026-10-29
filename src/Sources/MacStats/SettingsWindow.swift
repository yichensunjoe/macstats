import AppKit
import Observation
import SwiftUI
import MacStatsCore

/// 白名单列表的一行：名字 + 给普通人看的说明。
public struct ProcessOption: Identifiable, Equatable, Sendable {
    public var name: String
    public var summary: String
    public var impact: String
    public var isRunning: Bool

    public var id: String { name.lowercased() }

    public init(name: String, summary: String, impact: String, isRunning: Bool) {
        self.name = name
        self.summary = summary
        self.impact = impact
        self.isRunning = isRunning
    }
}

/// 设置窗口的状态镜像：读走 AppDelegate 的当前值，写都转给 AppDelegate。
@MainActor
@Observable
final class SettingsModel {
    @ObservationIgnored weak var app: AppDelegate?

    var selectedTab = 0
    var languageRevision = 0

    // 语种与外观
    var language: AppLanguage = .system
    var appearance: AppAppearance = .system
    var accentTint: AccentTintColor = .vibrant

    // 面板交互
    var showsWidget = true
    var panelLayout: WidgetLayout = .micro
    var isStrip = true
    var floating = false
    var clickThrough = false

    // 采样监控
    var interval: Double = 1
    var smoothingWindow: Int = 5
    var topProcessesCount: Int = 5

    // 启动与通知
    var launchAtLogin = false
    var startHidden = false
    var showMenuBarStats = true
    var soundEffects = true
    var notifyOnCleanup = true
    var confirmForceQuit = true
    var memoryAlert = false

    // 历史与阈值
    var historyEnabled = true
    var historyRetentionDays = 30
    var thresholdAlerts = false
    var historyUsage: Int64 = 0

    // 清理策略与白名单
    var cleanupMinimumIdle: TimeInterval = 600
    var cleanupMinMemoryMB: Int = 20
    var whitelist: Set<String> = []
    var options: [ProcessOption] = []
    var query = ""
    var manualName = ""

    // 系统与关于
    var version = "—"
    var hostName = ""

    init(app: AppDelegate) {
        self.app = app
        sync()
        NotificationCenter.default.addObserver(
            forName: L10n.languageDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sync()
                self?.languageRevision &+= 1
            }
        }
    }

    func sync() {
        guard let app else { return }
        language = app.appLanguage
        appearance = app.appearanceMode
        accentTint = app.accentTint

        showsWidget = app.isPanelVisible
        panelLayout = app.primaryLayout
        isStrip = app.isStripMode
        floating = app.isFloatingLevel
        clickThrough = app.isPassThrough

        interval = app.refreshInterval
        smoothingWindow = app.smoothingWindow
        topProcessesCount = app.topProcessesCount

        launchAtLogin = app.launchAtLoginEnabled
        startHidden = app.startHidden
        showMenuBarStats = app.showMenuBarStats
        soundEffects = app.soundEffectsEnabled
        notifyOnCleanup = app.notifyOnCleanupEnabled
        confirmForceQuit = app.confirmForceQuit
        memoryAlert = app.memoryAlertEnabled

        historyEnabled = app.historyEnabled
        historyRetentionDays = app.historyRetentionDays
        thresholdAlerts = app.thresholdAlertsEnabled
        historyUsage = app.historyUsageBytes()

        cleanupMinimumIdle = app.cleanupMinimumIdle
        cleanupMinMemoryMB = app.cleanupMinMemoryMB
        whitelist = app.cleanupWhitelist

        version = app.versionString
        hostName = Host.current().localizedName ?? "Mac"
        // 名单要扫进程表，异步取，设置窗口先画出来。
        refreshOptions()
    }

    // MARK: - 语种与外观

    func setLanguage(_ lang: AppLanguage) {
        language = lang
        app?.setLanguage(lang)
    }

    func setAppearance(_ mode: AppAppearance) {
        appearance = mode
        app?.setAppearance(mode)
    }

    func setAccentTint(_ tint: AccentTintColor) {
        accentTint = tint
        app?.setAccentTint(tint)
    }

    // MARK: - 显示与面板

    func setShowsWidget(_ on: Bool) {
        showsWidget = on
        app?.setPanelVisible(on)
    }

    func setPanelLayout(_ layout: WidgetLayout) {
        panelLayout = layout
        app?.setPrimaryLayout(layout)
        isStrip = layout == .micro
    }

    func setStrip(_ strip: Bool) {
        isStrip = strip
        app?.setStripMode(strip)
        isStrip = app?.isStripMode ?? strip
        panelLayout = app?.primaryLayout ?? (strip ? .micro : .standard)
    }

    func setFloating(_ on: Bool) {
        floating = on
        app?.setFloatingLevel(on)
    }

    func setClickThrough(_ on: Bool) {
        clickThrough = on
        app?.setPassThrough(on)
    }

    // MARK: - 采样与监控

    func setInterval(_ value: Double) {
        interval = value
        app?.setRefreshInterval(value)
    }

    func setSmoothingWindow(_ window: Int) {
        smoothingWindow = window
        app?.setSmoothingWindow(window)
    }

    func setTopProcessesCount(_ count: Int) {
        topProcessesCount = count
        app?.setTopProcessesCount(count)
    }

    // MARK: - 启动与通知

    func setLaunchAtLogin(_ on: Bool) {
        launchAtLogin = on
        app?.setLaunchAtLogin(on)
        launchAtLogin = app?.launchAtLoginEnabled ?? on
    }

    func setStartHidden(_ on: Bool) {
        startHidden = on
        app?.setStartHidden(on)
    }

    func setShowMenuBarStats(_ on: Bool) {
        showMenuBarStats = on
        app?.setShowMenuBarStats(on)
    }

    func setSoundEffects(_ on: Bool) {
        soundEffects = on
        app?.setSoundEffects(on)
    }

    func setNotifyOnCleanup(_ on: Bool) {
        notifyOnCleanup = on
        app?.setNotifyOnCleanup(on)
    }

    func setConfirmForceQuit(_ on: Bool) {
        confirmForceQuit = on
        app?.setConfirmForceQuit(on)
    }

    func setMemoryAlert(_ on: Bool) {
        memoryAlert = on
        app?.setMemoryAlert(on)
    }

    // MARK: - 历史与阈值

    func setHistoryEnabled(_ on: Bool) {
        historyEnabled = on
        app?.setHistoryEnabled(on)
        historyUsage = app?.historyUsageBytes() ?? 0
    }

    func setHistoryRetentionDays(_ days: Int) {
        historyRetentionDays = days
        app?.setHistoryRetentionDays(days)
        historyUsage = app?.historyUsageBytes() ?? 0
    }

    func setThresholdAlerts(_ on: Bool) {
        thresholdAlerts = on
        app?.setThresholdAlerts(on)
    }

    func clearHistory() {
        app?.clearHistory()
        historyUsage = 0
    }

    // MARK: - 清理策略与白名单

    func setCleanupMinimumIdle(_ seconds: TimeInterval) {
        cleanupMinimumIdle = seconds
        app?.setCleanupMinimumIdle(seconds)
    }

    func setCleanupMinMemoryMB(_ mb: Int) {
        cleanupMinMemoryMB = mb
        app?.setCleanupMinMemoryMB(mb)
    }

    func isWhitelisted(_ name: String) -> Bool {
        whitelist.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    func setWhitelisted(_ name: String, _ on: Bool) {
        app?.setWhitelisted(name, on)
        whitelist = app?.cleanupWhitelist ?? whitelist
    }

    func refreshOptions() {
        Task { [weak self] in
            guard let self, let app = self.app else { return }
            let options = await app.whitelistOptions()
            self.options = options
            self.whitelist = app.cleanupWhitelist
        }
    }

    func addManual() {
        let name = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        app?.setWhitelisted(name, true)
        whitelist = app?.cleanupWhitelist ?? whitelist
        if !options.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            let explanation = ProcessGlossary.explain(
                name: name,
                language: L10n.shared.resolvedLanguage
            )
            options.append(ProcessOption(
                name: name,
                summary: explanation.summary,
                impact: explanation.impact,
                isRunning: false
            ))
            options.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        manualName = ""
    }

    func clearWhitelist() {
        app?.clearCleanupWhitelist()
        whitelist = []
    }

    func resetToDefaults() {
        app?.resetAllPreferences()
        sync()
        languageRevision &+= 1
    }

    func openActivityMonitor() {
        app?.openActivityMonitor()
    }

    func runDiagnostics() {
        guard let app else { return }
        Task {
            let (passed, report) = await app.runSelfCheck()
            ProcessDialogs.showMessage(
                title: L10n.t(.runDiagnostics),
                message: passed
                    ? (L10n.shared.resolvedLanguage == .zhHans ? "硬件指标与接口自检全部通过" : "All hardware & metric invariants verified")
                    : (L10n.shared.resolvedLanguage == .zhHans ? "部分硬件指标异常" : "Hardware metric invariant issues detected"),
                details: report,
                isSuccess: passed
            )
        }
    }
}

/// 现代化系统级设置窗口：通用 / 外观 / 监控 / 清理 / 关于 五大面板。
struct SettingsView: View {
    let model: SettingsModel

    @State private var showResetConfirm = false
    @State private var showClearWhitelistConfirm = false
    @State private var showClearHistoryConfirm = false

    private let intervals: [Double] = [0.5, 1, 2, 5]
    private let smoothingWindows: [Int] = [1, 3, 5]
    private let idleThresholds: [(TimeInterval, L10nKey)] = [
        (300, .idle5m),
        (600, .idle10m),
        (900, .idle15m),
        (1800, .idle30m),
        (3600, .idle60m)
    ]
    private let memoryThresholds: [(Int, L10nKey)] = [
        (0, .memoryNone),
        (10, .memory10MB),
        (20, .memory20MB),
        (50, .memory50MB),
        (100, .memory100MB)
    ]

    var body: some View {
        TabView(selection: Binding(
            get: { model.selectedTab },
            set: { model.selectedTab = $0 }
        )) {
            generalTab
                .tabItem { Label(L10n.t(.tabGeneral), systemImage: "gearshape") }
                .tag(0)

            appearanceTab
                .tabItem { Label(L10n.t(.tabAppearance), systemImage: "paintpalette") }
                .tag(1)

            monitoringTab
                .tabItem { Label(L10n.t(.tabMonitoring), systemImage: "gauge.with.needle") }
                .tag(2)

            cleanupTab
                .tabItem { Label(L10n.t(.tabCleanup), systemImage: "trash") }
                .tag(3)

            aboutTab
                .tabItem { Label(L10n.t(.tabAbout), systemImage: "info.circle") }
                .tag(4)
        }
        .frame(width: 560, height: 540)
        .id("\(model.language.rawValue)-\(model.languageRevision)")
    }

    // MARK: - Tab 1: 通用 (General)

    private var generalTab: some View {
        Form {
            Section {
                Picker(L10n.t(.language), selection: Binding(
                    get: { model.language },
                    set: { model.setLanguage($0) }
                )) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                sectionHeader(title: L10n.t(.language), systemImage: "globe", color: .blue)
            } footer: {
                Text(L10n.t(.languageHint))
            }

            Section {
                Toggle(L10n.t(.showMenuBarStats), isOn: Binding(
                    get: { model.showMenuBarStats },
                    set: { model.setShowMenuBarStats($0) }
                ))
            } header: {
                sectionHeader(title: L10n.t(.menuBarSection), systemImage: "menubar.rectangle", color: .green)
            } footer: {
                Text(L10n.t(.showMenuBarStatsDesc))
            }

            Section {
                Toggle(L10n.t(.launchAtLogin), isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                Toggle(L10n.t(.startHidden), isOn: Binding(
                    get: { model.startHidden },
                    set: { model.setStartHidden($0) }
                ))
            } header: {
                sectionHeader(title: L10n.t(.startupSection), systemImage: "macwindow.badge.plus", color: .purple)
            } footer: {
                Text(L10n.t(.startHiddenDesc))
            }

            Section {
                Toggle(L10n.t(.soundEffects), isOn: Binding(
                    get: { model.soundEffects },
                    set: { model.setSoundEffects($0) }
                ))
                Toggle(L10n.t(.notifyOnCleanup), isOn: Binding(
                    get: { model.notifyOnCleanup },
                    set: { model.setNotifyOnCleanup($0) }
                ))
                Toggle(L10n.t(.memoryAlert), isOn: Binding(
                    get: { model.memoryAlert },
                    set: { model.setMemoryAlert($0) }
                ))
            } header: {
                sectionHeader(title: L10n.t(.notificationsSection), systemImage: "bell.badge", color: .orange)
            } footer: {
                Text(L10n.t(.memoryAlertDesc))
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab 2: 外观与面板 (Appearance & Panel)

    private var appearanceTab: some View {
        Form {
            Section {
                Picker(L10n.t(.theme), selection: Binding(
                    get: { model.appearance },
                    set: { model.setAppearance($0) }
                )) {
                    Text(L10n.t(.themeSystem)).tag(AppAppearance.system)
                    Text(L10n.t(.themeDark)).tag(AppAppearance.dark)
                    Text(L10n.t(.themeLight)).tag(AppAppearance.light)
                }
                .pickerStyle(.segmented)

                Picker(L10n.t(.accentTint), selection: Binding(
                    get: { model.accentTint },
                    set: { model.setAccentTint($0) }
                )) {
                    Text(L10n.t(.accentVibrant)).tag(AccentTintColor.vibrant)
                    Text(L10n.t(.accentMonochrome)).tag(AccentTintColor.monochrome)
                }
                .pickerStyle(.segmented)
            } header: {
                sectionHeader(title: L10n.t(.themeSection), systemImage: "paintpalette.fill", color: .pink)
            }

            Section {
                Toggle(L10n.t(.showWidget), isOn: Binding(
                    get: { model.showsWidget },
                    set: { model.setShowsWidget($0) }
                ))

                Picker(L10n.t(.panelStyle), selection: Binding(
                    get: { model.panelLayout },
                    set: { model.setPanelLayout($0) }
                )) {
                    ForEach(WidgetLayout.allCases, id: \.self) { layout in
                        Text(layout.localizedName).tag(layout)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(L10n.t(.alwaysOnTop), isOn: Binding(
                    get: { model.floating },
                    set: { model.setFloating($0) }
                ))
                Toggle(L10n.t(.clickThrough), isOn: Binding(
                    get: { model.clickThrough },
                    set: { model.setClickThrough($0) }
                ))
            } header: {
                sectionHeader(title: L10n.t(.panelSection), systemImage: "rectangle.inset.filled", color: .blue)
            } footer: {
                Text(L10n.t(.alwaysOnTopDesc))
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab 3: 指标监控 (Monitoring)

    private var monitoringTab: some View {
        Form {
            Section {
                Picker(L10n.t(.refreshInterval), selection: Binding(
                    get: { model.interval },
                    set: { model.setInterval($0) }
                )) {
                    ForEach(intervals, id: \.self) { value in
                        Text(value == 0.5 ? L10n.format(.secondsUnit, "0.5") : L10n.format(.secondsUnit, "\(Int(value))")).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                Picker(L10n.t(.smoothingWindow), selection: Binding(
                    get: { model.smoothingWindow },
                    set: { model.setSmoothingWindow($0) }
                )) {
                    Text(L10n.t(.smoothing1s)).tag(1)
                    Text(L10n.t(.smoothing3s)).tag(3)
                    Text(L10n.t(.smoothing5s)).tag(5)
                }
                .pickerStyle(.segmented)
            } header: {
                sectionHeader(title: L10n.t(.samplingSection), systemImage: "waveform.path.ecg", color: .teal)
            } footer: {
                Text(L10n.t(.smoothingHint))
            }

            Section {
                Picker(L10n.t(.topProcessesCount), selection: Binding(
                    get: { model.topProcessesCount },
                    set: { model.setTopProcessesCount($0) }
                )) {
                    Text(L10n.t(.processesCount3)).tag(3)
                    Text(L10n.t(.processesCount5)).tag(5)
                    Text(L10n.t(.processesCount8)).tag(8)
                }
                .pickerStyle(.segmented)

                Toggle(L10n.t(.confirmForceQuit), isOn: Binding(
                    get: { model.confirmForceQuit },
                    set: { model.setConfirmForceQuit($0) }
                ))
            } header: {
                sectionHeader(title: L10n.t(.processesSection), systemImage: "list.bullet.rectangle", color: .indigo)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t(.processesHint))
                    Text(L10n.t(.confirmForceQuitDesc))
                }
            }

            Section {
                Toggle(L10n.t(.historyRecording), isOn: Binding(
                    get: { model.historyEnabled },
                    set: { model.setHistoryEnabled($0) }
                ))

                Picker(L10n.t(.historyRetention), selection: Binding(
                    get: { model.historyRetentionDays },
                    set: { model.setHistoryRetentionDays($0) }
                )) {
                    ForEach([7, 30, 90], id: \.self) { days in
                        Text(L10n.format(.retentionDaysFormat, "\(days)")).tag(days)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!model.historyEnabled)

                HStack(spacing: 8) {
                    Text(L10n.format(.historyUsage, ByteFormat.decimalBytes(UInt64(max(0, model.historyUsage)))))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive) {
                        showClearHistoryConfirm = true
                    } label: {
                        Text(L10n.t(.clearHistory))
                    }
                    .disabled(model.historyUsage == 0)
                }

                Toggle(L10n.t(.thresholdAlerts), isOn: Binding(
                    get: { model.thresholdAlerts },
                    set: { model.setThresholdAlerts($0) }
                ))
            } header: {
                sectionHeader(title: L10n.t(.historySection), systemImage: "clock.arrow.circlepath", color: .teal)
            } footer: {
                Text(L10n.t(.historyRecordingDesc) + " " + L10n.t(.thresholdAlertsDesc))
            }
        }
        .formStyle(.grouped)
        .alert(L10n.t(.clearHistory), isPresented: $showClearHistoryConfirm) {
            Button(L10n.t(.clearHistory), role: .destructive) { model.clearHistory() }
            Button(L10n.t(.cancel), role: .cancel) {}
        } message: {
            Text(L10n.t(.clearHistoryConfirm))
        }
    }

    // MARK: - Tab 4: 后台清理 (Cleanup)

    private var cleanupTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 策略阈值区
            GroupBox {
                VStack(spacing: 8) {
                    HStack {
                        Text(L10n.t(.idleThreshold))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { model.cleanupMinimumIdle },
                            set: { model.setCleanupMinimumIdle($0) }
                        )) {
                            ForEach(idleThresholds, id: \.0) { item in
                                Text(L10n.t(item.1)).tag(item.0)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 170)
                    }

                    HStack {
                        Text(L10n.t(.memoryThreshold))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { model.cleanupMinMemoryMB },
                            set: { model.setCleanupMinMemoryMB($0) }
                        )) {
                            ForEach(memoryThresholds, id: \.0) { item in
                                Text(L10n.t(item.1)).tag(item.0)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 170)
                    }
                }
                .padding(4)
            } label: {
                Label(L10n.t(.cleanupRulesSection), systemImage: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .semibold))
            }

            Text(L10n.t(.cleanupHint))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            searchField

            List {
                let filtered = filteredOptions
                if filtered.isEmpty {
                    Text(model.options.isEmpty ? L10n.t(.scanningProcesses) : L10n.t(.noMatchingProcess))
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))
                } else {
                    ForEach(filtered) { option in
                        optionRow(option)
                    }
                }
            }
            .frame(minHeight: 140)

            manualRow
            actionRow
        }
        .padding(16)
        .confirmationDialog(
            L10n.t(.clearWhitelistConfirm),
            isPresented: $showClearWhitelistConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.t(.clearWhitelist), role: .destructive) {
                model.clearWhitelist()
            }
            Button(L10n.t(.cancel), role: .cancel) {}
        }
    }

    private var filteredOptions: [ProcessOption] {
        let needle = model.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return model.options }
        return model.options.filter {
            $0.name.localizedCaseInsensitiveContains(needle)
                || $0.summary.localizedCaseInsensitiveContains(needle)
                || $0.impact.localizedCaseInsensitiveContains(needle)
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField(L10n.t(.searchPlaceholder), text: Binding(
                get: { model.query },
                set: { model.query = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.8)
                )
        )
    }

    private func optionRow(_ option: ProcessOption) -> some View {
        Toggle(isOn: Binding(
            get: { model.isWhitelisted(option.name) },
            set: { model.setWhitelisted(option.name, $0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(option.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if !option.isRunning {
                        Text(L10n.t(.notRunning))
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(.quaternary))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(option.summary)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.checkbox)
        .help(L10n.t(.impactPrefix) + option.impact)
    }

    private var manualRow: some View {
        HStack(spacing: 8) {
            Text(L10n.t(.manualAdd))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField(L10n.t(.manualPlaceholder), text: Binding(
                get: { model.manualName },
                set: { model.manualName = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 11))
            .frame(width: 170)
            .onSubmit { model.addManual() }
            Button(L10n.t(.add)) { model.addManual() }
                .disabled(model.manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Spacer(minLength: 0)
            Text(L10n.format(.protectedCount, model.whitelist.count))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button(L10n.t(.refreshList)) { model.refreshOptions() }
            Button(L10n.t(.clearWhitelist)) { showClearWhitelistConfirm = true }
                .disabled(model.whitelist.isEmpty)
            Spacer(minLength: 0)
            Text(L10n.t(.cleanupMatchHint))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Tab 5: 关于与系统 (About)

    private var aboutTab: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    if let icon = AppIcon.image {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 54, height: 54)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [Color.blue.opacity(0.8), Color.indigo],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 54, height: 54)
                            Image(systemName: "gauge.with.needle")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t(.appName))
                            .font(.system(size: 17, weight: .bold))
                        Text(L10n.t(.appSubtitle))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text("v\(model.version) · macOS 15+ (Apple Silicon)")
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Section(L10n.t(.aboutSection)) {
                LabeledContent(L10n.t(.version), value: model.version)
                LabeledContent(L10n.t(.buildArch), value: systemArchitecture())
                LabeledContent(L10n.t(.dataSource), value: L10n.t(.dataSourceDesc))
                LabeledContent(L10n.t(.alignment), value: L10n.t(.alignmentDesc))
            }

            Section {
                Button {
                    model.openActivityMonitor()
                } label: {
                    Label(L10n.t(.openActivityMonitor), systemImage: "waveform.path.ecg")
                }

                Button {
                    model.runDiagnostics()
                } label: {
                    Label(L10n.t(.runDiagnostics), systemImage: "checkmark.seal")
                }

                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label(L10n.t(.resetSettings), systemImage: "arrow.counterclockwise")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            L10n.t(.resetSettingsConfirm),
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.t(.resetSettings), role: .destructive) {
                model.resetToDefaults()
            }
            Button(L10n.t(.cancel), role: .cancel) {}
        }
    }

    private func sectionHeader(title: String, systemImage: String, color: Color) -> some View {
        Label {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(color)
        }
    }

    private func systemArchitecture() -> String {
        #if arch(arm64)
        return "Apple Silicon (arm64)"
        #elseif arch(x86_64)
        return "Intel (x86_64)"
        #else
        return "Universal"
        #endif
    }
}
