import Foundation
import Darwin

/// 进程表里一行原始事实。来源与 `SystemSampler` 相同：`proc_listpids` /
/// `proc_pidinfo` / `proc_pidpath` / `proc_pid_rusage`，不涉及私有框架。
public struct LiveProcess: Sendable, Equatable {
    public var pid: Int32
    /// 父进程；1 表示已经与 launchd 重逢（原来的父进程退出了）。
    public var parentPID: Int32
    public var name: String
    public var path: String
    public var uid: UInt32
    /// 是否挂着控制终端：终端里跑的命令一律不动。
    ///
    /// 依据 `proc_bsdinfo.e_tdev`：真实 tty 是 `0x100000NN`（如 ttys002 = 268435458），
    /// 没有控制终端时内核填 `UINT32_MAX`（实测 Finder / GUI App / 无 tty 的 CLI 都是这个值）。
    public var hasTerminal: Bool
    /// 状态为 Z：进程已退出、只等父进程回收，杀它没有意义。
    public var isZombie: Bool
    public var startedAt: Date
    public var cpuTimeNanos: UInt64
    public var memoryBytes: UInt64

    public init(
        pid: Int32 = 0,
        parentPID: Int32 = 1,
        name: String = "",
        path: String = "",
        uid: UInt32 = 501,
        hasTerminal: Bool = false,
        isZombie: Bool = false,
        startedAt: Date = .distantPast,
        cpuTimeNanos: UInt64 = 0,
        memoryBytes: UInt64 = 0
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.name = name
        self.path = path
        self.uid = uid
        self.hasTerminal = hasTerminal
        self.isZombie = isZombie
        self.startedAt = startedAt
        self.cpuTimeNanos = cpuTimeNanos
        self.memoryBytes = memoryBytes
    }
}

/// 判定一个进程时用到的派生量。全部由 `ProcessCleaner` 算出，规则本身是纯函数。
public struct ProcessFacts: Sendable, Equatable {
    public var process: LiveProcess
    /// 进程已运行时长。
    public var age: TimeInterval
    /// 已闲置时长：自启动从未干活 = 年龄；否则取观测到的最后活跃时间。
    public var idle: TimeInterval
    /// 最近一次采样窗口内的 CPU 占用（单核比例）。
    public var cpu: Double
    /// 生命周期的平均 CPU 占用（累计 CPU / 运行时长）。
    public var lifetimeCPU: Double
    public var isForeground: Bool
    /// 父进程还在运行（ppid 不是 1）：它是某个活着的程序的子进程，不是遗留孤儿。
    public var hasLiveParent: Bool
    /// 自己还有子进程在跑：可能是某个服务 / 构建任务的父进程。
    public var hasChildren: Bool

    public init(
        process: LiveProcess,
        age: TimeInterval,
        idle: TimeInterval,
        cpu: Double,
        lifetimeCPU: Double,
        isForeground: Bool,
        hasLiveParent: Bool = false,
        hasChildren: Bool = false
    ) {
        self.process = process
        self.age = age
        self.idle = idle
        self.cpu = cpu
        self.lifetimeCPU = lifetimeCPU
        self.isForeground = isForeground
        self.hasLiveParent = hasLiveParent
        self.hasChildren = hasChildren
    }
}

/// 进程被排除的原因。保留原因是为了在诊断输出和文档里说清「为什么没动它」。
public enum CleanupSkipReason: String, Sendable, CaseIterable {
    case notCurrentUser
    case selfProcess
    case zombie
    case systemProcess
    case appBundle
    case terminal
    case foreground
    case whitelisted
    case hasLiveParent
    case hasChildren
    case networkActive
    case tooYoung
    case busy
    case recentlyActive
    case lowMemory

