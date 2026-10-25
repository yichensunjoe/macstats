# 架构

## 方案概述

三层结构：采样层（`MacStatsCore`，纯 Swift 逻辑，无 UI 依赖）→ 展示模型（`WidgetData`，快照 + 90 点环形历史）
→ SwiftUI 视图（`WidgetView` 及其组件）。App 层（`MacStats`）用一块桌面层 `NSPanel` 承载视图，另有一个诊断 CLI 复用同一采样层。

## 组件与边界

- `MacStatsCore/SystemSampler`：一次 `sample()` 读全部指标。CPU / 磁盘 / 网络是累计计数器差分，需要相邻两次采样；
  内存、进程列表是瞬时值。进程能耗用 `ri_energy_nj` 差分。
- `MacStatsCore/MemoryMath`：把 `vm_statistics64` 原始页数换算成活动监视器口径（唯一定义处）。
- `MacStatsCore/EnergyModel`：纳焦耳差分换瓦，缺能量计数时退回 CPU 占用估算并标记 `isEstimated`。
- `MacStatsCore/GPUReader`：从 `IOAccelerator` 的 `PerformanceStatistics` 读 GPU 利用率与统一内存占用，
  再从加速器属性取核心数与型号；读不到返回 nil，面板与小组件据此隐藏或显示「不可用」，不影响其它指标。
- `MacStatsCore/History`：`MetricRing` 定长环形缓冲、`SeriesMath.normalize` 多曲线共用纵轴。
- `MacStatsCore/Format`：字节 / 百分比 / 时长 / 瓦数格式化，纯函数，单测覆盖。
- `MacStatsCore/ProcessCleanup`：进程表快照（`proc_listpids` + `proc_pidinfo` + `proc_pid_rusage`）、
  空闲跟踪、保护规则、SIGTERM 终止。`LiveProcess` / `ProcessFacts` / `CleanupRules` 是纯数据与纯规则，
  单测不碰真进程；`ProcessInventory` 负责读内核，`ProcessCleaner` 把两者串起来。
  候选还需要两个额外字段：套接字族（`proc_pidfdinfo` + `socket_fdinfo.psi.soi_kind`）与 `argv[0]`
  （`sysctl(KERN_PROCARGS2)`）——两者都只对已通过其他规则的少量进程读取。
- `MacStats/AppDelegate`：窗口、菜单栏、定时器、偏好；把最近 5 个采样平均成展示值（`WindowAverages`）。
- `MacStatsCore/ProcessGlossary`：给普通人看的进程说明（它是什么 / 结束会怎样），纯函数、不碰系统；
  匹配顺序是 `argv[0]` 模式（MCP / 开发服务器……）→ 可执行名（node / python / esbuild……）→ 安装路径猜测 → 兜底。
  认不出来就声明「未知后台命令」，不编造用途。
- `MacStats/SettingsWindow`：设置窗口（SwiftUI `TabView` + `Form`）与 `SettingsModel` 状态镜像。
  读写全部转给 `AppDelegate` 的 `set…` 方法，与菜单栏共用同一批 setter 和持久化键，两处不会分叉；
  白名单页的名单来自 `protectableProcesses`（与清理候选同一套身份筛查）+ 已保存但当前未运行的名字。
- `MacStats/ProcessDialogs`：清理确认 / 结果 / 空状态 / 错误提示的 SwiftUI 窗口；
  `NSApp.runModal` 用按钮回传 `.OK` / `.cancel`，每个候选附 `ProcessGlossary` 的说明与影响。
- `MacStats/WidgetView` + `Components`：面板布局、趋势线、核心条、内存压力/构成条。
- `MacStats/SnapshotRenderer`：`--snapshot` 时用 `ImageRenderer` 离屏出图，便于比较排版。

## 数据流

1. `Task` 每 `interval`（默认 1 秒）调用 `sampler.sample()`；其中进程表与能耗按 `processInterval`（默认 3 秒）节流，
   两次扫描之间复用上次结果，磁盘可用空间每 10 秒查一次；CPU / 内存 / 网络仍按 1 秒采。
2. 采样结果推入各 `MetricRing`，同时对 CPU 总量/用户/系统、磁盘读写、网络上下行、能耗取最近 5 个点的均值。
3. `snapshot.applying(WindowAverages)` 生成展示快照（内存字段保持瞬时值，5 秒窗口只作用于速率类指标）。
4. 替换 `NSHostingView.rootView` 触发重绘；菜单栏标题同步更新。
5. 清理走独立节奏：每 30 秒扫一次进程表更新「最后活跃时间」，点「一键清理」时再扫一次算候选；
   候选先经过身份 / 路径 / 父子 / 套接字 / 闲置五层筛选，列出清单等用户确认后才发 SIGTERM。

## 外部依赖

- 无第三方库。系统框架：AppKit、SwiftUI、IOKit、ServiceManagement、Darwin。
- 采样接口：`host_processor_info`、`host_statistics64`、`sysctl(vm.swapusage)`、`IOBlockStorageDriver` 统计、
  `sysctl(NET_RT_IFLIST2)`、`proc_listpids` / `proc_pid_rusage`、`IOPSCopyPowerSourcesInfo`。

## 关键取舍

- **不做 WidgetKit**：系统小组件刷新受时间线限制（分钟级），无法 1 秒更新；桌面层 `NSPanel` 能贴桌面、能实时重绘。
- **5 秒滑动平均**：活动监视器默认「每 5 秒更新」，瞬时值会显得更跳；平均后既对齐 AM 又减少闪烁。
- **内存口径以 AM 为准**：即便「已使用 ≠ App + 联动 + 压缩」不符合直觉，也照 AM 实现，因为用户拿两块屏幕对比。
- **网络排除 lo0**：AM 按进程/套接字统计，本机 lo0 有约 1.4 MB/s 的内核侧流量，计入会大上百倍。
- **能耗显示瓦数**：AM 的「能耗影响」是相对分数量纲，无法复刻；直接给物理功率并标注来源。
- **最贵的一项降频**：进程表要遍历全部 PID 各读一次 `rusage`，是单次采样的主要开销，而进程内存与能耗都是慢变量，
  因此按 3 秒扫描；实测 1 秒刷新的常驻开销从 2.6% 单核降到 1.1%。
- **清理只动「遗留孤儿」**：父进程还在、自己有子进程、持有任何套接字（含 stdio 之外的 Unix socket）的进程一律跳过。
  这四条各自都算「有人在用」，覆盖面比「CPU 很低」大得多；实测本机 12 个闲置 node/python 全部被正确排除
  （MCP server、vite dev server、uvicorn、Electron 守护进程）。
- **终止用 SIGTERM 且不升级**：给进程机会保存退出；3 秒不退出的保持运行并在结果里报告，绝不 SIGKILL。
- **白名单同时匹配可执行名与 `argv[0]`**：Node 起的守护进程常把 `argv[0]` 改成自己的名字
  （实测一个 `node` 二进制的 `ps` 名是 `cliguard-daemon`），只按可执行名匹配会漏掉；
  列表里两个名字都显示（`node · cliguard-daemon`），避免用户认不出来。
- **僵尸（Z）不碰**：它已经退出，只等父进程回收，杀它没有意义，也不该去杀父进程。
- **launchd 保活的任务会回来**：`launchctl submit` 提交的探针被 SIGTERM 后 launchd 立刻重建（实测 `runs = 2`），
  因此清理结果只报告 3 秒窗口内的存活情况，不承诺进程不再出现。
