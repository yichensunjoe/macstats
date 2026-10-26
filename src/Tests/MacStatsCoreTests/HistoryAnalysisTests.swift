import XCTest
@testable import MacStatsCore

final class HistoryAnalysisTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_760_000_000)

    private func sample(
        minute: Int,
        cpu: Double,
        memory: Double,
        gpu: Double?,
        diskUsed: Double = 0.5
    ) -> HistorySample {
        HistorySample(
            timestamp: base.addingTimeInterval(Double(minute) * 60),
            cpu: cpu,
            memory: memory,
            gpu: gpu,
            diskUsed: diskUsed
        )
    }

    // MARK: - 空输入

    func testEmptySamplesReturnNilForEveryMetric() {
        for metric in HistoryMetric.allCases {
            XCTAssertNil(HistoryAnalysis.peak(in: [], metric: metric), "empty samples should have no \(metric) peak")
        }
    }

    func testAllNilGPUReturnsNilForGPUPeak() {
        let samples = [
            sample(minute: 0, cpu: 0.2, memory: 0.4, gpu: nil),
            sample(minute: 1, cpu: 0.9, memory: 0.6, gpu: nil),
            sample(minute: 2, cpu: 0.1, memory: 0.3, gpu: nil)
        ]
        XCTAssertNil(HistoryAnalysis.peak(in: samples, metric: .gpu))
        // CPU/内存仍然有峰值：nil GPU 不能影响其它指标。
        XCTAssertEqual(HistoryAnalysis.peak(in: samples, metric: .cpu)?.value, 0.9)
        XCTAssertEqual(HistoryAnalysis.peak(in: samples, metric: .memory)?.value, 0.6)
    }

    // MARK: - CPU / 内存峰值

    func testCPUPicksMaximumSample() throws {
        let samples = [
            sample(minute: 0, cpu: 0.10, memory: 0.40, gpu: nil),
            sample(minute: 1, cpu: 0.92, memory: 0.55, gpu: nil),
            sample(minute: 2, cpu: 0.31, memory: 0.61, gpu: nil)
        ]
        let peak = try XCTUnwrap(HistoryAnalysis.peak(in: samples, metric: .cpu))
        XCTAssertEqual(peak.metric, .cpu)
        XCTAssertEqual(peak.value, 0.92, accuracy: 0.000_000_1)
        XCTAssertEqual(peak.sample.timestamp, samples[1].timestamp)
        XCTAssertEqual(peak.sample, samples[1])
    }

    func testMemoryPicksMaximumSample() throws {
        let samples = [
            sample(minute: 0, cpu: 0.70, memory: 0.22, gpu: nil),
            sample(minute: 1, cpu: 0.12, memory: 0.88, gpu: nil),
            sample(minute: 2, cpu: 0.45, memory: 0.53, gpu: nil)
        ]
        let peak = try XCTUnwrap(HistoryAnalysis.peak(in: samples, metric: .memory))
        XCTAssertEqual(peak.metric, .memory)
        XCTAssertEqual(peak.value, 0.88, accuracy: 0.000_000_1)
        XCTAssertEqual(peak.sample, samples[1])
    }

    func testFirstSampleCanBeThePeak() throws {
        let samples = [
            sample(minute: 0, cpu: 0.99, memory: 0.10, gpu: 0.95),
            sample(minute: 1, cpu: 0.40, memory: 0.20, gpu: 0.30)
        ]
        let cpu = try XCTUnwrap(HistoryAnalysis.peak(in: samples, metric: .cpu))
        XCTAssertEqual(cpu.sample, samples[0])
        let gpu = try XCTUnwrap(HistoryAnalysis.peak(in: samples, metric: .gpu))
        XCTAssertEqual(gpu.sample, samples[0])
    }

    // MARK: - 并列取最早

    func testTiedMaximumReturnsEarliestSample() throws {
        let samples = [
            sample(minute: 0, cpu: 0.30, memory: 0.80, gpu: 0.40),
            sample(minute: 1, cpu: 0.85, memory: 0.80, gpu: 0.70),
            sample(minute: 2, cpu: 0.85, memory: 0.80, gpu: 0.70),
            sample(minute: 3, cpu: 0.20, memory: 0.10, gpu: nil)
        ]
        let cpu = try XCTUnwrap(HistoryAnalysis.peak(in: samples, metric: .cpu))
        XCTAssertEqual(cpu.value, 0.85, accuracy: 0.000_000_1)
        XCTAssertEqual(cpu.sample.timestamp, samples[1].timestamp, "tie should keep the earliest peak")

        let memory = try XCTUnwrap(HistoryAnalysis.peak(in: samples, metric: .memory))
        XCTAssertEqual(memory.sample.timestamp, samples[0].timestamp)

        let gpu = try XCTUnwrap(HistoryAnalysis.peak(in: samples, metric: .gpu))
        XCTAssertEqual(gpu.value, 0.70, accuracy: 0.000_000_1)
        XCTAssertEqual(gpu.sample.timestamp, samples[1].timestamp)
    }

    // MARK: - 单点

    func testSingleSampleIsItsOwnPeakForEveryMetric() throws {
        let only = sample(minute: 0, cpu: 0.42, memory: 0.37, gpu: 0.11)
        for metric in HistoryMetric.allCases {
            let peak = try XCTUnwrap(HistoryAnalysis.peak(in: [only], metric: metric))
            XCTAssertEqual(peak.metric, metric)
            XCTAssertEqual(peak.sample, only)
        }
        XCTAssertEqual(try XCTUnwrap(HistoryAnalysis.peak(in: [only], metric: .cpu)).value, 0.42, accuracy: 0.000_000_1)
        XCTAssertEqual(try XCTUnwrap(HistoryAnalysis.peak(in: [only], metric: .memory)).value, 0.37, accuracy: 0.000_000_1)
        XCTAssertEqual(try XCTUnwrap(HistoryAnalysis.peak(in: [only], metric: .gpu)).value, 0.11, accuracy: 0.000_000_1)
    }

    func testSingleSampleWithNilGPUStillHasNoGPUPeak() {
        let only = sample(minute: 0, cpu: 0.42, memory: 0.37, gpu: nil)
        XCTAssertNil(HistoryAnalysis.peak(in: [only], metric: .gpu))
        XCTAssertNotNil(HistoryAnalysis.peak(in: [only], metric: .cpu))
    }

    // MARK: - GPU 有值

    func testGPUPicksMaximumAmongPresentValues() throws {
        let samples = [
            sample(minute: 0, cpu: 0.10, memory: 0.20, gpu: nil),
            sample(minute: 1, cpu: 0.20, memory: 0.30, gpu: 0.15),
            sample(minute: 2, cpu: 0.30, memory: 0.40, gpu: 0.87),
            sample(minute: 3, cpu: 0.40, memory: 0.50, gpu: nil),
            sample(minute: 4, cpu: 0.50, memory: 0.60, gpu: 0.60)
        ]
        let peak = try XCTUnwrap(HistoryAnalysis.peak(in: samples, metric: .gpu))
        XCTAssertEqual(peak.metric, .gpu)
        XCTAssertEqual(peak.value, 0.87, accuracy: 0.000_000_1)
        XCTAssertEqual(peak.sample, samples[2])
    }

    // MARK: - 零值 / 契约细节

    func testAllZeroValuesReturnFirstSampleInsteadOfNil() throws {
        let samples = [
            sample(minute: 0, cpu: 0, memory: 0, gpu: 0),
            sample(minute: 1, cpu: 0, memory: 0, gpu: 0)
        ]
        let cpu = try XCTUnwrap(HistoryAnalysis.peak(in: samples, metric: .cpu))
        XCTAssertEqual(cpu.value, 0)
        XCTAssertEqual(cpu.sample.timestamp, samples[0].timestamp)
        XCTAssertEqual(try XCTUnwrap(HistoryAnalysis.peak(in: samples, metric: .gpu)).value, 0)
    }

    func testPeakValueMatchesSampleFieldForEachMetric() throws {
        let samples = [
            sample(minute: 0, cpu: 0.11, memory: 0.22, gpu: 0.33),
            sample(minute: 1, cpu: 0.77, memory: 0.44, gpu: 0.55)
        ]
        let cpu = try XCTUnwrap(HistoryAnalysis.peak(in: samples, metric: .cpu))
        XCTAssertEqual(cpu.value, cpu.sample.cpu, accuracy: 0.000_000_1)
        let memory = try XCTUnwrap(HistoryAnalysis.peak(in: samples, metric: .memory))
        XCTAssertEqual(memory.value, memory.sample.memory, accuracy: 0.000_000_1)
        let gpu = try XCTUnwrap(HistoryAnalysis.peak(in: samples, metric: .gpu))
        XCTAssertEqual(gpu.value, try XCTUnwrap(gpu.sample.gpu), accuracy: 0.000_000_1)
    }

    func testMetricCaseIterableOrderIsStable() {
        XCTAssertEqual(HistoryMetric.allCases, [.cpu, .memory, .gpu])
        XCTAssertEqual(HistoryMetric.cpu.rawValue, "cpu")
        XCTAssertEqual(HistoryMetric.memory.rawValue, "memory")
        XCTAssertEqual(HistoryMetric.gpu.rawValue, "gpu")
    }
}
