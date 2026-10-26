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
}
