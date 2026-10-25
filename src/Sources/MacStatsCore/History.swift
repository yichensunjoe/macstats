import Foundation

/// 定长环形缓冲，用来驱动小组件里的迷你趋势线。
public struct MetricRing: Sendable, Equatable {
    public let capacity: Int
    public private(set) var values: [Double]

    public init(capacity: Int = 60, values: [Double] = []) {
        self.capacity = max(1, capacity)
        self.values = Array(values.suffix(max(1, capacity)))
    }

    public mutating func append(_ value: Double) {
        values.append(value)
        if values.count > capacity {
            values.removeFirst(values.count - capacity)
        }
    }

    public var latest: Double? { values.last }

    /// 最后 `count` 个点的平均值；用于对齐活动监视器的 5 秒刷新窗口。
    public func mean(last count: Int) -> Double? {
        let slice = values.suffix(max(1, count))
        guard !slice.isEmpty else { return nil }
        return slice.reduce(0, +) / Double(slice.count)
    }

    public var average: Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    public var peak: Double? { values.max() }

    /// 归一化到 0...1，`minimumScale` 防止低负载时曲线被放大成满格。
    /// 少于两个点时补 0，保证刚启动时也能画出基线。
    public func normalized(minimumScale: Double) -> [Double] {
        SeriesMath.normalize([values], minimumScale: minimumScale).first ?? []
    }
}

/// 多条曲线共用同一纵轴刻度（例如磁盘读写、网络上下行），保证比例可比。
public enum SeriesMath {
    public static func normalize(_ series: [[Double]], minimumScale: Double) -> [[Double]] {
        let peak = series.flatMap { $0 }.max() ?? 0
        let scale = max(peak, minimumScale, .ulpOfOne)
        return series.map { values in
            var points = values.map { min(max($0 / scale, 0), 1) }
            if points.count == 1 { points.insert(points[0], at: 0) }
            return points
        }
    }
}