    public var displayName: String {
        switch self {
        case .notCurrentUser: "不是当前用户"
        case .selfProcess: "本应用自己"
        case .zombie: "僵尸进程（只能由父进程回收）"
        case .systemProcess: "系统路径或系统进程"
        case .appBundle: "App 或 App 的子进程"
        case .terminal: "挂在终端上"
        case .foreground: "当前前台 App"
        case .whitelisted: "在白名单里"
        case .hasLiveParent: "父进程还在运行（不是遗留孤儿）"
        case .hasChildren: "还有子进程在运行"
        case .networkActive: "持有 TCP/UDP 连接或监听端口"
        case .tooYoung: "刚启动不久"
        case .busy: "仍在占用 CPU"
        case .recentlyActive: "最近有活动"
        case .lowMemory: "内存占用低于过滤阈值"
        }
    }

    public var localizedName: String {
        if L10n.shared.resolvedLanguage == .zhHans {
            return displayName
        }
        switch self {
        case .notCurrentUser: return "Not current user"
        case .selfProcess: return "MacStats itself"
        case .zombie: return "Zombie process"
        case .systemProcess: return "System path or daemon"
        case .appBundle: return "Application bundle process"
        case .terminal: return "Attached to terminal"
        case .foreground: return "Frontmost application"
        case .whitelisted: return "Whitelisted"
        case .hasLiveParent: return "Parent process is still alive"
        case .hasChildren: return "Has running child processes"
        case .networkActive: return "Has active network socket"
        case .tooYoung: return "Recently started"
        case .busy: return "Actively using CPU"
        case .recentlyActive: return "Recently active"
        case .lowMemory: return "Memory below filter threshold"
        }
    }
}

/// 清理规则。默认值刻意保守：只动当前用户、后台、无窗口、无终端、已闲置 10 分钟以上的进程。
public struct CleanupRules: Sendable, Equatable {
    /// 进程至少运行这么久才可能被清理。
    public var minimumAge: TimeInterval
    /// 至少闲置这么久才可能被清理。
    public var minimumIdle: TimeInterval
    /// 最近一个采样窗口的 CPU 占用上限（单核比例）。
    public var maximumCPU: Double
    /// 生命周期平均 CPU 上限：低于它说明它自启动以来基本没干活。
    public var maximumLifetimeCPU: Double
    /// 一次最多清理多少个，避免一口气杀掉一大片。
    public var maxProcesses: Int
    /// 永远不碰的路径前缀。
    public var protectedPathPrefixes: [String]
    /// 永远不碰的进程名（系统界面进程等，路径规则之外的兜底）。
    public var protectedNames: Set<String>
    /// 用户自定义白名单，按名字比较、忽略大小写。
    public var whitelist: Set<String>
    /// 最小常驻内存过滤门槛（低于该大小忽略，0 表示不限制）。
    public var minimumMemoryBytes: UInt64

    public init(
        minimumAge: TimeInterval = 600,
        minimumIdle: TimeInterval = 600,
        maximumCPU: Double = 0.01,
        maximumLifetimeCPU: Double = 0.01,
        maxProcesses: Int = 12,
        minimumMemoryBytes: UInt64 = 0,
        protectedPathPrefixes: [String] = CleanupRules.defaultProtectedPaths,
        protectedNames: Set<String> = CleanupRules.defaultProtectedNames,
        whitelist: Set<String> = []
    ) {
        self.minimumAge = minimumAge
        self.minimumIdle = minimumIdle
        self.maximumCPU = maximumCPU
        self.maximumLifetimeCPU = maximumLifetimeCPU
        self.maxProcesses = max(1, maxProcesses)
        self.minimumMemoryBytes = minimumMemoryBytes
        self.protectedPathPrefixes = protectedPathPrefixes
        self.protectedNames = protectedNames
        self.whitelist = whitelist
    }

    /// `/Applications` 下的 App 已由 `.app` 规则覆盖，这里只列系统与系统级框架路径。
    public static let defaultProtectedPaths = [
        "/System/",
        "/usr/",
        "/bin/",
        "/sbin/",
        "/Library/",
        "/private/",
        "/dev/",
        "/cores/",
        "/.vol/"
    ]

