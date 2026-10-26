# B · 归因闭环

> 上位文档：[`docs/roadmap-v0.4.md`](../roadmap-v0.4.md)。
> 目标：把“什么时候高”变成“**当时是谁**”。这是 0.4 唯一的产品功能轨道；先做第一刀，不做 30 天视图。

---

## 1. 目的与非目标

### 目的

1. 历史分钟点记录 **CPU 前 3 的进程**；点 24 小时峰值能看到当时是谁。
2. 高负载通知带 **进程名 + 一句人话**，而不是只说“CPU 高”。
3. 清理结果不再把 **RSS 求和** 说成“已释放内存”；先改文案，测量可选。

### 非目标

- 不做 30 天视图、不做导出 CSV、不做跨设备同步。
- 不做 GPU 进程归因（当前采样拿不到可靠的 per-process GPU 占用）。
- 不存完整路径、用户名、命令行参数；历史只存进程显示名、CPU、内存。
- 不改告警阈值与默认关闭策略。
- 不把清理升级成 SIGKILL；现有 SIGTERM + 3 秒等待不变。

---

## 2. 现状与缺口

### 2.1 历史

`HistorySample`（`src/Sources/MacStatsCore/HistoryStore.swift`）目前是：

```swift
timestamp, cpu, memory, gpu?, diskUsed
```

`Bucket` 按分钟累加 CPU / 内存 / GPU / 磁盘，跨分钟写一行 JSONL。它能画出“15:20 CPU 92%”，但**没有进程字段**。

### 2.2 告警

`ThresholdAlertEvaluator.evaluate(cpu:memory:diskUsed:at:)` 只接收三个比例；`AlertEvent` 只有 `kind/value/threshold/consecutive`。所以通知正文只能说“92%，已连续超过阈值”。

### 2.3 采样

`SystemSampler.sampleProcesses` 先算出**全部进程**的 `ProcessStatus`，再按内存降序取前 `processLimit`（默认 32）放进 `MetricSnapshot.processes`。

这意味着：**CPU 很高但内存不大的进程可能不在 `snapshot.processes` 里**。如果直接对 `snapshot.processes` 排序取 top CPU，会漏掉真正的元凶。B3 必须在截断前单独保留一份 top CPU 列表。

### 2.4 清理

`CleanupResult.freedBytes` 是 `terminated.reduce(0) { $0 + $1.memoryBytes }`，即候选进程终止前的 RSS 合计。它**不是**系统实际回收量：macOS 会保留缓存、共享页、压缩页，RSS 也不等于物理内存。

结果框却写“预计释放约 %@ 内存”。这是一个信任风险：用户看到“释放 2 GB”，活动监视器却没变，就会认为整块面板在骗人。

---

## 3. 接口契约（B0 先落地，其他任务依赖它）

> 契约文件：`src/Sources/MacStatsCore/ProcessAttribution.swift`（新建）。先合并它，再开 B1/B2/B3。

```swift
import Foundation

/// 一条进程归因。按显示名聚合，避免同一个 node 出现三次。
/// 只用于本机历史与通知，不上报、不写路径/用户名/命令行。
public struct ProcessAttribution: Codable, Sendable, Equatable {
    /// `ProcessStatus.name`，已去掉 `.app` 后缀。
    public var name: String
    /// 单核比例：1.0 表示一个核心 100%（与 ProcessStatus.cpu 同口径）。
    public var cpu: Double
    /// 进程 footprint，字节。
    public var memory: UInt64

    public init(name: String, cpu: Double, memory: UInt64) {
        self.name = name
        self.cpu = max(0, cpu)
        self.memory = memory
    }
}
```

### 3.1 `HistorySample` 的变更

```swift
public struct HistorySample: Codable, Sendable, Equatable {
    public var timestamp: Date
    public var cpu: Double
    public var memory: Double
    public var gpu: Double?
    public var diskUsed: Double
    /// 该分钟 CPU 最高的最多 3 个进程；0.4 之前的历史为 nil。
    /// 必须是 optional：旧 JSONL 没有这个键，合成 Decodable 会走 decodeIfPresent。
    public var topProcesses: [ProcessAttribution]?

    public init(
        timestamp: Date,
        cpu: Double,
        memory: Double,
        gpu: Double?,
        diskUsed: Double,
        topProcesses: [ProcessAttribution]? = nil
    ) { ... }
}
```

