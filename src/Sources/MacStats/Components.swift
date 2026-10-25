import SwiftUI
import MacStatsCore

/// 统一的小卡片容器：图标 + 标题 + 内容。
/// 高度不再写死：卡片随窗口伸缩，网格行高由外部决定。
struct Tile<Content: View>: View {
    var title: String
    var systemImage: String
    var tint: Color
    var minHeight: CGFloat = 96
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(Theme.labelFont)
                    .tracking(0.4)
                    .foregroundStyle(Theme.secondaryText)
                Spacer(minLength: 0)
            }
            content
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.tileFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Theme.tileStroke, lineWidth: 0.8)
        )
    }
}

/// 迷你趋势线：主曲线填充 + 描边，可叠加第二条对比曲线（虚线）。
struct Sparkline: View {
    var points: [Double]
    var secondary: [Double] = []
    var color: Color
    var secondaryColor: Color?

    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }
            if secondary.count >= 2, let secondaryColor {
                context.stroke(
                    path(secondary, in: size),
                    with: .color(secondaryColor.opacity(0.7)),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round,
                                       dash: [3, 2.5])
                )
            }
            guard points.count >= 2 else { return }
            let line = path(points, in: size)
            var area = line
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.addLine(to: CGPoint(x: 0, y: size.height))
            area.closeSubpath()
            context.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.40), color.opacity(0.02)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
            context.stroke(line, with: .color(color.opacity(0.95)),
                           style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
    }

    private func path(_ values: [Double], in size: CGSize) -> Path {
        var path = Path()
        guard values.count >= 2 else { return path }
        for (index, value) in values.enumerated() {
            let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
            let y = size.height * (1 - CGFloat(min(max(value, 0), 1)))
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

/// 每个逻辑核心一根竖条，带底轨，空闲核心也能看出位置。
struct CoreBars: View {
    var cores: [Double]

    var body: some View {
        GeometryReader { geo in
            let count = max(cores.count, 1)
            let spacing: CGFloat = 2.5
            let barWidth = max(1.5, (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(cores.enumerated()), id: \.offset) { _, value in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(Theme.track.opacity(0.7))
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(Theme.load(value).opacity(0.9))
                            .frame(height: max(2, geo.size.height * CGFloat(min(max(value, 0), 1))))
                    }
                    .frame(width: barWidth, height: geo.size.height)
                }
            }
            .frame(width: geo.size.width, alignment: .leading)
        }
    }
}

/// 内存压力条：填充比例按 pressureScore，颜色按压力等级。
struct PressureBar: View {
    var score: Double
    var pressure: MemoryPressure
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(Theme.pressure(pressure))
                    .frame(width: max(height, geo.size.width * CGFloat(min(max(score, 0), 1))))
            }
        }
        .frame(height: height)
    }
}

/// 单色用量条：磁盘占用这类只需要一个比例的场合。
struct UsageBar: View {
    var fraction: Double
    var color: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(color.opacity(0.85))
                    .frame(width: max(height, geo.size.width * CGFloat(min(max(fraction, 0), 1))))
            }
        }
        .frame(height: height)
    }
}

/// 内存构成条：App / 联动 / 被压缩，按占物理内存比例分段。
struct CompositionBar: View {
    var segments: [(value: Double, color: Color)]
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(segment.color)
                        .frame(width: max(0, geo.size.width * CGFloat(min(max(segment.value, 0), 1))))
                }
                Spacer(minLength: 0)
            }
            .background(Capsule().fill(Theme.track))
            .clipShape(Capsule())
        }
        .frame(height: height)
    }
}

/// 顶部大数字 + 次要说明。
struct ValueLine: View {
    var prefix: String?
    var value: String
    var caption: String
    var tint: Color?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let prefix {
                Text(prefix)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            Text(value)
                .font(Theme.valueFont)
                .foregroundStyle(tint ?? Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(caption)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
    }
}

/// 进程行：名称 + 占用比例条 + 数值。
struct ProcessRow: View {
    var name: String
    var value: String
    var fraction: Double
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.primaryText.opacity(0.9))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                Text(value)
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.secondaryText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.track)
                    Capsule()
                        .fill(tint.opacity(0.85))
                        .frame(width: max(2, geo.size.width * CGFloat(min(max(fraction, 0), 1))))
                }
            }
            .frame(height: 2.5)
        }
    }
}
