import XCTest
@testable import MacStatsCore

final class MetricRingTests: XCTestCase {
    func testMeanOverTrailingWindow() {
        var ring = MetricRing(capacity: 10)
        for value in [1.0, 2.0, 3.0, 4.0, 100.0] { ring.append(value) }
        XCTAssertEqual(ring.mean(last: 2) ?? 0, 52, accuracy: 0.0001)
        XCTAssertEqual(ring.mean(last: 10) ?? 0, 22, accuracy: 0.0001)
        XCTAssertNil(MetricRing(capacity: 4).mean(last: 5))
    }


    func testAppendRespectsCapacity() {
        var ring = MetricRing(capacity: 3)
        for value in [1.0, 2.0, 3.0, 4.0, 5.0] { ring.append(value) }
        XCTAssertEqual(ring.values, [3, 4, 5])
        XCTAssertEqual(ring.latest, 5)
        XCTAssertEqual(ring.peak, 5)
        XCTAssertEqual(ring.average, 4)
    }

    func testNormalizeUsesMinimumScale() {
        var ring = MetricRing(capacity: 4)
        ring.append(0.01)
        ring.append(0.02)
        let points = ring.normalized(minimumScale: 0.5)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[1], 0.04, accuracy: 0.0001)
        XCTAssertEqual(points[0], 0.02, accuracy: 0.0001)
    }

    func testSinglePointIsDuplicated() {
        var ring = MetricRing(capacity: 4)
        ring.append(0.5)
        XCTAssertEqual(ring.normalized(minimumScale: 0.5).count, 2)
    }

    func testEmptyRingNormalizesToEmpty() {
        let ring = MetricRing(capacity: 4)
        XCTAssertTrue(ring.normalized(minimumScale: 1).isEmpty)
        XCTAssertNil(ring.latest)
    }
}

final class MemoryMathTests: XCTestCase {
    private func makeVM() -> VMSnapshot {
        VMSnapshot(
            totalBytes: 64_000,
            freeBytes: 4_000,
            activeBytes: 20_000,
            inactiveBytes: 6_000,
            wiredBytes: 8_000,
            compressedBytes: 5_000,
            purgeableBytes: 2_000,
            appBytes: 30_000,
            fileBackedBytes: 15_000,
            swapUsedBytes: 1_500,
            swapTotalBytes: 4_096,
            pressure: .warning
        )
    }

    /// 活动监视器口径：已使用 = 物理内存 - 空闲 - 文件缓存（不是三项之和）。
    func testUsedMatchesActivityMonitorFormula() {
        let status = MemoryMath.status(from: makeVM())
        XCTAssertEqual(status.used, 64_000 - 4_000 - 15_000)
        XCTAssertEqual(status.used, 45_000)
        XCTAssertEqual(status.cachedFiles, 17_000)
        XCTAssertEqual(status.free, 4_000)
        XCTAssertEqual(status.pressure, .warning)
        XCTAssertEqual(status.swapUsed, 1_500)
    }

    /// 内核把 speculative 页算进 free_count，活动监视器会扣掉它再算空闲/已使用。
    func testSpeculativePagesAreNotCountedAsFree() {
        var vm = makeVM()
        vm.speculativeBytes = 1_000
        let status = MemoryMath.status(from: vm)
        XCTAssertEqual(status.free, 3_000)
        XCTAssertEqual(status.used, 64_000 - 3_000 - 15_000)
    }

    func testCachedFilesIncludeFileBackedAndPurgeable() {
        var vm = makeVM()
        vm.purgeableBytes = 3_500
        let status = MemoryMath.status(from: vm)
        XCTAssertEqual(status.cachedFiles, 15_000 + 3_500)
    }

    func testPressureScoreStaysInRange() {
        var vm = makeVM()
        vm.appBytes = 60_000
        vm.wiredBytes = 20_000
        vm.compressedBytes = 20_000
        let status = MemoryMath.status(from: vm)
        XCTAssertLessThanOrEqual(status.pressureScore, 1)
        XCTAssertGreaterThanOrEqual(status.pressureScore, 0)
    }