**兼容性硬要求**：

- `topProcesses` 必须是 `Optional`，不能是带默认值的非 optional；否则旧 JSONL 解码会失败。
- 旧文件读出来是 `nil`，UI 显示“当时未记录进程”，不伪造。
- 新写的点最多 3 条，按 `cpu` 降序、`name` 升序稳定排序。

### 3.2 `HistoryStore.record` 的变更

```swift
@discardableResult
public func record(
    cpu: Double,
    memory: Double,
    gpu: Double?,
    diskUsed: Double,
    topProcesses: [ProcessAttribution] = [],
    at date: Date = Date()
) -> Bool
```

`topProcesses` 有默认值，现有调用 `record(cpu:memory:gpu:diskUsed:at:)` 仍可编译。

### 3.3 分钟聚合语义

`Bucket` 增加：

```swift
private var attributionPeaks: [String: (cpu: Double, memory: UInt64)] = [:]
```

每次 `add`：

1. 先按 `name` 合并同一秒内的重复进程：`cpu` 求和、`memory` 求和；
2. 对每个名字，更新该分钟内的**峰值**：`cpu = max(old, new)`，`memory = max(old, new)`；
3. 分钟落盘时，按 `cpu` 降序、`name` 升序取前 3，写入 `topProcesses`；没有进程则 `nil`。

为什么取峰值而不是平均：用户问“那阵卡是谁”，峰值比一分钟平均更接近元凶；平均会被空闲秒数稀释。

### 3.4 `MetricSnapshot` 的变更

```swift
public struct MetricSnapshot: Codable, Sendable, Equatable {
    // ... 现有字段 ...
    /// 按 CPU 排序、已按名字聚合的 top N（在按内存截断之前算），只用于归因。
    /// Optional 是为了旧 JSON 仍能解码；新采样会填。
    public var topCPUProcesses: [ProcessAttribution]?

    /// 读取便利；不参与 Codable。
    public var topCPU: [ProcessAttribution] { topCPUProcesses ?? [] }
}
```

> 这里存的是 `ProcessAttribution`，不是 `[ProcessStatus]`：采样层先在**全部 records** 上按名字聚合，再取 top N。
> 如果只取原始 top 8 再聚合，两个同名进程各自排在第 9、10 名时会被漏掉；聚合后再排序才准确。

`MetricSnapshot` 是手写 `init`，新增字段时必须给 `init` 加最后一个默认参数 `topCPUProcesses: [ProcessAttribution]? = nil`，并赋值；`applying(_:)` 用 `var copy = self`，会自然保留。

`SystemSampler.sampleProcesses` 在 `records` 生成后、`sorted(by: memory)` 之前：

```swift
let topCPU = ProcessRanking.attributions(from: records, limit: 8, by: .cpu)
let sorted = records.sorted { $0.memory > $1.memory }
let limited = Array(sorted.prefix(config.processLimit))
return (limited, energy, topCPU)
```

`ProcessRanking`（新建，纯函数，可单测）：

```swift
public enum AttributionMetric: String, Sendable {
    case cpu, memory
}

public enum ProcessRanking {
    /// 按 cpu 降序、name 升序、pid 升序；只返回前 limit 个。
    public static func topByCPU(_ processes: [ProcessStatus], limit: Int = 8) -> [ProcessStatus]

    /// 按 name 聚合（cpu 求和、memory 求和），再按指定指标降序、name 升序取前 limit。
    /// 默认按 CPU；B5 的“内存告警元凶”必须显式传 .memory，不能复用 CPU 排序。
    public static func attributions(
        from processes: [ProcessStatus],
        limit: Int = 3,
        by metric: AttributionMetric = .cpu
    ) -> [ProcessAttribution]
}
```

### 3.5 告警契约

```swift
public struct AlertEvent: Sendable, Equatable {
    public var kind: AlertKind
    public var value: Double
    public var threshold: Double
    public var consecutive: Int
    /// CPU 事件填 top CPU 进程；内存事件填 top 内存进程；磁盘事件为 nil。
    public var culprit: ProcessAttribution?
}

public func evaluate(
    cpu: Double,
    memory: Double,
    diskUsed: Double,
    topCPU: ProcessAttribution? = nil,
    topMemory: ProcessAttribution? = nil,
    at date: Date = Date()
) -> AlertEvent?
```

