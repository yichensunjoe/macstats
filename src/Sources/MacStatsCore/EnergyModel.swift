import Foundation

/// 能耗换算。macOS 通过 `proc_pid_rusage` 的 `ri_energy_nj` 暴露每个进程累计能耗（纳焦耳），
/// 差分后除以采样间隔即为该进程功率。拿不到能量计数时退回 CPU 占用估算。
public enum EnergyModel {
    /// 单核满载的粗略功耗估算，用于没有能量计数器时的降级路径。
    public static let estimatedWattsPerCore = 0.42

    /// 纳焦耳差的平均功率。
    public static func watts(energyNanojoules: Double, over seconds: TimeInterval) -> Double {
        guard seconds > 0, energyNanojoules > 0 else { return 0 }
        return energyNanojoules / 1_000_000_000.0 / seconds
    }

    /// 汇总所有进程：
    /// - 只要有一个进程报告了能量差，就用能量计数器（真实值）。
    /// - 全部为 0（例如首次采样或系统未暴露）则用 CPU 占用估算，并标记 `isEstimated`。
    public static func totalWatts(
        entries: [(energyNanojoules: Double, cpuFraction: Double)],
        over seconds: TimeInterval
    ) -> (watts: Double, isEstimated: Bool) {
        let energyTotal = entries.reduce(0.0) { $0 + max(0, $1.energyNanojoules) }
        if energyTotal > 0, seconds > 0 {
            return (energyTotal / 1_000_000_000.0 / seconds, false)
        }
        let estimated = entries.reduce(0.0) { $0 + max(0, $1.cpuFraction) } * estimatedWattsPerCore
        return (estimated, true)
    }

    /// 进程级功率：优先能量差，缺失时用 CPU 占用估算。
    public static func processWatts(
        energyNanojoules: Double,
        cpuFraction: Double,
        over seconds: TimeInterval
    ) -> Double {
        if energyNanojoules > 0, seconds > 0 {
            return energyNanojoules / 1_000_000_000.0 / seconds
        }
        return max(0, cpuFraction) * estimatedWattsPerCore
    }
}
