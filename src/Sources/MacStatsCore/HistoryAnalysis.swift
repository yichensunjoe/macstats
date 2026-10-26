import Foundation

/// 历史曲线上可以看峰值的三个指标。原始值直接用于持久化/日志，不要改拼写。
public enum HistoryMetric: String, Sendable, CaseIterable {
    case cpu
    case memory
    case gpu
}

/// 一次峰值：哪个指标、落在哪个分钟点、值是多少（0...1，与面板显示同源）。
public struct HistoryPeak: Sendable, Equatable {
    public var metric: HistoryMetric
    public var sample: HistorySample
    public var value: Double

    public init(metric: HistoryMetric, sample: HistorySample, value: Double) {
        self.metric = metric
        self.sample = sample
        self.value = value
    }
}

/// 纯函数峰值分析。UI 只调用这里，不要各自再写一遍「取最大值」。
public enum HistoryAnalysis {
    /// 返回第一个最大值（最早的峰值），空数组 / 全 nil GPU 返回 nil。
    ///
    /// 按数组顺序扫描；HistoryStore 返回的点已按时间升序，所以并列时保留的是最早的峰值。
    /// GPU 为 nil 的点直接跳过——没有独显的机器不能把「没数据」当成 0 参与比较。
    public static func peak(in samples: [HistorySample], metric: HistoryMetric) -> HistoryPeak? {
        switch metric {
        case .cpu:
            return peak(in: samples, metric: metric) { $0.cpu }
        case .memory:
            return peak(in: samples, metric: metric) { $0.memory }
        case .gpu:
            return peak(in: samples, metric: metric) { $0.gpu }
        }
    }

    private static func peak(
        in samples: [HistorySample],
        metric: HistoryMetric,
        read: (HistorySample) -> Double?
    ) -> HistoryPeak? {
        var best: HistoryPeak?
        for sample in samples {
            guard let current = read(sample) else { continue }
            // 严格大于才替换：并列时保留先遇到的那条，即最早峰值。
            if best.map({ current > $0.value }) ?? true {
                best = HistoryPeak(metric: metric, sample: sample, value: current)
            }
        }
        return best
    }
}
