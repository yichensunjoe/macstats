import Foundation

/// 内存压力等级。macOS 通过 `kern.memorystatus_vm_pressure_level` 暴露 1/2/4 三档。
public enum MemoryPressure: String, Codable, Sendable, CaseIterable {
    case normal
    case warning
    case critical

    /// 显示名称（活动监视器口径：正常 / 警告 / 严重）。
    public var displayName: String {
        switch self {
        case .normal: "正常"
        case .warning: "警告"
        case .critical: "严重"
        }
    }

    public init(rawPressureLevel: Int32) {
        switch rawPressureLevel {
        case 2: self = .warning
        case 4: self = .critical
        default: self = .normal
        }
    }
}

public struct CPUStatus: Codable, Sendable, Equatable {
    /// 全部核心合计占用率，0...1。
    public var total: Double
    /// 用户态占比，0...1。
    public var user: Double
    /// 系统态占比，0...1。
    public var system: Double
    /// 空闲占比，0...1。
    public var idle: Double
    /// 每个逻辑核心的占用率，0...1。
    public var cores: [Double]
    /// 1 / 5 / 15 分钟平均负载。
    public var loadAverage: [Double]

    public init(total: Double, user: Double, system: Double, idle: Double, cores: [Double], loadAverage: [Double]) {
        self.total = total
        self.user = user
        self.system = system
        self.idle = idle
        self.cores = cores
        self.loadAverage = loadAverage
    }

    public static let zero = CPUStatus(total: 0, user: 0, system: 0, idle: 1, cores: [], loadAverage: [0, 0, 0])
}

public struct MemoryStatus: Codable, Sendable, Equatable {
    public var total: UInt64
    /// 已使用内存 = 物理内存 - 空闲 - 已缓存文件（活动监视器口径，
    /// 因此会大于 App + 联动 + 被压缩 之和）。
    public var used: UInt64
    /// App 内存。
    public var app: UInt64
    /// 联动内存（wired）。
    public var wired: UInt64
    /// 被压缩。
    public var compressed: UInt64
    /// 已缓存文件。
    public var cachedFiles: UInt64
    public var free: UInt64
    public var swapUsed: UInt64
    public var swapTotal: UInt64
    public var pressure: MemoryPressure
    /// 内存压力进度条填充比例，0...1。
    public var pressureScore: Double

    public init(
        total: UInt64,
        used: UInt64,
        app: UInt64,
        wired: UInt64,
        compressed: UInt64,
        cachedFiles: UInt64,
        free: UInt64,
        swapUsed: UInt64,
        swapTotal: UInt64,
        pressure: MemoryPressure,
        pressureScore: Double
    ) {
        self.total = total
        self.used = used
        self.app = app
        self.wired = wired
        self.compressed = compressed
        self.cachedFiles = cachedFiles
        self.free = free
        self.swapUsed = swapUsed
        self.swapTotal = swapTotal
        self.pressure = pressure
        self.pressureScore = pressureScore
    }

    public static let zero = MemoryStatus(
        total: 0, used: 0, app: 0, wired: 0, compressed: 0, cachedFiles: 0, free: 0,
        swapUsed: 0, swapTotal: 0, pressure: .normal, pressureScore: 0
    )
}

public struct EnergyStatus: Codable, Sendable, Equatable {
    /// 采样窗口内的平均功率（瓦）。nil 表示拿不到能量数据。
    public var watts: Double?
    /// true 表示功率来自 CPU 占用估算，而不是内核提供的能量计数器。
    public var isEstimated: Bool
    /// 电池电量百分比；台式机为 nil。
    public var batteryPercent: Int?
    public var isCharging: Bool
    public var isOnBattery: Bool
    /// 电池剩余可用分钟；正在充电或无法估算时为 nil。
    public var minutesRemaining: Int?

    public init(
        watts: Double?,
        isEstimated: Bool,
        batteryPercent: Int?,
        isCharging: Bool,
        isOnBattery: Bool,
        minutesRemaining: Int?
    ) {
        self.watts = watts
        self.isEstimated = isEstimated
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
        self.isOnBattery = isOnBattery
        self.minutesRemaining = minutesRemaining
    }

    public static let zero = EnergyStatus(
        watts: nil, isEstimated: false, batteryPercent: nil,
        isCharging: false, isOnBattery: false, minutesRemaining: nil
    )
}

