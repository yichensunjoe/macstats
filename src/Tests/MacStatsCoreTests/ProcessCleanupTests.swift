import XCTest
@testable import MacStatsCore

final class ProcessCleanupTests: XCTestCase {
    private let rules = CleanupRules()
    private let currentUID = getuid()

    private func facts(
        name: String = "node",
        path: String = "/opt/homebrew/bin/node",
        uid: UInt32? = nil,
        terminal: Bool = false,
        zombie: Bool = false,
        age: TimeInterval = 3_600,
        idle: TimeInterval = 1_800,
        cpu: Double = 0,
        lifetimeCPU: Double = 0.0005,
        foreground: Bool = false,
        liveParent: Bool = false,
        withChildren: Bool = false
    ) -> ProcessFacts {
        ProcessFacts(
            process: LiveProcess(
                pid: 4_242,
                name: name,
                path: path,
                uid: uid ?? currentUID,
                hasTerminal: terminal,
                isZombie: zombie,
                startedAt: Date(timeIntervalSince1970: 1_700_000_000),
                cpuTimeNanos: UInt64(age * lifetimeCPU * 1_000_000_000),
                memoryBytes: 320 * 1_048_576
            ),
            age: age,
            idle: idle,
            cpu: cpu,
            lifetimeCPU: lifetimeCPU,
            isForeground: foreground,
            hasLiveParent: liveParent,
            hasChildren: withChildren
        )
    }

    private func skip(_ facts: ProcessFacts, rules: CleanupRules? = nil) -> CleanupSkipReason? {
        (rules ?? self.rules).skipReason(for: facts, currentUID: currentUID, selfPID: 9_999)
    }

    // MARK: - 正向

    func testIdleBackgroundProcessQualifies() {
        XCTAssertNil(skip(facts()))
    }

    /// 刚启动的进程不碰：可能是用户刚打开的东西。
    func testYoungProcessIsSkipped() {
        XCTAssertEqual(skip(facts(age: 60, idle: 60)), .tooYoung)
    }

    func testBusyProcessIsSkipped() {
        XCTAssertEqual(skip(facts(cpu: 0.4)), .busy)
    }

    /// 刚才还在干活、只是这一刻 CPU 为 0 的，不算闲置。
    func testRecentlyActiveProcessIsSkipped() {
        XCTAssertEqual(skip(facts(idle: 120)), .recentlyActive)
    }

    // MARK: - 保护规则

    func testSystemPathIsProtected() {
        XCTAssertEqual(skip(facts(name: "mdworker_shared", path: "/usr/libexec/mdworker_shared")), .systemProcess)
        XCTAssertEqual(skip(facts(name: "foo", path: "/System/Library/Frameworks/foo.framework/foo")), .systemProcess)
        XCTAssertEqual(skip(facts(name: "bar", path: "/Library/PrivilegedHelperTools/bar")), .systemProcess)
    }

    func testAppBundleIsProtected() {
        XCTAssertEqual(
            skip(facts(name: "Safari", path: "/Applications/Safari.app/Contents/MacOS/Safari")),
            .appBundle
        )
        // App 的 helper 也算 App 的一部分。
        XCTAssertEqual(
            skip(facts(name: "Google Chrome Helper", path: "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper")),
            .appBundle
        )
    }

    func testOtherUserProcessIsProtected() {
        XCTAssertEqual(skip(facts(uid: 0)), .notCurrentUser)
        XCTAssertEqual(skip(facts(uid: 501 &+ 1)), .notCurrentUser)
    }

    func testTerminalProcessIsProtected() {
        XCTAssertEqual(skip(facts(terminal: true)), .terminal)
    }

    func testForegroundProcessIsProtected() {
        XCTAssertEqual(skip(facts(foreground: true)), .foreground)
    }

    func testZombieIsProtected() {
        XCTAssertEqual(skip(facts(zombie: true)), .zombie)
    }

    /// 父进程还在的，是别人正在用的子进程（例如编辑器拉起的 MCP server），不是遗留孤儿。
    func testProcessWithLiveParentIsSkipped() {
        XCTAssertEqual(skip(facts(liveParent: true)), .hasLiveParent)
    }

    /// 自己还有子进程在跑（例如 npm run dev 拉着 vite），不杀。
    func testProcessWithChildrenIsSkipped() {
        XCTAssertEqual(skip(facts(withChildren: true)), .hasChildren)
    }

