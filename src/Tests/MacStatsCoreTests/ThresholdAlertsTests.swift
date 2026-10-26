import XCTest
@testable import MacStatsCore

final class ThresholdAlertsTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_790_000_000)

    func testFiresOnlyAfterConsecutiveBreaches() {
        let evaluator = ThresholdAlertEvaluator(thresholds: AlertThresholds(consecutive: 3))
        XCTAssertNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base))
        XCTAssertNil(evaluator.evaluate(cpu: 0.96, memory: 0.1, diskUsed: 0.1, at: base.addingTimeInterval(1)))
        let event = evaluator.evaluate(cpu: 0.97, memory: 0.1, diskUsed: 0.1, at: base.addingTimeInterval(2))
        XCTAssertEqual(event?.kind, .cpu)
        XCTAssertEqual(event?.consecutive, 3)
        XCTAssertEqual(event?.threshold ?? 0, 0.90, accuracy: 0.0001)
    }

    func testLowSampleResetsStreak() {
        let evaluator = ThresholdAlertEvaluator(thresholds: AlertThresholds(consecutive: 3))
        _ = evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base)
        _ = evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base.addingTimeInterval(1))
        XCTAssertNil(evaluator.evaluate(cpu: 0.10, memory: 0.1, diskUsed: 0.1, at: base.addingTimeInterval(2)))
        XCTAssertNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base.addingTimeInterval(3)))
        XCTAssertNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base.addingTimeInterval(4)))
        XCTAssertNotNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base.addingTimeInterval(5)))
    }

    func testCooldownSuppressesRepeatNotifications() {
        let evaluator = ThresholdAlertEvaluator(thresholds: AlertThresholds(consecutive: 1, cooldown: 600))
        XCTAssertNotNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base))
        XCTAssertNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base.addingTimeInterval(60)))
        XCTAssertNotNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base.addingTimeInterval(601)))
    }

    func testMemoryAndDiskUseTheirOwnThresholds() {
        let evaluator = ThresholdAlertEvaluator(thresholds: AlertThresholds(consecutive: 1))
        XCTAssertEqual(evaluator.evaluate(cpu: 0.1, memory: 0.86, diskUsed: 0.1, at: base)?.kind, .memory)
        XCTAssertEqual(evaluator.evaluate(cpu: 0.1, memory: 0.1, diskUsed: 0.95, at: base.addingTimeInterval(1))?.kind, .disk)
    }

    func testResetClearsStreaks() {
        let evaluator = ThresholdAlertEvaluator(thresholds: AlertThresholds(consecutive: 2))
        _ = evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base)
        evaluator.reset()
        XCTAssertNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base.addingTimeInterval(1)))
        XCTAssertNotNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base.addingTimeInterval(2)))
    }

    // MARK: - culprit 归属

    private let cpuCulprit = ProcessAttribution(name: "Xcode", cpu: 0.82, memory: 2_147_483_648)
    private let memoryCulprit = ProcessAttribution(name: "Safari", cpu: 0.05, memory: 8_589_934_592)

    func testCPUEventCarriesTopCPUCulprit() {
        let evaluator = ThresholdAlertEvaluator(thresholds: AlertThresholds(consecutive: 1))
        let event = evaluator.evaluate(
            cpu: 0.95, memory: 0.1, diskUsed: 0.1,
            topCPU: cpuCulprit, topMemory: memoryCulprit,
            at: base
        )
        XCTAssertEqual(event?.kind, .cpu)
        XCTAssertEqual(event?.culprit, cpuCulprit, "CPU 事件必须带 top CPU 进程，不能带内存第一名")
    }

    func testMemoryEventCarriesTopMemoryCulprit() {
        let evaluator = ThresholdAlertEvaluator(thresholds: AlertThresholds(consecutive: 1))
        let event = evaluator.evaluate(
            cpu: 0.1, memory: 0.90, diskUsed: 0.1,
            topCPU: cpuCulprit, topMemory: memoryCulprit,
            at: base
        )
        XCTAssertEqual(event?.kind, .memory)
        XCTAssertEqual(event?.culprit, memoryCulprit, "内存事件必须带内存第一名，不能复用 CPU 元凶")
        XCTAssertNotEqual(event?.culprit, cpuCulprit)
    }

    /// 接线场景：同一批进程里，CPU 事件拿 CPU 第一名、内存事件拿内存第一名，不能互相顶替。
    func testCulpritsComeFromTheirOwnRankingInSameSample() {
        let processes = [
            ProcessStatus(pid: 1, name: "CPUHog", cpu: 1.50, memory: 50_000_000, energyWatts: 0),
            ProcessStatus(pid: 2, name: "MemoryHog", cpu: 0.05, memory: 8_589_934_592, energyWatts: 0)
        ]
        let topCPU = ProcessRanking.attributions(from: processes, limit: 1, by: .cpu).first
        let topMemory = ProcessRanking.attributions(from: processes, limit: 1, by: .memory).first
        XCTAssertEqual(topCPU?.name, "CPUHog")
        XCTAssertEqual(topMemory?.name, "MemoryHog")

        let cpuEvaluator = ThresholdAlertEvaluator(thresholds: AlertThresholds(consecutive: 1))
        let cpuEvent = cpuEvaluator.evaluate(
            cpu: 0.95, memory: 0.1, diskUsed: 0.1,
            topCPU: topCPU, topMemory: topMemory, at: base
        )
        XCTAssertEqual(cpuEvent?.culprit?.name, "CPUHog")

        let memoryEvaluator = ThresholdAlertEvaluator(thresholds: AlertThresholds(consecutive: 1))
        let memoryEvent = memoryEvaluator.evaluate(
            cpu: 0.1, memory: 0.90, diskUsed: 0.1,
            topCPU: topCPU, topMemory: topMemory, at: base
        )
        XCTAssertEqual(memoryEvent?.culprit?.name, "MemoryHog")
    }

    func testDiskEventHasNoCulprit() {
        let evaluator = ThresholdAlertEvaluator(thresholds: AlertThresholds(consecutive: 1))
        let event = evaluator.evaluate(
            cpu: 0.1, memory: 0.1, diskUsed: 0.95,
            topCPU: cpuCulprit, topMemory: memoryCulprit,
            at: base
        )
        XCTAssertEqual(event?.kind, .disk)
        XCTAssertNil(event?.culprit, "磁盘事件不挂进程归因")
    }

    /// 0.4 之前的旧调用（不传 topCPU/topMemory）仍可编译、仍会触发，只是没有 culprit。
    func testLegacyCallWithoutCulpritsStillFires() {
        let evaluator = ThresholdAlertEvaluator(thresholds: AlertThresholds(consecutive: 3))
        XCTAssertNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base))
        XCTAssertNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base.addingTimeInterval(1)))
        let event = evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, at: base.addingTimeInterval(2))
        XCTAssertEqual(event?.kind, .cpu)
        XCTAssertEqual(event?.consecutive, 3)
        XCTAssertNil(event?.culprit)
    }

    /// 带 culprit 时连续 3 次与 10 分钟冷却逻辑保持不变。
    func testConsecutiveAndCooldownUnchangedWithCulprits() {
        let evaluator = ThresholdAlertEvaluator(thresholds: AlertThresholds(consecutive: 3, cooldown: 600))
        XCTAssertNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, topCPU: cpuCulprit, at: base))
        XCTAssertNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, topCPU: cpuCulprit, at: base.addingTimeInterval(1)))
        let first = evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, topCPU: cpuCulprit, at: base.addingTimeInterval(2))
        XCTAssertEqual(first?.consecutive, 3)
        XCTAssertEqual(first?.culprit, cpuCulprit)

        // 冷却期内继续超阈值：不重复通知（streak 继续累计，行为与 0.4 之前一致）。
        XCTAssertNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, topCPU: cpuCulprit, at: base.addingTimeInterval(60)))
        XCTAssertNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, topCPU: cpuCulprit, at: base.addingTimeInterval(300)))

        // 首次通知发生在 base+2；冷却 600 秒后（base+602）下一次超阈值立即再通知。
        XCTAssertNil(evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, topCPU: cpuCulprit, at: base.addingTimeInterval(601)))
        let second = evaluator.evaluate(cpu: 0.95, memory: 0.1, diskUsed: 0.1, topCPU: cpuCulprit, at: base.addingTimeInterval(602))
        XCTAssertEqual(second?.culprit, cpuCulprit)
        XCTAssertEqual(second?.consecutive, 4, "冷却期内的采样继续累计 streak，与旧行为一致")
    }

    // MARK: - 通知文案

    func testBodyWithCulpritUsesValueAndProcessName() {
        let event = AlertEvent(
            kind: .cpu, value: 0.92, threshold: 0.90, consecutive: 3, culprit: cpuCulprit
        )
        let body = AlertNotificationText.body(for: event, language: .zhHans)
        XCTAssertEqual(body, "92% · Xcode")
        XCTAssertFalse(body.contains("已连续超过阈值"), "有 culprit 时用「值 + 进程名」，不再只报数值")

        let english = AlertNotificationText.body(for: event, language: .en)
        XCTAssertEqual(english, "92% · Xcode")
    }

    func testBodyWithoutCulpritKeepsLegacyTemplate() {
        let event = AlertEvent(kind: .cpu, value: 0.92, threshold: 0.90, consecutive: 3)
        let zh = AlertNotificationText.body(for: event, language: .zhHans)
        XCTAssertTrue(zh.contains("92%"), "旧文案仍包含百分比数值")
        XCTAssertTrue(zh.contains("已连续超过阈值"), "旧文案仍保留原文案")
        XCTAssertFalse(zh.contains("·"), "没有 culprit 时不拼接进程名")

        let en = AlertNotificationText.body(for: event, language: .en)
        XCTAssertTrue(en.contains("92%"))
        XCTAssertTrue(en.contains("above the threshold"))
    }

    /// 进程名为空时不拼出一个只有分隔符的正文，回退旧文案。
    func testBodyIgnoresEmptyCulpritName() {
        let event = AlertEvent(
            kind: .cpu, value: 0.92, threshold: 0.90, consecutive: 3,
            culprit: ProcessAttribution(name: "", cpu: 0.9, memory: 0)
        )
        let body = AlertNotificationText.body(for: event, language: .zhHans)
        XCTAssertTrue(body.contains("已连续超过阈值"))
        XCTAssertFalse(body.contains("·"))
    }

    func testSubtitleUsesFirstSentenceOfGlossary() {
        let event = AlertEvent(
            kind: .cpu, value: 0.92, threshold: 0.90, consecutive: 3,
            culprit: ProcessAttribution(name: "node", cpu: 0.9, memory: 0)
        )
        let subtitle = AlertNotificationText.subtitle(for: event, language: .zhHans)
        XCTAssertEqual(subtitle, "用 Node.js 跑的后台程序。", "取解释的第一句，且不把 Node.js 的句点当句末")
        XCTAssertLessThanOrEqual(subtitle?.count ?? 0, 60)
    }

    func testSubtitleTruncatesTo60Characters() {
        let longName = String(repeating: "x", count: 80)
        let event = AlertEvent(
            kind: .cpu, value: 0.92, threshold: 0.90, consecutive: 3,
            culprit: ProcessAttribution(name: longName, cpu: 0.9, memory: 0)
        )
        let subtitle = AlertNotificationText.subtitle(for: event, language: .zhHans)
        XCTAssertEqual(subtitle?.count, 60, "第一句超过 60 字时截到 60 字")
        XCTAssertTrue(subtitle?.hasSuffix("…") ?? false)
    }

    func testSubtitleNilWithoutCulprit() {
        let event = AlertEvent(kind: .disk, value: 0.95, threshold: 0.90, consecutive: 3)
        XCTAssertNil(AlertNotificationText.subtitle(for: event, language: .zhHans))
        XCTAssertNil(AlertNotificationText.subtitle(for: event, language: .en))
    }

    func testSubtitleNilForEmptyCulpritName() {
        let event = AlertEvent(
            kind: .cpu, value: 0.92, threshold: 0.90, consecutive: 3,
            culprit: ProcessAttribution(name: "", cpu: 0.9, memory: 0)
        )
        XCTAssertNil(AlertNotificationText.subtitle(for: event, language: .zhHans))
    }

    func testFirstSentenceIgnoresDotsInsideWords() {
        XCTAssertEqual(
            AlertNotificationText.firstSentence(of: "Node.js runs a dev server. It has no window."),
            "Node.js runs a dev server."
        )
        XCTAssertEqual(
            AlertNotificationText.firstSentence(of: "用 Node.js 跑的后台程序。很多工具由它启动。"),
            "用 Node.js 跑的后台程序。"
        )
        XCTAssertEqual(
            AlertNotificationText.firstSentence(of: "no terminator"),
            "no terminator"
        )
    }
}