    /// 用户空间里的系统界面进程：路径不在 `/System` 也不在 `.app` 里的那几个，按名字兜底。
    public static let defaultProtectedNames: Set<String> = [
        "WindowServer", "WindowManager", "loginwindow", "Dock", "Finder",
        "SystemUIServer", "ControlCenter", "NotificationCenter", "Spotlight",
        "talagent", "universalaccessd", "UserEventAgent", "cfprefsd", "distnoted",
        "coreaudiod", "launchd", "kernel_task", "mds", "mds_stores",
        "TextInputMenuAgent", "TextInputSwitcher", "imklaunchagent",
        "AirPlayUIAgent", "screencaptureui", "Screenshot", "batteryhealthd",
        "powerd", "securityd", "tccd", "runningboardd", "opendirectoryd"
    ]

    public func isWhitelisted(_ name: String) -> Bool {
        whitelist.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// 纯规则判定：返回 nil 表示可以清理。
    public func skipReason(for facts: ProcessFacts, currentUID: UInt32, selfPID: Int32) -> CleanupSkipReason? {
        let process = facts.process
        if process.uid != currentUID { return .notCurrentUser }
        if process.pid == selfPID { return .selfProcess }
        if process.isZombie { return .zombie }
        if protectedNames.contains(process.name) { return .systemProcess }
        if process.path.isEmpty { return .systemProcess }
        if protectedPathPrefixes.contains(where: { process.path.hasPrefix($0) }) { return .systemProcess }
        if process.path.contains(".app/") { return .appBundle }
        if process.hasTerminal { return .terminal }
        if facts.isForeground { return .foreground }
        if isWhitelisted(process.name) { return .whitelisted }
        // 只动「遗留孤儿」：父进程还在的，说明它是别人正在用的子进程。
        if facts.hasLiveParent { return .hasLiveParent }
        if facts.hasChildren { return .hasChildren }
        // 套接字检查在 ProcessCleaner 里做（要读 fd 表，比纯规则贵）。
        if facts.age < minimumAge { return .tooYoung }
        if facts.cpu > maximumCPU { return .busy }
        if facts.idle < minimumIdle { return .recentlyActive }
        if minimumMemoryBytes > 0 && process.memoryBytes < minimumMemoryBytes { return .lowMemory }
        return nil
    }
}

/// 一个可以清理的候选进程。
public struct CleanupCandidate: Sendable, Equatable, Identifiable {
    public var pid: Int32
    public var name: String
    /// 进程自报的名字（`argv[0]`）。Node 起头的守护进程常把它改成自己的名字，
    /// 例如可执行文件是 `node`、`ps` 里却显示 `cliguard-daemon`；白名单要能按它匹配。
    public var title: String
    public var path: String
    public var startedAt: Date?
    public var memoryBytes: UInt64
    public var cpu: Double
    public var idleSeconds: TimeInterval
    public var ageSeconds: TimeInterval

    public var id: Int32 { pid }

    /// 列表里给人看的名字：进程名和自报名不同时都显示。
    public var displayName: String {
        title.isEmpty || title == name ? name : "\(name) · \(title)"
    }

    public init(
        pid: Int32,
        name: String,
        title: String = "",
        path: String,
        startedAt: Date? = nil,
        memoryBytes: UInt64,
        cpu: Double,
        idleSeconds: TimeInterval,
        ageSeconds: TimeInterval
    ) {
        self.pid = pid
        self.name = name
        self.title = title
        self.path = path
        self.startedAt = startedAt
        self.memoryBytes = memoryBytes
        self.cpu = cpu
        self.idleSeconds = idleSeconds
        self.ageSeconds = ageSeconds
    }
}

public struct CleanupPlan: Sendable {
    public var candidates: [CleanupCandidate]
    public var skipped: [CleanupSkipReason: Int]
    public var scanned: Int