    func testSelfIsProtected() {
        let selfFacts = facts()
        XCTAssertEqual(
            rules.skipReason(for: selfFacts, currentUID: currentUID, selfPID: 4_242),
            .selfProcess
        )
    }

    func testKnownSystemNamesAreProtectedEvenOutsideSystemPaths() {
        XCTAssertEqual(skip(facts(name: "WindowServer", path: "/somewhere/WindowServer")), .systemProcess)
        XCTAssertEqual(skip(facts(name: "Dock", path: "/somewhere/Dock")), .systemProcess)
    }

    /// 路径读不到就不动：宁可漏清理，也不误杀。
    func testProcessWithoutPathIsProtected() {
        XCTAssertEqual(skip(facts(path: "")), .systemProcess)
    }

    // MARK: - 白名单

    func testWhitelistMatchesCaseInsensitively() {
        var custom = rules
        custom.whitelist = ["Node"]
        XCTAssertTrue(custom.isWhitelisted("node"))
        XCTAssertTrue(custom.isWhitelisted("NODE"))
        XCTAssertFalse(custom.isWhitelisted("nodejs"))
        XCTAssertEqual(skip(facts(), rules: custom), .whitelisted)
    }

    /// Node 起的守护进程会把 argv[0] 改成自己的名字，列表里两个名字都给出来。
    func testCandidateDisplayNameIncludesRenamedTitle() {
        let candidate = CleanupCandidate(
            pid: 1, name: "node", title: "cliguard-daemon", path: "/opt/homebrew/bin/node",
            memoryBytes: 1, cpu: 0, idleSeconds: 1, ageSeconds: 1
        )
        XCTAssertEqual(candidate.displayName, "node · cliguard-daemon")
        let same = CleanupCandidate(
            pid: 2, name: "node", title: "node", path: "/opt/homebrew/bin/node",
            memoryBytes: 1, cpu: 0, idleSeconds: 1, ageSeconds: 1
        )
        XCTAssertEqual(same.displayName, "node")
    }

    /// 白名单菜单不能因为「进程刚启动」就把它藏起来：这里只看身份，不看闲置。
    func testProtectableNamesIgnoresAgeAndIdle() {
        let cleaner = ProcessCleaner()
        let young = LiveProcess(
            pid: 4_321, name: "node", path: "\(NSHomeDirectory())/bin/node", uid: currentUID,
            startedAt: Date(), memoryBytes: 1_000
        )
        let system = LiveProcess(pid: 4_322, name: "helper", path: "/System/Library/helper", startedAt: Date())
        let app = LiveProcess(pid: 4_323, name: "Safari", path: "/Applications/Safari.app/Contents/MacOS/Safari", startedAt: Date())

        let names = cleaner.protectableNames(in: [young, system, app], foregroundPID: nil, titleProvider: { _ in nil })
        XCTAssertEqual(names, ["node"])
    }

    /// argv[0] 改名过的进程按改名显示（`ps` 里看到的就是它）。
    /// 名字来源可注入，所以这条断言不读本机进程表。
    func testProtectableNamesUsesInjectedTitle() {
        let cleaner = ProcessCleaner()
        let daemon = LiveProcess(
            pid: 4_351, name: "node", path: "\(NSHomeDirectory())/bin/node", uid: currentUID,
            startedAt: Date(), memoryBytes: 1_000
        )
        let names = cleaner.protectableNames(
            in: [daemon], foregroundPID: nil, titleProvider: { _ in "cliguard-daemon" }
        )
        // 菜单版显示 argv[0] 本身（`ps` 里看到的就是它），不是清理列表里的「名字 · 改名」拼法。
        XCTAssertEqual(names, ["cliguard-daemon"])
    }

    /// 已勾选的进程要带着对勾留在列表里，否则勾上就再也没法取消保护。
    func testProtectableNamesKeepsWhitelistedProcesses() {
        let cleaner = ProcessCleaner()
        cleaner.updateWhitelist(["node"])
        let node = LiveProcess(
            pid: 4_331, name: "node", path: "\(NSHomeDirectory())/bin/node", uid: currentUID,
            startedAt: Date(), memoryBytes: 1_000
        )
        XCTAssertEqual(cleaner.protectableNames(in: [node], foregroundPID: nil, titleProvider: { _ in nil }), ["node"])
        XCTAssertTrue(cleaner.rules.isWhitelisted("node"))
    }

