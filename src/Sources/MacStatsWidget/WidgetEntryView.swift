import WidgetKit
import SwiftUI
import MacStatsCore

struct WidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: StatsEntry
    /// 离屏预览时直接指定尺寸档（环境里的 widgetFamily 由系统注入，外部改不了）。
    var familyOverride: WidgetFamily?

    private var resolvedFamily: WidgetFamily { familyOverride ?? family }

    var body: some View {
        Group {
            switch resolvedFamily {
            case .systemSmall: SmallWidgetView(entry: entry)
            case .systemMedium: MediumWidgetView(entry: entry)
            default: LargeWidgetView(entry: entry, spacious: resolvedFamily == .systemExtraLarge)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) { Palette.backdrop }
    }
}

// MARK: - 小尺寸：只有数字

private struct SmallWidgetView: View {
    var entry: StatsEntry

    private var snapshot: MetricSnapshot { entry.snapshot }
    private var memoryFraction: Double {
        snapshot.memory.total > 0 ? Double(snapshot.memory.used) / Double(snapshot.memory.total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Circle().fill(Palette.cpu).frame(width: 5, height: 5)
                Text("CPU").font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.tertiary)
                Spacer(minLength: 0)
                Text(PercentFormat.percent(memoryFraction))
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Palette.memory)
            }

            Text(PercentFormat.precise(snapshot.cpu.total))
                .font(.system(size: 32, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Sparkline(values: entry.feed.cpuHistory, tint: Palette.cpu)
                .frame(maxHeight: .infinity)
                .padding(.top, 4)
                .padding(.bottom, 6)

            HStack(alignment: .bottom, spacing: 8) {
                miniStat("内存", ByteFormat.memory(snapshot.memory.used), Palette.memory)
                // 有 GPU 计数就把它放进来，没有的机型退回网络速率。
                if let gpu = snapshot.gpu {
                    miniStat("GPU", PercentFormat.precise(gpu.utilization), Palette.gpu)
                } else {
                    miniStat("网络", ByteFormat.decimalRate(snapshot.network.bytesInPerSecond), Palette.network)
                }
            }
        }
        .padding(12)
    }

    private func miniStat(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 8.5, weight: .semibold)).foregroundStyle(Palette.tertiary)
            Text(value)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 中尺寸：主板 + 四个格子

private struct MediumWidgetView: View {
    var entry: StatsEntry

    private var snapshot: MetricSnapshot { entry.snapshot }
    private var memoryFraction: Double {
        snapshot.memory.total > 0 ? Double(snapshot.memory.used) / Double(snapshot.memory.total) : 0
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Circle().fill(Palette.cpu).frame(width: 5, height: 5)
                    Text("CPU").font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.tertiary)
                }
                Text(PercentFormat.precise(snapshot.cpu.total))
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("负载 \(String(format: "%.2f", snapshot.cpu.loadAverage.first ?? 0))")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(Palette.tertiary)
                Sparkline(values: entry.feed.cpuHistory, tint: Palette.cpu)
                    .frame(height: 30)
                    .padding(.top, 6)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 7) {
                gridCell("内存", ByteFormat.memory(snapshot.memory.used), Palette.memory, fraction: memoryFraction)
                gridCell("磁盘", ByteFormat.decimalRate(snapshot.disk.readBytesPerSecond), Palette.disk)
                gridCell("网络", "↓ " + ByteFormat.decimalRate(snapshot.network.bytesInPerSecond), Palette.network)
                gridCell(
                    "能耗",
                    snapshot.energy.watts.map { String(format: "%.1f W", $0) } ?? "—",
                    Palette.energy,
                    fraction: snapshot.energy.watts.map { min(max($0 / 60, 0), 1) }
                )
                if let gpu = snapshot.gpu {
                    gridCell(
                        "GPU",
                        PercentFormat.precise(gpu.utilization),
                        Palette.gpu,
                        fraction: gpu.utilization
                    )
                }
            }
            .frame(width: 150)
        }
        .padding(14)
    }

    private func gridCell(_ title: String, _ value: String, _ tint: Color, fraction: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Circle().fill(tint).frame(width: 4, height: 4)
                Text(title).font(.system(size: 8.5, weight: .semibold)).foregroundStyle(Palette.tertiary)
                Spacer(minLength: 0)
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            if let fraction {
                UsageBar(fraction: fraction, tint: tint).frame(height: 2.5)
            }
        }
    }
}