    public var estimatedBytes: UInt64 { candidates.reduce(0) { $0 &+ $1.memoryBytes } }

    public static let empty = CleanupPlan(candidates: [], skipped: [:], scanned: 0)
}

public struct CleanupResult: Sendable {
    /// 已按 SIGTERM 正常退出。
    public var terminated: [CleanupCandidate]
    /// 收到信号但 3 秒内仍在运行（例如正在保存、或在被 launchd 重启）。
    public var survived: [CleanupCandidate]
    /// 按终止前的 RSS 估算释放量；实际释放由内核回收，可能略有出入。
    public var freedBytes: UInt64
}

/// 进程表快照。一次扫描读全部 PID 的 bsdinfo / 路径 / rusage。
public enum ProcessInventory {
    /// `SZOMB`：进程已退出，等待父进程回收。
    public static let zombieStatus: UInt32 = 5

    public static func scan(uid: UInt32? = getuid()) -> [LiveProcess] {
        allPIDs().compactMap { read(pid: $0, targetUID: uid) }
    }

    private static func read(pid: Int32, targetUID: UInt32?) -> LiveProcess? {
        guard pid > 0 else { return nil }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        if let targetUID, info.pbi_uid != targetUID { return nil }
        guard let usage = rusage(pid: pid) else { return nil }

        let path = executablePath(pid: pid) ?? ""
        let name = displayName(path: path, info: info, pid: pid)
        let startedAt = Date(
            timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec)
                + TimeInterval(info.pbi_start_tvusec) / 1_000_000
        )
        return LiveProcess(
            pid: pid,
            parentPID: Int32(info.pbi_ppid),
            name: name,
            path: path,
            uid: info.pbi_uid,
            hasTerminal: info.e_tdev != UInt32.max && info.e_tdev != 0,
            isZombie: info.pbi_status == zombieStatus,
            startedAt: startedAt,
            cpuTimeNanos: usage.cpuTimeNanos,
            memoryBytes: usage.footprintBytes
        )
    }

    /// 是否持有互联网套接字（TCP 监听/连接、UDP）或微虚机通信（VSOCK）。
    ///
    /// 只对已经通过其他规则的少量进程调用。只看 `soi_kind`，不碰 union：
    /// macOS 把管道也实现成 Unix socket，`PROX_FDTYPE_SOCKET` 会把 `stdout | pipe`
    /// 也算进去（实测 `setsid` 起的探针 0/1/2 都是 unix socket），所以要筛到 INET/TCP/VSOCK。
    public static func hasInternetSocket(pid: Int32) -> Bool {
        let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard needed > 0 else { return false }
        // 进程可能在两次调用之间又开了 fd，多留几个槽位。
        let capacity = Int(needed) / MemoryLayout<proc_fdinfo>.stride + 8
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: capacity)
        let size = Int32(capacity * MemoryLayout<proc_fdinfo>.stride)
        let written = fds.withUnsafeMutableBufferPointer { buffer -> Int32 in
            proc_pidinfo(pid, PROC_PIDLISTFDS, 0, buffer.baseAddress, size)
        }
        guard written > 0 else { return false }
        let used = min(Int(written) / MemoryLayout<proc_fdinfo>.stride, capacity)
        // 注意：PROC_PIDFDSOCKETINFO 要的是 `socket_fdinfo`（proc_fileinfo + socket_info），
        // 直接传 `socket_info` 会因长度不符而返回 0。
        let socketInfoSize = Int32(MemoryLayout<socket_fdinfo>.size)

