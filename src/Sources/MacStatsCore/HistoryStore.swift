import Foundation

/// 一条分钟级历史样本。数值都是 0...1，和面板上显示的比例同源。
public struct HistorySample: Codable, Sendable, Equatable {
    public var timestamp: Date
    public var cpu: Double
    public var memory: Double
    /// 没有 GPU 的机器上是 nil，不是 0——0 会被画成「显卡闲着」。
    public var gpu: Double?
    /// 启动盘已用比例，用于磁盘阈值告警。
    public var diskUsed: Double
    /// 该分钟 CPU 最高的最多 3 个进程；0.4 之前写下的历史没有这个键，解码为 nil。
    /// 必须是 optional：旧 JSONL 缺键时合成的 Decodable 才会走 `decodeIfPresent`。
    public var topProcesses: [ProcessAttribution]?

    public init(
        timestamp: Date,
        cpu: Double,
        memory: Double,
        gpu: Double?,
        diskUsed: Double,
        topProcesses: [ProcessAttribution]? = nil
    ) {
        self.timestamp = timestamp
        self.cpu = cpu
        self.memory = memory
        self.gpu = gpu
        self.diskUsed = diskUsed
        self.topProcesses = topProcesses
    }
}

/// 把每秒采样压成分钟点，按天写 JSONL，供「过去 24 小时」卡片与后续导出使用。
///
/// 为什么不是每秒写盘：活动监视器口径的采样本身每秒都在抖，写下来既费磁盘也不好看。
/// 内存里按分钟累加，跨分钟时落一个平均值，一天只有 1440 行（约 150 KB），
/// 30 天也就 4 MB 出头，远低于「5 MB/天」的预算。
///
/// 线程模型：所有可变状态都在 `lock` 里；`record` 只会在采样线程调用一次/秒，
/// 真正的磁盘写发生在跨分钟那一刻。
public final class HistoryStore: @unchecked Sendable {
    public struct Configuration: Sendable {
        public var directory: URL
        /// 分钟点保留 24 小时；更早的按天文件保留 `retentionDays` 天（小时聚合用）。
        public var retentionDays: Int
        public var calendar: Calendar

        public init(directory: URL, retentionDays: Int = 30, calendar: Calendar = .current) {
            self.directory = directory
            self.retentionDays = max(1, retentionDays)
            self.calendar = calendar
        }
    }

    // `fileprivate` 而不是 `private`：CI 的较旧 Swift 不允许从外围类型调用
    // private 嵌套类型的成员初始化器；fileprivate 仍把 Bucket 限制在本文件内。
    fileprivate struct Bucket {
        var start: Date
        var cpuSum: Double = 0
        var memorySum: Double = 0
        var gpuSum: Double = 0
        var gpuCount: Int = 0
        var diskUsedSum: Double = 0
        var count: Int = 0
        /// 该分钟内每个进程名的峰值。先合并同一秒的重复进程，再取峰值——
        /// 用户问的是「那阵卡是谁」，峰值比一分钟平均更接近元凶；平均会被空闲秒稀释。
        private var attributionPeaks: [String: (cpu: Double, memory: UInt64)] = [:]

        // 合成成员初始化器的访问级别会被 private 的 attributionPeaks 拉到 private；
        // 显式给一个 fileprivate init，旧 Swift 也能从外围类型构造。
        fileprivate init(start: Date) {
            self.start = start
        }

        mutating func add(
            cpu: Double,
            memory: Double,
            gpu: Double?,
            diskUsed: Double,
            topProcesses: [ProcessAttribution] = []
        ) {
            cpuSum += cpu
            memorySum += memory
            diskUsedSum += diskUsed
            if let gpu {
                gpuSum += gpu
                gpuCount += 1
            }
            count += 1
            mergeAttributions(topProcesses)
        }

        /// 1. 同一秒内的同名进程先合并：cpu 求和、memory 求和；
        /// 2. 再对每个名字取分钟内的峰值：cpu / memory 各自取 max。
        private mutating func mergeAttributions(_ processes: [ProcessAttribution]) {
            guard !processes.isEmpty else { return }

            var merged: [String: (cpu: Double, memory: UInt64)] = [:]
            for process in processes {
                var entry = merged[process.name] ?? (cpu: 0, memory: 0)
                entry.cpu += process.cpu
                let (memory, overflow) = entry.memory.addingReportingOverflow(process.memory)
                entry.memory = overflow ? UInt64.max : memory
                merged[process.name] = entry
            }

            for (name, value) in merged {
                let peak = attributionPeaks[name] ?? (cpu: 0, memory: 0)
                attributionPeaks[name] = (
                    cpu: max(peak.cpu, value.cpu),
                    memory: max(peak.memory, value.memory)
                )
            }
        }

        func sample() -> HistorySample {
            let divisor = Double(max(count, 1))
            return HistorySample(
                timestamp: start,
                cpu: cpuSum / divisor,
                memory: memorySum / divisor,
                gpu: gpuCount > 0 ? gpuSum / Double(gpuCount) : nil,
                diskUsed: diskUsedSum / divisor,
                topProcesses: topProcesses()
            )
        }

        /// 按 cpu 降序、name 升序取前 3；没有进程时返回 nil（不伪造空数组）。
        private func topProcesses() -> [ProcessAttribution]? {
            guard !attributionPeaks.isEmpty else { return nil }
            let sorted = attributionPeaks
                .map { ProcessAttribution(name: $0.key, cpu: $0.value.cpu, memory: $0.value.memory) }
                .sorted { lhs, rhs in
                    if lhs.cpu != rhs.cpu { return lhs.cpu > rhs.cpu }
                    return lhs.name < rhs.name
                }
            return Array(sorted.prefix(3))
        }
    }

