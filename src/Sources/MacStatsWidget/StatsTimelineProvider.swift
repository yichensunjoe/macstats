import WidgetKit
import SwiftUI
import MacStatsCore

struct StatsEntry: TimelineEntry {
    var date: Date
    var feed: WidgetFeed

    var snapshot: MetricSnapshot { feed.snapshot }

    /// 图库预览与首次加载用的示例数值，避免空白。
    static let placeholder = StatsEntry(
        date: .now,
        feed: WidgetFeed(
            snapshot: MetricSnapshot(
                timestamp: .now,
                hostName: "Mac",
                uptime: 86_400 * 3,
                cpu: CPUStatus(
                    total: 0.23, user: 0.15, system: 0.08, idle: 0.77,
                    cores: [0.18, 0.31, 0.22, 0.4, 0.12, 0.26, 0.19, 0.33, 0.21, 0.15, 0.28, 0.24],
                    loadAverage: [2.1, 1.8, 1.6]
                ),
                memory: MemoryStatus(
                    total: 64 * 1_073_741_824,
                    used: 39 * 1_073_741_824,
                    app: 28 * 1_073_741_824,
                    wired: 4 * 1_073_741_824,
                    compressed: 4 * 1_073_741_824,
                    cachedFiles: 17 * 1_073_741_824,
                    free: 7 * 1_073_741_824,
                    swapUsed: 1_500_000_000,
                    swapTotal: 2_000_000_000,
                    pressure: .normal,
                    pressureScore: 0.42
                ),
                energy: EnergyStatus(
                    watts: 21.2, isEstimated: false, batteryPercent: nil,
                    isCharging: false, isOnBattery: false, minutesRemaining: nil
                ),
                disk: DiskStatus(
                    readBytesPerSecond: 4_200_000, writeBytesPerSecond: 1_100_000,
                    totalReadBytes: 0, totalWrittenBytes: 0,
                    capacity: 1_000_000_000_000, free: 380_000_000_000
                ),
                network: NetworkStatus(
                    bytesInPerSecond: 1_800_000, bytesOutPerSecond: 240_000,
                    totalBytesIn: 0, totalBytesOut: 0, interfaceCount: 1, activeInterfaces: ["en0"]
                ),
                processes: [
                    ProcessStatus(pid: 597, name: "WindowServer", cpu: 0.12, memory: 998 * 1_048_576, energyWatts: 1.2),
                    ProcessStatus(pid: 51303, name: "微信", cpu: 0.03, memory: 628 * 1_048_576, energyWatts: 0.4),
                    ProcessStatus(pid: 97722, name: "WPS Office", cpu: 0.01, memory: 515 * 1_048_576, energyWatts: 0.2)
                ],
                // 图库预览也带上 GPU，否则小/中/大尺寸的 GPU 格子在截图与预览里永远缺席。
                gpu: GPUStatus(
                    utilization: 0.37, renderer: 0.34, tiler: 0.18,
                    memoryInUse: 2_600_000_000, memoryAllocated: 3_200_000_000,
                    coreCount: 20, model: "Apple M5 Pro"
                )
            ),
            cpuHistory: [0.18, 0.24, 0.31, 0.22, 0.26, 0.41, 0.38, 0.29, 0.24, 0.21, 0.27, 0.23],
            memoryHistory: Array(repeating: 0.61, count: 12),
            networkInHistory: [0.2, 0.6, 1.1, 0.8, 1.6, 2.2, 1.4, 0.9, 1.7, 1.2, 1.5, 1.8],
            networkOutHistory: [0.1, 0.2, 0.3, 0.2, 0.4, 0.5, 0.3, 0.2, 0.4, 0.3, 0.2, 0.24]
        )
    )
}

/// 数据来源：优先用主程序递过来的快照；主程序没开或快照过期时，扩展自己采一次。
/// 这样小组件单独存在时也有数，使用持久的采样器计算差分，无需同步阻塞 sleep。
enum StatsFeedSource {
    private static let fallbackSampler = SystemSampler(config: SamplerConfig(processLimit: 0, includeProcesses: false))

    static func current() -> WidgetFeed {
        let shared = WidgetFeedStore.read()
        if let shared, Date.now.timeIntervalSince(shared.updatedAt) < 180 {
            return shared
        }

        let snapshot = fallbackSampler.sample()

        if snapshot.memory.total == 0, let shared {
            return shared
        }
        return WidgetFeed(snapshot: snapshot)
    }
}

struct StatsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(StatsEntry(date: .now, feed: StatsFeedSource.current()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        let feed = StatsFeedSource.current()
        let entry = StatsEntry(date: .now, feed: feed)
        // 主程序每次刷新也会主动叫醒小组件；这里再兜一层，避免主程序退出后数值停在旧值。
        let next = Date.now.addingTimeInterval(60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}