        for index in 0..<used where fds[index].proc_fdtype == UInt32(PROX_FDTYPE_SOCKET) {
            var info = socket_fdinfo()
            let result = proc_pidfdinfo(pid, fds[index].proc_fd, PROC_PIDFDSOCKETINFO, &info, socketInfoSize)
            // SOCKINFO_IN = 1（UDP/raw），SOCKINFO_TCP = 2，SOCKINFO_VSOCK = 7（微虚机/容器 IPC，如 Docker/OrbStack）；UN = 3 是 Unix socket/管道，不算。
            if result == socketInfoSize, info.psi.soi_kind == 1 || info.psi.soi_kind == 2 || info.psi.soi_kind == 7 {
                return true
            }
        }
        return false
    }

    /// 进程自报的名字（`argv[0]`）。读 `KERN_PROCARGS2`，只对本用户的少量候选调用。
    public static func processTitle(pid: Int32) -> String? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 4 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }

        // 布局：argc(4 字节) + 可执行路径\0 + 填充\0 + argv[0]\0 + ...
        var index = 4
        while index < size, buffer[index] != 0 { index += 1 }
        while index < size, buffer[index] == 0 { index += 1 }
        guard index < size else { return nil }
        let start = index
        while index < size, buffer[index] != 0 { index += 1 }
        let raw = String(decoding: buffer[start..<index], as: UTF8.self)
        guard !raw.isEmpty else { return nil }
        return (raw as NSString).lastPathComponent
    }

    /// 进程是否仍活着；僵尸视为已退出。
    public static func isAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return false }
        return info.pbi_status != zombieStatus
    }

    /// 校验待清理的候选进程是否仍在运行，且没有被其他进程复用 PID。
    /// 检查 PID 是否存在、非僵尸；若提供启动时间或路径，严格核验（秒级比对启动时间，完整比对路径）。
    public static func matches(_ candidate: CleanupCandidate) -> Bool {
        guard candidate.pid > 0 else { return false }
        guard candidate.startedAt != nil || !candidate.path.isEmpty else { return false }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(candidate.pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return false }
        guard info.pbi_status != zombieStatus else { return false }

        if let expectedStartedAt = candidate.startedAt {
            let actualTvSec = info.pbi_start_tvsec
            let expectedSec = Int64(expectedStartedAt.timeIntervalSince1970)
            guard expectedSec >= 0, actualTvSec == UInt64(expectedSec) else {
                return false
            }
        }

        if !candidate.path.isEmpty {
            guard let currentPath = executablePath(pid: candidate.pid), currentPath == candidate.path else {
                return false
            }
        }

        return true
    }

    private static func displayName(path: String, info: proc_bsdinfo, pid: Int32) -> String {
        let component = (path as NSString).lastPathComponent
        if !component.isEmpty { return component }
        let fromInfo = cString(info.pbi_name)
        if !fromInfo.isEmpty { return fromInfo }
        let short = cString(info.pbi_comm)
        return short.isEmpty ? "PID \(pid)" : short
    }

    /// 4 * MAXPATHLEN，与 `PROC_PIDPATHINFO_MAXSIZE` 一致（该宏在 Swift 中不可用）。
    private static let pidPathMaxSize = 4 * Int(MAXPATHLEN)

    private static func executablePath(pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: pidPathMaxSize)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        let bytes = buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func cString<T>(_ tuple: T) -> String {
        withUnsafeBytes(of: tuple) { raw in
            let bytes = raw.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
    }

    private static func allPIDs() -> [Int32] {
        let capacity = 8192
        var pids = [pid_t](repeating: 0, count: capacity)
        let bytes = pids.withUnsafeMutableBufferPointer { buffer -> Int32 in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, buffer.baseAddress, Int32(buffer.count * MemoryLayout<pid_t>.stride))
        }
        guard bytes > 0 else { return [] }
        let count = min(Int(bytes) / MemoryLayout<pid_t>.stride, capacity)
        return pids.prefix(count).filter { $0 > 0 }
    }

    struct Usage {
        var cpuTimeNanos: UInt64
        var footprintBytes: UInt64
    }

    /// 与 `SystemSampler` 同一套读法：优先 V6，系统不支持时退回 V4。
    private static func rusage(pid: Int32) -> Usage? {
        var info = rusage_info_v6()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { raw in
                proc_pid_rusage(pid, RUSAGE_INFO_V6, raw)
            }
        }
        if result == 0 {
            return Usage(
                cpuTimeNanos: info.ri_user_time &+ info.ri_system_time,
                footprintBytes: info.ri_phys_footprint
            )
        }

        var legacy = rusage_info_v4()
        let legacyResult = withUnsafeMutablePointer(to: &legacy) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { raw in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, raw)
            }
        }
        guard legacyResult == 0 else { return nil }
        return Usage(
            cpuTimeNanos: legacy.ri_user_time &+ legacy.ri_system_time,
            footprintBytes: legacy.ri_phys_footprint
        )
    }
}

