import Foundation

/// 一条进程归因。按显示名聚合，避免同一个 node 出现三次。
/// 只用于本机历史与通知，不上报、不写路径/用户名/命令行。
public struct ProcessAttribution: Codable, Sendable, Equatable {
    /// `ProcessStatus.name`，已去掉 `.app` 后缀。
    public var name: String
    /// 单核比例：1.0 表示一个核心 100%（与 `ProcessStatus.cpu` 同口径）。
    public var cpu: Double
    /// 进程 footprint，字节。
    public var memory: UInt64

    public init(name: String, cpu: Double, memory: UInt64) {
        self.name = name
        self.cpu = max(0, cpu)
        self.memory = memory
    }
}
