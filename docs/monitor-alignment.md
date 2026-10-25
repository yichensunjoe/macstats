# 活动监视器口径对照

> 目标：小组件里出现的每个数字，都能说出它在活动监视器（Activity Monitor）哪一格、用哪个内核计数器算出来。
>
> 所有结论都在本机（MacBook Pro，18 逻辑核，64 GB，macOS 26）实测得到，方法见最后一节。

![活动监视器内存汇总与小组件对照](monitor-compare.png)

## 0. 单位口径（先看这条，否则数字永远“看着不一样”）

活动监视器内部混用两套进位，本实现照抄：

| 位置 | 进位 | 例子 |
|---|---|---|
| 内存（物理/已使用/App/联动/被压缩/缓存/交换） | 二进制 1024，**2 位小数** | 64 GiB → `64.00 GB` |
| 磁盘「读取的数据」「写入的数据」及速率 | 十进制 1000，GB/TB 2 位、MB 1 位、KB 0 位 | 2.69e12 B → `2.69 TB` |
| 网络「收到的数据」「发出的数据」及速率 | 同上（十进制） | 1.54e11 B → `154.49 GB` |
| 进程列表内存 | 二进制 1024，1 位小数 | `966.1 MB` |

对应实现：`ByteFormat.memory` / `decimalBytes` / `decimalRate` / `processMemory`。

## 1. 内存（内存标签页底部）

| 活动监视器 | 小组件 | 计算方式（`vm_statistics64` / sysctl） |
|---|---|---|
| 物理内存 | `memory.total` | `hw.memsize` |
| 已使用内存 | `memory.used` | `total − 空闲 − external_page_count` |
| 已缓存文件 | `memory.cachedFiles` | `external_page_count + purgeable_count` |
| App 内存 | `memory.app` | `internal_page_count − purgeable_count` |
| 联动内存 | `memory.wired` | `wire_count` |
| 被压缩 | `memory.compressed` | `compressor_page_count` |
| 已使用的交换 | `memory.swapUsed` | `vm.swapusage.xsu_used` |
| 空闲（隐式） | `memory.free` | `free_count − speculative_count` |

要点：

- **已使用 ≠ App + 联动 + 被压缩。** 活动监视器用的是「总量 − 空闲 − 文件缓存」，
  所以它的「已使用」会大于右侧三项之和（本机实测差 2 GB 上下）。
- **内核的 `free_count` 含 speculative 页，活动监视器会扣掉。** 用 `free_count` 直接算会低 1～1.5 GB。
- 可清除页（purgeable）同时算进 App 内存和已缓存文件，因此三者相加会略微超过物理内存，这是活动监视器自身的行为。

用辅助访问（AX）读活动监视器同一刻的显示值后，逐项对照如下（单位 GB）：

| 轮次 | 已使用 AM / 小组件 | 已缓存 AM / 小组件 | App AM / 小组件 | 联动 AM / 小组件 | 压缩 AM / 小组件 | 交换 AM / 小组件 |
|---|---|---|---|---|---|---|
| 1 | 47.57 / 47.56 | 16.81 / 16.82 | 35.80 / 35.81 | 5.22 / 5.18 | 4.54 / 4.54 | 1.65 / 1.65 |
| 2 | 46.46 / 46.50 | 16.85 / 16.76 | 35.36 / 35.33 | 4.46 / 4.62 | 4.54 / 4.54 | 1.65 / 1.65 |
| 3 | 47.76 / 47.73 | 16.66 / 16.81 | 36.10 / 36.15 | 5.55 / 5.34 | 4.53 / 4.53 | 1.65 / 1.65 |
| 4 | 47.92 / 47.92 | 16.69 / 16.70 | 36.16 / 36.16 | 5.48 / — | 4.53 / 4.53 | 1.65 / 1.65 |

残差 ≤ 0.2 GB，来源是活动监视器自己的 5 秒刷新缓存（它显示的是上一次刷新时的快照，不是此刻的值）。

## 2. CPU（CPU 标签页底部）

- 数据源：`host_processor_info(PROCESSOR_CPU_LOAD_INFO)`，每个逻辑核 user / system / idle / nice 累计 tick 差分。
- 总量 = 全部核心 busy / 全部核心 total，与活动监视器的「用户 + 系统」同口径。
- 小组件按 5 个采样（默认 1 秒一次）滑动平均，等于活动监视器默认「每 5 秒更新」的窗口长度。
- 稳定负载实测（4 个 `yes` 进程）：AM 47.63% / 49.19%，面板 50.35% / 49.96%。
  波动负载下差 2～4 个百分点属窗口相位差，活动监视器自身相邻两次刷新也会跳动同样幅度。

