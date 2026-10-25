import Foundation
import IOKit

/// 读 GPU 利用率与统一内存占用。
///
/// macOS 没有公开的 GPU 计数 API，但 Mach 内核会把各加速器的运行统计挂在
/// `IOAccelerator` 的 `PerformanceStatistics` 属性里（活动监视器的 GPU 页签、
/// iStat 一类工具都读它）。这里只用 IORegistry 的公开读取接口，不需要 root，
/// 也不链接任何私有框架。
public enum GPUReader {
    public static func read() -> GPUStatus? {
        guard let matching = IOServiceMatching("IOAccelerator") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            guard
                let stats = property(service, "PerformanceStatistics") as? [String: Any],
                let percent = (stats["Device Utilization %"] as? NSNumber)?.doubleValue
            else { continue }

            let info = GPUStatus(
                utilization: min(max(percent / 100, 0), 1),
                renderer: percentValue(stats["Renderer Utilization %"]),
                tiler: percentValue(stats["Tiler Utilization %"]),
                memoryInUse: (stats["In use system memory"] as? NSNumber)?.uint64Value,
                memoryAllocated: (stats["Alloc system memory"] as? NSNumber)?.uint64Value,
                coreCount: (property(service, "gpu-core-count") as? NSNumber)?.intValue,
                model: property(service, "model") as? String
            )
            return info
        }
        return nil
    }

    private static func property(_ service: io_service_t, _ name: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, name as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()
    }

    private static func percentValue(_ value: Any?) -> Double? {
        (value as? NSNumber).map { min(max($0.doubleValue / 100, 0), 1) }
    }
}