    func testUsedNeverExceedsTotal() {
        var vm = makeVM()
        vm.freeBytes = 100
        vm.fileBackedBytes = 100
        vm.totalBytes = 200
        let status = MemoryMath.status(from: vm)
        XCTAssertEqual(status.used, 0)
    }

    func testPressureLevelMapping() {
        XCTAssertEqual(MemoryPressure(rawPressureLevel: 1), .normal)
        XCTAssertEqual(MemoryPressure(rawPressureLevel: 2), .warning)
        XCTAssertEqual(MemoryPressure(rawPressureLevel: 4), .critical)
    }
}

final class WindowAveragesTests: XCTestCase {
    func testApplyingReplacesRateMetricsOnly() {
        var snapshot = MetricSnapshot.empty
        snapshot.memory.used = 42
        snapshot.cpu.cores = [0.5, 0.25]
        let averaged = snapshot.applying(
            WindowAverages(
                cpuTotal: 0.4, cpuUser: 0.25, cpuSystem: 0.15, energyWatts: 7.5,
                diskRead: 1_024, diskWrite: 2_048, networkIn: 4_096, networkOut: 8_192,
                sampleCount: 5
            )
        )
        XCTAssertEqual(averaged.cpu.total, 0.4, accuracy: 0.0001)
        XCTAssertEqual(averaged.cpu.idle, 0.6, accuracy: 0.0001)
        XCTAssertEqual(averaged.disk.readBytesPerSecond, 1_024)
        XCTAssertEqual(averaged.network.bytesOutPerSecond, 8_192)
        XCTAssertEqual(averaged.memory.used, 42)
        XCTAssertEqual(averaged.cpu.cores, [0.5, 0.25])
        XCTAssertEqual(averaged.energy.watts, 7.5)
    }

    func testEmptyWindowKeepsSnapshot() {
        var snapshot = MetricSnapshot.empty
        snapshot.cpu.total = 0.7
        let averaged = snapshot.applying(WindowAverages())
        XCTAssertEqual(averaged.cpu.total, 0.7, accuracy: 0.0001)
    }
}

final class EnergyModelTests: XCTestCase {
    func testWattsFromNanojoules() {
        XCTAssertEqual(EnergyModel.watts(energyNanojoules: 2_000_000_000, over: 2), 1, accuracy: 0.0001)
        XCTAssertEqual(EnergyModel.watts(energyNanojoules: 0, over: 1), 0)
        XCTAssertEqual(EnergyModel.watts(energyNanojoules: 100, over: 0), 0)
    }

    func testTotalUsesEnergyCountersWhenPresent() {
        let result = EnergyModel.totalWatts(
            entries: [(energyNanojoules: 4_000_000_000, cpuFraction: 1.0), (energyNanojoules: 0, cpuFraction: 0.5)],
            over: 2
        )
        XCTAssertEqual(result.watts, 2, accuracy: 0.0001)
        XCTAssertFalse(result.isEstimated)
    }

    func testTotalFallsBackToCPUEstimate() {
        let result = EnergyModel.totalWatts(
            entries: [(energyNanojoules: 0, cpuFraction: 1.0), (energyNanojoules: 0, cpuFraction: 1.0)],
            over: 1
        )
        XCTAssertEqual(result.watts, EnergyModel.estimatedWattsPerCore * 2, accuracy: 0.0001)
        XCTAssertTrue(result.isEstimated)
    }

    func testProcessWattsPrefersEnergyDelta() {
        let watts = EnergyModel.processWatts(energyNanojoules: 1_000_000_000, cpuFraction: 4, over: 1)
        XCTAssertEqual(watts, 1, accuracy: 0.0001)
    }
}

final class SystemSamplerTests: XCTestCase {
    func testSampleWithoutProcessesSkipsProcessList() {
        let sampler = SystemSampler(config: SamplerConfig(processLimit: 10, includeProcesses: true))
        let snapshot = sampler.sample(includeProcesses: false)
        XCTAssertTrue(snapshot.processes.isEmpty)
        XCTAssertGreaterThan(snapshot.memory.total, 0)
    }