/// GPU 读数。来源是 `IOAccelerator` 的 `PerformanceStatistics`，与活动监视器的
/// GPU 页签同源；拿不到就返回 nil，不影响其它指标。
public struct GPUStatus: Codable, Sendable, Equatable {
    /// 设备利用率，0...1（内核给的是整百分比）。
    public var utilization: Double
    /// 渲染器 / 平铺器利用率；部分显卡不提供。
    public var renderer: Double?
    public var tiler: Double?
    /// 当前占用的统一内存（字节）。
    public var memoryInUse: UInt64?
    /// 已分配给 GPU 的统一内存（字节）。
    public var memoryAllocated: UInt64?
    /// GPU 核心数（Apple Silicon 的 `gpu-core-count`）。
    public var coreCount: Int?
    /// 显卡型号，例如 `Apple M5 Pro`。
    public var model: String?

    public init(
        utilization: Double,
        renderer: Double? = nil,
        tiler: Double? = nil,
        memoryInUse: UInt64? = nil,
        memoryAllocated: UInt64? = nil,
        coreCount: Int? = nil,
        model: String? = nil
    ) {
        self.utilization = utilization
        self.renderer = renderer
        self.tiler = tiler
        self.memoryInUse = memoryInUse
        self.memoryAllocated = memoryAllocated
        self.coreCount = coreCount
        self.model = model
    }
}

public struct DiskStatus: Codable, Sendable, Equatable {
    public var readBytesPerSecond: Double
    public var writeBytesPerSecond: Double
    public var totalReadBytes: UInt64
    public var totalWrittenBytes: UInt64
    public var capacity: UInt64
    public var free: UInt64

    public init(
        readBytesPerSecond: Double,
        writeBytesPerSecond: Double,
        totalReadBytes: UInt64,
        totalWrittenBytes: UInt64,
        capacity: UInt64,
        free: UInt64
    ) {
        self.readBytesPerSecond = readBytesPerSecond
        self.writeBytesPerSecond = writeBytesPerSecond
        self.totalReadBytes = totalReadBytes
        self.totalWrittenBytes = totalWrittenBytes
        self.capacity = capacity
        self.free = free
    }

    public var usedFraction: Double {
        capacity > 0 ? Double(capacity - min(free, capacity)) / Double(capacity) : 0
    }

    public static let zero = DiskStatus(
        readBytesPerSecond: 0, writeBytesPerSecond: 0, totalReadBytes: 0,
        totalWrittenBytes: 0, capacity: 0, free: 0
    )
}

public struct NetworkStatus: Codable, Sendable, Equatable {
    public var bytesInPerSecond: Double
    public var bytesOutPerSecond: Double
    public var totalBytesIn: UInt64
    public var totalBytesOut: UInt64
    /// 参与统计的有效接口数量（不含 lo0）。
    public var interfaceCount: Int
    /// 活动接口名，例如 en0。
    public var activeInterfaces: [String]

    public init(
        bytesInPerSecond: Double,
        bytesOutPerSecond: Double,
        totalBytesIn: UInt64,
        totalBytesOut: UInt64,
        interfaceCount: Int,
        activeInterfaces: [String]
    ) {
        self.bytesInPerSecond = bytesInPerSecond
        self.bytesOutPerSecond = bytesOutPerSecond
        self.totalBytesIn = totalBytesIn
        self.totalBytesOut = totalBytesOut
        self.interfaceCount = interfaceCount
        self.activeInterfaces = activeInterfaces
    }

    public static let zero = NetworkStatus(
        bytesInPerSecond: 0, bytesOutPerSecond: 0, totalBytesIn: 0,
        totalBytesOut: 0, interfaceCount: 0, activeInterfaces: []
    )
}

public struct ProcessStatus: Codable, Sendable, Equatable, Identifiable {
    public var pid: Int32
    public var name: String
    /// 占单核的比例；1.0 表示一个核心 100%。
    public var cpu: Double
    public var memory: UInt64
    public var energyWatts: Double

    public var id: Int32 { pid }

    public init(pid: Int32, name: String, cpu: Double, memory: UInt64, energyWatts: Double) {
        self.pid = pid
        self.name = name
        self.cpu = cpu
        self.memory = memory
        self.energyWatts = energyWatts
    }
}

/// 与活动监视器默认 5 秒刷新窗口对应的均值集合。
public struct WindowAverages: Sendable, Equatable {
    public var cpuTotal: Double
    public var cpuUser: Double
    public var cpuSystem: Double
    public var energyWatts: Double
    public var diskRead: Double
    public var diskWrite: Double
    public var networkIn: Double
    public var networkOut: Double
    public var sampleCount: Int

