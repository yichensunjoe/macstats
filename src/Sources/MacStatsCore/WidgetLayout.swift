import CoreGraphics

/// 小组件里可以出现的数据块。
public enum WidgetTile: String, Codable, Sendable, CaseIterable {
    case cpu
    case memory
    case energy
    case disk
    case network
    case gpu
    case processes
}

/// 极简条随尺寸微调的几何参数。
///
/// 极简条是面板里最贴边的一档：没有卡片、没有头尾，六个数字直接铺在底板上，
/// 所以留白和圆角都得跟着宽度走。窄条收紧留白，免得数字顶到弧线上；
/// 宽条放宽留白，长条才不会显得数字被挤在中间。圆角由高度给上限、宽度给压力，
/// 夹在 11…26 之间——矮条上不会圆成胶囊把第一栏推出弧线，长条上也不会平得像色块。
public struct MicroStripStyle: Equatable, Sendable {
    public var horizontalPadding: CGFloat
    public var verticalPadding: CGFloat
    public var cornerRadius: CGFloat
    /// 分隔线两侧留白。
    public var separatorSpacing: CGFloat
    public var separatorHeight: CGFloat
    /// 折成两行三列时的行距。
    public var rowSpacing: CGFloat

    public static func resolve(_ size: CGSize) -> MicroStripStyle {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        return MicroStripStyle(
            // 10…18：窄条两端留 10 出头就够，宽条给到 18 才不显得数字贴边。
            horizontalPadding: clamp(10 + width * 0.013, 10, 18),
            // 9…14：矮条少留一点，避免把 17pt 的数字压扁；两行三列时再放松。
            verticalPadding: clamp(height * 0.15, 9, 14),
            cornerRadius: clamp(min(height * 0.34, width * 0.08), 11, 26),
            separatorSpacing: clamp(width * 0.013, 3, 8),
            separatorHeight: clamp(height * 0.33, 18, 28),
            rowSpacing: clamp(height * 0.10, 8, 12)
        )
    }

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

/// 面板版式。由窗口实际尺寸推导，用户拖动边角即可在几档之间切换，
/// 右键菜单也能直接套用某一档的尺寸。
public enum WidgetLayout: String, Codable, Sendable, CaseIterable {
    /// 一行四个大数字（CPU / 内存 / 磁盘 / 网络），没有卡片、没有趋势线，
    /// 适合贴在菜单栏下方当指示灯；新装默认就用这一档。
    case micro
    /// CPU + 内存两块，保留趋势线与压力条。
    case compact
    /// 六块的标准形态。
    case standard
    /// 三列 + 更细的信息（每核占用、5 条进程、负载与交换）。
    case expanded

    public var displayName: String {
        switch self {
        case .micro: "极简"
        case .compact: "紧凑"
        case .standard: "标准"
        case .expanded: "详细"
        }
    }

    public var localizedName: String {
        switch self {
        case .micro: L10n.t(.styleMicro)
        case .compact: L10n.t(.styleCompact)
        case .standard: L10n.t(.styleStandard)
        case .expanded: L10n.t(.styleExpanded)
        }
    }

    /// 菜单里「添加小组件」时套用的初始尺寸。
    public var presetSize: CGSize {
        switch self {
        // 极简条固定六格（CPU / 内存 / GPU / 能耗 / 磁盘 / 网络），默认宽度按六栏排得下取。
        case .micro: CGSize(width: 452, height: 80)
        case .compact: CGSize(width: 340, height: 190)
        // 多了 GPU 一块，标准/详细各加一行的高度。
        case .standard: CGSize(width: 372, height: 640)
        case .expanded: CGSize(width: 600, height: 660)
        }
    }

    /// 再小就排不下了，拖拽缩放时按这个下限收敛。
    public static let minimumSize = CGSize(width: 236, height: 76)

    /// 卡片网格的列数；`micro` 不用卡片，返回 0。
    public var columns: Int {
        switch self {
        case .micro: 0
        case .compact, .standard: 2
        case .expanded: 3
        }
    }

    public var tiles: [WidgetTile] {
        switch self {
        case .micro: []
        case .compact: [.cpu, .memory]
        case .standard, .expanded: [.cpu, .memory, .energy, .disk, .network, .gpu, .processes]
        }
    }

    /// 进程块显示几行。
    public var processRows: Int {
        self == .expanded ? 5 : 3
    }

    /// 是否显示每核占用条（紧凑档放不下，省掉）。
    public var showsPerCore: Bool {
        self != .compact
    }

    public var showsHeader: Bool {
        self != .micro
    }

    public var showsFooter: Bool {
        self != .micro
    }

    /// 按内容尺寸选版式。阈值留了内容能排下的余量，避免在临界处出现挤压。
    public static func resolve(_ size: CGSize) -> WidgetLayout {
        if size.height < 140 || size.width < 300 { return .micro }
        if size.height < 336 { return .compact }
        // 三列要两排卡片 + 头尾，再矮就会把卡片压扁。
        if size.width >= 540, size.height >= 356 { return .expanded }
        return .standard
    }

    /// 极简条状与标准面板互为切换目标；其它版式一律先收成条。
    public static func toggled(_ current: WidgetLayout) -> WidgetLayout {
        current == .micro ? .standard : .micro
    }

    /// 某档版式在给定屏幕上允许的最大尺寸（留出菜单栏与 Dock）。
    public func clamped(to visibleFrame: CGRect) -> CGSize {
        let maxWidth = max(Self.minimumSize.width, visibleFrame.width - 24)
        let maxHeight = max(Self.minimumSize.height, visibleFrame.height - 24)
        return CGSize(
            width: min(max(presetSize.width, Self.minimumSize.width), maxWidth),
            height: min(max(presetSize.height, Self.minimumSize.height), maxHeight)
        )
    }
}