    func testResetBaselineClearsStateWithoutCrashing() {
        let sampler = SystemSampler()
        _ = sampler.sample()
        sampler.resetBaseline()
        let second = sampler.sample()
        XCTAssertGreaterThan(second.memory.total, 0)
    }

    func testConcurrentSamplingAndResetBaseline() async {
        let sampler = SystemSampler(config: SamplerConfig(processLimit: 5, includeProcesses: false))
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    if i % 5 == 0 {
                        sampler.resetBaseline()
                    } else {
                        let snap = sampler.sample(includeProcesses: false)
                        XCTAssertGreaterThan(snap.memory.total, 0)
                    }
                }
            }
        }
    }
}

/// `MetricSnapshot` 的旧 JSON 兼容：0.4 之前的 `widget-feed.json` 没有
/// `topCPUProcesses` 键，必须仍能解码，且 `topCPU` 为空。
final class MetricSnapshotCompatibilityTests: XCTestCase {
    /// 0.4 之前的真实形状：没有 topCPUProcesses，GPU 键也可能整体缺席。
    private let legacyJSON = #"""
    {
      "timestamp": 800000000,
      "hostName": "Mac",
      "uptime": 3600,
      "cpu": {
        "total": 0.42, "user": 0.3, "system": 0.12, "idle": 0.58,
        "cores": [0.4, 0.44], "loadAverage": [1.5, 1.2, 1.1]
      },
      "memory": {
        "total": 68719476736, "used": 42949672960, "app": 32212254720,
        "wired": 4294967296, "compressed": 4294967296, "cachedFiles": 18253611008,
        "free": 7516192768, "swapUsed": 1000000000, "swapTotal": 2000000000,
        "pressure": "warning", "pressureScore": 0.55
      },
      "energy": {
        "watts": 18.5, "isEstimated": false, "batteryPercent": 80,
        "isCharging": true, "isOnBattery": false, "minutesRemaining": null
      },
      "disk": {
        "readBytesPerSecond": 1000000, "writeBytesPerSecond": 500000,
        "totalReadBytes": 1, "totalWrittenBytes": 2, "capacity": 3, "free": 1
      },
      "network": {
        "bytesInPerSecond": 2000000, "bytesOutPerSecond": 300000,
        "totalBytesIn": 10, "totalBytesOut": 20, "interfaceCount": 1,
        "activeInterfaces": ["en0"]
      },
      "processes": [
        {"pid": 42, "name": "WindowServer", "cpu": 0.1, "memory": 1046478848, "energyWatts": 1.2}
      ]
    }
    """#

    func testLegacySnapshotJSONWithoutTopCPUProcessesDecodes() throws {
        let snapshot = try JSONDecoder().decode(MetricSnapshot.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(snapshot.hostName, "Mac")
        XCTAssertEqual(snapshot.cpu.total, 0.42, accuracy: 0.000_001)
        XCTAssertEqual(snapshot.processes.map(\.name), ["WindowServer"])
        XCTAssertNil(snapshot.gpu)
        XCTAssertNil(snapshot.topCPUProcesses, "旧 JSON 没有 topCPUProcesses 键，解码为 nil")
        XCTAssertTrue(snapshot.topCPU.isEmpty, "旧快照的 topCPU 为空数组，不伪造进程")
    }

    /// 旧 JSON 里带 GPU 键（0.3 中后期）但没有 topCPUProcesses，同样要能解码。
    func testLegacySnapshotJSONWithGPUButWithoutTopCPUProcessesDecodes() throws {
        let json = legacyJSON.replacingOccurrences(
            of: #""processes": ["#,
            with: #""gpu": {"utilization": 0.37, "coreCount": 20, "model": "Apple M5 Pro"}, "processes": ["#
        )
        let snapshot = try JSONDecoder().decode(MetricSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(snapshot.gpu?.utilization ?? -1, 0.37, accuracy: 0.000_001)
        XCTAssertNil(snapshot.topCPUProcesses)
        XCTAssertTrue(snapshot.topCPU.isEmpty)
    }
}