    public init(
        cpuTotal: Double = 0,
        cpuUser: Double = 0,
        cpuSystem: Double = 0,
        energyWatts: Double = 0,
        diskRead: Double = 0,
        diskWrite: Double = 0,
        networkIn: Double = 0,
        networkOut: Double = 0,
        sampleCount: Int = 0
    ) {
        self.cpuTotal = cpuTotal
        self.cpuUser = cpuUser
        self.cpuSystem = cpuSystem
        self.energyWatts = energyWatts
        self.diskRead = diskRead
        self.diskWrite = diskWrite
        self.networkIn = networkIn
        self.networkOut = networkOut
        self.sampleCount = sampleCount
    }
}

public struct MetricSnapshot: Codable, Sendable, Equatable {
    public var timestamp: Date
    public var hostName: String
    public var uptime: TimeInterval
    public var cpu: CPUStatus
    public var memory: MemoryStatus
    public var energy: EnergyStatus
    public var disk: DiskStatus
    public var network: NetworkStatus
    /// 按内存占用降序，最多 `processLimit` 条。
    public var processes: [ProcessStatus]
    /// 按 CPU 占用降序、逐 PID 的明细，最多 `processLimit` 条，同样在按内存截断之前取。
    /// 面板切到 CPU 榜后要能直接点开这些进程；Optional 是为了旧 JSON 仍能解码。
    public var cpuProcesses: [ProcessStatus]?
    /// GPU 读数；老版本写下的快照没有这个字段，解码为 nil。
    public var gpu: GPUStatus?
    /// 按 CPU 排序、已按名字聚合的 top N（在按内存截断之前算），只用于归因。
    /// Optional 是为了旧 JSON 仍能解码；新采样会填。
    public var topCPUProcesses: [ProcessAttribution]?

    public init(
        timestamp: Date,
        hostName: String,
        uptime: TimeInterval,
        cpu: CPUStatus,
        memory: MemoryStatus,
        energy: EnergyStatus,
        disk: DiskStatus,
        network: NetworkStatus,
        processes: [ProcessStatus],
        cpuProcesses: [ProcessStatus]? = nil,
        gpu: GPUStatus? = nil,
        topCPUProcesses: [ProcessAttribution]? = nil
    ) {
        self.timestamp = timestamp
        self.hostName = hostName
        self.uptime = uptime
        self.cpu = cpu
        self.memory = memory
        self.energy = energy
        self.disk = disk
        self.network = network
        self.processes = processes
        self.cpuProcesses = cpuProcesses
        self.gpu = gpu
        self.topCPUProcesses = topCPUProcesses
    }

    /// 读取便利：旧快照/未采进程时为空数组。不参与 Codable。
    public var topCPU: [ProcessAttribution] { topCPUProcesses ?? [] }

    /// 读取便利：旧快照没有 CPU 明细时回退到内存榜再排一次（至少能看，只是候选不全）。
    public var cpuRankedProcesses: [ProcessStatus] {
        cpuProcesses ?? ProcessRanking.topByCPU(processes, limit: processes.count)
    }

    /// 速率类指标在一个滑动窗口内的均值；内存是瞬时量，不参与平均。
    public func applying(_ window: WindowAverages) -> MetricSnapshot {
        guard window.sampleCount > 0 else { return self }
        var copy = self
        copy.cpu.total = min(max(window.cpuTotal, 0), 1)
        copy.cpu.user = min(max(window.cpuUser, 0), 1)
        copy.cpu.system = min(max(window.cpuSystem, 0), 1)
        copy.cpu.idle = max(0, 1 - copy.cpu.user - copy.cpu.system)
        copy.energy.watts = window.energyWatts > 0 ? window.energyWatts : nil
        copy.disk.readBytesPerSecond = max(0, window.diskRead)
        copy.disk.writeBytesPerSecond = max(0, window.diskWrite)
        copy.network.bytesInPerSecond = max(0, window.networkIn)
        copy.network.bytesOutPerSecond = max(0, window.networkOut)
        return copy
    }

    public static let empty = MetricSnapshot(
        timestamp: .distantPast,
        hostName: "",
        uptime: 0,
        cpu: .zero,
        memory: .zero,
        energy: .zero,
        disk: .zero,
        network: .zero,
        processes: [],
        topCPUProcesses: nil
    )
}
