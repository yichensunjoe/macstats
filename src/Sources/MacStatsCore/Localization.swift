import Foundation

/// 应用程序支持的语种设置。
public enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case system = "system"
    case zhHans = "zh-Hans"
    case en = "en"

    public var displayName: String {
        switch self {
        case .system: L10n.t(.languageFollowSystem)
        case .zhHans: "简体中文"
        case .en: "English"
        }
    }

    public var resolved: ResolvedLanguage {
        switch self {
        case .zhHans:
            return .zhHans
        case .en:
            return .en
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased()
                ?? Locale.current.language.languageCode?.identifier.lowercased()
                ?? "en"
            if preferred.hasPrefix("zh") {
                return .zhHans
            }
            return .en
        }
    }
}

/// 实际生效的二元语言（简体中文 / 英文）。
public enum ResolvedLanguage: String, Sendable {
    case zhHans = "zh-Hans"
    case en = "en"
}

/// 外观主题模式。
public enum AppAppearance: String, CaseIterable, Codable, Sendable {
    case system = "system"
    case dark = "dark"
    case light = "light"

    public var displayName: String {
        switch self {
        case .system: L10n.t(.themeSystem)
        case .dark: L10n.t(.themeDark)
        case .light: L10n.t(.themeLight)
        }
    }
}

/// 仪表盘着色风格。
public enum AccentTintColor: String, CaseIterable, Codable, Sendable {
    case vibrant = "vibrant"
    case monochrome = "monochrome"

    public var displayName: String {
        switch self {
        case .vibrant: L10n.t(.accentVibrant)
        case .monochrome: L10n.t(.accentMonochrome)
        }
    }
}

/// 本地化文本键。
public enum L10nKey: String, CaseIterable, Sendable {
    // App & Window
    case appName
    case widgetTitle
    case settings

    // Tabs
    case tabGeneral
    case tabAppearance
    case tabMonitoring
    case tabCleanup
    case tabAbout

    // General Tab
    case language
    case languageFollowSystem
    case languageZh
    case languageEn
    case languageHint
    case startupSection
    case launchAtLogin
    case launchAtLoginDesc
    case startHidden
    case startHiddenDesc
    case notificationsSection
    case notifyOnCleanup
    case notifyOnCleanupDesc
    case soundEffects
    case soundEffectsDesc
    case memoryAlert
    case memoryAlertDesc

    // Appearance & Panel Tab
    case themeSection
    case theme
    case themeSystem
    case themeDark
    case themeLight
    case accentTint
    case accentVibrant
    case accentMonochrome
    case panelSection
    case panelStyle
    case styleMicro
    case styleCompact
    case styleStandard
    case styleExpanded
    case showWidget
    case alwaysOnTop
    case alwaysOnTopDesc
    case clickThrough
    case clickThroughDesc

    // Monitoring Tab
    case samplingSection
    case refreshInterval
    case smoothingWindow
    case smoothing1s
    case smoothing3s
    case smoothing5s
    case smoothingHint
    case processesSection
    case topProcessesCount
    case processesCount3
    case processesCount5
    case processesCount8
    case processesHint

    // History & Alerts
    case historySection
    case historyRecording
    case historyRecordingDesc
    case historyRetention
    case retentionDaysFormat
    case clearHistory
    case clearHistoryConfirm
    case historyUsage
    case history24hTitle
    case historyPeakToday
    case historyInsufficient
    case historyPeakDetailTitle
    case historyPeakAt
    case historyPeakProcesses
    case historyPeakNoProcess
    case historyPeakGPUNoProcess
    case historyPeakMemoryFormat
    case thresholdAlerts
    case thresholdAlertsDesc
    case alertCPU
    case alertMemory
    case alertDisk
    case alertBody
    case alertBodyWithProcess

    // Cleanup Tab
    case cleanupRulesSection
    case idleThreshold
    case idle5m
    case idle10m
    case idle15m
    case idle30m
    case idle60m
    case memoryThreshold
    case memoryNone
    case memory10MB
    case memory20MB
    case memory50MB
    case memory100MB
    case cleanupWhitelistSection
    case cleanupHint
    case searchPlaceholder
    case manualAdd
    case manualPlaceholder
    case add
    case refreshList
    case clearWhitelist
    case clearWhitelistConfirm
    case protectedCount
    case notRunning
    case noMatchingProcess
    case scanningProcesses
    case cleanupMatchHint

