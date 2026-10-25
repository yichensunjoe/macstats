import XCTest
@testable import MacStatsCore

final class WidgetFeedTests: XCTestCase {
    func testFeedPathLivesUnderApplicationSupport() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
        let url = WidgetFeedStore.url(inHome: home)
        XCTAssertEqual(
            url.path,
            "/Users/example/Library/Application Support/MacStats/widget-feed.json"
        )
    }

    /// 主程序写、扩展读，两边靠这一个 JSON 对齐；时间戳与进程都要原样回来。
    func testFeedRoundTripsThroughDisk() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("macstats-feed-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let feed = WidgetFeed(
            snapshot: MetricSnapshot(
                timestamp: Date(timeIntervalSince1970: 1_760_000_000),
                hostName: "Mac",
                uptime: 3600,
                cpu: CPUStatus(total: 0.42, user: 0.3, system: 0.12, idle: 0.58, cores: [0.4, 0.44], loadAverage: [1.5, 1.2, 1.1]),
                memory: MemoryStatus(
                    total: 64 * 1_073_741_824,
                    used: 40 * 1_073_741_824,
                    app: 30 * 1_073_741_824,
                    wired: 4 * 1_073_741_824,
                    compressed: 4 * 1_073_741_824,
                    cachedFiles: 17 * 1_073_741_824,
                    free: 7 * 1_073_741_824,
                    swapUsed: 1_000_000_000,
                    swapTotal: 2_000_000_000,
                    pressure: .warning,
                    pressureScore: 0.55
                ),
                energy: EnergyStatus(
                    watts: 18.5, isEstimated: false, batteryPercent: 80,
                    isCharging: true, isOnBattery: false, minutesRemaining: nil
                ),
                disk: DiskStatus(
                    readBytesPerSecond: 1_000_000, writeBytesPerSecond: 500_000,
                    totalReadBytes: 1, totalWrittenBytes: 2,
                    capacity: 3, free: 1
                ),
                network: NetworkStatus(
                    bytesInPerSecond: 2_000_000, bytesOutPerSecond: 300_000,
                    totalBytesIn: 10, totalBytesOut: 20, interfaceCount: 1, activeInterfaces: ["en0"]
                ),
                processes: [
                    ProcessStatus(pid: 42, name: "WindowServer", cpu: 0.1, memory: 998 * 1_048_576, energyWatts: 1.2)
                ]
            ),
            cpuHistory: [0.2, 0.4, 0.42],
            memoryHistory: [0.5, 0.6, 0.62],
            networkInHistory: [1, 2],
            networkOutHistory: [0.1]
        )

        let url = WidgetFeedStore.url(inHome: home)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(feed).write(to: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetFeed.self, from: Data(contentsOf: url))

        XCTAssertEqual(decoded, feed)
        XCTAssertEqual(decoded.updatedAt, feed.snapshot.timestamp)
        XCTAssertEqual(decoded.snapshot.processes.first?.name, "WindowServer")
        XCTAssertEqual(decoded.cpuHistory.last ?? -1, 0.42, accuracy: 0.0001)
    }
}

