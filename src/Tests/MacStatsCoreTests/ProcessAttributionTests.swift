import XCTest
@testable import MacStatsCore

final class ProcessAttributionTests: XCTestCase {
    // MARK: - JSON 编解码

    func testJSONRoundTripPreservesValues() throws {
        let original = ProcessAttribution(name: "Xcode", cpu: 0.78, memory: 2_147_483_648)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProcessAttribution.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.name, "Xcode")
        XCTAssertEqual(decoded.cpu, 0.78, accuracy: 0.000_000_1)
        XCTAssertEqual(decoded.memory, 2_147_483_648)
    }

    func testJSONRoundTripKeepsOrderOfTopProcesses() throws {
        let original = [
            ProcessAttribution(name: "Xcode", cpu: 0.78, memory: 2_147_483_648),
            ProcessAttribution(name: "WindowServer", cpu: 0.09, memory: 524_288_000),
            ProcessAttribution(name: "kernel_task", cpu: 0.04, memory: 1_073_741_824)
        ]
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([ProcessAttribution].self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.map(\.name), ["Xcode", "WindowServer", "kernel_task"])
    }

    func testJSONUsesOnlyContractKeys() throws {
        let data = try JSONEncoder().encode(ProcessAttribution(name: "node", cpu: 1.5, memory: 1024))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["name", "cpu", "memory"])
    }

    func testDecodesFromExplicitJSONObject() throws {
        let json = #"{"name":"WindowServer","cpu":0.09,"memory":524288000}"#
        let decoded = try JSONDecoder().decode(ProcessAttribution.self, from: Data(json.utf8))
        XCTAssertEqual(decoded, ProcessAttribution(name: "WindowServer", cpu: 0.09, memory: 524_288_000))
    }

    func testLargeMemoryValueRoundTrips() throws {
        let original = ProcessAttribution(name: "big", cpu: 1.0, memory: UInt64.max)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProcessAttribution.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - 负 CPU 归零

    func testNegativeCPUIsClampedToZero() {
        let attribution = ProcessAttribution(name: "stale", cpu: -12.5, memory: 4096)
        XCTAssertEqual(attribution.cpu, 0)
        XCTAssertEqual(attribution.name, "stale")
        XCTAssertEqual(attribution.memory, 4096)
    }

    func testSlightlyNegativeCPUIsClampedToZero() {
        let attribution = ProcessAttribution(name: "jitter", cpu: -0.000_001, memory: 0)
        XCTAssertEqual(attribution.cpu, 0)
    }

    func testNonNegativeCPUIsKept() {
        let attribution = ProcessAttribution(name: "busy", cpu: 1.75, memory: 0)
        XCTAssertEqual(attribution.cpu, 1.75, accuracy: 0.000_000_1)
    }

    func testZeroValuesArePreserved() {
        let attribution = ProcessAttribution(name: "idle", cpu: 0, memory: 0)
        XCTAssertEqual(attribution, ProcessAttribution(name: "idle", cpu: 0, memory: 0))
    }

    // MARK: - 空名字

    func testEmptyNameIsAllowed() throws {
        let attribution = ProcessAttribution(name: "", cpu: 0.5, memory: 1024)
        XCTAssertEqual(attribution.name, "")

        let data = try JSONEncoder().encode(attribution)
        let decoded = try JSONDecoder().decode(ProcessAttribution.self, from: data)
        XCTAssertEqual(decoded, attribution)
        XCTAssertEqual(decoded.name, "")
    }

    // MARK: - Equatable

    func testEquatableComparesAllFields() {
        let base = ProcessAttribution(name: "node", cpu: 0.5, memory: 1024)
        XCTAssertEqual(base, ProcessAttribution(name: "node", cpu: 0.5, memory: 1024))
        XCTAssertNotEqual(base, ProcessAttribution(name: "node2", cpu: 0.5, memory: 1024))
        XCTAssertNotEqual(base, ProcessAttribution(name: "node", cpu: 0.6, memory: 1024))
        XCTAssertNotEqual(base, ProcessAttribution(name: "node", cpu: 0.5, memory: 2048))
    }
}
