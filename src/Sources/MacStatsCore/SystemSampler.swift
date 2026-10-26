import Foundation
import Darwin
import IOKit
import IOKit.ps

public struct SamplerConfig: Sendable {
    /// 快照里保留的进程条数（按内存降序）。
    public var processLimit: Int
    /// 是否采集进程列表；关闭可降低开销。
    public var includeProcesses: Bool
    /// 进程表扫描（含能耗折算）的最短间隔，秒。
    ///
    /// 进程表要遍历全部 PID 各读一次 `rusage`，是单次采样里最贵的一项；
    /// 而进程内存和能耗都是慢变量，按秒刷新没有意义。CPU / 内存 / 网络仍按调用频率采。
    public var processInterval: TimeInterval

    public init(
        processLimit: Int = 32,
        includeProcesses: Bool = true,
        processInterval: TimeInterval = 3
    ) {
        self.processLimit = max(0, processLimit)
        self.includeProcesses = includeProcesses
        self.processInterval = max(0, processInterval)
    }
}

/// 一次采样里进程的原始计数，功率与 CPU% 都由相邻两次采样的差分得到。
struct ProcessRaw {
    var name: String
    var cpuTimeNanos: UInt64
    var energyNanojoules: UInt64
    var memoryBytes: UInt64
}

/// 从 Mach / IOKit / libproc 直接读取系统指标，等价于活动监视器各标签页的数据源。
/// 采样本身是同步的，调用方负责节流（本应用为 1 秒）。
public final class SystemSampler: @unchecked Sendable {
    private let config: SamplerConfig
    private var lastCPUTicks: [[UInt64]] = []
    private var lastProcessRaw: [pid_t: ProcessRaw] = [:]
    private var lastDisk: (read: UInt64, written: UInt64)?
    private var lastNetwork: (inBytes: UInt64, outBytes: UInt64)?
    private var lastNetworkRate: (inBytes: UInt64, outBytes: UInt64)?
    private var lastTimestamp: UInt64?
    private var nameCache: [pid_t: String] = [:]

    // 进程扫描按 `config.processInterval` 节流，两次扫描之间直接复用上次结果。
    private var lastProcessScan: UInt64?
    private var cachedProcesses: [ProcessStatus] = []
    private var cachedEnergy: EnergyStatus = .zero
    // top CPU 在按内存截断前算，缓存路径必须一起带出，否则节流期间归因会闪回空。
    private var cachedTopCPU: [ProcessAttribution] = []

    // 卷容量（statfs）变化很慢，没必要跟着每秒采样走。
    private var cachedVolume: (total: UInt64, free: UInt64)?
    private var lastVolumeCheck: UInt64 = 0

    private let hostName: String
    private let pageSize: UInt64
    private let physicalMemory: UInt64
    private let hostPort: mach_port_t
    private let lock = NSLock()

    public init(config: SamplerConfig = SamplerConfig()) {
        self.config = config
        self.hostName = ProcessInfo.processInfo.hostName
        self.pageSize = UInt64(getpagesize())
        self.physicalMemory = Self.sysctlUInt64("hw.memsize") ?? 0
        self.hostPort = mach_host_self()
    }

    deinit {
        mach_port_deallocate(mach_task_self_, hostPort)
    }

    /// 重置采样基线，用于系统休眠唤醒后防止因时间跳跃产生畸高的速率读数。
    public func resetBaseline() {
        lock.lock()
        defer { lock.unlock() }
        lastCPUTicks = []
        lastProcessRaw = [:]
        lastDisk = nil
        lastNetwork = nil
        lastNetworkRate = nil
        lastTimestamp = nil
        lastProcessScan = nil
    }

    // MARK: - Public