    private let lock = NSLock()
    private var configuration: Configuration
    private let fileManager: FileManager
    private let dayFormatter: DateFormatter

    private var bucket: Bucket?
    private var points: [HistorySample] = []
    private var lastPrunedDay: Date?

    public init(configuration: Configuration, fileManager: FileManager = .default) {
        self.configuration = configuration
        self.fileManager = fileManager
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = configuration.calendar
        formatter.timeZone = configuration.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        self.dayFormatter = formatter

        try? fileManager.createDirectory(
            at: configuration.directory,
            withIntermediateDirectories: true
        )
        pruneLocked(now: Date())
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        points = loadPointsLocked(since: cutoff)
    }

    // MARK: - 写入

    /// 记录一次采样。返回 true 表示刚刚落下了一个新的分钟点（界面需要刷新历史）。
    /// `topProcesses` 有默认值，旧的 `record(cpu:memory:gpu:diskUsed:at:)` 调用仍可编译。
    @discardableResult
    public func record(
        cpu: Double,
        memory: Double,
        gpu: Double?,
        diskUsed: Double,
        topProcesses: [ProcessAttribution] = [],
        at date: Date = Date()
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let minute = configuration.calendar.dateInterval(of: .minute, for: date)?.start ?? date
        var flushed = false

        if var current = bucket {
            if current.start == minute {
                current.add(
                    cpu: cpu,
                    memory: memory,
                    gpu: gpu,
                    diskUsed: diskUsed,
                    topProcesses: topProcesses
                )
                bucket = current
                return false
            }
            let sample = current.sample()
            appendLocked(sample)
            flushed = true
            pruneLocked(now: minute)
        }

        var fresh = Bucket(start: minute)
        fresh.add(
            cpu: cpu,
            memory: memory,
            gpu: gpu,
            diskUsed: diskUsed,
            topProcesses: topProcesses
        )
        bucket = fresh
        return flushed
    }

    /// 把缓冲区里还没落盘的分钟点立刻写下去（退出前调用）。
    public func flush() {
        lock.lock()
        defer { lock.unlock() }
        guard let current = bucket else { return }
        appendLocked(current.sample())
        bucket = nil
    }

    // MARK: - 读取

    public func recent24h(now: Date = Date()) -> [HistorySample] {
        lock.lock()
        defer { lock.unlock() }
        let cutoff = now.addingTimeInterval(-24 * 3600)
        var result = points.filter { $0.timestamp >= cutoff }
        // 当前这一分钟还没跨过去，也让它出现在图里，避免「最后半小时空着」。
        if let bucket, bucket.start >= cutoff {
            let live = bucket.sample()
            if result.last?.timestamp != live.timestamp {
                result.append(live)
            }
        }
        return result
    }

    public func todayPeak(now: Date = Date()) -> (cpu: Double, memory: Double, gpu: Double?)? {
        let start = configuration.calendar.startOfDay(for: now)
        let samples = recent24h(now: now).filter { $0.timestamp >= start }
        guard !samples.isEmpty else { return nil }
        let gpuValues = samples.compactMap(\.gpu)
        return (
            samples.map(\.cpu).max() ?? 0,
            samples.map(\.memory).max() ?? 0,
            gpuValues.max()
        )
    }

