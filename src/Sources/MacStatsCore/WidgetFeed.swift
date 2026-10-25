import Foundation

/// 主程序写给系统小组件（WidgetKit 扩展）的一份快照。
///
/// 扩展运行在自己的沙盒里，拿不到主程序的 UserDefaults，所以两边约好一个文件：
/// 主程序写入 `~/Library/Application Support/MacStats/widget-feed.json`，
/// 扩展先读自己容器里的同名路径，读不到再回主目录读同一个文件。
public struct WidgetFeed: Codable, Sendable, Equatable {
    public var snapshot: MetricSnapshot
    public var cpuHistory: [Double]
    public var memoryHistory: [Double]
    public var networkInHistory: [Double]
    public var networkOutHistory: [Double]

    public init(
        snapshot: MetricSnapshot,
        cpuHistory: [Double] = [],
        memoryHistory: [Double] = [],
        networkInHistory: [Double] = [],
        networkOutHistory: [Double] = []
    ) {
        self.snapshot = snapshot
        self.cpuHistory = cpuHistory
        self.memoryHistory = memoryHistory
        self.networkInHistory = networkInHistory
        self.networkOutHistory = networkOutHistory
    }

    /// 组件的更新时间；没拿到数时用远过去表示「还没采到」。
    public var updatedAt: Date { snapshot.timestamp }
}

/// 小组件上真正会变的那几个数字的粗粒度指纹。
///
/// 每次采样都写盘、叫醒扩展是纯浪费：原始浮点数每秒都在抖，但界面上显示的是
/// 取整后的百分比、0.1 W、0.1 MB/s。这里按「显示的精度」量化，值没变样就不发布。
public struct WidgetFeedSignature: Equatable, Sendable {
    public var cpuPermille: Int
    public var memoryUsedMegabytes: Int
    public var memoryPermille: Int
    public var diskReadDeciMegabytes: Int
    public var diskWriteDeciMegabytes: Int
    public var networkInDeciMegabytes: Int
    public var networkOutDeciMegabytes: Int
    public var energyDeciWatts: Int
    public var loadHundredths: Int
    public var uptimeMinutes: Int
    public var batteryPercent: Int
    public var gpuPermille: Int
    public var gpuMemoryMegabytes: Int

    public init(feed: WidgetFeed) {
        let snapshot = feed.snapshot
        cpuPermille = Int((snapshot.cpu.total * 1000).rounded())
        memoryUsedMegabytes = Int((Double(snapshot.memory.used) / 1_048_576).rounded())
        memoryPermille = snapshot.memory.total > 0
            ? Int((Double(snapshot.memory.used) / Double(snapshot.memory.total) * 1000).rounded())
            : 0
        diskReadDeciMegabytes = Self.deciMegabytes(snapshot.disk.readBytesPerSecond)
        diskWriteDeciMegabytes = Self.deciMegabytes(snapshot.disk.writeBytesPerSecond)
        networkInDeciMegabytes = Self.deciMegabytes(snapshot.network.bytesInPerSecond)
        networkOutDeciMegabytes = Self.deciMegabytes(snapshot.network.bytesOutPerSecond)
        // nil（取不到）与 0 W 在界面上是「—」和「0.0 W」，必须区分开。
        energyDeciWatts = snapshot.energy.watts.map { Int(($0 * 10).rounded()) } ?? -1
        loadHundredths = Int(((snapshot.cpu.loadAverage.first ?? 0) * 100).rounded())
        uptimeMinutes = Int((snapshot.uptime / 60).rounded())
        batteryPercent = snapshot.energy.batteryPercent ?? -1
        gpuPermille = snapshot.gpu.map { Int(($0.utilization * 1000).rounded()) } ?? -1
        gpuMemoryMegabytes = snapshot.gpu?.memoryInUse.map { Int(($0 / 1_048_576)) } ?? -1
    }

    /// 0.1 MB/s 一格，与小号/中号组件里的 `ByteFormat.decimalRate` 精度对齐。
    private static func deciMegabytes(_ bytesPerSecond: Double) -> Int {
        Int((bytesPerSecond / 100_000).rounded())
    }
}

public enum WidgetFeedStore {
    /// 扩展的沙盒容器 id，主程序按这个路径把数据递进去。
    public static let extensionBundleID = "com.macstats.app.widget"

    private static let folder = "MacStats"
    private static let fileName = "widget-feed.json"

    /// 当前用户真实主目录（沙盒进程里 `NSHomeDirectory()` 会指向容器）。
    public static var realHome: URL {
        if let entry = getpwuid(getuid()), let path = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: path), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    public static func url(inHome home: URL) -> URL {
        home
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    /// 主程序调用：写到真实主目录，顺带补一份到扩展容器（存在才写）。
    public static func write(_ feed: WidgetFeed) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(feed) else { return }
        write(data, to: url(inHome: realHome))

        if hasExtensionContainer {
            write(data, to: url(inHome: containerURL))
        }
    }

    /// 扩展的沙盒容器目录；只有用户真正添加过这个小组件（或预览过）才会存在。
    public static var containerURL: URL {
        realHome
            .appendingPathComponent("Library/Containers", isDirectory: true)
            .appendingPathComponent(extensionBundleID, isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
    }

    /// 容器都不存在时，没有任何进程会读这份快照——主程序可以干脆不写、不叫醒系统。
    public static var hasExtensionContainer: Bool {
        FileManager.default.fileExists(atPath: containerURL.path)
    }

    /// 扩展调用：先读自己容器（沙盒里就是 NSHomeDirectory），再回落到主目录。
    public static func read() -> WidgetFeed? {
        let candidates = [URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true), realHome]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for home in candidates {
            guard let data = try? Data(contentsOf: url(inHome: home)) else { continue }
            if let feed = try? decoder.decode(WidgetFeed.self, from: data) {
                return feed
            }
        }
        return nil
    }

    private static func write(_ data: Data, to url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }
}
