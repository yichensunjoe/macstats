import Foundation

/// `host_statistics64` 一次采样的原始字节数，供 `MemoryMath` 换算成活动监视器口径。
public struct VMSnapshot: Sendable, Equatable {
    public var totalBytes: UInt64
    /// `vm_statistics64.free_count`；（内核把 speculative 页也算在 free 里，
    /// 活动监视器会再扣掉它们，见 `MemoryMath`）。
    public var freeBytes: UInt64
    /// `vm_statistics64.speculative_count`。
    public var speculativeBytes: UInt64
    public var activeBytes: UInt64
    public var inactiveBytes: UInt64
    public var wiredBytes: UInt64
    public var compressedBytes: UInt64
    public var purgeableBytes: UInt64
    /// App 内存：匿名可回收页（internal - purgeable）。
    public var appBytes: UInt64
    /// 文件缓存页（file-backed）。
    public var fileBackedBytes: UInt64
    public var swapUsedBytes: UInt64
    public var swapTotalBytes: UInt64
    public var pressure: MemoryPressure

    public init(
        totalBytes: UInt64,
        freeBytes: UInt64,
        speculativeBytes: UInt64 = 0,
        activeBytes: UInt64,
        inactiveBytes: UInt64,
        wiredBytes: UInt64,
        compressedBytes: UInt64,
        purgeableBytes: UInt64,
        appBytes: UInt64,
        fileBackedBytes: UInt64,
        swapUsedBytes: UInt64,
        swapTotalBytes: UInt64,
        pressure: MemoryPressure
    ) {
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.speculativeBytes = speculativeBytes
        self.activeBytes = activeBytes
        self.inactiveBytes = inactiveBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.purgeableBytes = purgeableBytes
        self.appBytes = appBytes
        self.fileBackedBytes = fileBackedBytes
        self.swapUsedBytes = swapUsedBytes
        self.swapTotalBytes = swapTotalBytes
        self.pressure = pressure
    }
}

public enum MemoryMath {
    /// 与活动监视器（内存标签页底部）逐项对齐，口径由 12 组同步采样反推、误差 < 0.08 GB：
    /// - 空闲 = free_count - speculative_count（内核的 free 含 speculative 页，活动监视器扣掉）
    /// - 已使用 = 物理内存 - 空闲 - 文件缓存页；因此会略大于 App + 联动 + 被压缩 之和
    /// - 已缓存文件 = 文件缓存 + 可清除页（可清除页同时算进 App 与缓存，故三者相加会略超物理内存）
    /// - App / 联动 / 被压缩 分别对应 internal-purgeable / wired / compressor 页
    /// - 压力条 = (联动 + 被压缩 + 一半 App 内存) / 物理内存
    public static func status(from vm: VMSnapshot) -> MemoryStatus {
        let total = vm.totalBytes
        let free = min(vm.freeBytes > vm.speculativeBytes ? vm.freeBytes - vm.speculativeBytes : 0, total)
        let reclaimed = free &+ min(vm.fileBackedBytes, total)
        let used = total > reclaimed ? total &- reclaimed : 0

        let cached = vm.fileBackedBytes &+ vm.purgeableBytes

        let score: Double
        if total == 0 {
            score = 0
        } else {
            let numerator = Double(vm.wiredBytes) + Double(vm.compressedBytes) + Double(vm.appBytes) * 0.5
            score = min(max(numerator / Double(total), 0), 1)
        }

        return MemoryStatus(
            total: total,
            used: used,
            app: vm.appBytes,
            wired: vm.wiredBytes,
            compressed: vm.compressedBytes,
            cachedFiles: cached,
            free: free,
            swapUsed: vm.swapUsedBytes,
            swapTotal: vm.swapTotalBytes,
            pressure: vm.pressure,
            pressureScore: score
        )
    }
}