/// 空闲跟踪 + 候选筛选 + 温和终止。
///
/// 只在主线程使用（面板 1 秒 tick、菜单动作），因此不做加锁。
public final class ProcessCleaner {
    /// 每次观测到的累计 CPU 增长超过这个秒数，就记一次「有活动」。
    private static let activeCPUSeconds: Double = 0.02

    private struct Observation {
        var startedAt: Date
        var lastActiveAt: Date
        var lastSeenAt: Date
        var lastCPUTime: UInt64
        var lastCPU: Double
        var samples: Int
    }

    public private(set) var rules: CleanupRules
    /// 最近一次进程表扫描时间；菜单重复打开时据此避免重复扫描。
    public private(set) var lastScanAt: Date = .distantPast
    private var observations: [Int32: Observation] = [:]
    private var lastProcesses: [LiveProcess] = []

    /// 两次扫描的最小间隔（秒）：低于它的请求直接复用当前观测。
    private static let minimumRescanInterval: TimeInterval = 10

    public init(rules: CleanupRules = CleanupRules()) {
        self.rules = rules
    }

    public func updateWhitelist(_ names: Set<String>) {
        rules.whitelist = names
    }

    public func updateMinimumIdle(_ idle: TimeInterval) {
        rules.minimumIdle = max(60, idle)
    }

    public func updateMinimumMemory(_ bytes: UInt64) {
        rules.minimumMemoryBytes = bytes
    }

    /// 扫一遍进程表并更新闲置跟踪。返回本次快照。
    @discardableResult
    public func observe(now: Date = Date()) -> [LiveProcess] {
        let processes = ProcessInventory.scan()
        observe(processes: processes, now: now)
        return processes
    }

    /// 使用外部（如后台线程）已采集的进程快照更新闲置跟踪，避免在主线程执行系统调用。
    public func observe(processes: [LiveProcess], now: Date = Date()) {
        var updated: [Int32: Observation] = [:]
        updated.reserveCapacity(processes.count)

        for process in processes {
            if var record = observations[process.pid], record.startedAt == process.startedAt {
                let elapsed = now.timeIntervalSince(record.lastSeenAt)
                if process.cpuTimeNanos > record.lastCPUTime, elapsed > 0.05 {
                    let delta = Double(process.cpuTimeNanos - record.lastCPUTime) / 1_000_000_000
                    record.lastCPU = delta / elapsed
                    if delta >= Self.activeCPUSeconds {
                        record.lastActiveAt = now
                    }
                } else if process.cpuTimeNanos <= record.lastCPUTime {
                    // 计数器没动，说明这个窗口内没用 CPU。
                    record.lastCPU = 0
                }
                record.lastSeenAt = now
                record.lastCPUTime = process.cpuTimeNanos
                record.samples += 1
                updated[process.pid] = record
            } else {
                // 第一次见到（或 PID 被复用）：从这一刻开始跟踪。
                updated[process.pid] = Observation(
                    startedAt: process.startedAt,
                    lastActiveAt: now,
                    lastSeenAt: now,
                    lastCPUTime: process.cpuTimeNanos,
                    lastCPU: 0,
                    samples: 1
                )
            }
        }

        observations = updated
        lastProcesses = processes
        lastScanAt = now
    }

