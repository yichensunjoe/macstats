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
}
