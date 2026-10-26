import XCTest
@testable import MacStatsCore

final class HistoryStoreTests: XCTestCase {
    private var directory: URL!
    private var calendar: Calendar!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("macstats-history-\(UUID().uuidString)", isDirectory: true)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStore(retentionDays: Int = 30) -> HistoryStore {
        HistoryStore(configuration: .init(directory: directory, retentionDays: retentionDays, calendar: calendar))
    }

    private func minuteStart(_ date: Date) -> Date {
        calendar.dateInterval(of: .minute, for: date)?.start ?? date
    }

    func testSamplesWithinOneMinuteAreAveragedAndFlushedOnRollover() throws {
        let store = makeStore()
        let base = minuteStart(Date())

        XCTAssertFalse(store.record(cpu: 0.2, memory: 0.5, gpu: 0.1, diskUsed: 0.4, at: base.addingTimeInterval(5)))
        XCTAssertFalse(store.record(cpu: 0.4, memory: 0.7, gpu: 0.3, diskUsed: 0.4, at: base.addingTimeInterval(40)))
        XCTAssertTrue(store.record(cpu: 0.6, memory: 0.9, gpu: 0.5, diskUsed: 0.4, at: base.addingTimeInterval(65)))

        let points = store.recent24h(now: base.addingTimeInterval(120))
        XCTAssertEqual(points.count, 2)
        let flushed = try XCTUnwrap(points.first)
        XCTAssertEqual(flushed.timestamp, base)
        XCTAssertEqual(flushed.cpu, 0.3, accuracy: 0.0001)
        XCTAssertEqual(flushed.memory, 0.6, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(flushed.gpu), 0.2, accuracy: 0.0001)
        XCTAssertEqual(points.last?.timestamp, base.addingTimeInterval(60))
        XCTAssertEqual(points.last?.cpu ?? 0, 0.6, accuracy: 0.0001)
    }

