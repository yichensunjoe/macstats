import XCTest
@testable import MacStatsCore

final class ProcessRankingTests: XCTestCase {
    private func process(
        pid: Int32,
        name: String,
        cpu: Double,
        memory: UInt64 = 1_048_576
    ) -> ProcessStatus {
        ProcessStatus(pid: pid, name: name, cpu: cpu, memory: memory, energyWatts: 0)
    }

    // MARK: - topByCPU

    /// 排序规则：cpu 降序 → name 升序 → pid 升序。
    func testTopByCPUSortsByCPUThenNameThenPID() {
        let processes = [
            process(pid: 3, name: "beta", cpu: 0.5),
            process(pid: 2, name: "alpha", cpu: 0.5),
            process(pid: 1, name: "alpha", cpu: 0.5),
            process(pid: 4, name: "busy", cpu: 1.2)
        ]
        let ranked = ProcessRanking.topByCPU(processes, limit: 4)
        XCTAssertEqual(ranked.map(\.pid), [4, 1, 2, 3])
        XCTAssertEqual(ranked.map(\.name), ["busy", "alpha", "alpha", "beta"])
    }

    func testTopByCPURespectsLimit() {
        let processes = (0..<10).map { process(pid: Int32($0), name: "p\($0)", cpu: Double($0) / 10) }
        XCTAssertEqual(ProcessRanking.topByCPU(processes, limit: 3).map(\.pid), [9, 8, 7])
    }

    func testTopByCPUNonPositiveLimitReturnsEmpty() {
        let processes = [process(pid: 1, name: "a", cpu: 1)]
        XCTAssertTrue(ProcessRanking.topByCPU(processes, limit: 0).isEmpty)
        XCTAssertTrue(ProcessRanking.topByCPU(processes, limit: -1).isEmpty)
    }

    /// 同名进程在 topByCPU 里保持各自独立（逐 PID 明细），不聚合。
    func testTopByCPUKeepsSameNameProcessesSeparate() {
        let processes = [
            process(pid: 1, name: "node", cpu: 0.4),
            process(pid: 2, name: "node", cpu: 0.3)
        ]
        XCTAssertEqual(ProcessRanking.topByCPU(processes, limit: 8).map(\.pid), [1, 2])
    }

    // MARK: - top CPU 不受按内存截断影响

    /// 采样层按内存截断到 processLimit；CPU 归因必须用截断前的全量 records。
    func testTopCPUIsUnaffectedByMemoryTruncation() {
        let records = [
            process(pid: 100, name: "MemoryHog", cpu: 0.01, memory: 10_737_418_240),
            process(pid: 200, name: "CPUHog", cpu: 1.40, memory: 10_485_760),
            process(pid: 300, name: "Middle", cpu: 0.20, memory: 1_073_741_824)
        ]
        // 模拟 SystemSampler：按内存降序截断到 processLimit = 2。
        let limited = Array(records.sorted { $0.memory > $1.memory }.prefix(2))
        XCTAssertEqual(limited.map(\.name), ["MemoryHog", "Middle"])
        XCTAssertFalse(limited.contains { $0.name == "CPUHog" })

        // 截断前算的 top CPU 仍然命中真正的元凶。
        let topCPU = ProcessRanking.attributions(from: records, limit: 8, by: .cpu)
        XCTAssertEqual(topCPU.first?.name, "CPUHog")
        XCTAssertEqual(topCPU.first?.cpu ?? 0, 1.40, accuracy: 0.000_001)

        // topByCPU 同样不受内存截断影响。
        XCTAssertEqual(ProcessRanking.topByCPU(records, limit: 1).first?.name, "CPUHog")
    }

    // MARK: - 按名字聚合

    func testAttributionsAggregateSameNameCPUAndMemory() {
        let processes = [
            process(pid: 1, name: "node", cpu: 0.3, memory: 100),
            process(pid: 2, name: "node", cpu: 0.25, memory: 200),
            process(pid: 3, name: "Xcode", cpu: 0.4, memory: 300)
        ]
        let attributions = ProcessRanking.attributions(from: processes, limit: 3, by: .cpu)
        XCTAssertEqual(attributions.map(\.name), ["node", "Xcode"])
        XCTAssertEqual(attributions[0].cpu, 0.55, accuracy: 0.000_001)
        XCTAssertEqual(attributions[0].memory, 300)
        XCTAssertEqual(attributions[1].cpu, 0.4, accuracy: 0.000_001)
    }

