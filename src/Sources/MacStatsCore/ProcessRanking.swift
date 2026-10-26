import Foundation

/// 归因排序指标。CPU 与内存必须分开排：内存告警的元凶通常不是 CPU 第一名。
public enum AttributionMetric: String, Sendable {
    case cpu
    case memory
}

/// 进程排序纯函数：不采样、不碰 I/O，便于单测。
///
/// 采样层会把进程列表按内存截断到 `processLimit`；CPU 归因必须在截断**之前**
/// 从全量进程里算，否则高 CPU、低内存的元凶会被丢掉。
public enum ProcessRanking {
    /// 按 CPU 降序、名字升序、pid 升序取前 `limit` 个。
    ///
    /// 同名进程保持各自独立（不聚合），供需要逐 PID 明细的调用方使用；
    /// 归因场景请用 `attributions(from:limit:by:)`，它会先按名字聚合。
    public static func topByCPU(_ processes: [ProcessStatus], limit: Int = 8) -> [ProcessStatus] {
        guard limit > 0 else { return [] }
        return Array(processes.sorted(by: cpuOrder).prefix(limit))
    }

    /// 先按 `name` 聚合（cpu 求和、memory 求和），再按指定指标降序、名字升序取前 `limit`。
    ///
    /// 先聚合再排序：两个同名进程各自排在第 9、10 名时，只取原始 top 8 再聚合会漏掉它们；
    /// 聚合后的合计 CPU 可能已经进 top 3。
    public static func attributions(
        from processes: [ProcessStatus],
        limit: Int = 3,
        by metric: AttributionMetric = .cpu
    ) -> [ProcessAttribution] {
        guard limit > 0 else { return [] }
        var sums: [String: (cpu: Double, memory: UInt64)] = [:]
        sums.reserveCapacity(processes.count)
        for process in processes {
            var entry = sums[process.name] ?? (cpu: 0, memory: 0)
            // 与 ProcessAttribution 的口径一致：负 CPU 归零，避免一个坏读数拉低合计。
            entry.cpu += max(0, process.cpu)
            entry.memory &+= process.memory
            sums[process.name] = entry
        }

        let aggregated = sums.map { name, value in
            ProcessAttribution(name: name, cpu: value.cpu, memory: value.memory)
        }

        let ranked: [ProcessAttribution]
        switch metric {
        case .cpu:
            ranked = aggregated.sorted { lhs, rhs in
                if lhs.cpu != rhs.cpu { return lhs.cpu > rhs.cpu }
                return lhs.name < rhs.name
            }
        case .memory:
            ranked = aggregated.sorted { lhs, rhs in
                if lhs.memory != rhs.memory { return lhs.memory > rhs.memory }
                return lhs.name < rhs.name
            }
        }
        return Array(ranked.prefix(limit))
    }

    private static func cpuOrder(_ lhs: ProcessStatus, _ rhs: ProcessStatus) -> Bool {
        if lhs.cpu != rhs.cpu { return lhs.cpu > rhs.cpu }
        if lhs.name != rhs.name { return lhs.name < rhs.name }
        return lhs.pid < rhs.pid
    }
}