    func testFlushPersistsAndReloads() throws {
        let base = minuteStart(Date())
        do {
            let store = makeStore()
            store.record(cpu: 0.3, memory: 0.4, gpu: nil, diskUsed: 0.2, at: base)
            store.record(cpu: 0.8, memory: 0.6, gpu: 0.9, diskUsed: 0.2, at: base.addingTimeInterval(61))
            store.flush()
        }

        let reloaded = makeStore()
        let points = reloaded.recent24h(now: base.addingTimeInterval(300))
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].timestamp, base)
        XCTAssertNil(points[0].gpu)
        XCTAssertEqual(points[1].timestamp, base.addingTimeInterval(60))
        XCTAssertEqual(try XCTUnwrap(points[1].gpu), 0.9, accuracy: 0.0001)
        XCTAssertGreaterThan(reloaded.diskUsageBytes(), 0)
    }

    func testClearRemovesPointsAndFiles() throws {
        let base = minuteStart(Date())
        let store = makeStore()
        store.record(cpu: 0.3, memory: 0.4, gpu: 0.2, diskUsed: 0.2, at: base)
        store.record(cpu: 0.5, memory: 0.5, gpu: 0.2, diskUsed: 0.2, at: base.addingTimeInterval(61))
        XCTAssertGreaterThan(store.diskUsageBytes(), 0)

        store.clear()
        XCTAssertEqual(store.recent24h(now: base.addingTimeInterval(120)).count, 0)
        XCTAssertEqual(store.diskUsageBytes(), 0)
    }

    func testFilesOlderThanRetentionArePruned() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let oldDate = Date().addingTimeInterval(-10 * 86_400)
        let oldFile = directory.appendingPathComponent("history-\(formatter.string(from: oldDate)).jsonl")
        try Data("{}\n".utf8).write(to: oldFile)

        _ = makeStore(retentionDays: 3)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldFile.path))
    }

    func testHourlyAveragesAcrossMinutes() throws {
        let base = calendar.dateInterval(of: .hour, for: Date())!.start
        let store = makeStore()
        store.record(cpu: 0.2, memory: 0.4, gpu: nil, diskUsed: 0.5, at: base.addingTimeInterval(30 * 60))
        store.record(cpu: 0.6, memory: 0.8, gpu: nil, diskUsed: 0.5, at: base.addingTimeInterval(31 * 60))
        store.flush()

        let hourly = store.hourly(days: 1, now: base.addingTimeInterval(3600))
        let hour = try XCTUnwrap(hourly.first)
        XCTAssertEqual(hour.cpu, 0.4, accuracy: 0.0001)
        XCTAssertEqual(hour.memory, 0.6, accuracy: 0.0001)
        XCTAssertEqual(hour.timestamp, base)
    }

    func testTodayPeakUsesTodayOnly() throws {
        let base = minuteStart(Date())
        let store = makeStore()
        store.record(cpu: 0.9, memory: 0.5, gpu: 0.3, diskUsed: 0.4, at: base)
        store.record(cpu: 0.1, memory: 0.7, gpu: nil, diskUsed: 0.4, at: base.addingTimeInterval(61))
        store.flush()

        let peak = try XCTUnwrap(store.todayPeak(now: base.addingTimeInterval(120)))
        XCTAssertEqual(peak.cpu, 0.9, accuracy: 0.0001)
        XCTAssertEqual(peak.memory, 0.7, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(peak.gpu), 0.3, accuracy: 0.0001)
    }

    func testRetentionChangePrunesImmediately() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        let file = directory.appendingPathComponent("history-\(formatter.string(from: Date().addingTimeInterval(-5 * 86_400))).jsonl")
        try Data("{}\n".utf8).write(to: file)

        let store = makeStore(retentionDays: 30)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        store.setRetentionDays(2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    // MARK: - 归因（topProcesses）

    private func dayFileURL(for date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return directory.appendingPathComponent("history-\(formatter.string(from: date)).jsonl")
    }

    /// 0.4 之前的 JSONL 行：没有 topProcesses 键，也没有 gpu 键（无 GPU 的机器）。
    private func legacySampleLine(timestamp: Date, cpu: Double, memory: Double, diskUsed: Double) throws -> Data {
        let object: [String: Any] = [
            "timestamp": timestamp.timeIntervalSinceReferenceDate,
            "cpu": cpu,
            "memory": memory,
            "diskUsed": diskUsed
        ]
        var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        data.append(0x0A)
        return data
    }

    private func persistedObjects(for date: Date) throws -> [[String: Any]] {
        let data = try Data(contentsOf: dayFileURL(for: date))
        return try data.split(separator: 0x0A).map { line in
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line)) as? [String: Any])
        }
    }

    private func rollover(_ store: HistoryStore, base: Date, offset: TimeInterval = 61) {
        store.record(cpu: 0, memory: 0, gpu: nil, diskUsed: 0, at: base.addingTimeInterval(offset))
    }

    func testLegacyJSONLineWithoutTopProcessesDecodesToNil() throws {
        let base = minuteStart(Date())
        let line = try legacySampleLine(timestamp: base, cpu: 0.42, memory: 0.55, diskUsed: 0.3)
        let decoded = try JSONDecoder().decode(HistorySample.self, from: line)
        XCTAssertEqual(decoded.cpu, 0.42, accuracy: 0.0001)
        XCTAssertEqual(decoded.memory, 0.55, accuracy: 0.0001)
        XCTAssertEqual(decoded.diskUsed, 0.3, accuracy: 0.0001)
        XCTAssertNil(decoded.gpu)
        XCTAssertNil(decoded.topProcesses)
    }

    func testStoreReadsLegacyJSONLAndKeepsSamples() throws {
        let base = minuteStart(Date())
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try legacySampleLine(timestamp: base, cpu: 0.42, memory: 0.55, diskUsed: 0.3)
            .write(to: dayFileURL(for: base))

        let store = makeStore()
        let points = store.recent24h(now: base.addingTimeInterval(60))
        let loaded = try XCTUnwrap(points.first)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(loaded.cpu, 0.42, accuracy: 0.0001)
        XCTAssertNil(loaded.topProcesses)
    }

    func testTopProcessesUseMinutePeakNotAverage() throws {
        let base = minuteStart(Date())
        let store = makeStore()

        store.record(
            cpu: 0.2, memory: 0.5, gpu: nil, diskUsed: 0.4,
            topProcesses: [ProcessAttribution(name: "Xcode", cpu: 0.2, memory: 100)],
            at: base.addingTimeInterval(1)
        )
        store.record(
            cpu: 0.4, memory: 0.5, gpu: nil, diskUsed: 0.4,
            topProcesses: [ProcessAttribution(name: "Xcode", cpu: 0.9, memory: 900)],
            at: base.addingTimeInterval(2)
        )
        rollover(store, base: base)

        let points = store.recent24h(now: base.addingTimeInterval(120))
        let flushed = try XCTUnwrap(points.first)
        XCTAssertEqual(flushed.timestamp, base)
        let processes = try XCTUnwrap(flushed.topProcesses)
        XCTAssertEqual(processes.count, 1)
        XCTAssertEqual(processes[0].name, "Xcode")
        XCTAssertEqual(processes[0].cpu, 0.9, accuracy: 0.0001)   // 峰值，不是平均 0.55
        XCTAssertEqual(processes[0].memory, 900)                  // 峰值，不是平均 500
    }

    func testSameNameProcessesInOneSecondAreMerged() throws {
        let base = minuteStart(Date())
        let store = makeStore()

        store.record(
            cpu: 0.5, memory: 0.4, gpu: nil, diskUsed: 0.2,
            topProcesses: [
                ProcessAttribution(name: "node", cpu: 0.2, memory: 100),
                ProcessAttribution(name: "node", cpu: 0.3, memory: 200),
                ProcessAttribution(name: "Xcode", cpu: 0.6, memory: 50)
            ],
            at: base.addingTimeInterval(1)
        )
        rollover(store, base: base)

        let flushed = try XCTUnwrap(store.recent24h(now: base.addingTimeInterval(120)).first)
        let processes = try XCTUnwrap(flushed.topProcesses)
        XCTAssertEqual(processes.count, 2) // 同名合并成一条，不是三条
        XCTAssertEqual(processes.map(\.name), ["Xcode", "node"])
        XCTAssertEqual(processes[1].cpu, 0.5, accuracy: 0.0001) // 0.2 + 0.3
        XCTAssertEqual(processes[1].memory, 300)                // 100 + 200
    }

    func testTopProcessesKeepOnlyThreeSortedByCPUThenName() throws {
        let base = minuteStart(Date())
        let store = makeStore()

        store.record(
            cpu: 0.9, memory: 0.5, gpu: nil, diskUsed: 0.2,
            topProcesses: [
                ProcessAttribution(name: "beta", cpu: 0.5, memory: 1),
                ProcessAttribution(name: "alpha", cpu: 0.5, memory: 2),   // CPU 并列，按 name 升序
                ProcessAttribution(name: "gamma", cpu: 0.9, memory: 3),
                ProcessAttribution(name: "delta", cpu: 0.1, memory: 4),
                ProcessAttribution(name: "epsilon", cpu: 0.05, memory: 5)
            ],
            at: base.addingTimeInterval(1)
        )
        rollover(store, base: base)

        let flushed = try XCTUnwrap(store.recent24h(now: base.addingTimeInterval(120)).first)
        let processes = try XCTUnwrap(flushed.topProcesses)
        XCTAssertEqual(processes.count, 3)
        XCTAssertEqual(processes.map(\.name), ["gamma", "alpha", "beta"])
    }

    func testTopProcessesNilWhenNoProcessesRecorded() throws {
        let base = minuteStart(Date())
        let store = makeStore()

        store.record(cpu: 0.3, memory: 0.4, gpu: nil, diskUsed: 0.2, at: base.addingTimeInterval(1))
        rollover(store, base: base)

        let flushed = try XCTUnwrap(store.recent24h(now: base.addingTimeInterval(120)).first)
        XCTAssertNil(flushed.topProcesses)

        // 落盘的那一行也不该出现 topProcesses 键，旧版本仍能读。
        let objects = try persistedObjects(for: base)
        let first = try XCTUnwrap(objects.first)
        XCTAssertNil(first["topProcesses"])
        XCTAssertNotNil(first["timestamp"])
    }

    func testTopProcessesRoundTripThroughJSONL() throws {
        // 固定在当天中午，避免跨午夜时两个分钟点落到不同日文件里。
        let base = calendar.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        do {
            let store = makeStore()
            store.record(
                cpu: 0.7, memory: 0.6, gpu: nil, diskUsed: 0.2,
                topProcesses: [
                    ProcessAttribution(name: "Xcode", cpu: 0.78, memory: 2_147_483_648),
                    ProcessAttribution(name: "WindowServer", cpu: 0.09, memory: 524_288_000)
                ],
                at: base.addingTimeInterval(1)
            )
            rollover(store, base: base)
            store.flush()
        }

        let reloaded = makeStore()
        let flushed = try XCTUnwrap(reloaded.recent24h(now: base.addingTimeInterval(120)).first)
        let processes = try XCTUnwrap(flushed.topProcesses)
        XCTAssertEqual(processes.map(\.name), ["Xcode", "WindowServer"])
        XCTAssertEqual(processes[0].cpu, 0.78, accuracy: 0.000_000_1)
        XCTAssertEqual(processes[0].memory, 2_147_483_648)

        // 写盘行必须是合法 JSONL，且带 topProcesses。
        let objects = try persistedObjects(for: base)
        XCTAssertEqual(objects.count, 2) // 分钟点 + flush 出来的当前分钟
        XCTAssertNotNil(objects.first?["topProcesses"])
    }

    func testHourlyAggregatesTopProcessesAndKeepsAtMostThree() throws {
        let base = calendar.dateInterval(of: .hour, for: Date())!.start
        let store = makeStore()

        store.record(
            cpu: 0.2, memory: 0.4, gpu: nil, diskUsed: 0.5,
            topProcesses: [
                ProcessAttribution(name: "Xcode", cpu: 0.8, memory: 10),
                ProcessAttribution(name: "node", cpu: 0.2, memory: 20)
            ],
            at: base.addingTimeInterval(30 * 60)
        )
        store.record(
            cpu: 0.4, memory: 0.6, gpu: nil, diskUsed: 0.5,
            topProcesses: [
                ProcessAttribution(name: "Safari", cpu: 0.9, memory: 30),
                ProcessAttribution(name: "Xcode", cpu: 0.4, memory: 40) // 小时内取峰值 0.8，不是 0.4
            ],
            at: base.addingTimeInterval(31 * 60)
        )
        store.record(
            cpu: 0.6, memory: 0.8, gpu: nil, diskUsed: 0.5,
            topProcesses: [
                ProcessAttribution(name: "kernel_task", cpu: 0.05, memory: 50),
                ProcessAttribution(name: "WindowServer", cpu: 0.01, memory: 60)
            ],
            at: base.addingTimeInterval(32 * 60)
        )
        store.record(cpu: 0.8, memory: 1.0, gpu: nil, diskUsed: 0.5, at: base.addingTimeInterval(33 * 60))
        store.flush()

        let hourly = store.hourly(days: 1, now: base.addingTimeInterval(3600))
        let hour = try XCTUnwrap(hourly.first)
        XCTAssertEqual(hour.cpu, 0.5, accuracy: 0.0001) // (0.2+0.4+0.6+0.8)/4，分钟点平均值不变
        let processes = try XCTUnwrap(hour.topProcesses)
        XCTAssertLessThanOrEqual(processes.count, 3)
        XCTAssertEqual(processes.map(\.name), ["Safari", "Xcode", "node"])
        XCTAssertEqual(processes[1].cpu, 0.8, accuracy: 0.0001)
    }

    func testHourlyToleratesLegacySamplesWithoutTopProcesses() throws {
        let base = calendar.dateInterval(of: .hour, for: Date())!.start
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try legacySampleLine(
            timestamp: base.addingTimeInterval(10 * 60),
            cpu: 0.2,
            memory: 0.4,
            diskUsed: 0.5
        ).write(to: dayFileURL(for: base))

        let store = makeStore()
        store.record(
            cpu: 0.6, memory: 0.8, gpu: nil, diskUsed: 0.5,
            topProcesses: [ProcessAttribution(name: "Xcode", cpu: 0.7, memory: 10)],
            at: base.addingTimeInterval(20 * 60)
        )
        store.flush()

        let hourly = store.hourly(days: 1, now: base.addingTimeInterval(3600))
        let hour = try XCTUnwrap(hourly.first)
        XCTAssertEqual(hour.cpu, 0.4, accuracy: 0.0001) // (0.2 + 0.6)/2
        let processes = try XCTUnwrap(hour.topProcesses)
        XCTAssertEqual(processes.map(\.name), ["Xcode"])
    }

    func testRecordWithoutTopProcessesKeepsLegacyBehavior() throws {
        let base = minuteStart(Date())
        let store = makeStore()

        XCTAssertFalse(store.record(cpu: 0.2, memory: 0.5, gpu: 0.1, diskUsed: 0.4, at: base.addingTimeInterval(5)))
        XCTAssertFalse(store.record(cpu: 0.4, memory: 0.7, gpu: 0.3, diskUsed: 0.4, at: base.addingTimeInterval(40)))
        XCTAssertTrue(store.record(cpu: 0.6, memory: 0.9, gpu: 0.5, diskUsed: 0.4, at: base.addingTimeInterval(65)))

        let points = store.recent24h(now: base.addingTimeInterval(120))
        XCTAssertEqual(points.count, 2)
        let flushed = try XCTUnwrap(points.first)
        XCTAssertEqual(flushed.cpu, 0.3, accuracy: 0.0001)
        XCTAssertEqual(flushed.memory, 0.6, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(flushed.gpu), 0.2, accuracy: 0.0001)
        XCTAssertNil(flushed.topProcesses)
    }
}