final class WidgetFeedSignatureTests: XCTestCase {
    private func feed(
        cpu: Double = 0.25,
        memoryUsed: UInt64 = 8 * 1_073_741_824,
        memoryTotal: UInt64 = 16 * 1_073_741_824,
        diskRead: Double = 2_000_000,
        diskWrite: Double = 1_000_000,
        networkIn: Double = 5_000_000,
        networkOut: Double = 1_000_000,
        watts: Double? = 12.3,
        load: Double = 1.25,
        uptime: TimeInterval = 7_200,
        battery: Int? = nil,
        gpuUtilization: Double? = nil,
        gpuMemory: UInt64? = nil
    ) -> WidgetFeed {
        let snapshot = MetricSnapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            hostName: "test",
            uptime: uptime,
            cpu: CPUStatus(
                total: cpu,
                user: cpu / 2,
                system: cpu / 2,
                idle: 1 - cpu,
                cores: [cpu],
                loadAverage: [load, load / 2, load / 4]
            ),
            memory: MemoryStatus(
                total: memoryTotal,
                used: memoryUsed,
                app: memoryUsed / 2,
                wired: memoryUsed / 4,
                compressed: 0,
                cachedFiles: 0,
                free: memoryTotal - memoryUsed,
                swapUsed: 0,
                swapTotal: 0,
                pressure: .normal,
                pressureScore: 0
            ),
            energy: EnergyStatus(
                watts: watts,
                isEstimated: false,
                batteryPercent: battery,
                isCharging: false,
                isOnBattery: battery != nil,
                minutesRemaining: nil
            ),
            disk: DiskStatus(
                readBytesPerSecond: diskRead,
                writeBytesPerSecond: diskWrite,
                totalReadBytes: 0,
                totalWrittenBytes: 0,
                capacity: 500_000_000_000,
                free: 100_000_000_000
            ),
            network: NetworkStatus(
                bytesInPerSecond: networkIn,
                bytesOutPerSecond: networkOut,
                totalBytesIn: 0,
                totalBytesOut: 0,
                interfaceCount: 1,
                activeInterfaces: ["en0"]
            ),
            processes: [],
            gpu: gpuUtilization.map {
                GPUStatus(utilization: $0, memoryInUse: gpuMemory, coreCount: 20, model: "Apple M5 Pro")
            }
        )
        return WidgetFeed(snapshot: snapshot)
    }

    func testIdenticalNumbersHaveSameSignature() {
        XCTAssertEqual(WidgetFeedSignature(feed: feed()), WidgetFeedSignature(feed: feed()))
    }

    func testJitterBelowDisplayedPrecisionIsIgnored() {
        // CPU 0.04%、内存 0.3 MB、网络 10 kB/s、负载 0.001：界面上都看不出变化。
        let base = WidgetFeedSignature(feed: feed())
        let jittered = WidgetFeedSignature(feed: feed(
            cpu: 0.2504,
            memoryUsed: 8 * 1_073_741_824 + 300_000,
            networkIn: 5_010_000,
            load: 1.251
        ))
        XCTAssertEqual(base, jittered)
    }

    func testVisibleChangesBreakTheSignature() {
        let base = WidgetFeedSignature(feed: feed())
        XCTAssertNotEqual(base, WidgetFeedSignature(feed: feed(cpu: 0.30)))
        XCTAssertNotEqual(base, WidgetFeedSignature(feed: feed(memoryUsed: 9 * 1_073_741_824)))
        XCTAssertNotEqual(base, WidgetFeedSignature(feed: feed(diskWrite: 2_500_000)))
        XCTAssertNotEqual(base, WidgetFeedSignature(feed: feed(networkOut: 1_500_000)))
        XCTAssertNotEqual(base, WidgetFeedSignature(feed: feed(watts: 12.6)))
        XCTAssertNotEqual(base, WidgetFeedSignature(feed: feed(load: 1.40)))
        XCTAssertNotEqual(base, WidgetFeedSignature(feed: feed(uptime: 7_260)))
        XCTAssertNotEqual(base, WidgetFeedSignature(feed: feed(battery: 80)))
    }

    func testGPUChangesBreakTheSignature() {
        let base = WidgetFeedSignature(feed: feed(gpuUtilization: 0.40, gpuMemory: 2 * 1_073_741_824))
        XCTAssertEqual(base, WidgetFeedSignature(feed: feed(gpuUtilization: 0.4004, gpuMemory: 2 * 1_073_741_824 + 200_000)))
        XCTAssertNotEqual(base, WidgetFeedSignature(feed: feed(gpuUtilization: 0.45, gpuMemory: 2 * 1_073_741_824)))
        XCTAssertNotEqual(base, WidgetFeedSignature(feed: feed(gpuUtilization: 0.40, gpuMemory: 3 * 1_073_741_824)))
        // 没有 GPU 计数的机器与「0%」必须区分开。
        XCTAssertNotEqual(
            WidgetFeedSignature(feed: feed(gpuUtilization: nil)),
            WidgetFeedSignature(feed: feed(gpuUtilization: 0))
        )
    }

    func testMissingEnergyIsDistinctFromZeroWatts() {
        XCTAssertNotEqual(
            WidgetFeedSignature(feed: feed(watts: nil)),
            WidgetFeedSignature(feed: feed(watts: 0))
        )
    }
}