    /// 当前可清理的候选，按内存降序。
    public func evaluate(now: Date = Date(), foregroundPID: Int32? = nil) -> CleanupPlan {
        let processes = observe(now: now)
        let outcome = classify(processes, rules: rules, now: now, foregroundPID: foregroundPID)
        return CleanupPlan(candidates: outcome.candidates, skipped: outcome.skipped, scanned: processes.count)
    }

    /// 白名单菜单用：当前可辨认的后台进程名。
    ///
    /// 只做身份类筛查（用户 / 系统路径 / App / 终端 / 前台），
    /// 不要求闲置，也不看父子关系与套接字——这些状态会变，白名单要能提前设。
    /// 已在白名单里的名字照旧列出（带对勾），否则勾上就再也没法取消。
    public func protectableNames(now: Date = Date(), foregroundPID: Int32? = nil) -> [String] {
        // 菜单可能连续打开；10 秒内的重复请求不再扫进程表。
        let processes = now.timeIntervalSince(lastScanAt) < Self.minimumRescanInterval
            ? lastProcesses
            : observe(now: now)
        return protectableNames(in: processes, foregroundPID: foregroundPID)
    }

    /// 纯函数版本：只筛身份类规则（用户 / 系统路径 / App / 终端 / 前台），便于单测。
    /// 已在白名单里的名字照旧保留，否则勾上就再也没法取消。
    public func protectableProcesses(in processes: [LiveProcess], foregroundPID: Int32?) -> [LiveProcess] {
        let currentUID = getuid()
        let selfPID = getpid()
        // 已勾选的进程要留在列表里（带对勾）：它要是被这里过滤掉，就再也没法取消保护了。
        var identityRules = rules
        identityRules.whitelist = []

        return processes.filter { process in
            // age / idle 给一个大值：这一步只要身份类筛查，不走「是否闲置」的门槛。
            let facts = ProcessFacts(
                process: process,
                age: 30 * 86_400,
                idle: 30 * 86_400,
                cpu: 0,
                lifetimeCPU: 0,
                isForeground: foregroundPID.map { $0 == process.pid } ?? false
            )
            return identityRules.skipReason(for: facts, currentUID: currentUID, selfPID: selfPID) == nil
        }
    }