    public func sample(includeProcesses: Bool? = nil) -> MetricSnapshot {
        lock.lock()
        defer { lock.unlock() }

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = lastTimestamp.map { Double(now &- $0) / 1_000_000_000 } ?? 0
        lastTimestamp = now

        let cpu = sampleCPU()
        let memory = sampleMemory()
        let disk = sampleDisk(elapsed: elapsed, now: now)
        let network = sampleNetwork(elapsed: elapsed)
        let shouldIncludeProcesses = includeProcesses ?? config.includeProcesses
        let (processes, energy, topCPU) = sampleProcessesIfDue(now: now, elapsed: elapsed, includeProcesses: shouldIncludeProcesses)
        let gpu = GPUReader.read()

        return MetricSnapshot(
            timestamp: Date(),
            hostName: hostName,
            uptime: ProcessInfo.processInfo.systemUptime,
            cpu: cpu,
            memory: memory,
            energy: energy,
            disk: disk,
            network: network,
            processes: processes,
            gpu: gpu,
            topCPUProcesses: topCPU
        )
    }

    // MARK: - CPU

    private func sampleCPU() -> CPUStatus {
        let ticks = readCPUTicks()
        guard !ticks.isEmpty else { return .zero }

        var cores: [Double] = []
        var busyTotal = 0.0
        var idleTotal = 0.0
        var userTotal = 0.0
        var systemTotal = 0.0

        for (index, current) in ticks.enumerated() {
            let previous = index < lastCPUTicks.count ? lastCPUTicks[index] : []
            var delta = [Double](repeating: 0, count: 4)
            for state in 0..<min(4, current.count) {
                let before = state < previous.count ? previous[state] : 0
                delta[state] = current[state] >= before ? Double(current[state] - before) : 0
            }
            let total = delta.reduce(0, +)
            let busy = delta[0] + delta[1] + delta[3]   // user + system + nice
            let idle = delta[2]
            if total > 0 {
                cores.append(min(busy / total, 1))
                busyTotal += busy
                idleTotal += idle
                userTotal += delta[0] + delta[3]
                systemTotal += delta[1]
            } else {
                cores.append(0)
            }
        }
        lastCPUTicks = ticks

        let total = busyTotal + idleTotal
        let overall: Double
        if total > 0 {
            overall = min(busyTotal / total, 1)
        } else {
            overall = cores.isEmpty ? 0 : cores.reduce(0, +) / Double(cores.count)
        }
        let user = total > 0 ? min(userTotal / total, 1) : 0
        let system = total > 0 ? min(systemTotal / total, 1) : 0

        return CPUStatus(
            total: overall,
            user: user,
            system: system,
            idle: max(0, 1 - user - system),
            cores: cores,
            loadAverage: Self.loadAverage()
        )
    }

    /// 每个逻辑核心 [user, system, idle, nice] 的累计 tick。
    private func readCPUTicks() -> [[UInt64]] {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(hostPort, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else { return [] }
        defer {
            let size = vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), size)
        }