    /// 按小时平均，最多 `days` 天。给后续 30 天曲线与导出用；当前面板只用 24 小时分钟点。
    public func hourly(days: Int = 30, now: Date = Date()) -> [HistorySample] {
        lock.lock()
        defer { lock.unlock() }

        let cutoff = configuration.calendar.startOfDay(for: now.addingTimeInterval(-Double(max(1, days)) * 86_400))
        var groups: [Date: Bucket] = [:]
        for sample in loadPointsLocked(since: cutoff) {
            let hour = configuration.calendar.dateInterval(of: .hour, for: sample.timestamp)?.start ?? sample.timestamp
            var bucket = groups[hour] ?? Bucket(start: hour)
            // 用分钟点重新求平均：每条分钟点权重相同，正好等于这一小时的平均占用。
            bucket.add(
                cpu: sample.cpu,
                memory: sample.memory,
                gpu: sample.gpu,
                diskUsed: sample.diskUsed,
                topProcesses: sample.topProcesses ?? []
            )
            groups[hour] = bucket
        }
        return groups.values.map { $0.sample() }.sorted { $0.timestamp < $1.timestamp }
    }

    public func diskUsageBytes() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        return filesLocked().reduce(into: Int64(0)) { total, url in
            let attributes = try? fileManager.attributesOfItem(atPath: url.path)
            total += (attributes?[.size] as? NSNumber)?.int64Value ?? 0
        }
    }

    public func sampleCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return points.count
    }

    // MARK: - 维护

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        bucket = nil
        points.removeAll()
        for url in filesLocked() {
            try? fileManager.removeItem(at: url)
        }
    }

    public func setRetentionDays(_ days: Int) {
        lock.lock()
        defer { lock.unlock() }
        let clamped = max(1, days)
        guard clamped != configuration.retentionDays else { return }
        configuration.retentionDays = clamped
        // 保留天数变短时要立刻清一次，不能等「今天已经清理过」的短路。
        lastPrunedDay = nil
        pruneLocked(now: Date())
    }

    // MARK: - 磁盘

    private var directory: URL { configuration.directory }

    private func dayFileLocked(for date: Date) -> URL {
        directory.appendingPathComponent("history-\(dayFormatter.string(from: date)).jsonl")
    }

    private func appendLocked(_ sample: HistorySample) {
        guard let data = try? JSONEncoder().encode(sample) else { return }
        let url = dayFileLocked(for: sample.timestamp)
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data + Data("\n".utf8))

        points.append(sample)
        let cutoff = sample.timestamp.addingTimeInterval(-24 * 3600)
        if points.count > 1_500 || points.first.map({ $0.timestamp < cutoff }) == true {
            points.removeAll { $0.timestamp < cutoff }
        }
    }

    private func loadPointsLocked(since cutoff: Date) -> [HistorySample] {
        let decoder = JSONDecoder()
        var result: [HistorySample] = []
        for url in filesLocked() {
            guard let data = try? Data(contentsOf: url) else { continue }
            for line in data.split(separator: 0x0A) where !line.isEmpty {
                guard let sample = try? decoder.decode(HistorySample.self, from: Data(line)) else { continue }
                if sample.timestamp >= cutoff { result.append(sample) }
            }
        }
        return result.sorted { $0.timestamp < $1.timestamp }
    }

    private func filesLocked() -> [URL] {
        (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?.filter {
            $0.lastPathComponent.hasPrefix("history-") && $0.pathExtension == "jsonl"
        } ?? []
    }

    /// 删掉超过保留天数的按天文件。按文件名里的日期判断，不依赖 mtime。
    private func pruneLocked(now: Date) {
        let today = configuration.calendar.startOfDay(for: now)
        if let last = lastPrunedDay, configuration.calendar.isDate(last, inSameDayAs: today) { return }
        lastPrunedDay = today

        guard let cutoff = configuration.calendar.date(byAdding: .day, value: -(configuration.retentionDays - 1), to: today) else { return }
        for url in filesLocked() {
            let name = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "history-", with: "")
            guard let date = dayFormatter.date(from: name) else { continue }
            if date < cutoff {
                try? fileManager.removeItem(at: url)
            }
        }
    }
}
