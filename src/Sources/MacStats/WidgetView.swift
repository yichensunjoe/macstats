import SwiftUI
import Observation
import MacStatsCore

/// 小组件渲染所需的全部数据：最新快照 + 各指标的短历史。
struct WidgetData {
    var snapshot: MetricSnapshot = .empty
    var cpu = MetricRing(capacity: 90)
    var gpu = MetricRing(capacity: 90)
    var energy = MetricRing(capacity: 90)
    var diskRead = MetricRing(capacity: 90)
    var diskWrite = MetricRing(capacity: 90)
    var networkIn = MetricRing(capacity: 90)
    var networkOut = MetricRing(capacity: 90)
    var refreshInterval: TimeInterval = 1
    var topProcessesCount: Int = 5
    /// 分钟级历史（最多 24 小时），跨分钟时由 AppDelegate 更新。
    var history: [HistorySample] = []
}

/// 驱动小组件响应式刷新的 Observable 模型。
///
/// 通过属性观测实现细粒度更新，避免每秒重设 NSHostingView.rootView
/// 导致整棵 SwiftUI 视图树被销毁与重构。
@Observable
final class WidgetViewModel {
    var data: WidgetData

    init(data: WidgetData = WidgetData()) {
        self.data = data
    }
}

/// 桌面小组件主视图。
///
/// 版式不写死：按面板实际尺寸在「极简 / 紧凑 / 标准 / 详细」四档之间切换，
/// 所以同一个视图既能当一行指示灯，也能摊开成三列明细。
struct WidgetView: View {
    var model: WidgetViewModel
    var surface: SurfaceStyle = .material

    var onRefresh: () -> Void = {}
    var onOpenActivityMonitor: () -> Void = {}
    var onCleanup: () -> Void = {}

    @State private var hovering = false
    /// 当前打开的峰值详情；nil 表示没有 popover。点空白或再次点击同一个峰值都会回到 nil。
    @State private var selectedPeak: HistoryPeak?

    private var data: WidgetData { model.data }

    init(
        model: WidgetViewModel,
        surface: SurfaceStyle = .material,
        onRefresh: @escaping () -> Void = {},
        onOpenActivityMonitor: @escaping () -> Void = {},
        onCleanup: @escaping () -> Void = {}
    ) {
        self.model = model
        self.surface = surface
        self.onRefresh = onRefresh
        self.onOpenActivityMonitor = onOpenActivityMonitor
        self.onCleanup = onCleanup
    }

    init(
        data: WidgetData,
        surface: SurfaceStyle = .material,
        onRefresh: @escaping () -> Void = {},
        onOpenActivityMonitor: @escaping () -> Void = {},
        onCleanup: @escaping () -> Void = {}
    ) {
        self.model = WidgetViewModel(data: data)
        self.surface = surface
        self.onRefresh = onRefresh
        self.onOpenActivityMonitor = onOpenActivityMonitor
        self.onCleanup = onCleanup
    }

    private var snapshot: MetricSnapshot { data.snapshot }