    /// 只要名字的版本（菜单用），按内存降序去重。
    func protectableNames(in processes: [LiveProcess], foregroundPID: Int32?) -> [String] {
        let entries = protectableProcesses(in: processes, foregroundPID: foregroundPID)
            .map { (pid: $0.pid, name: $0.name, memory: $0.memoryBytes) }

        // 显示 argv[0]（如果有）：`ps` 里看到的是它，用户凭它认进程。
        var seen = Set<String>()
        var names: [String] = []
        for entry in entries.sorted(by: { $0.memory > $1.memory }) {
            let title = ProcessInventory.processTitle(pid: entry.pid) ?? ""
            let display = title.isEmpty || title == entry.name ? entry.name : title
            guard seen.insert(display).inserted else { continue }
            names.append(display)
            if names.count >= 20 { break }
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func classify(
        _ processes: [LiveProcess],
        rules: CleanupRules,
        now: Date,
        foregroundPID: Int32?
    ) -> (candidates: [CleanupCandidate], skipped: [CleanupSkipReason: Int]) {
        let currentUID = getuid()
        let selfPID = getpid()
        // 有人把它当父进程，就说明它还在被使用。
        let parentsWithChildren = Set(processes.map(\.parentPID))
        var candidates: [CleanupCandidate] = []
        var skipped: [CleanupSkipReason: Int] = [:]

        for process in processes {
            let age = max(0, now.timeIntervalSince(process.startedAt))
            let lifetimeCPU = age > 1 ? Double(process.cpuTimeNanos) / 1_000_000_000 / age : 1
            let record = observations[process.pid]
            let cpu = record.map { $0.samples >= 2 ? $0.lastCPU : lifetimeCPU } ?? lifetimeCPU
            let idle = idleSeconds(rules: rules, process: process, record: record, age: age, lifetimeCPU: lifetimeCPU, now: now)

            let facts = ProcessFacts(
                process: process,
                age: age,
                idle: idle,
                cpu: cpu,
                lifetimeCPU: lifetimeCPU,
                isForeground: foregroundPID.map { $0 == process.pid } ?? false,
                hasLiveParent: process.parentPID > 1,
                hasChildren: parentsWithChildren.contains(process.pid)
            )
            if let reason = rules.skipReason(for: facts, currentUID: currentUID, selfPID: selfPID) {
                skipped[reason, default: 0] += 1
                continue
            }
            // 白名单可能记的是 argv[0]（Node 守护进程常见），所以只对通过其他规则的少量进程读一次。
            let title = ProcessInventory.processTitle(pid: process.pid) ?? ""
            if !title.isEmpty, title != process.name, rules.isWhitelisted(title) {
                skipped[.whitelisted, default: 0] += 1
                continue
            }
            if ProcessInventory.hasInternetSocket(pid: process.pid) {
                skipped[.networkActive, default: 0] += 1
                continue
            }
            candidates.append(
                CleanupCandidate(
                    pid: process.pid,
                    name: process.name,
                    title: title,
                    path: process.path,
                    startedAt: process.startedAt,
                    memoryBytes: process.memoryBytes,
                    cpu: cpu,
                    idleSeconds: idle,
                    ageSeconds: age
                )
            )
        }

        candidates.sort { $0.memoryBytes > $1.memoryBytes }
        if candidates.count > rules.maxProcesses {
            candidates = Array(candidates.prefix(rules.maxProcesses))
        }
        return (candidates, skipped)
    }

    /// 闲置时长的两个来源取较大值：
    /// 观测到的最后活动时间，以及「生命周期平均 CPU 极低 → 自启动就一直闲着」。
    private func idleSeconds(
        rules: CleanupRules,
        process: LiveProcess,
        record: Observation?,
        age: TimeInterval,
        lifetimeCPU: Double,
        now: Date
    ) -> TimeInterval {
        let lifetimeIdle: TimeInterval
        if age >= rules.minimumAge, lifetimeCPU <= rules.maximumLifetimeCPU {
            lifetimeIdle = age
        } else {
            lifetimeIdle = 0
        }
        guard let record, record.samples >= 2 else { return lifetimeIdle }
        return max(lifetimeIdle, now.timeIntervalSince(record.lastActiveAt))
    }

    /// 发送 SIGTERM，最多等 3 秒；不退出的保持运行，绝不升级成 SIGKILL。
    /// 发信号前重新核对 PID、启动时间与可执行文件路径，防止 PID 复用导致误杀。
    public func terminate(_ candidates: [CleanupCandidate], grace: TimeInterval = 3) -> CleanupResult {
        var signaled: [CleanupCandidate] = []
        for candidate in candidates {
            guard ProcessInventory.matches(candidate) else { continue }
            if kill(candidate.pid, SIGTERM) == 0 {
                signaled.append(candidate)
            }
        }

        let deadline = Date().addingTimeInterval(grace)
        var alive = signaled
        while !alive.isEmpty, Date() < deadline {
            usleep(100_000)
            alive = alive.filter { ProcessInventory.matches($0) }
        }

        let survivedIDs = Set(alive.map(\.pid))
        let terminated = signaled.filter { !survivedIDs.contains($0.pid) }
        return CleanupResult(
            terminated: terminated,
            survived: alive,
            freedBytes: terminated.reduce(0) { $0 &+ $1.memoryBytes }
        )
    }
}