## 3. 磁盘（磁盘标签页底部）

- 数据源：`IOBlockStorageDriver` 的 `Statistics.Bytes (Read)` / `Bytes (Write)` 累计值差分。
- 对应活动监视器的「读取的数据」「写入的数据」及其 `/秒`（不是「读入/秒」那列的 IOPS）。
- 实测同步同一刻：读取 2.71 TB / 2.71 TB，写入 2.53 TB / 2.53 TB，累计值逐字节一致；
  速率 15.2 MB/s vs 15.3 MB/s。写入速率在突发时会有窗口相位差（AM 4.3 MB/s、面板 1.8 MB/s 这类）。
- 单位是十进制：`2.69e12` 字节在活动监视器里是 `2.69 TB`，不是 `2.45 TiB`。

## 4. 网络（网络标签页底部）

- 累计值：`sysctl` 的 **IFMIB**（`CTL_NET, AF_LINK, 0, IFMIB_IFDATA, ifindex, IFDATA_GENERAL`）遍历全部接口，
  `ifmd_data.ifi_ibytes / ifi_obytes` 求和，**包含 `lo0`**。
- 速率：同样的计数，但**排除 `lo0`**（活动监视器也是这么显示的）。
- 实测同步：收到的数据 156.66 GB vs 156.65 GB，发出的数据 153.86 GB vs 153.85 GB，累计值一致。
  速率（排除 lo0）：AM 90 KB/s / 34 KB/s，面板 44 KB/s / 40 KB/s，同量级。
- 两个必须踩过的坑：
  1. **`NET_RT_IFLIST2` 路由消息里的 `ifi_ibytes` 是截断的。** 本机 `lo0` 真实值 122.9 GB，
     路由消息只填低 32 位、读到 2.6 GB；`en0` 同样从 10.6 GB 截成 1.9 GB。
     用路由消息求和只能得到 7.2 GB，而活动监视器是 154 GB。**必须走 IFMIB。**
  2. **`lo0` 的环回流量要按列区分。** 本机 `lo0` 常驻约 1.5 MB/s（内核侧），
     累计值里活动监视器算它，速率列里不算；两边口径要分开实现，否则速率会比活动监视器大 60 倍。

## 5. 能耗（能耗标签页）

- 数据源：`proc_pid_rusage(RUSAGE_INFO_V6).ri_energy_nj` 逐进程差分求和，换算成瓦。
- 活动监视器的「能耗影响」是相对分数、「12 小时能耗」是历史均值，都不等价于瓦数；
  因此这一格标注为「CPU 能量计数」，不与活动监视器做数值对照。电池电量/充电状态来自 IOPowerSources。

## 6. 进程内存（内存标签页列表）

- 数据源：`proc_pid_rusage(RUSAGE_INFO_V6).ri_phys_footprint`，按大小降序。
- 按 PID 逐条对照（同一刻）：Codex (Renderer) 928.6 / 928.6 MB，mediaanalysisd 650.7 / 650.7 MB，
  访达 564.1 / 564.1 MB，微信 499.0 / 499.0 MB，DockHelper 469.0 / 469.0 MB，误差 0。
  少数条目差 2～50 MB，是两次读取间隔里内存本身在变。
- 已知差异：其它用户的进程读不到。`_windowserver` 的 WindowServer 在活动监视器里常排第一（约 0.9 GB），
  但普通进程调 `proc_pid_rusage` 得 EPERM、`proc_pidinfo(PROC_PIDTASKINFO)` 返回 0 字节，所以列表里没有它。

## 7. 对照方法（可复现）

1. 打开辅助访问后，直接用 AX API 读活动监视器：
   - 标签页是 `AXRadioButton`，`AXValue == 1` 表示选中，`AXPress` 切换；
   - 底部数值是 `AXStaticText`，按「标签右侧最近、纵向 ±14pt 内」配对成字段；
   - 窗口底部 235pt 之外的都是进程行，过滤掉即可。
   比早先的「截图 + Vision OCR」快两个数量级，而且能做毫秒级同步对照。
2. 同一进程内同时读 AX 值并调 `MacStatsCore.SystemSampler.sample()`，
   避免工具间时差；内存取 3～4 轮，速率取 5 个 1 秒采样的均值。
3. 单位提示：活动监视器用 `U+2006`（六分之一空格）分隔数值与单位，解析时要抽数字而不是匹配 `" GB"`。
4. 通过标准：累计值逐字节一致；内存残差 ≤ 0.2 GB（AM 自身刷新缓存）；
   速率与 CPU 在同量级且方向一致，差值归因于两者窗口相位。
