import Foundation

/// 会触发通知的指标。
public enum AlertKind: String, Codable, Sendable, CaseIterable {
    case cpu
    case memory
    case disk
}

public struct AlertThresholds: Sendable, Equatable {
    public var cpu: Double
    public var memory: Double
    public var disk: Double
    /// 连续多少次越过阈值才算「持续」，单次尖峰不打扰人。
    public var consecutive: Int
    /// 同一指标两次通知之间的最短间隔。
    public var cooldown: TimeInterval

    public init(
        cpu: Double = 0.90,
        memory: Double = 0.85,
        disk: Double = 0.90,
        consecutive: Int = 3,
        cooldown: TimeInterval = 600
    ) {
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.consecutive = max(1, consecutive)
        self.cooldown = cooldown
    }

    public func threshold(for kind: AlertKind) -> Double {
        switch kind {
        case .cpu: cpu
        case .memory: memory
        case .disk: disk
        }
    }
}

public struct AlertEvent: Sendable, Equatable {
    public var kind: AlertKind
    public var value: Double
    public var threshold: Double
    public var consecutive: Int
}

/// 纯状态机：喂进每秒采样，只在「连续 N 次超阈值 + 冷却期已过」时吐一个事件。
/// 不碰通知、不读设置，方便单测。
public final class ThresholdAlertEvaluator: @unchecked Sendable {
    private let lock = NSLock()
    private let thresholds: AlertThresholds
    private var streaks: [AlertKind: Int] = [:]
    private var lastFired: [AlertKind: Date] = [:]

    public init(thresholds: AlertThresholds = AlertThresholds()) {
        self.thresholds = thresholds
    }

    public func evaluate(cpu: Double, memory: Double, diskUsed: Double, at date: Date = Date()) -> AlertEvent? {
        lock.lock()
        defer { lock.unlock() }

        let values: [(AlertKind, Double)] = [(.cpu, cpu), (.memory, memory), (.disk, diskUsed)]
        var fired: AlertEvent?
        for (kind, value) in values {
            if value >= thresholds.threshold(for: kind) {
                let count = (streaks[kind] ?? 0) + 1
                streaks[kind] = count
                guard fired == nil, count >= thresholds.consecutive else { continue }
                if let last = lastFired[kind], date.timeIntervalSince(last) < thresholds.cooldown {
                    continue
                }
                lastFired[kind] = date
                streaks[kind] = 0
                fired = AlertEvent(
                    kind: kind,
                    value: value,
                    threshold: thresholds.threshold(for: kind),
                    consecutive: count
                )
            } else {
                streaks[kind] = 0
            }
        }
        return fired
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        streaks.removeAll()
        lastFired.removeAll()
    }
}