旧调用（不传 `topCPU/topMemory`）仍编译、仍触发，只是 `culprit = nil`。

### 3.6 峰值分析契约

```swift
public enum HistoryMetric: String, Sendable, CaseIterable {
    case cpu, memory, gpu
}

public struct HistoryPeak: Sendable, Equatable {
    public var metric: HistoryMetric
    public var sample: HistorySample
    public var value: Double
}

public enum HistoryAnalysis {
    /// 返回第一个最大值（最早的峰值），空数组/全 nil GPU 返回 nil。
    public static func peak(in samples: [HistorySample], metric: HistoryMetric) -> HistoryPeak?
}
```

### 3.7 数据体积

现有约 133 字节/点、190 KB/天。增加 3 条归因（名字 + 两个数字）后，估算 **250–450 KB/天**；30 天约 8–14 MB，仍低于 50 MB 预算。

如果实测超过 500 KB/天：只在 `cpu >= 0.5` 的分钟写 `topProcesses`；其余分钟写 `nil`。先测量再优化，不要提前降采样。

---

## 4. 任务卡

> 所有任务卡的文件所有权以 [E §2](E-parallel-execution.md) 为准；同一文件同一时间只能有一个 writer。

### B0 · 归因类型与契约（0.25 天）

- **Owner**：worker-b0
- **依赖**：无
- **文件（新建，独占）**：
  - `src/Sources/MacStatsCore/ProcessAttribution.swift`
  - `src/Tests/MacStatsCoreTests/ProcessAttributionTests.swift`
- **步骤**：
  1. 按 §3 写 `ProcessAttribution`；
  2. 单测：编码/解码、负 CPU 归零、空名字（允许，但 UI 兜底为“未知进程”）。
- **验收**：`swift test --filter ProcessAttributionTests` 绿；`ProcessAttribution` 可被 `HistorySample`/`AlertEvent` 引用。
- **不要**：在这一步改 `HistoryStore`、`ThresholdAlerts`、`SystemSampler`。

### B1 · 历史点记录 top 进程（0.5 天）

- **Owner**：worker-b1
- **依赖**：B0
- **文件（独占）**：
  - `src/Sources/MacStatsCore/HistoryStore.swift`
  - `src/Tests/MacStatsCoreTests/HistoryStoreTests.swift`
- **步骤**：
  1. `HistorySample` 加 optional `topProcesses`，更新 init（默认 nil）；
  2. `Bucket` 加 `attributionPeaks`，`add` 接收 `topProcesses`，按 §3.3 聚合；
  3. `Bucket.sample()` 取前 3；`record` 增加默认参数；
  4. `hourly(days:)` 聚合时把 `sample.topProcesses ?? []` 传回 `Bucket.add`；
  5. 测试：
     - 旧 JSONL（无 `topProcesses` 键）能解码为 nil；
     - 同一分钟多秒取峰值，不取平均；
     - 同名进程合并；
     - 只保留 3 条，排序稳定；
     - 无进程时 nil；
     - `hourly` 不崩、top 进程仍最多 3 条。
- **验收**：`swift test --filter HistoryStoreTests` 绿；写盘行仍为合法 JSONL；旧历史文件可读。
- **风险**：`HistorySample` 的 memberwise init 调用点（`Bucket.sample`、测试）要全部更新；用默认参数减少破坏。

### B2 · 峰值分析纯函数（0.25 天）

- **Owner**：worker-b2
- **依赖**：B0（类型）、B1（字段）
- **文件（新建，独占）**：
  - `src/Sources/MacStatsCore/HistoryAnalysis.swift`
  - `src/Tests/MacStatsCoreTests/HistoryAnalysisTests.swift`
- **步骤**：
  1. 按 §3.6 实现 `HistoryMetric` / `HistoryPeak` / `HistoryAnalysis`；
  2. 测试：空数组、全 nil GPU、CPU/内存峰值、并列取最早、单点。
- **验收**：`swift test --filter HistoryAnalysisTests` 绿。
- **不要**：在 View 里重复实现峰值逻辑；B4 必须调这个函数。

### B3 · 采样层保留 top CPU（0.5 天）

