import XCTest
@testable import MacStatsCore

final class FormatTests: XCTestCase {
    func testBytesUsesBinaryUnits() {
        XCTAssertEqual(ByteFormat.bytes(UInt64(0)), "0 B")
        XCTAssertEqual(ByteFormat.bytes(UInt64(512)), "512 B")
        XCTAssertEqual(ByteFormat.bytes(UInt64(1024)), "1.0 KB")
        XCTAssertEqual(ByteFormat.bytes(UInt64(39_730_000_000)), "37.0 GB")
        XCTAssertEqual(ByteFormat.bytes(UInt64(64) * 1024 * 1024 * 1024), "64.0 GB")
    }

    func testRateAppendsPerSecond() {
        XCTAssertEqual(ByteFormat.rate(0), "0 B/s")
        XCTAssertEqual(ByteFormat.rate(1_572_864), "1.5 MB/s")
    }

    /// 内存跟随活动监视器：二进制进位、固定两位小数（64 GiB 显示 64.00 GB）。
    func testMemoryUsesBinaryWithTwoDecimals() {
        XCTAssertEqual(ByteFormat.memory(UInt64(64) * 1024 * 1024 * 1024), "64.00 GB")
        XCTAssertEqual(ByteFormat.memory(UInt64(46.77 * 1_073_741_824)), "46.77 GB")
        XCTAssertEqual(ByteFormat.memory(UInt64(1.65 * 1_073_741_824)), "1.65 GB")
    }

    /// 磁盘与网络跟随活动监视器：十进制进位（2.69e12 显示 2.69 TB）。
    func testDecimalUnitsForDiskAndNetwork() {
        XCTAssertEqual(ByteFormat.decimalBytes(UInt64(2_690_000_000_000)), "2.69 TB")
        XCTAssertEqual(ByteFormat.decimalBytes(UInt64(153_790_000_000)), "153.79 GB")
        XCTAssertEqual(ByteFormat.decimalBytes(UInt64(31_000)), "31 KB")
        XCTAssertEqual(ByteFormat.decimalRate(7_900_000), "7.9 MB/s")
        XCTAssertEqual(ByteFormat.decimalRate(147_000), "147 KB/s")
    }

    /// 单个进程内存保留一位小数，与活动监视器的 `966.1 MB` 一致。
    func testProcessMemoryKeepsOneDecimal() {
        XCTAssertEqual(ByteFormat.processMemory(UInt64(966 * 1_048_576)), "966.0 MB")
        XCTAssertEqual(ByteFormat.processMemory(UInt64(4 * 1_048_576)), "4.0 MB")
    }

    func testPercentClamps() {
        XCTAssertEqual(PercentFormat.percent(0.384), "38%")
        XCTAssertEqual(PercentFormat.percent(1.4), "100%")
        XCTAssertEqual(PercentFormat.percent(-0.2), "0%")
    }

    /// 活动监视器显示一位小数，小组件的 CPU 大数字沿用同一精度。
    func testPrecisePercentKeepsOneDecimal() {
        XCTAssertEqual(PercentFormat.precise(0.0974), "9.7%")
        XCTAssertEqual(PercentFormat.precise(1.2), "100.0%")
        XCTAssertEqual(PercentFormat.precise(-0.5), "0.0%")
    }

    /// 进程 CPU 按单核计，多核可超过 100%，不能封顶。
    func testProcessCPUIsNotCapped() {
        XCTAssertEqual(PercentFormat.processCPU(0.123), "12.3%")
        XCTAssertEqual(PercentFormat.processCPU(1.56), "156.0%")
        XCTAssertEqual(PercentFormat.processCPU(-0.1), "0.0%")
    }

    func testUptimeFormatting() {
        XCTAssertEqual(DurationFormat.uptime(3 * 86_400 + 4 * 3_600 + 60), "3天4小时")
        XCTAssertEqual(DurationFormat.uptime(4 * 3_600 + 12 * 60), "4小时12分")
        XCTAssertEqual(DurationFormat.uptime(750), "12分30秒")
    }

    func testMinutesFormatting() {
        XCTAssertEqual(DurationFormat.minutes(135), "2小时15分")
        XCTAssertEqual(DurationFormat.minutes(45), "45分")
        XCTAssertEqual(DurationFormat.minutes(0), "—")
    }

    func testWattsFormatting() {
        XCTAssertEqual(EnergyFormat.watts(12.44), "12.4 W")
        XCTAssertEqual(EnergyFormat.watts(-3), "0.0 W")
    }

    /// 极简条六格挤在一行，数字要短：不带空格、小值保留一位小数。
    func testCompactFormatsForMicroStrip() {
        XCTAssertEqual(ByteFormat.compactMemory(UInt64(46) * 1024 * 1024 * 1024), "46GB")
        XCTAssertEqual(ByteFormat.compactMemory(UInt64(1.5 * 1_073_741_824)), "1.5GB")
        XCTAssertEqual(ByteFormat.compactMemory(UInt64(966) * 1_048_576), "966MB")
        XCTAssertEqual(ByteFormat.compactMemory(0), "0B")
        XCTAssertEqual(ByteFormat.compactRate(79_000), "79KB/s")
        XCTAssertEqual(ByteFormat.compactRate(1_400_000), "1.4MB/s")
        XCTAssertEqual(ByteFormat.compactRate(-5), "0B/s")
        XCTAssertEqual(EnergyFormat.compactWatts(0.86), "0.9W")
        XCTAssertEqual(EnergyFormat.compactWatts(12.4), "12W")
    }
}