    /// 设置里的名单与清理候选共用身份筛查：系统进程、App 不列，白名单里的仍列出。
    func testProtectableProcessesFilterSystemAndKeepWhitelisted() {
        let cleaner = ProcessCleaner()
        cleaner.updateWhitelist(["node"])
        let node = LiveProcess(
            pid: 4_341, name: "node", path: "\(NSHomeDirectory())/bin/node", uid: currentUID,
            startedAt: Date(), memoryBytes: 1_000
        )
        let system = LiveProcess(pid: 4_342, name: "mdworker", path: "/System/Library/mdworker", startedAt: Date())
        let app = LiveProcess(pid: 4_343, name: "Safari", path: "/Applications/Safari.app/Contents/MacOS/Safari", startedAt: Date())
        let foreground = LiveProcess(
            pid: 4_344, name: "claude", path: "\(NSHomeDirectory())/bin/claude", uid: currentUID,
            startedAt: Date(), memoryBytes: 2_000
        )

        let kept = cleaner.protectableProcesses(in: [node, system, app, foreground], foregroundPID: 4_344)
        XCTAssertEqual(kept.map(\.pid), [4_341])
    }

    // MARK: - 真实进程表

    func testInventoryContainsSelf() {
        let processes = ProcessInventory.scan()
        XCTAssertFalse(processes.isEmpty)
        let selfProcess = processes.first { $0.pid == getpid() }
        XCTAssertNotNil(selfProcess)
        XCTAssertFalse(selfProcess?.path.isEmpty ?? true)
        XCTAssertEqual(selfProcess?.uid, currentUID)
    }

    /// 实机评估的结构性保证：系统路径、App、自己都不会出现在候选里。
    func testLiveEvaluationOnlyReturnsSafeCandidates() {
        let plan = ProcessCleaner().evaluate()
        XCTAssertFalse(plan.candidates.contains { $0.path.hasPrefix("/System/") })
        XCTAssertFalse(plan.candidates.contains { $0.path.hasPrefix("/usr/") })
        XCTAssertFalse(plan.candidates.contains { $0.path.contains(".app/") })
        XCTAssertFalse(plan.candidates.contains { $0.pid == getpid() })
        XCTAssertTrue(plan.candidates.allSatisfy { $0.idleSeconds >= rules.minimumIdle })
        XCTAssertTrue(plan.candidates.count <= rules.maxProcesses)
        XCTAssertEqual(plan.estimatedBytes, plan.candidates.reduce(0) { $0 &+ $1.memoryBytes })
    }

    // MARK: - 终止