// MARK: - 大尺寸：全量指标 + 进程

private struct LargeWidgetView: View {
    var entry: StatsEntry
    var spacious: Bool

    private var snapshot: MetricSnapshot { entry.snapshot }
    private var memoryFraction: Double {
        snapshot.memory.total > 0 ? Double(snapshot.memory.used) / Double(snapshot.memory.total) : 0
    }
    private var processRows: [ProcessStatus] {
        Array(spacious ? snapshot.processes.prefix(8) : snapshot.processes.prefix(3))
    }

    var body: some View {
        if spacious {
            spaciousBody
        } else {
            regularBody
        }
    }

    /// 特大尺寸：一排四张指标卡，下面用整宽列进程，把 700+ 的宽度用满。
    private var spaciousBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            HStack(alignment: .top, spacing: 12) {
                cpuCard
                memoryCard
                diskCard
                networkCard
            }
            if !processRows.isEmpty {
                processCard
                    .frame(maxHeight: .infinity)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
    }

    private var regularBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            HStack(alignment: .top, spacing: 10) {
                cpuCard
                memoryCard
            }

            HStack(spacing: 10) {
                diskCard
                networkCard
            }

            if !processRows.isEmpty {
                processList
                    .padding(.horizontal, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
    }

    // MARK: 卡片

    private var cpuCard: some View {
        card {
            VStack(alignment: .leading, spacing: 4) {
                cardTitle("CPU", Palette.cpu, trailing: PercentFormat.precise(snapshot.cpu.total))
                Sparkline(values: entry.feed.cpuHistory, tint: Palette.cpu).frame(height: 34)
                CoreBars(cores: snapshot.cpu.cores).frame(height: 10)
                Text(cpuDetail)
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(Palette.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private var memoryCard: some View {
        card {
            VStack(alignment: .leading, spacing: 5) {
                cardTitle("内存", Palette.memory, trailing: ByteFormat.memory(snapshot.memory.used))
                UsageBar(fraction: memoryFraction, tint: Palette.memory).frame(height: 4)
                Text("App \(ByteFormat.memory(snapshot.memory.app)) · 联动 \(ByteFormat.memory(snapshot.memory.wired))")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(Palette.tertiary)
                    .lineLimit(1)
                Text("压缩 \(ByteFormat.memory(snapshot.memory.compressed)) · 交换 \(ByteFormat.memory(snapshot.memory.swapUsed))")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(Palette.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private var diskCard: some View {
        card {
            VStack(alignment: .leading, spacing: 5) {
                cardTitle("磁盘", Palette.disk, trailing: ByteFormat.decimalRate(snapshot.disk.readBytesPerSecond))
                UsageBar(fraction: snapshot.disk.usedFraction, tint: Palette.disk).frame(height: 4)
                Text("写 \(ByteFormat.decimalRate(snapshot.disk.writeBytesPerSecond)) · 剩余 \(ByteFormat.decimalBytes(snapshot.disk.free))")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(Palette.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private var networkCard: some View {
        card {
            VStack(alignment: .leading, spacing: 5) {
                cardTitle("网络", Palette.network, trailing: "↓ " + ByteFormat.decimalRate(snapshot.network.bytesInPerSecond))
                Sparkline(values: entry.feed.networkInHistory, tint: Palette.network).frame(height: 24)
                Text("↑ \(ByteFormat.decimalRate(snapshot.network.bytesOutPerSecond)) · \(snapshot.network.activeInterfaces.first ?? "—")")
                    .font(.system(size: 9, weight: .medium).monospacedDigit())
                    .foregroundStyle(Palette.tertiary)
                    .lineLimit(1)
            }
        }
    }

    private var processCard: some View {
        card {
            processList
        }
    }

    private var processList: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("占用最高的进程")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Palette.tertiary)
            ForEach(processRows) { process in
                HStack(spacing: 6) {
                    Text(process.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(PercentFormat.precise(process.cpu))
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Palette.primary)
                    Text(ByteFormat.processMemory(process.memory))
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(Palette.tertiary)
                        .frame(width: 58, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cpuDetail: String {
        snapshot.cpu.cores.isEmpty ? "负载 \(loadText)" : "负载 \(loadText) · \(snapshot.cpu.cores.count) 核"
    }

    private var loadText: String {
        snapshot.cpu.loadAverage.prefix(3)
            .map { String(format: "%.2f", $0) }
            .joined(separator: " / ")
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(snapshot.hostName.isEmpty ? "系统监视" : snapshot.hostName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Palette.secondary)
            Text("· \(DurationFormat.uptime(snapshot.uptime))")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.tertiary)
            Spacer(minLength: 0)
            if let gpu = snapshot.gpu {
                Text("GPU \(PercentFormat.precise(gpu.utilization))")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Palette.gpu)
            }
            if let watts = snapshot.energy.watts {
                Text(String(format: "%.1f W", watts))
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Palette.energy)
            }
            if Date.now.timeIntervalSince(entry.feed.updatedAt) > 300 {
                Text("旧数据")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.tertiary)
            }
        }
    }

    private func cardTitle(_ title: String, _ tint: Color, trailing: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 4, height: 4)
            Text(title).font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.tertiary)
            Spacer(minLength: 4)
            Text(trailing)
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.8)
            )
    }
}

// MARK: - 通用零件

/// 每核占用的小竖条：颜色按负载从蓝到橙再到红，与悬浮面板一致。
private struct CoreBars: View {
    var cores: [Double]

    private var tint: (Double) -> Color {
        { load in
            switch load {
            case ..<0.45: Palette.cpu
            case ..<0.75: Color(hex: 0xFFC53B)
            default: Color(hex: 0xFF6B5B)
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let values = Array(cores.suffix(24))
            if !values.isEmpty {
                let spacing: CGFloat = 1.5
                let width = max(1, (geometry.size.width - spacing * CGFloat(values.count - 1)) / CGFloat(values.count))
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(tint(min(max(value, 0), 1)).opacity(0.85))
                            .frame(width: width, height: max(2, geometry.size.height * CGFloat(min(max(value, 0), 1))))
                    }
                }
            }
        }
    }
}

private struct Sparkline: View {
    var values: [Double]
    var tint: Color

    var body: some View {
        GeometryReader { geometry in
            let points = normalized()
            if points.count > 1 {
                let stepX = geometry.size.width / CGFloat(points.count - 1)
                let line = Path { path in
                    for (index, value) in points.enumerated() {
                        let point = CGPoint(x: CGFloat(index) * stepX, y: geometry.size.height * (1 - value))
                        if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                }
                let area = Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height))
                    for (index, value) in points.enumerated() {
                        path.addLine(to: CGPoint(x: CGFloat(index) * stepX, y: geometry.size.height * (1 - value)))
                    }
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.closeSubpath()
                }
                ZStack {
                    area.fill(
                        LinearGradient(
                            colors: [tint.opacity(0.28), tint.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    line.stroke(tint.opacity(0.9), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func normalized() -> [CGFloat] {
        let slice = Array(values.suffix(40))
        guard let maxValue = slice.max(), maxValue > 0 else {
            return Array(repeating: 0.02, count: slice.count)
        }
        let scale = max(maxValue, 0.05)
        return slice.map { CGFloat(min(max($0 / scale, 0.02), 1)) }
    }
}

private struct UsageBar: View {
    var fraction: Double
    var tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.track)
                Capsule()
                    .fill(tint)
                    .frame(width: max(2, geometry.size.width * CGFloat(min(max(fraction, 0), 1))))
            }
        }
    }
}