    private var cpuPoints: [Double] {
        SeriesMath.normalize([data.cpu.values], minimumScale: 0.25).first ?? []
    }
    private var energyPoints: [Double] {
        SeriesMath.normalize([data.energy.values], minimumScale: 1).first ?? []
    }
    private var gpuPoints: [Double] {
        SeriesMath.normalize([data.gpu.values], minimumScale: 0.25).first ?? []
    }
    private var diskPoints: [[Double]] {
        SeriesMath.normalize([data.diskRead.values, data.diskWrite.values], minimumScale: 64 * 1024)
    }
    private var networkPoints: [[Double]] {
        SeriesMath.normalize([data.networkIn.values, data.networkOut.values], minimumScale: 32 * 1024)
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = WidgetLayout.resolve(geometry.size)
            let strip = MicroStripStyle.resolve(geometry.size)
            let isStrip = layout == .micro
            // 极简条随尺寸收放圆角，常规面板保持统一的大圆角。
            let cornerRadius = isStrip ? strip.cornerRadius : Theme.cornerRadius
            Group {
                if isStrip {
                    microBody(strip)
                } else {
                    fullBody(layout)
                }
            }
            .padding(
                isStrip
                    ? EdgeInsets(
                        top: strip.verticalPadding,
                        leading: strip.horizontalPadding,
                        bottom: strip.verticalPadding,
                        trailing: strip.horizontalPadding
                    )
                    : EdgeInsets(top: 11, leading: 11, bottom: 11, trailing: 11)
            )
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .background(WidgetBackground(style: surface, cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(hovering ? 0.35 : 0.14), Color.white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
            .onHover { hovering = $0 }
        }
    }

    // MARK: - 极简档

    /// 极简条固定六格：CPU / 内存 / GPU / 能耗 / 磁盘 / 网络。
    /// 用紧凑数字（`43G`、`37M/s`）换取宽度，任何宽度下都不藏指标。
    private var microStats: [(title: String, value: String, tint: Color)] {
        [
            (L10n.t(.cpu), PercentFormat.precise(snapshot.cpu.total), Theme.cpu),
            (L10n.t(.memory), ByteFormat.compactMemory(snapshot.memory.used), Theme.memory),
            (L10n.t(.gpu), snapshot.gpu.map { PercentFormat.percent($0.utilization) } ?? "—", Theme.gpu),
            (L10n.t(.energy), snapshot.energy.watts.map { EnergyFormat.compactWatts($0) } ?? "—", Theme.energy),
            (L10n.t(.disk), ByteFormat.compactRate(snapshot.disk.readBytesPerSecond), Theme.disk),
            (L10n.t(.network), "↓" + ByteFormat.compactRate(snapshot.network.bytesInPerSecond), Theme.network)
        ]
    }

    private func microBody(_ style: MicroStripStyle) -> some View {
        GeometryReader { geometry in
            let stats = microStats
            // 这里的尺寸已经是扣掉内边距后的内容盒，分栏只剩分隔线要算。
            let innerWidth = max(geometry.size.width, 60)
            let innerHeight = max(geometry.size.height, 40)
            let separatorPadding = style.separatorSpacing
            let oneRowColumn = (innerWidth - 5 * (1 + separatorPadding * 2)) / 6
            // 一行摆六个会把字挤到不可读时（例如 287pt 宽的面板），
            // 而竖向又有空余，就折成两行三列——仍然六个指标，但能保持大字号。
            let wraps = oneRowColumn < 46 && innerHeight >= 78
            let columns = wraps ? 3 : 6
            let columnWidth = (innerWidth - CGFloat(columns - 1) * (1 + separatorPadding * 2)) / CGFloat(columns)
            let valueSize = min(17, max(9.5, columnWidth / 3.6))
            // 极窄时标题会截成 “C…”，先把色点换成纯文字标题。
            let showsDot = columnWidth >= 44
            let rows: [[(title: String, value: String, tint: Color)]] = stride(
                from: 0, to: stats.count, by: columns
            ).map { start in
                Array(stats[start..<min(start + columns, stats.count)])
            }

            VStack(spacing: wraps ? style.rowSpacing : 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { index, item in
                            if index > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 1, height: style.separatorHeight)
                                    .padding(.horizontal, separatorPadding)
                            }
                            microStat(title: item.title, value: item.value, tint: item.tint, valueSize: valueSize, showsDot: showsDot)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private func microStat(title: String, value: String, tint: Color, valueSize: CGFloat, showsDot: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                if showsDot {
                    Circle().fill(tint).frame(width: 5, height: 5)
                }
                Text(title)
                    .font(.system(size: showsDot ? 9 : 8, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(value)
                .font(.system(size: valueSize, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 常规档（紧凑 / 标准 / 详细）

    private func fullBody(_ layout: WidgetLayout) -> some View {
        VStack(spacing: 8) {
            header
            tileGrid(layout)
            if layout != .compact {
                // 固定高度：Tile 内部是 maxHeight: .infinity，不钉住就会把下方的卡片挤扁。
                historyCard.frame(height: 84)
            }
            if layout.showsFooter {
                footer
            }
        }
    }

    private func tileGrid(_ layout: WidgetLayout) -> some View {
        let tiles = layout.tiles
        let columns = max(layout.columns, 1)
        let rows: [[WidgetTile]] = stride(from: 0, to: tiles.count, by: columns).map { start in
            Array(tiles[start..<min(start + columns, tiles.count)])
        }
        return VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { tile in
                        tileView(tile, layout: layout)
                    }
                    // 末行只剩一块时让它横跨整行（进程榜放全宽更好读）；
                    // 只剩两块时仍然补占位，保持卡片等宽。
                    if row.count < columns, row.count > 1 {
                        ForEach(0..<(columns - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func tileView(_ tile: WidgetTile, layout: WidgetLayout) -> some View {
        switch tile {
        case .cpu: cpuTile(layout)
        case .memory: memoryTile(layout)
        case .energy: energyTile
        case .disk: diskTile(layout)
        case .network: networkTile(layout)
        case .gpu: gpuTile(layout)
        case .processes: processTile(layout)
        }
    }

    // MARK: - 24 小时历史

    private var historyCard: some View {
        Tile(
            title: L10n.t(.history24hTitle),
            systemImage: "clock.arrow.circlepath",
            tint: Theme.network,
            minHeight: 62
        ) {
            if data.history.count >= 2 {
                HStack(spacing: 10) {
                    historySeries(
                        metric: .cpu,
                        values: data.history.map(\.cpu),
                        color: Theme.cpu
                    )
                    historySeries(
                        metric: .memory,
                        values: data.history.map(\.memory),
                        color: Theme.memory
                    )
                    historySeries(
                        metric: .gpu,
                        values: data.history.compactMap(\.gpu),
                        color: Theme.gpu
                    )
                }
            } else {
                Text(L10n.t(.historyInsufficient))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func historySeries(metric: HistoryMetric, values: [Double], color: Color) -> some View {
        // 峰值统一走 HistoryAnalysis，不在视图里再写一遍「取最大值」。
        let peak = HistoryAnalysis.peak(in: data.history, metric: metric)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 4.5, height: 4.5)
                Text(historyMetricTitle(metric))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                Spacer(minLength: 2)
                if let peak {
                    // 外观与原文字一致：字号/颜色/行数都不变，只多一个点击动作。
                    Button(action: { togglePeak(peak) }) {
                        Text(L10n.format(.historyPeakToday, PercentFormat.percent(peak.value)))
                            .font(.system(size: 8.5, weight: .medium).monospacedDigit())
                            .foregroundStyle(Theme.tertiaryText)
                            .lineLimit(1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: peakPopoverBinding(for: metric), arrowEdge: .bottom) {
                        if let selected = selectedPeak, selected.metric == metric {
                            PeakDetailView(peak: selected)
                        }
                    }
                } else {
                    // 没有 GPU 计数器时保持原来的「—」，不给假按钮。
                    Text("—")
                        .font(.system(size: 8.5, weight: .medium).monospacedDigit())
                        .foregroundStyle(Theme.tertiaryText)
                        .lineLimit(1)
                }
            }
            Sparkline(points: values, color: color)
                .frame(height: 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func historyMetricTitle(_ metric: HistoryMetric) -> String {
        switch metric {
        case .cpu: L10n.t(.cpu)
        case .memory: L10n.t(.memory)
        case .gpu: L10n.t(.gpu)
        }
    }

    /// 再点同一个峰值关闭；点另一个峰值则切换。
    private func togglePeak(_ peak: HistoryPeak) {
        if selectedPeak?.metric == peak.metric {
            selectedPeak = nil
        } else {
            selectedPeak = peak
        }
    }

    /// popover 显隐跟着 selectedPeak 走：点空白处系统会置 false，这里同步清空。
    private func peakPopoverBinding(for metric: HistoryMetric) -> Binding<Bool> {
        Binding(
            get: { selectedPeak?.metric == metric },
            set: { presented in
                if !presented, selectedPeak?.metric == metric {
                    selectedPeak = nil
                }
            }
        )
    }

    private var header: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Theme.pressure(snapshot.memory.pressure))
                .frame(width: 6, height: 6)
                .shadow(color: Theme.pressure(snapshot.memory.pressure).opacity(0.9), radius: 3)
            // 面板标题用 App 显示名（MacS）；.widgetTitle 是系统小组件库里的画廊名，两者不是一回事。
            Text(L10n.t(.appName))
                .font(.system(size: 11.5, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Theme.primaryText)
            Text(shortHost)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(L10n.format(.uptime, DurationFormat.uptime(snapshot.uptime)))
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(height: 15)
    }

    private var shortHost: String {
        let name = snapshot.hostName.split(separator: ".").first.map(String.init) ?? snapshot.hostName
        return name.isEmpty ? "" : name
    }

    // MARK: - Tiles

    private func cpuTile(_ layout: WidgetLayout) -> some View {
        Tile(title: L10n.t(.cpu), systemImage: "cpu", tint: Theme.cpu) {
            // 紧凑档的卡片窄，副标题会挤掉大数字，改成下面单独一行。
            ValueLine(
                value: PercentFormat.precise(snapshot.cpu.total),
                caption: layout == .compact ? "" : L10n.format(.cpuUserSystem, PercentFormat.percent(snapshot.cpu.user), PercentFormat.percent(snapshot.cpu.system))
            )
            Sparkline(points: cpuPoints, color: Theme.cpu)
                .frame(height: 20)
            if layout == .compact {
                Text(L10n.format(.cpuUserSystem, PercentFormat.percent(snapshot.cpu.user), PercentFormat.percent(snapshot.cpu.system)))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }
            if layout.showsPerCore {
                CoreBars(cores: snapshot.cpu.cores)
                    .frame(height: 12)
            }
        }
    }

    private func memoryTile(_ layout: WidgetLayout) -> some View {
        Tile(title: L10n.t(.memory), systemImage: "memorychip", tint: Theme.memory) {
            ValueLine(
                value: ByteFormat.memory(snapshot.memory.used),
                caption: layout == .compact ? "" : L10n.format(.totalAmount, ByteFormat.memory(snapshot.memory.total))
            )
            PressureBar(score: snapshot.memory.pressureScore, pressure: snapshot.memory.pressure)
            CompositionBar(segments: memorySegments)
            if layout == .compact {
                Text(L10n.format(.totalAmount, ByteFormat.memory(snapshot.memory.total)) + " · " + L10n.format(.cacheAmount, ByteFormat.memory(snapshot.memory.cachedFiles)))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                HStack(spacing: 4) {
                    Text(L10n.format(.cacheAmount, ByteFormat.memory(snapshot.memory.cachedFiles)))
                        .foregroundStyle(Theme.tertiaryText)
                    Text("· " + L10n.format(.compressedAmount, ByteFormat.memory(snapshot.memory.compressed)))
                        .foregroundStyle(Theme.tertiaryText)
                    Spacer(minLength: 0)
                }
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
            }
            if layout == .expanded {
                Text(L10n.format(.appAndWired, ByteFormat.memory(snapshot.memory.app), ByteFormat.memory(snapshot.memory.wired)))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }
        }
    }

    private var memorySegments: [(value: Double, color: Color)] {
        let total = max(Double(snapshot.memory.total), 1)
        return [
            (Double(snapshot.memory.app) / total, Theme.memory),
            (Double(snapshot.memory.wired) / total, Theme.cpu),
            (Double(snapshot.memory.compressed) / total, Theme.energy)
        ]
    }

    private func gpuTile(_ layout: WidgetLayout) -> some View {
        Tile(title: L10n.t(.gpu), systemImage: "square.stack.3d.up.fill", tint: Theme.gpu) {
            if let gpu = snapshot.gpu {
                ValueLine(
                    value: PercentFormat.precise(gpu.utilization),
                    caption: gpuCaption(gpu)
                )
                Sparkline(points: gpuPoints, color: Theme.gpu)
                    .frame(height: 20)
                if layout == .expanded, let allocated = gpu.memoryAllocated {
                    Text("\(L10n.t(.gpuMemory)) 分配 \(ByteFormat.memory(allocated))")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else {
                ValueLine(value: "—", caption: L10n.t(.gpuUnavailable))
                Spacer(minLength: 0)
            }
        }
    }

    private func gpuCaption(_ gpu: GPUStatus) -> String {
        guard let memory = gpu.memoryInUse else { return gpu.model ?? "" }
        let size = ByteFormat.memory(memory)
        if let cores = gpu.coreCount {
            return L10n.format(.gpuDetail, size, cores)
        }
        return "\(L10n.t(.gpuMemory)) \(size)"
    }

    private var energyTile: some View {
        Tile(title: L10n.t(.energy), systemImage: "bolt.fill", tint: Theme.energy) {
            ValueLine(
                value: snapshot.energy.watts.map { EnergyFormat.watts($0) } ?? "—",
                caption: snapshot.energy.isEstimated ? L10n.t(.cpuEstimate) : L10n.t(.cpuEnergyCounter)
            )
            Sparkline(points: energyPoints, color: Theme.energy)
                .frame(height: 20)
            HStack(spacing: 4) {
                if let percent = snapshot.energy.batteryPercent {
                    Image(systemName: batterySymbol(percent: percent))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(snapshot.energy.isCharging ? Theme.memory : Theme.energy)
                    Text(batteryText(percent: percent))
                        .foregroundStyle(Theme.tertiaryText)
                } else {
                    Image(systemName: "powerplug.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.energy)
                    Text(L10n.t(.acPower))
                        .foregroundStyle(Theme.tertiaryText)
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 9, weight: .medium))
            .lineLimit(1)
        }
    }

    private func diskTile(_ layout: WidgetLayout) -> some View {
        Tile(title: L10n.t(.disk), systemImage: "internaldrive.fill", tint: Theme.disk) {
            // 读写速率都比活动监视器的“读取/写入的数据/秒”；写速率放到底行留出宽度。
            ValueLine(
                prefix: L10n.t(.read),
                value: ByteFormat.decimalRate(snapshot.disk.readBytesPerSecond),
                caption: ""
            )
            Sparkline(
                points: diskPoints.first ?? [],
                secondary: diskPoints.count > 1 ? diskPoints[1] : [],
                color: Theme.disk,
                secondaryColor: Theme.energy
            )
            .frame(height: 22)
            HStack(spacing: 3) {
                Text(L10n.t(.write) + " " + ByteFormat.decimalRate(snapshot.disk.writeBytesPerSecond))
                Text("· " + L10n.format(.freeAmount, ByteFormat.decimalBytes(snapshot.disk.free)))
                Spacer(minLength: 0)
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)
            .lineLimit(1)
            if layout == .expanded {
                UsageBar(fraction: snapshot.disk.usedFraction, color: Theme.disk)
                    .frame(height: 5)
                Text(L10n.format(.capacityAndUsed, ByteFormat.decimalBytes(snapshot.disk.capacity), PercentFormat.percent(snapshot.disk.usedFraction)))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
            }
        }
    }

    private func networkTile(_ layout: WidgetLayout) -> some View {
        Tile(title: L10n.t(.network), systemImage: "network", tint: Theme.network) {
            ValueLine(
                prefix: "↓",
                value: ByteFormat.decimalRate(snapshot.network.bytesInPerSecond),
                caption: "↑ \(ByteFormat.decimalRate(snapshot.network.bytesOutPerSecond))"
            )
            Sparkline(
                points: networkPoints.first ?? [],
                secondary: networkPoints.count > 1 ? networkPoints[1] : [],
                color: Theme.network,
                secondaryColor: Theme.cpu
            )
            .frame(height: 22)
            HStack(spacing: 3) {
                Text(interfaceSummary)
                Spacer(minLength: 0)
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)
            .lineLimit(1)
            if layout == .expanded {
                Text(L10n.format(.totalNetworkInOut, ByteFormat.decimalBytes(snapshot.network.totalBytesIn), ByteFormat.decimalBytes(snapshot.network.totalBytesOut)))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    private func processTile(_ layout: WidgetLayout) -> some View {
        Tile(title: L10n.t(.topMemory), systemImage: "list.bullet", tint: Theme.primaryText.opacity(0.7)) {
            let total = max(snapshot.processes.first?.memory ?? 0, 1)
            VStack(spacing: 4) {
                ForEach(snapshot.processes.prefix(min(layout.processRows, data.topProcessesCount))) { process in
                    ProcessRow(
                        name: process.name,
                        value: "CPU \(PercentFormat.processCPU(process.cpu))  \(ByteFormat.processMemory(process.memory))",
                        fraction: Double(process.memory) / Double(total),
                        tint: Theme.memory
                    )
                }
                if snapshot.processes.isEmpty {
                    Text(L10n.t(.sampling))
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Text(L10n.format(.loadAmount, loadText))
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.tertiaryText)
            Spacer(minLength: 0)
            Text(L10n.format(.swapAmount, ByteFormat.memory(snapshot.memory.swapUsed)))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
            Button(action: onCleanup) {
                Image(systemName: "trash")
                    .font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.secondaryText.opacity(hovering ? 0.95 : 0.55))
            .help(L10n.t(.cleanIdleProcesses))
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.secondaryText.opacity(hovering ? 0.95 : 0.55))
            .help(L10n.t(.menuRefreshNow))
            Button(action: onOpenActivityMonitor) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.secondaryText.opacity(hovering ? 0.95 : 0.55))
            .help(L10n.t(.openActivityMonitor))
        }
        .frame(height: 12)
    }

    private var loadText: String {
        snapshot.cpu.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: " ")
    }

    private var interfaceSummary: String {
        if let primary = snapshot.network.activeInterfaces.first {
            return L10n.format(.interfacesCount, primary, snapshot.network.interfaceCount)
        }
        return L10n.format(.interfacesCountOnly, snapshot.network.interfaceCount)
    }

    private func batterySymbol(percent: Int) -> String {
        if snapshot.energy.isCharging { return "battery.100percent.bolt" }
        switch percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private func batteryText(percent: Int) -> String {
        if snapshot.energy.isCharging { return L10n.format(.batteryCharging, percent) }
        if let minutes = snapshot.energy.minutesRemaining {
            return L10n.format(.batteryRemaining, percent, DurationFormat.minutes(minutes))
        }
        return L10n.format(.batteryPercent, percent)
    }
}

// MARK: - 峰值详情浮层

/// 峰值详情浮层：哪个指标、几点、多高，以及当时 CPU 最高的几个进程。
///
/// 数据来自 HistorySample.topProcesses（B1 起才写入）；0.4 之前的历史没有进程，
/// 这里必须如实说「未记录」，不能用当前进程列表补——那会把归因变成编造。
private struct PeakDetailView: View {
    var peak: HistoryPeak

    private var metricTitle: String {
        switch peak.metric {
        case .cpu: L10n.t(.cpu)
        case .memory: L10n.t(.memory)
        case .gpu: L10n.t(.gpu)
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: peak.sample.timestamp)
    }

    private var processes: [ProcessAttribution] { peak.sample.topProcesses ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L10n.format(.historyPeakDetailTitle, metricTitle))
                .font(.system(size: 11, weight: .semibold))
            Text(L10n.format(.historyPeakAt, timeText, PercentFormat.percent(peak.value)))
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)

            if peak.metric == .gpu {
                // GPU 归因这一轮不做，明说比留空更可信。
                Text(L10n.t(.historyPeakGPUNoProcess))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if processes.isEmpty {
                Text(L10n.t(.historyPeakNoProcess))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(L10n.t(.historyPeakProcesses))
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.tertiary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(processes.prefix(3).enumerated()), id: \.offset) { _, process in
                        PeakProcessRow(process: process)
                    }
                }
            }
        }
        .padding(11)
        .frame(width: 208, alignment: .leading)
    }
}

/// 峰值浮层里的一行进程：名字 + CPU% + 内存，附一句人话说明（有词条时）。
private struct PeakProcessRow: View {
    var process: ProcessAttribution

    private var summary: String? {
        // 只取第一句：浮层窄，完整说明留给清理对话框。
        let text = ProcessGlossary.explain(name: process.name).summary
        guard !text.isEmpty else { return nil }
        if let stop = text.firstIndex(where: { $0 == "。" || $0 == "." }) {
            return String(text[...stop])
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(process.name.isEmpty ? "—" : process.name)
                    .font(.system(size: 9.5, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(PercentFormat.processCPU(process.cpu))
                    .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                Text(L10n.format(.historyPeakMemoryFormat, ByteFormat.memory(process.memory)))
                    .font(.system(size: 9, weight: .regular).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let summary {
                Text(summary)
                    .font(.system(size: 8, weight: .regular))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