    // About Tab
    case aboutSection
    case appSubtitle
    case version
    case buildArch
    case dataSource
    case dataSourceDesc
    case alignment
    case alignmentDesc
    case openActivityMonitor
    case runDiagnostics
    case resetSettings
    case resetSettingsConfirm

    // Metrics & Tiles
    case uptime
    case cpu
    case user
    case system
    case cpuUserSystem
    case memory
    case total
    case totalAmount
    case cache
    case cacheAmount
    case compressed
    case compressedAmount
    case appMemory
    case wired
    case appAndWired
    case energy
    case cpuEstimate
    case cpuEnergyCounter
    case acPower
    case battery
    case batteryCharging
    case batteryRemaining
    case batteryPercent
    case disk
    case read
    case write
    case free
    case freeAmount
    case capacity
    case used
    case capacityAndUsed
    case network
    case gpu
    case gpuMemory
    case gpuDetail
    case gpuUnavailable
    case interfaces
    case interfacesCount
    case interfacesCountOnly
    case cumulative
    case totalNetworkInOut
    case topMemory
    case sampling
    case load
    case loadAmount
    case swap
    case swapAmount

    // Menus
    case menuShowWidget
    case menuHideWidget
    case menuExpandToStandard
    case menuCollapseToMicro
    case menuAddWidget
    case menuRemoveAllWidgets
    case menuRunCleanup
    case menuCleanupWhitelist
    case menuNoProtectableProcesses
    case menuClearWhitelist
    case menuOpenActivityMonitor
    case menuSettings
    case menuAbout
    case menuQuit
    case menuRefreshNow
    case menuSize
    case menuDuplicateWidget
    case menuPinToDesktop
    case menuAlwaysOnTop
    case menuRemoveWidget

    // Dialogs
    case cleanIdleProcesses
    case confirmCleanup
    case confirmCleanupDesc
    case cleanupNow
    case cancel
    case cleanupResult
    case cleanupSuccess
    case cleanupTerminated
    case cleanupStillRunning
    case done
    case ok
    case nothingToClean
    case nothingToCleanDesc
    case reasonSystem
    case reasonTerminal
    case reasonActive
    case reasonWhitelist

    // Menu Bar Stats Option
    case menuBarSection
    case showMenuBarStats
    case showMenuBarStatsDesc

    // Detailed Dialog Texts
    case confirmCleanupTitle
    case confirmCleanupSubtitle
    case confirmCleanupNote
    case candidateImpactPrefix
    case candidateIdlePrefix
    case resultTerminatedOnly
    case resultTerminatedAndRunning
    case resultFreedBytes
    case resultSurvivedNote
    case nothingToCleanRule1
    case nothingToCleanRule2
    case nothingToCleanRule3
    case nothingToCleanRule4
    case nothingToCleanScannedSummary
    case loginItemErrorTitle
    case loginItemErrorMessage
    case statusToolTip
    case impactPrefix

    // 单个进程：详情、退出与强制退出
    case processInfo
    case processTapHint
    case processPath
    case processParent
    case processStartedAt
    case processUptime
    case quitProcess
    case forceQuitProcess
    case forceQuitConfirm
    case forceQuitNow
    case processStillRunning
    case close

    // Units
    case secondsUnit
    case minutesUnit
}

/// 集中式多语言文本管理器。
public final class L10n: @unchecked Sendable {
    public static let shared = L10n()
    public static let languageDidChangeNotification = Notification.Name("MacStatsLanguageDidChangeNotification")

    private let lock = NSLock()
    private var _language: AppLanguage = .system

    public init() {
        let stored = UserDefaults.standard.string(forKey: "appLanguage")
        if let stored, let lang = AppLanguage(rawValue: stored) {
            _language = lang
        } else {
            _language = .system
        }
    }