        let stride = Int(CPU_STATE_MAX)
        var ticks: [[UInt64]] = []
        ticks.reserveCapacity(Int(cpuCount))
        for core in 0..<Int(cpuCount) {
            let base = core * stride
            var states = [UInt64](repeating: 0, count: 4)
            for state in 0..<min(4, stride) {
                states[state] = UInt64(UInt32(bitPattern: info[base + state]))
            }
            ticks.append(states)
        }
        return ticks
    }

    private static func loadAverage() -> [Double] {
        var loads = [Double](repeating: 0, count: 3)
        let count = getloadavg(&loads, 3)
        return count > 0 ? Array(loads.prefix(Int(count))) : [0, 0, 0]
    }

    // MARK: - Memory

    private func sampleMemory() -> MemoryStatus {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return .zero }

        let page = pageSize
        func bytes(_ value: UInt64) -> UInt64 { value &* page }

        let purgeable = bytes(UInt64(stats.purgeable_count))
        let internalPages = bytes(UInt64(stats.internal_page_count))
        let appBytes = internalPages > purgeable ? internalPages - purgeable : 0

        var swapUsed: UInt64 = 0
        var swapTotal: UInt64 = 0
        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 {
            swapUsed = UInt64(swap.xsu_used)
            swapTotal = UInt64(swap.xsu_total)
        }

        let total = physicalMemory > 0 ? physicalMemory : bytes(UInt64(stats.wire_count) &+ UInt64(stats.active_count) &+ UInt64(stats.inactive_count) &+ UInt64(stats.free_count))

        let vm = VMSnapshot(
            totalBytes: total,
            freeBytes: bytes(UInt64(stats.free_count)),
            speculativeBytes: bytes(UInt64(stats.speculative_count)),
            activeBytes: bytes(UInt64(stats.active_count)),
            inactiveBytes: bytes(UInt64(stats.inactive_count)),
            wiredBytes: bytes(UInt64(stats.wire_count)),
            compressedBytes: bytes(UInt64(stats.compressor_page_count)),
            purgeableBytes: purgeable,
            appBytes: appBytes,
            fileBackedBytes: bytes(UInt64(stats.external_page_count)),
            swapUsedBytes: swapUsed,
            swapTotalBytes: swapTotal,
            pressure: MemoryPressure(rawPressureLevel: Self.memoryPressureLevel())
        )
        return MemoryMath.status(from: vm)
    }

    private static func memoryPressureLevel() -> Int32 {
        var level: Int32 = 1
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return 1 }
        return level
    }

    // MARK: - Disk

    private func sampleDisk(elapsed: TimeInterval, now: UInt64) -> DiskStatus {
        let totals = diskTotals()
        var status = DiskStatus.zero
        if let totals {
            if let previous = lastDisk, elapsed > 0, totals.read >= previous.read, totals.written >= previous.written {
                status.readBytesPerSecond = Double(totals.read - previous.read) / elapsed
                status.writeBytesPerSecond = Double(totals.written - previous.written) / elapsed
            }
            status.totalReadBytes = totals.read
            status.totalWrittenBytes = totals.written
            lastDisk = totals
        }
        // 可用空间 10 秒看一次就够：statfs 不快，而面板上的数字本来就不会秒秒变。
        let capacity: (total: UInt64, free: UInt64)
        if let cached = cachedVolume, now &- lastVolumeCheck < 10_000_000_000 {
            capacity = cached
        } else {
            capacity = Self.volumeCapacity()
            cachedVolume = capacity
            lastVolumeCheck = now
        }
        status.capacity = capacity.total
        status.free = capacity.free
        return status
    }

    private func diskTotals() -> (read: UInt64, written: UInt64)? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var read: UInt64 = 0
        var written: UInt64 = 0
        var found = false
        while true {
            let drive = IOIteratorNext(iterator)
            if drive == 0 { break }
            defer { IOObjectRelease(drive) }
            guard let stats = IORegistryEntryCreateCFProperty(
                drive, "Statistics" as CFString, kCFAllocatorDefault, 0
            )?.takeRetainedValue() as? [String: Any] else { continue }
            if let value = (stats["Bytes (Read)"] as? NSNumber)?.uint64Value {
                read &+= value
                found = true
            }
            if let value = (stats["Bytes (Write)"] as? NSNumber)?.uint64Value {
                written &+= value
            }
        }
        return found ? (read, written) : nil
    }

    private static func volumeCapacity() -> (total: UInt64, free: UInt64) {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]) else { return (0, 0) }
        let total = UInt64(values.volumeTotalCapacity ?? 0)
        let free = UInt64(max(0, values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)))
        return (total, free)
    }

    // MARK: - Network

    private func sampleNetwork(elapsed: TimeInterval) -> NetworkStatus {
        let totals = networkTotals()
        var status = NetworkStatus.zero
        status.totalBytesIn = totals.inBytes
        status.totalBytesOut = totals.outBytes
        status.interfaceCount = totals.interfaces.count
        status.activeInterfaces = totals.interfaces
        // 活动监视器的「收到的数据」含 lo0，但「收到的数据/秒」不含：
        // 本机 lo0 上常驻约 1.5 MB/s 的内核环回流量，算进速率会比活动监视器大几十倍。
        if let previous = lastNetworkRate, elapsed > 0,
           totals.rateInBytes >= previous.inBytes, totals.rateOutBytes >= previous.outBytes {
            status.bytesInPerSecond = Double(totals.rateInBytes - previous.inBytes) / elapsed
            status.bytesOutPerSecond = Double(totals.rateOutBytes - previous.outBytes) / elapsed
        }
        lastNetwork = (totals.inBytes, totals.outBytes)
        lastNetworkRate = (totals.rateInBytes, totals.rateOutBytes)
        return status
    }

    private func networkTotals() -> (inBytes: UInt64, outBytes: UInt64, rateInBytes: UInt64, rateOutBytes: UInt64, interfaces: [String]) {
        // 活动监视器「网络」页的累计值 = 所有接口 if_data64 之和（含 lo0）。
        // 必须走 IFMIB：NET_RT_IFLIST2 消息里 lo0 的 ifi_ibytes 只填了低 32 位
        // （本机真实值 122.9 GB，路由消息里读到 2.6 GB），两者会差上百 GB。
        var count: Int32 = 0
        var countSize = MemoryLayout<Int32>.size
        var countMIB: [Int32] = [CTL_NET, AF_LINK, Self.ifmibAll, Self.ifmibSystem, Self.ifmibIfCount]
        guard sysctl(&countMIB, u_int(countMIB.count), &count, &countSize, nil, 0) == 0, count > 0 else {
            return (0, 0, 0, 0, [])
        }

        var inBytes: UInt64 = 0
        var outBytes: UInt64 = 0
        var rateInBytes: UInt64 = 0
        var rateOutBytes: UInt64 = 0
        var active: [(name: String, traffic: UInt64)] = []

        for index in Int32(1)...Int32(count) {
            var mib: [Int32] = [CTL_NET, AF_LINK, Self.ifmibAll, Self.ifmibIfData, index, Self.ifdataGeneral]
            var data = ifmibdata()
            var size = MemoryLayout<ifmibdata>.size
            guard sysctl(&mib, u_int(mib.count), &data, &size, nil, 0) == 0 else { continue }

            let name = withUnsafeBytes(of: data.ifmd_name) { raw -> String in
                let bytes = raw.prefix { $0 != 0 }
                return String(decoding: bytes, as: UTF8.self)
            }
            guard !name.isEmpty else { continue }

            let received = data.ifmd_data.ifi_ibytes
            let sent = data.ifmd_data.ifi_obytes
            inBytes &+= received
            outBytes &+= sent
            if name != "lo0" {
                rateInBytes &+= received
                rateOutBytes &+= sent
            }
            if (data.ifmd_flags & UInt32(IFF_UP)) != 0 {
                active.append((name, received &+ sent))
            }
        }

        // 物理网卡（en*）优先，其次按累计流量排序；界面直接取 first 作为主接口。
        let names = active.sorted { lhs, rhs in
            let lhsIsPhysical = lhs.name.hasPrefix("en")
            let rhsIsPhysical = rhs.name.hasPrefix("en")
            if lhsIsPhysical != rhsIsPhysical { return lhsIsPhysical }
            return lhs.traffic > rhs.traffic
        }.map(\.name)
        return (inBytes, outBytes, rateInBytes, rateOutBytes, names)
    }

    // net/if_mib.h 里的 MIB 常量；Darwin 模块没有导出，这里按头文件取值。
    // MIB 为 {CTL_NET, AF_LINK, PF_ALL, IFMIB_IFDATA, ifindex, IFDATA_GENERAL}；
    // 本机 PF_ALL 取 0 才能命中，0xff 会返回 ENOENT。
    private static let ifmibSystem: Int32 = 1
    private static let ifmibIfCount: Int32 = 1
    private static let ifmibIfData: Int32 = 2
    private static let ifdataGeneral: Int32 = 1
    private static let ifmibAll: Int32 = 0

    private static func interfaceName(index: UInt16) -> String? {
        var name = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        guard if_indextoname(UInt32(index), &name) != nil else { return nil }
        let bytes = name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    // MARK: - Energy & processes

    /// 到点才真正扫进程表，其余时刻复用上一次的进程列表、能耗与 top CPU。
    private func sampleProcessesIfDue(
        now: UInt64,
        elapsed: TimeInterval,
        includeProcesses: Bool
    ) -> (processes: [ProcessStatus], energy: EnergyStatus, topCPU: [ProcessAttribution]) {
        guard includeProcesses else {
            return ([], sampleEnergy(entries: [], elapsed: elapsed), [])
        }
        let interval = config.processInterval
        if interval > 0, let last = lastProcessScan {
            let sinceLast = Double(now &- last) / 1_000_000_000
            if sinceLast < interval {
                return (cachedProcesses, cachedEnergy, cachedTopCPU)
            }
        }
        // 首次扫描没有上一帧，用调用方的 elapsed；之后用两次扫描之间的真实间隔，
        // 否则节流后的 CPU%/能耗会被按 1 秒窗口放大。
        let scanElapsed: TimeInterval
        if let last = lastProcessScan {
            scanElapsed = Double(now &- last) / 1_000_000_000
        } else {
            scanElapsed = elapsed
        }
        lastProcessScan = now
        let result = sampleProcesses(elapsed: scanElapsed)
        cachedProcesses = result.processes
        cachedEnergy = result.energy
        cachedTopCPU = result.topCPU
        return result
    }

    private func sampleProcesses(
        elapsed: TimeInterval
    ) -> (processes: [ProcessStatus], energy: EnergyStatus, topCPU: [ProcessAttribution]) {
        let pids = Self.allPIDs()
        var raw: [pid_t: ProcessRaw] = [:]
        raw.reserveCapacity(pids.count)
        var records: [ProcessStatus] = []
        records.reserveCapacity(pids.count)
        var energyEntries: [(energyNanojoules: Double, cpuFraction: Double)] = []

        for pid in pids {
            guard let usage = Self.rusage(pid: pid) else { continue }
            let cpuTime = usage.cpuTimeNanos
            let energy = usage.energyNanojoules
            let memory = usage.footprintBytes
            let name = name(for: pid)
            raw[pid] = ProcessRaw(name: name, cpuTimeNanos: cpuTime, energyNanojoules: energy, memoryBytes: memory)

            var cpuFraction = 0.0
            var energyDelta = 0.0
            if let previous = lastProcessRaw[pid] {
                if cpuTime >= previous.cpuTimeNanos {
                    cpuFraction = Double(cpuTime - previous.cpuTimeNanos) / 1_000_000_000 / max(elapsed, .ulpOfOne)
                }
                if energy >= previous.energyNanojoules {
                    energyDelta = Double(energy - previous.energyNanojoules)
                }
            }
            energyEntries.append((energyNanojoules: energyDelta, cpuFraction: cpuFraction))

            let watts = EnergyModel.processWatts(
                energyNanojoules: energyDelta,
                cpuFraction: cpuFraction,
                over: elapsed
            )
            records.append(ProcessStatus(pid: pid, name: name, cpu: cpuFraction, memory: memory, energyWatts: watts))
        }

        lastProcessRaw = raw
        // 清掉已退出进程的名字缓存，防止长时间运行后无限增长。
        if nameCache.count > raw.count * 2 {
            nameCache = nameCache.filter { raw[$0.key] != nil }
        }

        // 必须在按内存截断之前取 top CPU：CPU 高但内存小的进程可能不在 processes 里。
        let topCPU = ProcessRanking.attributions(from: records, limit: 8, by: .cpu)
        let sorted = records.sorted { $0.memory > $1.memory }
        let limited = Array(sorted.prefix(config.processLimit))
        return (limited, sampleEnergy(entries: energyEntries, elapsed: elapsed), topCPU)
    }

    private func sampleEnergy(
        entries: [(energyNanojoules: Double, cpuFraction: Double)],
        elapsed: TimeInterval
    ) -> EnergyStatus {
        var status = EnergyStatus.zero
        let totals = EnergyModel.totalWatts(entries: entries, over: elapsed)
        status.watts = elapsed > 0.05 ? totals.watts : nil
        status.isEstimated = totals.isEstimated
        if let battery = Self.batteryStatus() {
            status.batteryPercent = battery.percent
            status.isCharging = battery.isCharging
            status.isOnBattery = battery.isOnBattery
            status.minutesRemaining = battery.minutesRemaining
        }
        return status
    }

    private static func batteryStatus() -> (percent: Int?, isCharging: Bool, isOnBattery: Bool, minutesRemaining: Int?)? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            let state = description[kIOPSPowerSourceStateKey as String] as? String
            let isOnBattery = state == (kIOPSBatteryPowerValue as String)
            let isCharging = (description[kIOPSIsChargingKey as String] as? Bool) ?? false
            let current = description[kIOPSCurrentCapacityKey as String] as? Int
            let maximum = description[kIOPSMaxCapacityKey as String] as? Int
            var percent: Int?
            if let current, let maximum, maximum > 0 {
                percent = Int((Double(current) / Double(maximum) * 100).rounded())
            }
            var minutes: Int?
            if isOnBattery, !isCharging {
                let remaining = description[kIOPSTimeToEmptyKey as String] as? Int
                if let remaining, remaining > 0 { minutes = remaining }
            }
            if percent != nil || isOnBattery {
                return (percent, isCharging, isOnBattery, minutes)
            }
        }
        return nil
    }

    private func name(for pid: pid_t) -> String {
        if let cached = nameCache[pid] { return cached }
        var resolved = Self.processPathName(pid: pid) ?? Self.processShortName(pid: pid) ?? "PID \(pid)"
        if resolved.hasSuffix(".app") { resolved.removeLast(4) }
        nameCache[pid] = resolved
        return resolved
    }

    /// 4 * MAXPATHLEN，与 `PROC_PIDPATHINFO_MAXSIZE` 一致（该宏在 Swift 中不可用）。
    private static let pidPathMaxSize = 4 * Int(MAXPATHLEN)

    private static func processPathName(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: pidPathMaxSize)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        let path = decodeCString(buffer, length: Int(length))
        let component = (path as NSString).lastPathComponent
        return component.isEmpty ? nil : component
    }

    private static func processShortName(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = proc_name(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        let name = decodeCString(buffer, length: Int(length))
        return name.isEmpty ? nil : name
    }

    private static func decodeCString(_ buffer: [CChar], length: Int) -> String {
        let bytes = buffer.prefix(max(0, length)).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func allPIDs() -> [pid_t] {
        let capacity = 4096
        var pids = [pid_t](repeating: 0, count: capacity)
        let bytes = pids.withUnsafeMutableBufferPointer { buffer -> Int32 in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, buffer.baseAddress, Int32(buffer.count * MemoryLayout<pid_t>.stride))
        }
        guard bytes > 0 else { return [] }
        let count = min(Int(bytes) / MemoryLayout<pid_t>.stride, capacity)
        return pids.prefix(count).filter { $0 > 0 }
    }

    /// 进程累计用量。优先 V6（含 `ri_energy_nj` 能量计数），系统不支持时退回 V4。
    struct ProcUsage {
        var cpuTimeNanos: UInt64
        var energyNanojoules: UInt64
        var footprintBytes: UInt64
    }

    private static func rusage(pid: pid_t) -> ProcUsage? {
        var info = rusage_info_v6()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { raw in
                proc_pid_rusage(pid, RUSAGE_INFO_V6, raw)
            }
        }
        if result == 0 {
            return ProcUsage(
                cpuTimeNanos: info.ri_user_time &+ info.ri_system_time,
                energyNanojoules: info.ri_energy_nj,
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
        return ProcUsage(
            cpuTimeNanos: legacy.ri_user_time &+ legacy.ri_system_time,
            energyNanojoules: 0,
            footprintBytes: legacy.ri_phys_footprint
        )
    }

    private static func sysctlUInt64(_ name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}
