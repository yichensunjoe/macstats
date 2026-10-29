import Foundation

/// 归因排序指标。CPU 与内存必须分开排：内存告警的元凶通常不是 CPU 第一名。
public enum AttributionMetric: String, Sendable {
    case cpu
    case memory
}

/// 面板进程榜的排序口径。
///
/// rawValue 直接写进偏好，是跨版本存盘契约，不要改名。默认内存，和 0.4.5 之前一致；
/// 用户切过一次就记住，重开面板不必再切。
public enum ProcessSort: String, CaseIterable, Sendable {
    case memory
    case cpu

    /// 读偏好里的字符串：缺失、旧版本或手改坏了一律回落内存榜。
    public static func stored(_ raw: String?) -> ProcessSort {
        guard let raw, let sort = ProcessSort(rawValue: raw) else { return .memory }
        return sort
    }

    public var title: String {
        switch self {
        case .memory: L10n.t(.processSortMemory)
        case .cpu: L10n.t(.processSortCPU)
        }
    }
}

/// 菜单栏「占用前三」的一条：进程本身 + 拼好的标题。
/// 标题在这里定，菜单与测试看同一份文案；AppKit 只负责塞进 NSMenuItem。
public struct ProcessMenuEntry: Equatable, Sendable {
    public var process: ProcessStatus
    public var title: String
    /// 非空表示这个进程受保护：菜单要禁用退出 / 强制退出，并直接写明原因。
    public var refusal: TerminationRefusal?

    public init(process: ProcessStatus, title: String, refusal: TerminationRefusal? = nil) {
        self.process = process
        self.title = title
        self.refusal = refusal
    }
}

/// 一个口径的菜单段：段标题（如「CPU 前三」）与前三名。
public struct ProcessMenuGroup: Equatable, Sendable {
    public var sort: ProcessSort
    public var title: String
    /// 采样还没就绪时为空，菜单据此显示「采样中…」。
    public var entries: [ProcessMenuEntry]

    public init(sort: ProcessSort, title: String, entries: [ProcessMenuEntry]) {
        self.sort = sort
        self.title = title
        self.entries = entries
    }
}

/// 菜单栏「占用前三」的数据与文案。
/// CPU 在前、内存在后：面板被挡住时两张榜都要能看，不能只给当前排序的一张；
/// 取数用采样层在按内存截断之前算好的 `cpuProcesses`，否则高 CPU、低内存的进程永远进不来。
public enum ProcessMenuBuilder {
    /// `refusal` 只在构建菜单时调用（最多 6 次），默认不查，便于单测保持纯函数；
    /// 宿主传入 `ProcessTerminator.refusal(pid:)`，让受保护进程的退出项提前禁用。
    public static func groups(
        from snapshot: MetricSnapshot,
        limit: Int = 3,
        refusal: (ProcessStatus) -> TerminationRefusal? = { _ in nil }
    ) -> [ProcessMenuGroup] {
        let capped = max(0, limit)
        return [ProcessSort.cpu, .memory].map { sort in
            // 不依赖调用方已排好：旧快照或手动构造的快照可能乱序，菜单不能跟着乱。
            let metric: AttributionMetric = sort == .cpu ? .cpu : .memory
            let source = sort == .cpu ? snapshot.cpuRankedProcesses : snapshot.processes
            let processes = ProcessRanking.ranked(source, by: metric, limit: capped)
            let entries = processes.map { process in
                let value = sort == .cpu
                    ? PercentFormat.processCPU(process.cpu)
                    : ByteFormat.processMemory(process.memory)
                return ProcessMenuEntry(
                    process: process,
                    title: "\(process.name)  —  \(value)",
                    refusal: refusal(process)
                )
            }
            return ProcessMenuGroup(
                sort: sort,
                title: L10n.format(.menuTopByMetric, sort.title),
                entries: entries
            )
        }
    }
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
        ranked(processes, by: .cpu, limit: limit)
    }

    /// 按指定指标降序、名字升序、pid 升序取前 `limit` 个，逐 PID 不聚合。
    ///
    /// 面板要在内存榜和 CPU 榜之间切换：两张榜都得在采样截断**之前**从全量进程里取，
    /// 否则高 CPU、低内存的进程永远不会出现在可点列表里。
    public static func ranked(
        _ processes: [ProcessStatus],
        by metric: AttributionMetric,
        limit: Int = 8
    ) -> [ProcessStatus] {
        guard limit > 0 else { return [] }
        let order: (ProcessStatus, ProcessStatus) -> Bool
        switch metric {
        case .cpu: order = cpuOrder
        case .memory: order = memoryOrder
        }
        return Array(processes.sorted(by: order).prefix(limit))
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

    private static func memoryOrder(_ lhs: ProcessStatus, _ rhs: ProcessStatus) -> Bool {
        if lhs.memory != rhs.memory { return lhs.memory > rhs.memory }
        if lhs.name != rhs.name { return lhs.name < rhs.name }
        return lhs.pid < rhs.pid
    }
}