- **Owner**：worker-b3
- **依赖**：B0
- **文件（独占）**：
  - `src/Sources/MacStatsCore/ProcessRanking.swift`（新建）
  - `src/Sources/MacStatsCore/Metrics.swift`
  - `src/Sources/MacStatsCore/SystemSampler.swift`
  - `src/Tests/MacStatsCoreTests/ProcessRankingTests.swift`（新建）
  - `src/Tests/MacStatsCoreTests/ModelTests.swift`
- **步骤**：
  1. 加 `ProcessRanking.attributions`（`by: .cpu/.memory`）；`topByCPU` 可保留作测试辅助；
  2. `MetricSnapshot` 加 optional `topCPUProcesses: [ProcessAttribution]` + 计算属性 `topCPU`；同步更新手写 `init`（末尾默认参数）与 `empty`；
  3. `sampleProcesses` 返回三元组，`topCPU` 用 `ProcessRanking.attributions(from: records, limit: 8, by: .cpu)`（**在内存截断之前**）；
  4. 测试：
     - top CPU 不受 `processLimit`（按内存截断）影响；
     - 同名聚合、排序稳定；
     - `.cpu` 与 `.memory` 两种排序各测一次（内存元凶不能取成 CPU 第一名）；
     - 两个同名进程各自排名靠后、但合计 CPU 应进 top 3 时，聚合后仍能命中；
     - 旧 `MetricSnapshot` JSON（无 `topCPUProcesses`）能解码，`topCPU` 为空。
- **验收**：`swift test --filter ProcessRankingTests` 与 `ModelTests` 绿；`macstatsDiag --self-check` 仍全 ok。
- **风险**：`MetricSnapshot` 是 `Codable`，新字段必须 optional；否则旧 `widget-feed.json` / 测试 fixture 解码失败。

### B4 · 峰值 UI（1 天）

- **Owner**：worker-b4
- **依赖**：B1、B2；**独占** `Localization.swift`
- **文件（独占）**：
  - `src/Sources/MacStats/WidgetView.swift`
  - `src/Sources/MacStatsCore/Localization.swift`
  - `src/Tests/MacStatsCoreTests/LocalizationTests.swift`
- **步骤**：
  1. `historySeries` 改为接收 `metric: HistoryMetric`，内部用 `HistoryAnalysis.peak(in: data.history, metric:)`；
  2. 峰值文字改成按钮（`.buttonStyle(.plain)`，保留原字号/颜色）；
  3. 点击设置 `@State private var selectedPeak: HistoryPeak?`，用 `.popover` 展示 `PeakDetailView`；
  4. `PeakDetailView` 内容：
     - 标题：CPU / 内存 / GPU 峰值；
     - 时间 `HH:mm` + 百分比；
     - `topProcesses` 列表：名字、CPU%、内存；每条可附 `ProcessGlossary.explain(name:)` 的第一句；
     - 无进程：`当时未记录进程（0.4 之前的历史）`；
     - GPU：`GPU 归因暂未记录`；
  5. 新增 L10n key（中英）：
     - `historyPeakDetailTitle`
     - `historyPeakAt`
     - `historyPeakProcesses`
     - `historyPeakNoProcess`
     - `historyPeakGPUNoProcess`
     - `historyPeakMemoryFormat`
  6. `LocalizationTests` 断言新 key 在中英字典都存在且非空。
- **验收**：
  - 372×640 标准、600×660 详细两档快照里峰值按钮不挤压曲线；
  - 点击 CPU/内存峰值出现 popover；点空白/再次点击关闭；
  - 旧历史（topProcesses = nil）显示“当时未记录进程”；
  - GPU 峰值不显示进程列表；
  - `swift test` 全绿。
- **视觉核对**：
  ```bash
  cd src && swift build -c release
  .build/release/MacStats --snapshot 372x640 /tmp/p087-standard.png
  .build/release/MacStats --snapshot 600x660 /tmp/p087-expanded.png
  ```
  （如当前 `--snapshot` 参数格式不同，按 `SnapshotRenderer.swift` 的实际用法执行。）
- **风险**：NSPanel 里 popover 可能抢焦点/被裁切；优先用 `.popover`，不行再改成面板内浮层。不要为此改窗口层级。

### B5 · 集成：history + alert culprit（0.5 天）

- **Owner**：worker-b5
- **依赖**：B1、B3、B4（L10n key 已就位）
- **文件（独占）**：
  - `src/Sources/MacStats/AppDelegate.swift`
  - `src/Sources/MacStatsCore/ThresholdAlerts.swift`
  - `src/Tests/MacStatsCoreTests/ThresholdAlertsTests.swift`（如不存在则新建）