    public var language: AppLanguage {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _language
        }
        set {
            lock.lock()
            _language = newValue
            lock.unlock()
            UserDefaults.standard.set(newValue.rawValue, forKey: "appLanguage")
            NotificationCenter.default.post(name: Self.languageDidChangeNotification, object: newValue)
        }
    }

    public var resolvedLanguage: ResolvedLanguage {
        language.resolved
    }

    public func setLanguage(_ lang: AppLanguage) {
        language = lang
    }

    public static func t(_ key: L10nKey, lang: ResolvedLanguage? = nil) -> String {
        string(key, lang: lang)
    }

    public static func format(_ key: L10nKey, _ args: CVarArg...) -> String {
        let template = string(key)
        return String(format: template, arguments: args)
    }

    public static func string(_ key: L10nKey, lang: ResolvedLanguage? = nil) -> String {
        let effective = lang ?? shared.resolvedLanguage
        switch effective {
        case .zhHans:
            return stringsZh[key] ?? stringsEn[key] ?? key.rawValue
        case .en:
            return stringsEn[key] ?? stringsZh[key] ?? key.rawValue
        }
    }

    // MARK: - 词库对照

    private static let stringsZh: [L10nKey: String] = [
        .appName: "MacStats Panel",
        .widgetTitle: "系统监视",
        .settings: "设置",

        .tabGeneral: "通用",
        .tabAppearance: "外观与面板",
        .tabMonitoring: "指标监控",
        .tabCleanup: "后台清理",
        .tabAbout: "关于",

        .language: "界面语言",
        .languageFollowSystem: "跟随系统",
        .languageZh: "简体中文",
        .languageEn: "English",
        .languageHint: "实时切换，面板、菜单与弹窗立即生效。",
        .startupSection: "启动与行为",
        .launchAtLogin: "登录时启动",
        .launchAtLoginDesc: "在系统开机或用户登录时自动启动小组件。",
        .startHidden: "启动时隐藏面板",
        .startHiddenDesc: "仅驻留菜单栏，点击菜单栏图标即可随时唤起面板。",
        .notificationsSection: "通知与声音",
        .notifyOnCleanup: "清理完成发送系统通知",
        .notifyOnCleanupDesc: "终止后台孤儿进程后发送 macOS 横幅通知。",
        .soundEffects: "操作反馈音效",
        .soundEffectsDesc: "清理完成或触发关键操作时播放系统提示音。",
        .memoryAlert: "内存压力严重警告",
        .memoryAlertDesc: "当系统内存压力升至警告或危急级别时自动提醒。",

        .themeSection: "外观主题",
        .theme: "外观模式",
        .themeSystem: "跟随系统",
        .themeDark: "深色模式",
        .themeLight: "浅色模式",
        .accentTint: "仪表配色",
        .accentVibrant: "经典多彩",
        .accentMonochrome: "极简浅灰",
        .panelSection: "面板形态与交互",
        .panelStyle: "面板形态",
        .styleMicro: "极简条",
        .styleCompact: "紧凑面板",
        .styleStandard: "标准面板",
        .styleExpanded: "详细面板",
        .showWidget: "显示桌面小组件",
        .alwaysOnTop: "始终置顶",
        .alwaysOnTopDesc: "面板悬浮在普通应用窗口之上，不被遮挡。",
        .clickThrough: "点击穿透（仅菜单栏可操作）",
        .clickThroughDesc: "鼠标点击直接穿透至下层桌面或窗口，仅菜单栏可操作。",

        .samplingSection: "采样与刷新",
        .refreshInterval: "刷新间隔",
        .smoothingWindow: "速率平滑窗口",
        .smoothing1s: "1 秒（实时瞬时）",
        .smoothing3s: "3 秒（动态平衡）",
        .smoothing5s: "5 秒（对齐活动监视器）",
        .smoothingHint: "5 秒平滑窗口与系统活动监视器一致，消除短时毛刺；1 秒瞬时捕捉波动峰值。",
        .processesSection: "进程列表设置",
        .topProcessesCount: "最多展示进程数",
        .processesCount3: "3 个进程",
        .processesCount5: "5 个进程",
        .processesCount8: "8 个进程",
        .processesHint: "在标准与详细面板中按内存降序排列占用最高的进程。",

        .historySection: "历史与告警",
        .historyRecording: "记录历史",
        .historyRecordingDesc: "每分钟落一个平均点，按天保存在本机；更早的小时数据按设置的时长自动清理。",
        .historyRetention: "保留时长",
        .retentionDaysFormat: "%d 天",
        .clearHistory: "清空历史",
        .clearHistoryConfirm: "清空后无法恢复，确定删除本机所有历史记录？",
        .historyUsage: "本机已占用 %@",
        .history24hTitle: "过去 24 小时",
        .historyPeakToday: "峰值 %@",
        .historyInsufficient: "刚开始记录，曲线会随使用逐渐补全",
        .historyPeakDetailTitle: "%@ 峰值",
        .historyPeakAt: "%@ · %@",
        .historyPeakProcesses: "当时的进程",
        .historyPeakNoProcess: "当时未记录进程（0.4 之前的历史）",
        .historyPeakGPUNoProcess: "GPU 归因暂未记录",
        .historyPeakMemoryFormat: "内存 %@",
        .thresholdAlerts: "持续高负载提醒",
        .thresholdAlertsDesc: "CPU ≥ 90%%、内存 ≥ 85%% 或磁盘 ≥ 90%% 连续 3 次采样时通知；同一指标 10 分钟内不重复。",
        .alertCPU: "CPU 持续高负载",
        .alertMemory: "内存持续偏高",
        .alertDisk: "磁盘空间不足",
        .alertBody: "%@，已连续超过阈值",
        .alertBodyWithProcess: "%@ · %@",

        .cleanupRulesSection: "清理判定策略",
        .idleThreshold: "闲置时间下限",
        .idle5m: "5 分钟",
        .idle10m: "10 分钟（推荐）",
        .idle15m: "15 分钟",
        .idle30m: "30 分钟",
        .idle60m: "1 小时",
        .memoryThreshold: "内存过滤阈值",
        .memoryNone: "不限制",
        .memory10MB: "≥ 10 MB",
        .memory20MB: "≥ 20 MB（推荐）",
        .memory50MB: "≥ 50 MB",
        .memory100MB: "≥ 100 MB",
        .cleanupWhitelistSection: "受保护白名单",
        .cleanupHint: "勾选 = 永远不清理。下面列出可能被清理的后台进程，每条附带说明；可搜索或手动添加保护名单。",
        .searchPlaceholder: "搜索进程名或说明",
        .manualAdd: "手动添加",
        .manualPlaceholder: "进程名，如 node",
        .add: "添加",
        .refreshList: "刷新列表",
        .clearWhitelist: "清空白名单",
        .clearWhitelistConfirm: "确定清空白名单？所有自定保护的进程名将被移除。",
        .protectedCount: "%d 项已保护",
        .notRunning: "未运行",
        .noMatchingProcess: "没有匹配的进程",
        .scanningProcesses: "正在扫描进程…",
        .cleanupMatchHint: "按可执行名或 ps 显示的名字匹配，忽略大小写",

        .aboutSection: "关于 MacStats Panel",
        .appSubtitle: "系统级轻量化桌面监控小组件",
        .version: "版本",
        .buildArch: "运行架构",
        .dataSource: "数据源",
        .dataSourceDesc: "Mach / IOKit / libproc 公开内核接口，无需 Root 或关闭 SIP",
        .alignment: "活动监视器对照",
        .alignmentDesc: "内存误差 ≤ 0.2GB，磁盘与网络速率逐字节一致",
        .openActivityMonitor: "打开活动监视器…",
        .runDiagnostics: "运行诊断自检",
        .resetSettings: "恢复所有默认设置",
        .resetSettingsConfirm: "确定要将所有设置恢复为默认值吗？",

        .uptime: "已运行 %@",
        .cpu: "CPU",
        .user: "用户",
        .system: "系统",
        .cpuUserSystem: "用户 %@ 系统 %@",
        .memory: "内存",
        .total: "共",
        .totalAmount: "共 %@",
        .cache: "缓存",
        .cacheAmount: "缓存 %@",
        .compressed: "压缩",
        .compressedAmount: "压缩 %@",
        .appMemory: "App",
        .wired: "联动",
        .appAndWired: "App %@ · 联动 %@",
        .energy: "能耗",
        .cpuEstimate: "CPU 估算",
        .cpuEnergyCounter: "CPU 能量计数",
        .acPower: "电源供电",
        .battery: "电池",
        .batteryCharging: "电池 %d%% · 充电中",
        .batteryRemaining: "电池 %d%% · 剩余 %@",
        .batteryPercent: "电池 %d%%",
        .disk: "磁盘",
        .read: "读",
        .write: "写",
        .free: "可用",
        .freeAmount: "可用 %@",
        .capacity: "容量",
        .used: "已用",
        .capacityAndUsed: "容量 %@ · 已用 %@",
        .network: "网络",
        .gpu: "GPU",
        .gpuMemory: "显存",
        .gpuDetail: "%@ · %d 核",
        .gpuUnavailable: "此机型不提供 GPU 计数",
        .interfaces: "接口",
        .interfacesCount: "%@ · 共 %d 个接口",
        .interfacesCountOnly: "%d 个接口",
        .cumulative: "累计",
        .totalNetworkInOut: "累计 ↓ %@ · ↑ %@",
        .topMemory: "内存占用最高",
        .sampling: "采样中…",
        .load: "负载",
        .loadAmount: "负载 %@",
        .swap: "交换",
        .swapAmount: "交换 %@",

        .menuShowWidget: "显示小组件",
        .menuHideWidget: "隐藏小组件",
        .menuExpandToStandard: "展开为标准面板",
        .menuCollapseToMicro: "收成极简条",
        .menuAddWidget: "添加桌面小组件",
        .menuRemoveAllWidgets: "移除所有附加小组件",
        .menuRunCleanup: "一键清理后台闲置进程…",
        .menuCleanupWhitelist: "清理白名单",
        .menuNoProtectableProcesses: "当前没有可保护的后台进程",
        .menuClearWhitelist: "清空白名单",
        .menuOpenActivityMonitor: "打开活动监视器…",
        .menuSettings: "设置…",
        .menuAbout: "关于 MacStats Panel",
        .menuQuit: "退出",
        .menuRefreshNow: "立即刷新",
        .menuSize: "尺寸",
        .menuDuplicateWidget: "复制一个同样的小组件",
        .menuPinToDesktop: "固定在桌面",
        .menuAlwaysOnTop: "始终置顶",
        .menuRemoveWidget: "移除这个小组件",

        .cleanIdleProcesses: "清理后台闲置进程",
        .confirmCleanup: "确定清理以下后台闲置进程？",
        .confirmCleanupDesc: "这些进程已闲置且无关联终端，可安全退出。",
        .cleanupNow: "立即清理",
        .cancel: "取消",
        .cleanupResult: "清理结果",
        .cleanupSuccess: "成功终止 %d 个进程",
        .cleanupTerminated: "已退出",
        .cleanupStillRunning: "仍在运行",
        .done: "完成",
        .ok: "我知道了",
        .nothingToClean: "没有需要清理的后台进程",
        .nothingToCleanDesc: "系统运行良好，未发现符合清理条件的闲置孤儿进程。",
        .reasonSystem: "系统与核心框架进程受保护",
        .reasonTerminal: "终端里正在运行的命令不会被触及",
        .reasonActive: "最近有 CPU 活动或刚启动不久的进程继续保留",
        .reasonWhitelist: "白名单中的进程永远不会被清理",

        .menuBarSection: "菜单栏状态",
        .showMenuBarStats: "在菜单栏显示数值",
        .showMenuBarStatsDesc: "在菜单栏图标旁实时显示 CPU 与内存占用百分比。",

        .confirmCleanupTitle: "清理 %d 个后台闲置进程？",
        .confirmCleanupSubtitle: "这些进程终止前的内存合计约 %@。只会请它们正常退出，不会强制结束。",
        .confirmCleanupNote: "3 秒内没退出的会保持运行",
        .candidateImpactPrefix: "影响：",
        .candidateIdlePrefix: "闲置 ",
        .resultTerminatedOnly: "已清理 %d 个进程",
        .resultTerminatedAndRunning: "已清理 %d 个，%d 个仍在运行",
        .resultFreedBytes: "这些进程终止前的内存合计为 %@；系统实际回收量可能不同。",
        .resultSurvivedNote: "仍在运行的进程可能在保存数据，或被系统自动拉起，已保持原样。",
        .nothingToCleanRule1: "只挑你自己启动、而且当初启动它的程序已经退出的后台命令",
        .nothingToCleanRule2: "它没有窗口、没接在终端里、没有正在连接的端口",
        .nothingToCleanRule3: "已经运行超过 10 分钟，最近 10 分钟也没怎么占用 CPU",
        .nothingToCleanRule4: "系统进程、App、白名单里的进程一律不碰",
        .nothingToCleanScannedSummary: "这次扫了 %d 个进程，%d 个按上面的规则排除了。",
        .loginItemErrorTitle: "无法修改登录项",
        .loginItemErrorMessage: "请把 App 放进「应用程序」文件夹后再试。",
        .statusToolTip: "CPU %@ · 内存 %@ · 能耗 %@",
        .impactPrefix: "结束它会怎样：",

        .processInfo: "进程信息",
        .processTapHint: "点开查看详情，可退出或强制退出",
        .processPath: "路径",
        .processParent: "父进程",
        .processStartedAt: "启动时间",
        .processUptime: "已运行 %@",
        .quitProcess: "退出",
        .forceQuitProcess: "强制退出…",
        .forceQuitConfirm: "强制退出会立即结束它，没保存的内容会丢失。",
        .forceQuitNow: "强制退出",
        .processStillRunning: "它没有退出，可能正在保存数据；可以再试一次，或强制退出。",
        .close: "关闭",

        .secondsUnit: "%@ 秒",
        .minutesUnit: "%d 分钟"
    ]

    private static let stringsEn: [L10nKey: String] = [
        .appName: "MacStats Panel",
        .widgetTitle: "System Stats",
        .settings: "Settings",

        .tabGeneral: "General",
        .tabAppearance: "Appearance & Panel",
        .tabMonitoring: "Monitoring",
        .tabCleanup: "Process Cleanup",
        .tabAbout: "About",

        .language: "Language",
        .languageFollowSystem: "Follow System",
        .languageZh: "简体中文",
        .languageEn: "English",
        .languageHint: "Switches live across panels, menus, and alert dialogs.",
        .startupSection: "Startup & Behavior",
        .launchAtLogin: "Launch at Login",
        .launchAtLoginDesc: "Automatically start widget when logging in to macOS.",
        .startHidden: "Start Minimized",
        .startHiddenDesc: "Run silently in menu bar on launch without showing floating panels.",
        .notificationsSection: "Notifications & Audio",
        .notifyOnCleanup: "Send Notification on Cleanup",
        .notifyOnCleanupDesc: "Post a banner notification when idle processes are terminated.",
        .soundEffects: "Sound Effects",
        .soundEffectsDesc: "Play feedback sound effect when cleanup completes.",
        .memoryAlert: "Critical Memory Alert",
        .memoryAlertDesc: "Notify when memory pressure reaches warning or critical levels.",

        .themeSection: "Appearance Theme",
        .theme: "Theme Mode",
        .themeSystem: "Follow System",
        .themeDark: "Dark Mode",
        .themeLight: "Light Mode",
        .accentTint: "Accent Style",
        .accentVibrant: "Vibrant Multi-color",
        .accentMonochrome: "Monochrome Slate",
        .panelSection: "Panel Style & Interaction",
        .panelStyle: "Panel Style",
        .styleMicro: "Micro Bar",
        .styleCompact: "Compact Panel",
        .styleStandard: "Standard Panel",
        .styleExpanded: "Expanded Panel",
        .showWidget: "Show Desktop Widget",
        .alwaysOnTop: "Always on Top",
        .alwaysOnTopDesc: "Keep widget floating above regular application windows.",
        .clickThrough: "Click-through",
        .clickThroughDesc: "Pass mouse clicks through to windows beneath; interact via menu bar.",

        .samplingSection: "Sampling & Refresh",
        .refreshInterval: "Refresh Interval",
        .smoothingWindow: "Rate Smoothing Window",
        .smoothing1s: "1s (Instantaneous)",
        .smoothing3s: "3s (Balanced)",
        .smoothing5s: "5s (Activity Monitor Alignment)",
        .smoothingHint: "5s window matches Activity Monitor's smoothing; 1s captures peaks instantly.",
        .processesSection: "Process List Settings",
        .topProcessesCount: "Top Processes Displayed",
        .processesCount3: "3 processes",
        .processesCount5: "5 processes",
        .processesCount8: "8 processes",
        .processesHint: "Processes with highest memory consumption shown in standard/expanded panels.",

        .historySection: "History & Alerts",
        .historyRecording: "Record History",
        .historyRecordingDesc: "One averaged point per minute, stored per day on this Mac; older hourly data is pruned after the retention you pick.",
        .historyRetention: "Keep History For",
        .retentionDaysFormat: "%d days",
        .clearHistory: "Clear History",
        .clearHistoryConfirm: "This cannot be undone. Delete all history stored on this Mac?",
        .historyUsage: "%@ on disk",
        .history24hTitle: "Last 24 Hours",
        .historyPeakToday: "Peak %@",
        .historyInsufficient: "Just started recording — the curve fills in as you use your Mac",
        .historyPeakDetailTitle: "%@ peak",
        .historyPeakAt: "%@ · %@",
        .historyPeakProcesses: "Processes at that time",
        .historyPeakNoProcess: "No processes recorded then (history before 0.4)",
        .historyPeakGPUNoProcess: "GPU attribution not recorded yet",
        .historyPeakMemoryFormat: "Memory %@",
        .thresholdAlerts: "Sustained Load Alerts",
        .thresholdAlertsDesc: "Notify when CPU ≥ 90%%, memory ≥ 85%%, or disk ≥ 90%% for 3 consecutive samples; each metric repeats at most every 10 minutes.",
        .alertCPU: "Sustained High CPU",
        .alertMemory: "Sustained High Memory",
        .alertDisk: "Low Disk Space",
        .alertBody: "%@, above the threshold",
        .alertBodyWithProcess: "%@ · %@",

        .cleanupRulesSection: "Cleanup Thresholds",
        .idleThreshold: "Minimum Idle Time",
        .idle5m: "5 minutes",
        .idle10m: "10 minutes (Recommended)",
        .idle15m: "15 minutes",
        .idle30m: "30 minutes",
        .idle60m: "1 hour",
        .memoryThreshold: "Memory Filter Threshold",
        .memoryNone: "No limit",
        .memory10MB: "≥ 10 MB",
        .memory20MB: "≥ 20 MB (Recommended)",
        .memory50MB: "≥ 50 MB",
        .memory100MB: "≥ 100 MB",
        .cleanupWhitelistSection: "Protected Whitelist",
        .cleanupHint: "Checked = Never clean. Listed below are idle candidate processes; search or add custom names to protect.",
        .searchPlaceholder: "Search process name or description",
        .manualAdd: "Add Manually",
        .manualPlaceholder: "Process name, e.g. node",
        .add: "Add",
        .refreshList: "Refresh List",
        .clearWhitelist: "Clear Whitelist",
        .clearWhitelistConfirm: "Are you sure you want to clear all whitelisted process names?",
        .protectedCount: "%d protected",
        .notRunning: "Not Running",
        .noMatchingProcess: "No matching processes",
        .scanningProcesses: "Scanning processes…",
        .cleanupMatchHint: "Matches executable or ps process title (case-insensitive)",

        .aboutSection: "About MacStats Panel",
        .appSubtitle: "Lightweight macOS System Monitor Widget",
        .version: "Version",
        .buildArch: "Architecture",
        .dataSource: "Data Source",
        .dataSourceDesc: "Mach / IOKit / libproc public APIs (No Root / SIP required)",
        .alignment: "Activity Monitor Alignment",
        .alignmentDesc: "Memory delta ≤ 0.2GB, disk & network byte-accurate",
        .openActivityMonitor: "Open Activity Monitor…",
        .runDiagnostics: "Run Diagnostics",
        .resetSettings: "Reset All Settings",
        .resetSettingsConfirm: "Are you sure you want to reset all preferences to default values?",

        .uptime: "Uptime %@",
        .cpu: "CPU",
        .user: "User",
        .system: "Sys",
        .cpuUserSystem: "User %@  Sys %@",
        .memory: "Memory",
        .total: "Total",
        .totalAmount: "Total %@",
        .cache: "Cache",
        .cacheAmount: "Cache %@",
        .compressed: "Compressed",
        .compressedAmount: "Compressed %@",
        .appMemory: "App",
        .wired: "Wired",
        .appAndWired: "App %@ · Wired %@",
        .energy: "Energy",
        .cpuEstimate: "CPU Estimate",
        .cpuEnergyCounter: "CPU Energy Counter",
        .acPower: "AC Power",
        .battery: "Battery",
        .batteryCharging: "Battery %d%% · Charging",
        .batteryRemaining: "Battery %d%% · %@ remaining",
        .batteryPercent: "Battery %d%%",
        .disk: "Disk",
        .read: "Read",
        .write: "Write",
        .free: "Free",
        .freeAmount: "Free %@",
        .capacity: "Capacity",
        .used: "Used",
        .capacityAndUsed: "Capacity %@ · Used %@",
        .network: "Network",
        .gpu: "GPU",
        .gpuMemory: "VRAM",
        .gpuDetail: "%@ · %d cores",
        .gpuUnavailable: "GPU counters unavailable",
        .interfaces: "Interfaces",
        .interfacesCount: "%@ · %d interfaces",
        .interfacesCountOnly: "%d interfaces",
        .cumulative: "Total",
        .totalNetworkInOut: "Total ↓ %@ · ↑ %@",
        .topMemory: "Top Memory",
        .sampling: "Sampling…",
        .load: "Load",
        .loadAmount: "Load %@",
        .swap: "Swap",
        .swapAmount: "Swap %@",

        .menuShowWidget: "Show Widget",
        .menuHideWidget: "Hide Widget",
        .menuExpandToStandard: "Expand to Standard Panel",
        .menuCollapseToMicro: "Collapse to Micro Bar",
        .menuAddWidget: "Add Desktop Widget",
        .menuRemoveAllWidgets: "Remove All Extra Widgets",
        .menuRunCleanup: "Clean Idle Background Processes…",
        .menuCleanupWhitelist: "Cleanup Whitelist",
        .menuNoProtectableProcesses: "No protectable background processes",
        .menuClearWhitelist: "Clear Whitelist",
        .menuOpenActivityMonitor: "Open Activity Monitor…",
        .menuSettings: "Settings…",
        .menuAbout: "About MacStats Panel",
        .menuQuit: "Quit",
        .menuRefreshNow: "Refresh Now",
        .menuSize: "Size",
        .menuDuplicateWidget: "Duplicate Widget",
        .menuPinToDesktop: "Pin to Desktop",
        .menuAlwaysOnTop: "Always on Top",
        .menuRemoveWidget: "Remove This Widget",

        .cleanIdleProcesses: "Clean Idle Background Processes",
        .confirmCleanup: "Terminate the following idle processes?",
        .confirmCleanupDesc: "These processes are idle with no attached terminal and can be safely terminated.",
        .cleanupNow: "Clean Up Now",
        .cancel: "Cancel",
        .cleanupResult: "Cleanup Result",
        .cleanupSuccess: "Successfully terminated %d processes",
        .cleanupTerminated: "Terminated",
        .cleanupStillRunning: "Still Running",
        .done: "Done",
        .ok: "OK",
        .nothingToClean: "No Idle Processes to Clean",
        .nothingToCleanDesc: "System is running smoothly. No orphan or idle background processes found.",
        .reasonSystem: "System and core framework processes are protected",
        .reasonTerminal: "Processes attached to active terminals are protected",
        .reasonActive: "Recently active or newly started processes are retained",
        .reasonWhitelist: "Whitelisted processes are never cleaned",

        .menuBarSection: "Menu Bar Status",
        .showMenuBarStats: "Show Metrics in Menu Bar",
        .showMenuBarStatsDesc: "Display live CPU and memory percentages beside the menu bar icon.",

        .confirmCleanupTitle: "Terminate %d idle processes?",
        .confirmCleanupSubtitle: "Their reported footprint is about %@. Sends SIGTERM for graceful exit.",
        .confirmCleanupNote: "Processes not exiting in 3s stay running",
        .candidateImpactPrefix: "Impact: ",
        .candidateIdlePrefix: "Idle ",
        .resultTerminatedOnly: "Terminated %d processes",
        .resultTerminatedAndRunning: "Terminated %d, %d still running",
        .resultFreedBytes: "Their reported footprint was %@; actual reclaim may differ.",
        .resultSurvivedNote: "Processes still running may be persisting data or restarted by system launchd.",
        .nothingToCleanRule1: "Only targets orphan commands started by you whose parent has already exited",
        .nothingToCleanRule2: "Has no window, not attached to terminal, and holds no active sockets",
        .nothingToCleanRule3: "Has run for >10 minutes with near-zero CPU usage over that idle time",
        .nothingToCleanRule4: "System daemons, app bundles, and whitelisted processes are always preserved",
        .nothingToCleanScannedSummary: "Scanned %d processes; %d excluded by safety rules.",
        .loginItemErrorTitle: "Unable to Update Login Item",
        .loginItemErrorMessage: "Please move the app to the Applications folder and try again.",
        .statusToolTip: "CPU %@ · Memory %@ · Energy %@",
        .impactPrefix: "Impact: ",

        .processInfo: "Process Info",
        .processTapHint: "Click for details; quit or force quit",
        .processPath: "Path",
        .processParent: "Parent",
        .processStartedAt: "Started",
        .processUptime: "Uptime %@",
        .quitProcess: "Quit",
        .forceQuitProcess: "Force Quit…",
        .forceQuitConfirm: "Force quitting ends it immediately; unsaved work will be lost.",
        .forceQuitNow: "Force Quit",
        .processStillRunning: "It didn't exit and may be saving data; try again or force quit.",
        .close: "Close",

        .secondsUnit: "%@ s",
        .minutesUnit: "%d min"
    ]
}