    /// 两个同名进程各自排名靠后，但合计 CPU 应进 top 3：先聚合再排序才能命中。
    func testAttributionsAggregateBeforeRankingSoLowRankedDuplicatesEnterTop() {
        let processes = [
            process(pid: 1, name: "A", cpu: 0.50),
            process(pid: 2, name: "B", cpu: 0.40),
            process(pid: 3, name: "C", cpu: 0.35),
            process(pid: 4, name: "node", cpu: 0.30),
            process(pid: 5, name: "node", cpu: 0.25)
        ]

        // 反面：只取原始 top 3 再聚合，node 会整体丢失（这正是采样层不能复用截断后列表的原因）。
        let naive = ProcessRanking.topByCPU(processes, limit: 3)
        XCTAssertEqual(naive.map(\.name), ["A", "B", "C"])
        XCTAssertFalse(naive.contains { $0.name == "node" })

        // 正确：全量聚合后 node 合计 0.55，进入 top 3 且排第一。
        let attributions = ProcessRanking.attributions(from: processes, limit: 3, by: .cpu)
        XCTAssertEqual(attributions.map(\.name), ["node", "A", "B"])
        XCTAssertEqual(attributions[0].cpu, 0.55, accuracy: 0.000_001)
    }

    /// 稳定排序：指标相同时按 name 升序，结果与输入顺序无关。
    func testAttributionsTieBreaksByNameAscending() {
        let forward = [
            process(pid: 1, name: "beta", cpu: 0.5),
            process(pid: 2, name: "alpha", cpu: 0.5),
            process(pid: 3, name: "gamma", cpu: 0.5)
        ]
        let reversed = Array(forward.reversed())
        let expected = ["alpha", "beta", "gamma"]
        XCTAssertEqual(ProcessRanking.attributions(from: forward, limit: 3).map(\.name), expected)
        XCTAssertEqual(ProcessRanking.attributions(from: reversed, limit: 3).map(\.name), expected)
    }

    func testAttributionsRespectLimit() {
        let processes = (0..<6).map { process(pid: Int32($0), name: "p\($0)", cpu: Double(6 - $0) / 10) }
        XCTAssertEqual(ProcessRanking.attributions(from: processes, limit: 2, by: .cpu).map(\.name), ["p0", "p1"])
        XCTAssertEqual(ProcessRanking.attributions(from: processes, limit: 0, by: .cpu).count, 0)
        XCTAssertEqual(ProcessRanking.attributions(from: processes, limit: -3, by: .cpu).count, 0)
    }

    func testAttributionsEmptyInputReturnsEmpty() {
        XCTAssertTrue(ProcessRanking.attributions(from: [], limit: 3, by: .cpu).isEmpty)
        XCTAssertTrue(ProcessRanking.attributions(from: [], limit: 3, by: .memory).isEmpty)
    }

    /// 负 CPU 是坏读数，聚合前先归零，不能拉低同名进程的合计。
    func testAttributionsClampNegativeCPUBeforeSumming() {
        let processes = [
            process(pid: 1, name: "jitter", cpu: -0.5),
            process(pid: 2, name: "jitter", cpu: 0.5)
        ]
        let attributions = ProcessRanking.attributions(from: processes, limit: 1, by: .cpu)
        XCTAssertEqual(attributions.count, 1)
        XCTAssertEqual(attributions[0].cpu, 0.5, accuracy: 0.000_001)
    }

    // MARK: - .cpu 与 .memory 两种排序

    func testAttributionsByCPUAndByMemoryPickDifferentCulprits() {
        let processes = [
            process(pid: 1, name: "CPUHog", cpu: 1.50, memory: 50_000_000),
            process(pid: 2, name: "MemoryHog", cpu: 0.05, memory: 8_589_934_592)
        ]
        XCTAssertEqual(ProcessRanking.attributions(from: processes, limit: 1, by: .cpu).first?.name, "CPUHog")
        XCTAssertEqual(ProcessRanking.attributions(from: processes, limit: 1, by: .memory).first?.name, "MemoryHog")
    }