- **步骤**：
  1. `recordHistory` 调 `store.record(..., topProcesses: Array(snapshot.topCPU.prefix(3)))`；
  2. `ThresholdAlertEvaluator` 增加 `topCPU`/`topMemory` 参数与 `AlertEvent.culprit`；
  3. `checkThresholdAlerts` 传：
     - `topCPU: snapshot.topCPU.first`
     - `topMemory: ProcessRanking.attributions(from: snapshot.processes, limit: 1, by: .memory).first`
  4. 通知：
     - title 不变；
     - body 有 culprit 时用 `alertBodyWithProcess`（`"%@ 82% · %@"`，第二参为进程名），无 culprit 用旧 `alertBody`；
     - subtitle 用 `ProcessGlossary.explain(name: culprit.name, language: ...).summary` 的第一句（截到 60 字），没有就不设；
  5. 测试：
     - CPU 事件带 culprit；内存事件带 memory culprit；磁盘事件 nil；
     - 不传 culprit 的旧调用仍触发；
     - 连续 3 次 + 冷却逻辑不变；
     - 通知文案格式化（有/无 culprit）。
- **验收**：
  - 实机打开告警开关，用 `yes > /dev/null` 或编译任务把 CPU 顶到 90% 连续 3 秒，通知标题/正文含进程名；
  - 关闭开关后不再通知；
  - `swift test` 全绿。
- **注意**：`snapshot.processes` 是按内存截断的 top 32，用于内存 culprit 足够；CPU 必须用 `snapshot.topCPU`。

### B6a · 清理文案诚实化（0.5 天，先于 C）

- **Owner**：worker-b6a
- **依赖**：无
- **文件（独占）**：
  - `src/Sources/MacStats/ProcessDialogs.swift`
  - `src/Sources/MacStatsCore/Localization.swift`（本波次由 B6a 独占；B4 在下一波次接手）
  - `src/Sources/MacStatsCore/ProcessCleanup.swift`（只改注释）
  - `src/Tests/MacStatsCoreTests/LocalizationTests.swift`
- **步骤**：
  1. `resultFreedBytes` 文案改为：
     - zh：`这些进程终止前的内存合计为 %@；系统实际回收量可能不同。`
     - en：`Their reported footprint was %@; actual reclaim may differ.`
  2. `CleanupResult.freedBytes` 注释改为“RSS 合计，不是实际回收”；**不改属性名**（避免破坏 API/测试）。
  3. 结果框标题保持“已清理 N 个进程”；不再出现“释放”二字。
  4. 测试：中英文案都不含“释放 / freed”；L10n key 仍存在。
- **验收**：清理结果窗口不再承诺释放量；`swift test` 全绿。
- **为什么先做**：C 发布后会有用户试清理；一句假承诺会把整块面板的可信度打掉。改文案是 30 分钟的事，测量可以后做。

### B6b · 清理实际回收测量（可选，0.5–1 天，C 有反馈再做）

- **Owner**：worker-b6b
- **依赖**：B5（AppDelegate 集成）、B6a
- **文件**：
  - `src/Sources/MacStatsCore/CleanupMeasurement.swift`（新建）
  - `src/Tests/MacStatsCoreTests/CleanupMeasurementTests.swift`（新建）
  - `src/Sources/MacStats/AppDelegate.swift`（与 B5 同一 owner 协调，仅加一个调用点）
  - `src/Sources/MacStats/ProcessDialogs.swift`（显示测量结果）
- **设计**：
  - 清理前记录 `snapshot.memory.used`；
  - 清理后 45–60 秒再取一次；
  - `delta = after - before`；只有 `delta <= -50 MB` 才说“系统回收约 X”；
  - 否则说“系统未明显回收；macOS 会按需复用缓存”，不硬凑数字；
  - 测量结果写本地日志（可选），不上报。
- **验收**：单测覆盖正/负/小于阈值；实机用一个分配 500 MB 的测试进程验证方向正确；不阻塞 0.4.0。
- **注意**：不要在清理后立刻弹第二个通知；把结果放在“设置 → 后台清理 → 上次清理”一行，或下次打开结果框时显示。