    private func spawn(_ executable: String, _ arguments: [String]) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        return process
    }

    private func candidate(_ pid: Int32, path: String = "/bin/sleep", memory: UInt64 = 4_096) -> CleanupCandidate {
        CleanupCandidate(
            pid: pid, name: (path as NSString).lastPathComponent, path: path, memoryBytes: memory,
            cpu: 0, idleSeconds: 900, ageSeconds: 900
        )
    }

    /// 正常退出的进程：报告终止、返回释放量。
    func testTerminateStopsNormalProcess() throws {
        let process = try spawn("/bin/sleep", ["30"])
        defer { if process.isRunning { process.terminate() } }
        let pid = process.processIdentifier

        let result = ProcessCleaner().terminate([candidate(pid)], grace: 2)
        XCTAssertEqual(result.terminated.map(\.pid), [pid])
        XCTAssertTrue(result.survived.isEmpty)
        XCTAssertEqual(result.freedBytes, 4_096)
        XCTAssertFalse(ProcessInventory.isAlive(pid))
        process.waitUntilExit()
    }

    /// 忽略 SIGTERM 的进程：如实报告「仍在跑」，绝不升级成 SIGKILL。
    func testTerminateDoesNotEscalateToSigkill() throws {
        let process = try spawn("/bin/bash", ["-c", "trap '' TERM; sleep 30"])
        let pid = process.processIdentifier
        defer { kill(pid, SIGKILL) }
        usleep(300_000)

        let result = ProcessCleaner().terminate([candidate(pid, path: "/bin/bash")], grace: 0.5)
        XCTAssertTrue(result.terminated.isEmpty)
        XCTAssertEqual(result.survived.map(\.pid), [pid])
        XCTAssertEqual(result.freedBytes, 0)
        XCTAssertTrue(ProcessInventory.isAlive(pid))
    }

    func testRepeatedObservationDoesNotMarkActiveProcessIdle() {
        let cleaner = ProcessCleaner()
        let start = Date()
        cleaner.observe(now: start)
        // 同一时刻再扫一次：计数器没变，CPU 记为 0，但 lastActiveAt 仍是首次观测时间。
        let plan = cleaner.evaluate(now: start.addingTimeInterval(1))
        XCTAssertFalse(plan.candidates.contains { $0.pid == getpid() })
    }

    /// PID 复用防御：若启动时间或路径与候选不符，绝不发送信号。
    func testTerminateRejectsMismatchedStartTimeOrPath() throws {
        let process = try spawn("/bin/sleep", ["30"])
        defer { if process.isRunning { process.terminate() } }
        let pid = process.processIdentifier

        // 1. 路径不匹配（提供 startedAt）
        let wrongPath = CleanupCandidate(
            pid: pid, name: "sleep", path: "/bin/nonexistent", startedAt: Date(),
            memoryBytes: 4096, cpu: 0, idleSeconds: 900, ageSeconds: 900
        )
        let resWrongPath = ProcessCleaner().terminate([wrongPath], grace: 0.1)
        XCTAssertTrue(resWrongPath.terminated.isEmpty)
        XCTAssertTrue(resWrongPath.survived.isEmpty)
        XCTAssertTrue(ProcessInventory.isAlive(pid))

        // 2. 路径不匹配且未传 startedAt（验证路径核验不依赖于 startedAt 是否存在）
        let wrongPathNoDate = CleanupCandidate(
            pid: pid, name: "sleep", path: "/bin/nonexistent", startedAt: nil,
            memoryBytes: 4096, cpu: 0, idleSeconds: 900, ageSeconds: 900
        )
        let resWrongPathNoDate = ProcessCleaner().terminate([wrongPathNoDate], grace: 0.1)
        XCTAssertTrue(resWrongPathNoDate.terminated.isEmpty)
        XCTAssertTrue(resWrongPathNoDate.survived.isEmpty)
        XCTAssertTrue(ProcessInventory.isAlive(pid))

        // 3. 缺少核验锚点（既无路径也无启动时间）
        let emptyAnchor = CleanupCandidate(
            pid: pid, name: "sleep", path: "", startedAt: nil,
            memoryBytes: 4096, cpu: 0, idleSeconds: 900, ageSeconds: 900
        )
        let resEmptyAnchor = ProcessCleaner().terminate([emptyAnchor], grace: 0.1)
        XCTAssertTrue(resEmptyAnchor.terminated.isEmpty)
        XCTAssertTrue(resEmptyAnchor.survived.isEmpty)
        XCTAssertTrue(ProcessInventory.isAlive(pid))

        // 4. 启动时间不匹配（模拟 PID 被新进程复用）
        let wrongTime = CleanupCandidate(
            pid: pid, name: "sleep", path: "/bin/sleep", startedAt: Date(timeIntervalSince1970: 1000),
            memoryBytes: 4096, cpu: 0, idleSeconds: 900, ageSeconds: 900
        )
        let resWrongTime = ProcessCleaner().terminate([wrongTime], grace: 0.1)
        XCTAssertTrue(resWrongTime.terminated.isEmpty)
        XCTAssertTrue(resWrongTime.survived.isEmpty)
        XCTAssertTrue(ProcessInventory.isAlive(pid))
    }

    /// 测试传入已采集的进程列表更新观测（解耦后台采集与主线程状态管理）
    func testObserveWithPreScannedProcesses() {
        let cleaner = ProcessCleaner()
        let now = Date()
        let proc = LiveProcess(
            pid: 12345, parentPID: 1, name: "testProc", path: "/usr/bin/testProc",
            uid: getuid(), hasTerminal: false, isZombie: false, startedAt: now,
            cpuTimeNanos: 50_000_000, memoryBytes: 10_000_000
        )
        cleaner.observe(processes: [proc], now: now)
        XCTAssertEqual(cleaner.lastScanAt, now)
    }
}
