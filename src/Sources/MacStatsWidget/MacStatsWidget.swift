import WidgetKit
import SwiftUI
import MacStatsCore

/// 系统「小组件库」里的入口。右键桌面 →「编辑小组件」，搜「系统监视」即可添加，
/// 小/中/大/特大四档各自对应桌面上的四种形态。
@main
struct MacStatsWidgetBundle: WidgetBundle {
    var body: some Widget {
        MacStatsWidget()
    }
}

struct MacStatsWidget: Widget {
    static let kind = "com.macstats.app.widget.summary"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: StatsTimelineProvider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("系统监视")
        .description("CPU、内存、能耗、磁盘与网络；小尺寸只看数字，拉大后展开趋势和进程。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

