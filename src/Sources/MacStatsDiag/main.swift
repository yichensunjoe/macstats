import Foundation
import MacStatsCore

/// 诊断命令行：验证采样层能否在本机拿到真实数据，并做基本不变量自检。
/// 用法：
///   macstatsDiag            # 秒级两次采样 + 人类可读摘要
///   macstatsDiag --json     # 输出 JSON 快照（一次预热 + 一次正式采样）
///   macstatsDiag --self-check
///   macstatsDiag --cleanup-dry-run   # 只列出会被「一键清理」选中的进程，不杀任何进程
///   macstatsDiag --cleanup-dry-run --relaxed   # 同上，但把时阈放宽到 1 秒（验证链路用）
///   macstatsDiag --cleanup-dry-run --whitelist <名字>   # 验证白名单（可重复传入）
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

let arguments = Array(CommandLine.arguments.dropFirst())
let wantsJSON = arguments.contains("--json")
let wantsSelfCheck = arguments.contains("--self-check")
let wantsRaw = arguments.contains("--raw")
let wantsCleanupDryRun = arguments.contains("--cleanup-dry-run")
let warmup = arguments.contains("--no-warmup") ? 0.0 : 1.05

// 诊断每次调用都要拿到当次结果，因此关掉进程扫描节流。
let sampler = SystemSampler(config: SamplerConfig(processLimit: 32, processInterval: 0))
_ = sampler.sample()
if warmup > 0 { Thread.sleep(forTimeInterval: warmup) }
let snapshot = sampler.sample()
_ = sampler.sample()

func check(_ condition: Bool, _ label: String) -> Bool {
    print(condition ? "ok   \(label)" : "FAIL \(label)")
    return condition
}

if wantsRaw {
    // 打印原始 VM 计数与活动监视器口径的候选公式，用于对齐“已使用/已缓存文件”。
    var stats = vm_statistics64_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    let hostPort = mach_host_self()
    let result = withUnsafeMutablePointer(to: &stats) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
        }
    }
    mach_port_deallocate(mach_task_self_, hostPort)
    if result == KERN_SUCCESS {
        let page = UInt64(getpagesize())
        func gb(_ pages: UInt32) -> Double { Double(UInt64(pages) * page) / 1_073_741_824 }
        let total = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        print("pageSize=\(page) total=\(String(format: "%.2f", total)) GB")
        print("-- raw pages --")
        print("free          \(String(format: "%.2f", gb(stats.free_count)))")
        print("speculative   \(String(format: "%.2f", gb(stats.speculative_count)))")
        print("external      \(String(format: "%.2f", gb(stats.external_page_count)))")
        print("internal      \(String(format: "%.2f", gb(stats.internal_page_count)))")
        print("purgeable     \(String(format: "%.2f", gb(stats.purgeable_count)))")
        print("wired         \(String(format: "%.2f", gb(stats.wire_count)))")
        print("compressor    \(String(format: "%.2f", gb(stats.compressor_page_count)))")
        print("anonymous     \(String(format: "%.2f", gb(stats.internal_page_count - stats.purgeable_count)))")
        func f(_ value: Double) -> String { String(format: "%.2f", value) }
        let snapshot = sampler.sample()
        let m = snapshot.memory
        let toGB = 1_073_741_824.0
        print("-- 活动监视器口径 --")
        print("物理内存  \(f(Double(m.total) / toGB))")
        print("已使用    \(f(Double(m.used) / toGB))   = total - (free - speculative) - file-backed")
        print("已缓存文件 \(f(Double(m.cachedFiles) / toGB))   = file-backed + purgeable")
        print("App      \(f(Double(m.app) / toGB))   = internal - purgeable")
        print("联动      \(f(Double(m.wired) / toGB))   = wire_count")
        print("被压缩    \(f(Double(m.compressed) / toGB))   = compressor_count")
        print("空闲      \(f(Double(m.free) / toGB))   = free_count - speculative_count")
        print("交换      \(f(Double(m.swapUsed) / toGB))")
        _ = total
    }
    // 内存总量 / 交换
    var swap = xsw_usage()
    var swapSize = MemoryLayout<xsw_usage>.size
    if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 {
        print("swap used \(String(format: "%.2f", Double(swap.xsu_used) / 1_073_741_824)) GB")
    }
    exit(0)
}

if wantsCleanupDryRun {
    // 纯只读：同一个 ProcessCleaner，但只调用 evaluate，不调用 terminate。
    // --relaxed 只为验证「扫描 → 筛选 → 列出」这条链路，不会改变应用里的默认阈值。
    var rules = CleanupRules()
    if arguments.contains("--relaxed") {
        rules.minimumAge = 1
        rules.minimumIdle = 1
    }
    if let index = arguments.firstIndex(of: "--whitelist"), index + 1 < arguments.count {
        rules.whitelist = Set(arguments[(index + 1)...].prefix { !$0.hasPrefix("--") })
    }
    let cleaner = ProcessCleaner(rules: rules)
    let plan = cleaner.evaluate()
    print("扫描 \(plan.scanned) 个进程；候选 \(plan.candidates.count) 个，合计 \(ByteFormat.memory(plan.estimatedBytes))")
    for candidate in plan.candidates {
        print("  \(candidate.displayName.padding(toLength: 26, withPad: " ", startingAt: 0)) PID \(candidate.pid)\t\(ByteFormat.processMemory(candidate.memoryBytes))\t已闲置 \(DurationFormat.uptime(candidate.idleSeconds))\t运行 \(DurationFormat.uptime(candidate.ageSeconds))")
    }
    print("跳过原因:")
    for reason in CleanupSkipReason.allCases {
        let count = plan.skipped[reason] ?? 0
        if count > 0 { print("  \(reason.rawValue.padding(toLength: 16, withPad: " ", startingAt: 0)) \(count)") }
    }
    exit(0)
}