### B7 · 文档与发布说明（0.5 天）

- **Owner**：worker-b7
- **依赖**：B1–B6
- **文件**：
  - `docs/requirements.md`（历史/告警口径加“top 进程”）
  - `docs/architecture.md`（数据流、HistorySample 字段、top CPU 采样）
  - `docs/release-notes-0.4.md`（新建）
  - `README.md` / `docs/readme/README_en.md` 的“24 小时历史”一节
- **验收**：
  - 文档不再说“历史只有曲线”，而是“峰值可点开看当时进程”；
  - 明确“GPU 归因暂未记录”“0.4 之前的历史没有进程”；
  - 清理文案与 B6a 一致；
  - 10 份 README 的数字/链接由 D2 脚本同步，不手工改 8 份翻译正文。

---

## 5. 完成定义

- [ ] B0 契约合并，B1/B2/B3 可并行开发。
- [ ] 旧 `history-*.jsonl`（无 `topProcesses`）能正常读取，不丢点、不崩溃。
- [ ] 新历史点最多 3 条归因，按 CPU 降序；同名进程合并。
- [ ] 24 小时卡的 CPU/内存峰值可点开，看到时间、数值、top 3 进程。
- [ ] GPU 峰值显示“GPU 归因暂未记录”，不伪造。
- [ ] CPU/内存告警通知带进程名；磁盘告警仍只有数值。
- [ ] 清理结果不再把 RSS 求和说成“已释放”。
- [ ] 全量 `swift test` ≥103 项全绿；`macstatsDiag --self-check` 全 ok。
- [ ] 372×640 / 600×660 快照无布局回归。
- [ ] `docs/requirements.md`、`docs/architecture.md`、`docs/release-notes-0.4.md` 已同步。

---

## 6. 测试清单（按文件）

| 测试 | 覆盖 |
|---|---|
| `ProcessAttributionTests` | 编解码、负值、空名字 |
| `HistoryStoreTests` | 旧 JSON 兼容、分钟峰值、同名合并、top 3、排序、hourly |
| `HistoryAnalysisTests` | CPU/内存/GPU 峰值、空数组、并列取最早 |
| `ProcessRankingTests` | top CPU 不受内存截断影响、同名聚合、稳定排序 |
| `ModelTests` | `MetricSnapshot` 旧 JSON 兼容、`topCPU` 空 |
| `ThresholdAlertsTests` | culprit 归属、旧调用兼容、连续/冷却不变 |
| `LocalizationTests` | 新 key 中英非空、通知文案、清理文案不含“释放” |

---

## 7. 风险与回滚

| 风险 | 信号 | 缓解 / 回滚 |
|---|---|---|
| 旧历史读不出 | 启动后历史卡空白、控制台 decode 失败 | `topProcesses` 必须 optional；先用旧 JSONL fixture 写测试 |
| 数据变大 | 30 天 >50 MB | 只在 CPU ≥50% 的分钟存；或只存 top 1；保留旧字段 |
| CPU 元凶漏掉 | 峰值点开显示“未记录”但当时确实有高 CPU | B3 必须从全量 `records` 取 top CPU，不能用按内存截断的 `processes` |
| popover 在 NSPanel 里异常 | 点击无反应/被裁切 | 改用面板内浮层；不改窗口层级；保留峰值文字可读 |
| 通知太吵 | 用户关开关 | 阈值/连续/冷却不变；默认关闭；通知带原因反而减少“不知道为什么” |
| 清理测量误导 | 回收数字仍对不上 | B6a 先不承诺；B6b 只在 ≥50 MB 时说“约”，否则说“未明显回收” |
| 文件冲突 | 两个 agent 同时改 `Localization.swift` | 严格按 [E §2](E-parallel-execution.md)：同一文件单 writer；B6a 与 B4 分波次 |

---

## 8. 交接给 C 的素材

B 完成后，C 的 GIF 可以多一个高光镜头：

1. 桌面面板，CPU 数字跳到 90%；
2. 点“峰值”，popover 显示 `15:20 · 92%`；
3. 下面三行：`Xcode 78%` / `WindowServer 9%` / `kernel_task 4%`；
4. 一句字幕：`不是告诉你高，是告诉你是谁。`

如果 B 没赶上 C，GIF 用“1 秒刷新 + 拖拽变版式”也够发；不要把发布绑在 B 上。
