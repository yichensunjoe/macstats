import XCTest
@testable import MacStatsCore

/// 「点进程退出 / 强制退出」的安全边界：规则判定不碰硬件，
/// 发信号的部分用自己拉起的子进程验证，绝不拿真实应用当靶子。
final class ProcessTerminationTests: XCTestCase {
    private let policy = TerminationPolicy()
    /// 系统路径在默认规则里受保护，测信号链路时显式放开。
    private let permissive = TerminationPolicy(protectedPathPrefixes: [], protectedNames: [])

    private func facts(
        pid: Int32 = 4242,
        name: String = "node",
        path: String = "/Users/me/project/node",
        uid: UInt32? = nil,
        zombie: Bool = false
    ) -> TerminationFacts {
        TerminationFacts(
            pid: pid,
            name: name,
            path: path,
            uid: uid ?? getuid(),
            isZombie: zombie
        )
    }

    // MARK: - 规则

    func testRefusesSelf() {
        XCTAssertEqual(
            policy.refusal(
                for: facts(pid: getpid(), name: "MacStats", path: "/Applications/MacStats.app/Contents/MacOS/MacStats"),
                currentUID: getuid(),
                selfPID: getpid()
            ),
            .selfProcess
        )
    }

    func testRefusesOtherUsersProcesses() {
        XCTAssertEqual(
            policy.refusal(for: facts(uid: getuid() + 1), currentUID: getuid(), selfPID: 999),
            .notCurrentUser
        )
    }

    func testRefusesSystemProcesses() {
        XCTAssertEqual(
            policy.refusal(for: facts(name: "WindowServer", path: "/System/Library/PrivateFrameworks/SkyLight"), currentUID: getuid(), selfPID: 999),
            .systemProcess
        )
        XCTAssertEqual(
            policy.refusal(for: facts(name: "customd", path: "/usr/libexec/customd"), currentUID: getuid(), selfPID: 999),
            .systemProcess
        )
        XCTAssertEqual(
            policy.refusal(for: facts(name: "launchd", path: "/sbin/launchd"), currentUID: getuid(), selfPID: 999),
            .systemProcess
        )
    }

    func testZombieCountsAsGone() {
        XCTAssertEqual(
            policy.refusal(for: facts(zombie: true), currentUID: getuid(), selfPID: 999),
            .notFound
        )
    }

    /// 与「一键清理」的差别：用户点名的 App 与终端命令允许结束，
    /// 否则「少开活动监视器」这件事就做不到。
    func testAppsAndTerminalCommandsAreAllowed() {
        XCTAssertNil(
            policy.refusal(for: facts(name: "Slack", path: "/Applications/Slack.app/Contents/MacOS/Slack"), currentUID: getuid(), selfPID: 999)
        )
        XCTAssertNil(
            policy.refusal(for: facts(name: "python3", path: "/Users/me/.venv/bin/python3"), currentUID: getuid(), selfPID: 999)
        )
    }

    // MARK: - 身份核对

    func testRealSelfIsRefusedWithoutSignaling() throws {
        let detail = try XCTUnwrap(ProcessInventory.detail(pid: getpid()))
        let outcome = ProcessTerminator.terminate(detail.target, by: .force)
        XCTAssertEqual(outcome.refusal, .selfProcess)
        XCTAssertFalse(outcome.exited)
        XCTAssertTrue(ProcessInventory.isAlive(getpid()))
    }

    func testTargetForSelfFailsWithRefusal() {
        if case .success = ProcessTerminator.target(pid: getpid()) {
            XCTFail("Self must never be a valid termination target")
        }
    }

    func testWrongIdentityIsRefusedBeforeSignaling() throws {
        let child = try spawnSleep()
        defer { if child.isRunning { child.terminate() } }
        let detail = try XCTUnwrap(ProcessInventory.detail(pid: child.processIdentifier))

        // PID 对、路径不对：模拟 PID 被复用，必须当成「已经退出」拒绝。
        let wrong = TerminateTarget(
            pid: detail.pid,
            name: detail.name,
            path: "/tmp/definitely-not-the-same-binary",
            startedAt: detail.startedAt
        )
        let outcome = ProcessTerminator.terminate(wrong, by: .force, policy: permissive)
        XCTAssertEqual(outcome.refusal, .notFound)
        XCTAssertTrue(ProcessInventory.isAlive(detail.pid))
    }

    // MARK: - 信号

    func testQuitTerminatesSpawnedProcess() throws {
        let child = try spawnSleep()
        defer { if child.isRunning { child.terminate() } }
        let detail = try XCTUnwrap(ProcessInventory.detail(pid: child.processIdentifier))

        let outcome = ProcessTerminator.terminate(detail.target, by: .quit, grace: 2, policy: permissive)
        XCTAssertNil(outcome.refusal)
        XCTAssertTrue(outcome.isSuccess)
        XCTAssertFalse(ProcessInventory.isAlive(detail.pid))
    }

    func testForceQuitKillsProcessThatIgnoresSigterm() throws {
        let child = try spawnIgnoringSigterm()
        defer {
            kill(child.processIdentifier, SIGKILL)
            _ = try? child.waitUntilExit()
        }
        // 给 shell 一点时间装好 trap。
        Thread.sleep(forTimeInterval: 0.4)
        let detail = try XCTUnwrap(ProcessInventory.detail(pid: child.processIdentifier))

        let quit = ProcessTerminator.terminate(detail.target, by: .quit, grace: 0.6, policy: permissive)
        XCTAssertNil(quit.refusal)
        XCTAssertTrue(ProcessInventory.isAlive(detail.pid), "忽略了 SIGTERM 的进程应该还活着")

        let force = ProcessTerminator.terminate(detail.target, by: .force, grace: 1.5, policy: permissive)
        XCTAssertTrue(force.isSuccess)
        XCTAssertFalse(ProcessInventory.isAlive(detail.pid))
    }

    // MARK: - Helpers

    private func spawnSleep() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]
        try process.run()
        return process
    }

    private func spawnIgnoringSigterm() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "trap '' TERM; while :; do sleep 1; done"]
        try process.run()
        return process
    }
}
