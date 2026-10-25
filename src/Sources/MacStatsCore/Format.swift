import Foundation

/// 数据展示格式化。全部为纯函数，方便单测。
///
/// 单位口径跟随活动监视器：内存用二进制（64 GiB 显示为 `64.00 GB`），
/// 磁盘与网络用十进制（2.69e12 字节显示为 `2.69 TB`）。
public enum ByteFormat {
    private static let binaryUnits = ["B", "KB", "MB", "GB", "TB", "PB"]
    private static let decimalUnits = ["B", "KB", "MB", "GB", "TB", "PB"]

    /// 字节数，二进制进位（1 KB = 1024 B），保留 1 位小数，例如 `39.7 GB`。
    public static func bytes(_ value: UInt64) -> String {
        format(Double(value))
    }

    public static func bytes(_ value: Double) -> String {
        format(max(0, value))
    }

    /// 内存类数值，二进制进位并固定 2 位小数，与活动监视器的 `46.77 GB` 一致。
    public static func memory(_ value: UInt64) -> String {
        memory(Double(value))
    }

    public static func memory(_ value: Double) -> String {
        let scaled = max(0, value)
        guard scaled >= 1 else { return String(format: "%.0f B", scaled) }
        var size = scaled
        var index = 0
        while size >= 1024, index < binaryUnits.count - 1 {
            size /= 1024
            index += 1
        }
        return String(format: "%.2f %@", size, binaryUnits[index])
    }

    /// 极简条用的紧凑内存值：`43G`、`9.8G`、`966M`，不带空格与两位小数。
    public static func compactMemory(_ value: UInt64) -> String {
        compactBinary(Double(value))
    }

    /// 极简条用的紧凑速率：`37M/s`、`113K/s`（十进制进位）。
    public static func compactRate(_ bytesPerSecond: Double) -> String {
        compactDecimal(max(0, bytesPerSecond)) + "/s"
    }

    /// 单进程内存，二进制进位保留 1 位小数，与活动监视器的 `966.1 MB` 一致。
    public static func processMemory(_ value: UInt64) -> String {
        let scaled = max(0, Double(value))
        guard scaled >= 1 else { return String(format: "%.0f B", scaled) }
        var size = scaled
        var index = 0
        while size >= 1024, index < binaryUnits.count - 1 {
            size /= 1024
            index += 1
        }
        return String(format: "%.1f %@", size, binaryUnits[index])
    }

    /// 磁盘、网络类数值，十进制进位（1 KB = 1000 B），与活动监视器一致。
    public static func decimalBytes(_ value: UInt64) -> String {
        decimalFormat(Double(value))
    }

    public static func decimalBytes(_ value: Double) -> String {
        decimalFormat(max(0, value))
    }

    /// 速率，例如 `12.0 MB/s`。
    public static func rate(_ bytesPerSecond: Double) -> String {
        format(max(0, bytesPerSecond)) + "/s"
    }

    /// 十进制速率，例如 `7.9 MB/s`、`31 KB/s`。
    public static func decimalRate(_ bytesPerSecond: Double) -> String {
        decimalFormat(max(0, bytesPerSecond)) + "/s"
    }

    private static func format(_ value: Double) -> String {
        guard value >= 1 else { return String(format: "%.0f B", value) }
        var scaled = value
        var index = 0
        while scaled >= 1024, index < binaryUnits.count - 1 {
            scaled /= 1024
            index += 1
        }
        let digits = scaled >= 100 ? 0 : 1
        return String(format: "%.\(digits)f %@", scaled, binaryUnits[index])
    }

    private static func compactBinary(_ value: Double) -> String {
        guard value >= 1 else { return "0B" }
        var scaled = value
        var index = 0
        while scaled >= 1024, index < binaryUnits.count - 1 {
            scaled /= 1024
            index += 1
        }
        let digits = scaled >= 10 ? 0 : 1
        return String(format: "%.\(digits)f%@", scaled, binaryUnits[index])
    }

    private static func compactDecimal(_ value: Double) -> String {
        guard value >= 1 else { return "0B" }
        var scaled = value
        var index = 0
        while scaled >= 1000, index < decimalUnits.count - 1 {
            scaled /= 1000
            index += 1
        }
        let digits = scaled >= 10 ? 0 : 1
        return String(format: "%.\(digits)f%@", scaled, decimalUnits[index])
    }

    /// 活动监视器的十进制显示：KB 不带小数，MB 1 位，GB/TB 2 位。
    private static func decimalFormat(_ value: Double) -> String {
        guard value >= 1 else { return String(format: "%.0f B", value) }
        var scaled = value
        var index = 0
        while scaled >= 1000, index < decimalUnits.count - 1 {
            scaled /= 1000
            index += 1
        }
        let digits: Int
        switch index {
        case 0, 1: digits = 0
        case 2: digits = 1
        default: digits = 2
        }
        return String(format: "%.\(digits)f %@", scaled, decimalUnits[index])
    }
}

public enum PercentFormat {
    /// 0...1 的比例转成百分比整数，例如 `38%`（菜单栏这种窄位置用）。
    public static func percent(_ fraction: Double) -> String {
        let clamped = min(max(fraction, 0), 1)
        return String(format: "%.0f%%", clamped * 100)
    }

    /// 保留一位小数，与活动监视器的 `9.7%` 一致。
    public static func precise(_ fraction: Double) -> String {
        let clamped = min(max(fraction, 0), 1)
        return String(format: "%.1f%%", clamped * 100)
    }

    /// 单进程 CPU：按单核计，多核可超过 100%（与活动监视器的进程列表一致），只保底不封顶。
    public static func processCPU(_ fraction: Double) -> String {
        String(format: "%.1f%%", max(0, fraction) * 100)
    }
}

public enum DurationFormat {
    /// 例如 `3天4小时`、`4小时12分`、`12分30秒`。
    public static func uptime(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)天\(hours)小时" }
        if hours > 0 { return "\(hours)小时\(minutes)分" }
        return "\(minutes)分\(total % 60)秒"
    }

    /// 电池剩余时间，例如 `2小时15分`。
    public static func minutes(_ value: Int) -> String {
        guard value > 0 else { return "—" }
        if value >= 60 { return "\(value / 60)小时\(value % 60)分" }
        return "\(value)分"
    }
}

public enum EnergyFormat {
    public static func watts(_ value: Double) -> String {
        String(format: "%.1f W", max(0, value))
    }

    /// 极简条用的紧凑瓦数：`12W`、`9.8W`。
    public static func compactWatts(_ value: Double) -> String {
        let clamped = max(0, value)
        return String(format: clamped >= 10 ? "%.0fW" : "%.1fW", clamped)
    }
}