    /// 内存排序也按 name 聚合求和后再排，而不是拿单进程内存。
    func testAttributionsByMemoryAggregatesThenSorts() {
        let processes = [
            process(pid: 1, name: "node", cpu: 0.1, memory: 1_000),
            process(pid: 2, name: "node", cpu: 0.1, memory: 2_000),
            process(pid: 3, name: "Safari", cpu: 0.9, memory: 2_500)
        ]
        let attributions = ProcessRanking.attributions(from: processes, limit: 2, by: .memory)
        XCTAssertEqual(attributions.map(\.name), ["node", "Safari"])
        XCTAssertEqual(attributions[0].memory, 3_000)
        XCTAssertEqual(attributions[1].memory, 2_500)
    }

    /// 默认指标是 .cpu（B5 的内存元凶必须显式传 .memory）。
    func testAttributionsDefaultMetricIsCPU() {
        let processes = [
            process(pid: 1, name: "CPUHog", cpu: 1.50, memory: 50_000_000),
            process(pid: 2, name: "MemoryHog", cpu: 0.05, memory: 8_589_934_592)
        ]
        XCTAssertEqual(ProcessRanking.attributions(from: processes, limit: 1).first?.name, "CPUHog")
    }

    // MARK: - MetricSnapshot 接线

    /// 新快照写入 topCPUProcesses 后能原样编解码，读取便利属性与之一致。
    func testSnapshotWithTopCPUProcessesRoundTrips() throws {
        var snapshot = MetricSnapshot.empty
        let topCPU = [
            ProcessAttribution(name: "Xcode", cpu: 0.78, memory: 2_147_483_648),
            ProcessAttribution(name: "WindowServer", cpu: 0.09, memory: 524_288_000)
        ]
        snapshot.topCPUProcesses = topCPU

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(MetricSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.topCPU, topCPU)
    }

    /// 空快照没有进程归因：topCPU 是空数组而不是崩溃。
    func testEmptySnapshotTopCPUIsEmpty() {
        XCTAssertNil(MetricSnapshot.empty.topCPUProcesses)
        XCTAssertTrue(MetricSnapshot.empty.topCPU.isEmpty)
        XCTAssertNil(MetricSnapshot.empty.cpuProcesses)
        XCTAssertTrue(MetricSnapshot.empty.cpuRankedProcesses.isEmpty)
    }

    // MARK: - 面板内存/CPU 双榜

    /// 内存榜：内存降序 → 名字升序 → pid 升序。
    func testRankedByMemorySortsByMemoryThenNameThenPID() {
        let processes = [
            process(pid: 3, name: "beta", cpu: 0.1, memory: 500),
            process(pid: 2, name: "alpha", cpu: 0.2, memory: 500),
            process(pid: 1, name: "gamma", cpu: 0.3, memory: 900)
        ]
        XCTAssertEqual(ProcessRanking.ranked(processes, by: .memory, limit: 3).map(\.pid), [1, 2, 3])
        XCTAssertEqual(ProcessRanking.ranked(processes, by: .memory, limit: 1).map(\.pid), [1])
        XCTAssertTrue(ProcessRanking.ranked(processes, by: .memory, limit: 0).isEmpty)
    }

    /// 高 CPU、低内存的进程必须在 CPU 榜里，即使它被内存榜的截断丢掉了。
    func testRankedByCPUKeepsHighCPULowMemoryProcessOutsideMemoryLimit() {
        let processes = [
            process(pid: 1, name: "MemoryHogA", cpu: 0.01, memory: 9_000),
            process(pid: 2, name: "MemoryHogB", cpu: 0.02, memory: 8_000),
            process(pid: 3, name: "CPUHog", cpu: 1.75, memory: 40)
        ]
        let memoryTop = ProcessRanking.ranked(processes, by: .memory, limit: 2)
        XCTAssertEqual(memoryTop.map(\.pid), [1, 2])
        XCTAssertFalse(memoryTop.contains { $0.pid == 3 })

        let cpuTop = ProcessRanking.ranked(processes, by: .cpu, limit: 2)
        XCTAssertEqual(cpuTop.map(\.pid), [3, 2])
        XCTAssertEqual(cpuTop.first?.pid, 3, "CPU 榜要带出可点击的 PID")
    }

