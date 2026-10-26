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
    /// CPU 事件填 top CPU 进程；内存事件填 top 内存进程；磁盘事件为 nil。
    /// 调用方没传（0.4 之前的旧调用）时也是 nil，通知正文回退到旧文案。
    public var culprit: ProcessAttribution?

    public init(
        kind: AlertKind,
        value: Double,
        threshold: Double,
        consecutive: Int,
        culprit: ProcessAttribution? = nil
    ) {
        self.kind = kind
        self.value = value
        self.threshold = threshold
        self.consecutive = consecutive
        self.culprit = culprit
    }
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

    /// - Parameters:
    ///   - topCPU: CPU 事件要挂到通知上的元凶（通常 snapshot.topCPU.first）。
    ///   - topMemory: 内存事件要挂的元凶，必须显式用 .memory 排名算出来，不能复用 CPU 第一名。
    ///
    /// 新参数都有默认值，0.4 之前的 evaluate(cpu:memory:diskUsed:at:) 调用仍可编译、仍会触发，
    /// 只是 culprit 为 nil。
    public func evaluate(
        cpu: Double,
        memory: Double,
        diskUsed: Double,
        topCPU: ProcessAttribution? = nil,
        topMemory: ProcessAttribution? = nil,
        at date: Date = Date()
    ) -> AlertEvent? {
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
                    consecutive: count,
                    culprit: culprit(for: kind, topCPU: topCPU, topMemory: topMemory)
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

    private func culprit(
        for kind: AlertKind,
        topCPU: ProcessAttribution?,
        topMemory: ProcessAttribution?
    ) -> ProcessAttribution? {
        switch kind {
        case .cpu: return topCPU
        case .memory: return topMemory
        case .disk: return nil
        }
    }
}

/// 告警通知的文案格式化。纯函数，便于单测；也把「有/无 culprit」的分支从 AppDelegate 里挪出来。
public enum AlertNotificationText {
    /// 有 culprit：值 + 进程名；无 culprit：沿用旧 alertBody 模板（含「已连续超过阈值」）。
    public static func body(for event: AlertEvent, language: ResolvedLanguage? = nil) -> String {
        if let culprit = event.culprit, !culprit.name.isEmpty {
            let template = L10n.string(.alertBodyWithProcess, lang: language)
            return String(format: template, PercentFormat.percent(event.value), culprit.name)
        }
        // 旧文案：与 0.4 之前完全一致地走 .alertBody 模板（模板第一个 %@ 收已格式化的百分比字符串）。
        let template = L10n.string(.alertBody, lang: language)
        return String(format: template, PercentFormat.percent(event.value))
    }

    /// culprit 的大白话解释第一句，截到 60 字；没有 culprit 或解释为空时返回 nil（调用方不设 subtitle）。
    public static func subtitle(for event: AlertEvent, language: ResolvedLanguage? = nil) -> String? {
        guard let culprit = event.culprit, !culprit.name.isEmpty else { return nil }
        let lang = language ?? L10n.shared.resolvedLanguage
        let summary = ProcessGlossary.explain(name: culprit.name, language: lang).summary
        let first = firstSentence(of: summary).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !first.isEmpty else { return nil }
        return truncated(first, limit: 60)
    }

    /// 取第一句：中文按句末标点，英文按句末句点（句点后必须跟空白或结束，避免把 Node.js 截断）。
    static func firstSentence(of text: String) -> String {
        let characters = Array(text)
        for index in characters.indices {
            let character = characters[index]
            if "。！？!?".contains(character) {
                return String(characters[...index])
            }
            if character == "." {
                let next = index + 1
                if next >= characters.count || characters[next] == " " || characters[next] == "\n" {
                    return String(characters[...index])
                }
            }
        }
        return text
    }

    /// 超过 limit 时截到 limit 个字符（含省略号），否则原样返回。
    static func truncated(_ text: String, limit: Int) -> String {
        guard limit > 0, text.count > limit else { return text }
        return String(text.prefix(limit - 1)) + "…"
    }
}