if wantsSelfCheck {
    var passed = true
    passed = check((0...1).contains(snapshot.cpu.total), "cpu.total 在 0...1") && passed
    passed = check(!snapshot.cpu.cores.isEmpty, "cpu.cores 非空（本机逻辑核心数）") && passed
    passed = check(snapshot.cpu.cores.allSatisfy { (0...1).contains($0) }, "每个核心占用率在 0...1") && passed
    passed = check(snapshot.memory.total > 0, "memory.total > 0 (hw.memsize)") && passed
    passed = check(snapshot.memory.used <= snapshot.memory.total, "memory.used <= memory.total") && passed
    passed = check(snapshot.memory.used + snapshot.memory.free <= snapshot.memory.total,
                   "已使用 + 空闲 <= 物理内存（已使用 = 物理 - 空闲 - 文件缓存）") && passed
    passed = check(snapshot.memory.app <= snapshot.memory.used, "App 内存 <= 已使用") && passed
    passed = check(snapshot.memory.cachedFiles > 0, "已缓存文件 > 0") && passed
    passed = check(snapshot.memory.pressureScore >= 0 && snapshot.memory.pressureScore <= 1, "memory.pressureScore 在 0...1") && passed
    passed = check(snapshot.disk.capacity > 0, "disk.capacity > 0") && passed
    passed = check(snapshot.network.interfaceCount > 0, "network.interfaceCount > 0") && passed
    passed = check(snapshot.disk.readBytesPerSecond >= 0 && snapshot.disk.writeBytesPerSecond >= 0, "磁盘速率非负") && passed
    passed = check(snapshot.network.bytesInPerSecond >= 0 && snapshot.network.bytesOutPerSecond >= 0, "网络速率非负") && passed
    passed = check(!snapshot.processes.isEmpty, "进程列表非空") && passed
    passed = check(snapshot.processes.allSatisfy { !$0.name.isEmpty }, "进程名非空") && passed
    passed = check(snapshot.processes.map(\.memory) == snapshot.processes.map(\.memory).sorted(by: >), "进程按内存降序") && passed
    if let watts = snapshot.energy.watts {
        passed = check(watts >= 0, "能耗功率非负")
    }
    print(passed ? "SELF-CHECK PASSED" : "SELF-CHECK FAILED")
    exit(passed ? 0 : 2)
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
encoder.dateEncodingStrategy = .iso8601

if wantsJSON {
    do {
        let data = try encoder.encode(snapshot)
        FileHandle.standardOutput.write(data)
        print("")
    } catch {
        fail("JSON 编码失败: \(error)")
    }
    exit(0)
}

let top = snapshot.processes.prefix(5)
print("""
主机: \(snapshot.hostName)  运行: \(DurationFormat.uptime(snapshot.uptime))
CPU : \(PercentFormat.percent(snapshot.cpu.total))  用户 \(PercentFormat.percent(snapshot.cpu.user))  系统 \(PercentFormat.percent(snapshot.cpu.system))  核心 \(snapshot.cpu.cores.count)  负载 \(snapshot.cpu.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: " "))
内存: \(ByteFormat.memory(snapshot.memory.used)) / \(ByteFormat.memory(snapshot.memory.total))  App \(ByteFormat.memory(snapshot.memory.app))  联动 \(ByteFormat.memory(snapshot.memory.wired))  压缩 \(ByteFormat.memory(snapshot.memory.compressed))  缓存 \(ByteFormat.memory(snapshot.memory.cachedFiles))  交换 \(ByteFormat.memory(snapshot.memory.swapUsed))  压力 \(snapshot.memory.pressure.displayName) (\(String(format: "%.2f", snapshot.memory.pressureScore)))
能耗: \(snapshot.energy.watts.map { EnergyFormat.watts($0) } ?? "—")\(snapshot.energy.isEstimated ? " (估算)" : "")  电池 \(snapshot.energy.batteryPercent.map { "\($0)%" } ?? "无/台式机")  供电中 \(snapshot.energy.isCharging)  电池供电 \(snapshot.energy.isOnBattery)
磁盘: 读 \(ByteFormat.decimalRate(snapshot.disk.readBytesPerSecond))  写 \(ByteFormat.decimalRate(snapshot.disk.writeBytesPerSecond))  累计读 \(ByteFormat.decimalBytes(snapshot.disk.totalReadBytes))  累计写 \(ByteFormat.decimalBytes(snapshot.disk.totalWrittenBytes))  容量 \(ByteFormat.decimalBytes(snapshot.disk.capacity))  可用 \(ByteFormat.decimalBytes(snapshot.disk.free))
网络: 入 \(ByteFormat.decimalRate(snapshot.network.bytesInPerSecond))  出 \(ByteFormat.decimalRate(snapshot.network.bytesOutPerSecond))  累计入 \(ByteFormat.decimalBytes(snapshot.network.totalBytesIn))  累计出 \(ByteFormat.decimalBytes(snapshot.network.totalBytesOut))  接口 \(snapshot.network.activeInterfaces.joined(separator: ","))
内存占用最高:
""" + "\n" + top.map { "  \($0.name.padding(toLength: 28, withPad: " ", startingAt: 0)) \(ByteFormat.processMemory($0.memory))  CPU \(PercentFormat.percent($0.cpu))  \(EnergyFormat.watts($0.energyWatts))" }.joined(separator: "\n"))