    /// 新快照同时带两份榜，各自保持自己的顺序，编解码后不串行。
    func testSnapshotCarriesMemoryAndCPUProcessLists() throws {
        var snapshot = MetricSnapshot.empty
        snapshot.processes = [
            process(pid: 2, name: "MemoryHog", cpu: 0.01, memory: 9_000),
            process(pid: 3, name: "CPUHog", cpu: 1.75, memory: 40)
        ]
        snapshot.cpuProcesses = [
            process(pid: 3, name: "CPUHog", cpu: 1.75, memory: 40),
            process(pid: 2, name: "MemoryHog", cpu: 0.01, memory: 9_000)
        ]

        let decoded = try JSONDecoder().decode(
            MetricSnapshot.self,
            from: JSONEncoder().encode(snapshot)
        )
        XCTAssertEqual(decoded.processes.map(\.pid), [2, 3])
        XCTAssertEqual(decoded.cpuProcesses?.map(\.pid), [3, 2])
        XCTAssertEqual(decoded.cpuRankedProcesses.map(\.pid), [3, 2])
    }

    /// 旧 JSON 没有 cpuProcesses：解码为 nil，读取时回退到内存榜重新按 CPU 排。
    func testLegacySnapshotWithoutCPUProcessesFallsBackToResorting() throws {
        var snapshot = MetricSnapshot.empty
        snapshot.processes = [
            process(pid: 2, name: "MemoryHog", cpu: 0.01, memory: 9_000),
            process(pid: 3, name: "CPUHog", cpu: 1.75, memory: 40)
        ]
        let data = try JSONEncoder().encode(snapshot)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "cpuProcesses")
        let legacy = try JSONDecoder().decode(
            MetricSnapshot.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertNil(legacy.cpuProcesses)
        XCTAssertEqual(legacy.cpuRankedProcesses.map(\.pid), [3, 2])
    }

    // MARK: - 排序口径偏好

    /// rawValue 是跨版本存盘契约：认得的恢复，缺失 / 旧版本 / 手改坏了一律回落内存榜。
    func testProcessSortStoredValueRoundTripsAndFallsBackToMemory() {
        XCTAssertEqual(ProcessSort.memory.rawValue, "memory")
        XCTAssertEqual(ProcessSort.cpu.rawValue, "cpu")
        XCTAssertEqual(ProcessSort.stored("cpu"), .cpu)
        XCTAssertEqual(ProcessSort.stored("memory"), .memory)
        XCTAssertEqual(ProcessSort.stored(nil), .memory)
        XCTAssertEqual(ProcessSort.stored(""), .memory)
        XCTAssertEqual(ProcessSort.stored("GPU"), .memory)
        XCTAssertEqual(ProcessSort.stored("cpu "), .memory)
    }

    // MARK: - 采样层接线

    /// topCPU 必须在按内存截断之前算，并在进程扫描节流的缓存路径上一起带出。
    func testSamplerSnapshotCarriesTopCPUIndependentOfProcessLimitAndCachePath() {
        // processInterval 取大一些，保证第二次采样一定走缓存路径，不受机器快慢影响。
        let sampler = SystemSampler(config: SamplerConfig(processLimit: 1, processInterval: 30))
        let first = sampler.sample()
        let cached = sampler.sample()

        XCTAssertEqual(first.processes.count, 1, "processLimit = 1 时快照只保留 1 条进程")
        XCTAssertFalse(first.topCPU.isEmpty, "topCPU 来自截断前的全量进程，不受 processLimit 影响")
        XCTAssertLessThanOrEqual(first.topCPU.count, 8)
        XCTAssertEqual(first.topCPU, cached.topCPU, "缓存路径不能把 topCPU 丢掉")
        XCTAssertEqual(first.topCPUProcesses, cached.topCPUProcesses)
    }

    /// CPU 榜同样在截断前算，并随节流缓存一起带出。
    func testSamplerSnapshotCarriesCPUProcessListOutsideMemoryLimitAndCachePath() {
        let sampler = SystemSampler(config: SamplerConfig(processLimit: 1, processInterval: 30))
        let first = sampler.sample()
        let cached = sampler.sample()

        let cpuList = first.cpuProcesses ?? []
        XCTAssertEqual(cpuList.count, 1, "cpuProcesses 与 processLimit 同上限")
        XCTAssertEqual(cached.cpuProcesses, cpuList, "缓存路径不能把 CPU 榜丢掉")
        if let topCPU = first.topCPU.first {
            XCTAssertEqual(cpuList.first?.name, topCPU.name, "逐 PID 榜首应与聚合归因的元凶一致")
        }
    }
}
