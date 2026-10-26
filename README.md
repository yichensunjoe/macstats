<div align="center">

**简体中文** · [English](docs/readme/README_en.md) · [繁體中文](docs/readme/README_zh-TW.md) · [日本語](docs/readme/README_ja.md) · [한국어](docs/readme/README_ko.md) · [Deutsch](docs/readme/README_de.md) · [Español](docs/readme/README_es.md) · [Français](docs/readme/README_fr.md) · [Русский](docs/readme/README_ru.md) · [Português (Brasil)](docs/readme/README_pt-BR.md)

# MacS

原名 MacStats。

### 把「活动监视器」钉在桌面上的一块实时仪表。

**CPU、内存、GPU、能耗、磁盘、网络，一眼看完；口径逐项对齐活动监视器。**

[![macOS](https://img.shields.io/badge/macOS-15%2B-1d1d1f?style=flat-square&logo=apple&logoColor=white)](#下载安装)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)](#实现方式)
[![tests](https://img.shields.io/badge/tests-103%20passing-3fb950?style=flat-square)](#命令)
[![dependencies](https://img.shields.io/badge/dependencies-none-4c8eda?style=flat-square)](#实现方式)

[下载安装](#下载安装) · [能看什么](#能看什么) · [两种形态](#两种形态) · [24 小时历史](#24-小时历史与持续高负载提醒) · [口径对齐](#和活动监视器对到什么程度) · [常见问题](#常见问题) · [限制](#已知限制)

**[下载 MacStats.zip](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip)** · 拖进 `/Applications`，首次右键 →「打开」

</div>

---

## 下载安装

[**下载 MacStats.zip**](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip)（约 2.4 MB，macOS 15+ / Apple 芯片）

> **下载的包叫 MacStats，装好后显示名是 MacS。** Release 里的文件是 `MacStats.zip`，解压出来是 `MacStats.app`；Finder、启动台、菜单栏显示的是 MacS。同一个 App，Bundle ID 仍是 `com.macstats.app`，偏好与已添加的小组件都不受影响。

1. 解压，把 `MacStats.app` 拖进 `/Applications`
2. 右键 MacS →「打开」，确认一次（**未公证**，原因与其它放行方式见[安装说明](docs/install.md)）
3. 面板出现在桌面；想要系统小组件，右键桌面 →「编辑小组件」→ 搜「系统监视」

放行只对这一次下载生效：重新下载、覆盖安装或升级后可能再被拦一次，照旧右键 →「打开」。

第 1 步不能省：系统小组件只从 `/Applications` 发现扩展宿主，放在下载目录或 `~/Applications` 里，小组件库中不会出现 MacS。

**校验下载**（在下载目录里，两个文件同级）：

```bash
shasum -a 256 -c MacStats.zip.sha256
```

输出 `MacStats.zip: OK` 表示文件完整；失败就重新下载，不要继续安装。

**另外两种可选方式**（终端清隔离属性 / Homebrew）：

```bash
# 1. 清掉下载隔离属性，之后正常打开
xattr -dr com.apple.quarantine /Applications/MacStats.app
open /Applications/MacStats.app

# 2. 或者用 Homebrew
brew tap yichensunjoe/macstats https://github.com/yichensunjoe/macstats
brew trust yichensunjoe/macstats      # Homebrew 5+ 需要显式信任第三方 tap
brew install --cask macstats
```

**装不上时先看这里**：

1. **Gatekeeper 拦截**：用上面的方式放行（右键 →「打开」，或清隔离属性）；也可以在系统设置 → 隐私与安全性里点「仍要打开」。提示「App 已损坏，无法打开」多半是下载不完整——先跑 sha256 校验，失败就重新下载；校验通过仍报损坏，用清隔离属性的方式再打开。
2. **架构不对**：只提供 Apple 芯片（arm64）包，Intel Mac 无法运行，也没有 Rosetta 版本。`uname -m` 应输出 `arm64`。
3. **系统版本太低**：需要 macOS 15（Sequoia）或更新，`sw_vers -productVersion` 确认。
4. **系统小组件不出现**：确认 App 在 `/Applications`（不是下载目录或 `~/Applications`）、至少启动过一次，然后 `killall chronod NotificationCenter`，再打开一次 App；一台机器只应注册一份。
5. **Homebrew 报 untrusted tap**：Homebrew 5 起第三方 tap 必须先 `brew trust yichensunjoe/macstats` 再 `brew install --cask macstats`；`brew untrust yichensunjoe/macstats` 可撤回。Homebrew 不会替你清隔离属性，首次启动仍可能需要右键放行。

**卸载**：先退出 App（菜单栏图标 → 退出），再 `rm -rf /Applications/MacStats.app`；Homebrew 装的用 `brew uninstall --cask macstats`。偏好与快照留在 `~/Library/Application Support/MacStats/` 和 `~/Library/Preferences/com.macstats.app.plist`，需要彻底清掉时一并删除。

<p align="center">
  <img src="docs/live-window.png" alt="MacStats 桌面面板：CPU、内存、GPU、能耗、磁盘、网络与内存占用最高的进程" width="460" />
</p>

macOS 自带的活动监视器信息够全，但它是个窗口：要开、要点、要切到前台。MacStats 把同样五个数做成一块常驻桌面的深色面板——每秒采样、随窗口尺寸自动换版式，再顺手提供 WidgetKit 系统小组件，让你能在桌面排版里放一块小的。

它不追求「多」：指标就是活动监视器那五项，加上一项它没有单独列出的 GPU 利用率与显存占用，再加 90 秒趋势线、每核心占用、内存构成、以及内存占用最高的 3 个进程。真正花时间的地方不是画界面，是**把每个数算成和活动监视器一样的数**——同一刻截图对照，内存残差 ≤ 0.2 GB，磁盘与网络的累计读写逐字节一致。

<p align="center">
  <img src="docs/compact-strip.png" alt="极简条拉宽：CPU、内存、GPU、能耗、磁盘、网络六项一行排开" width="620" />
  <br />
  <img src="docs/compact-strip-narrow.png" alt="极简条收窄：同样六项自动折成两行三列" width="330" />
</p>

**拖成一条，就是极简版。** 没有卡片、没有趋势线，六个指标一行排开，贴在菜单栏下面当指示灯。面板窄到一行排不下时自动折成两行三列，六个指标始终都在。整块面板按 1 秒刷新时约占单核 1%、常驻内存 80 MB 上下（arm64 + macOS 26 实测），这一档的绘制最轻。新装默认就是这一档；右键 →「展开为标准面板」摊开成完整面板，再点同一项切回条状。

> [!NOTE]
> 桌面悬浮面板开箱即用。系统「小组件库」里的那份需要一份有效的 Apple Development 签名，并且必须装进 `/Applications`——这两条是 `chronod` 的硬要求，不是可选项，详见[系统小组件](#系统小组件)。

## 从源码构建

已经用上面的 zip 装好就不用看这一节。需要 macOS 15 或更新、Xcode 命令行工具（Swift 6）。没有第三方依赖，也不需要 Xcode 工程文件。

```bash
git clone https://github.com/yichensunjoe/macstats.git
cd macstats
bash scripts/bundle.sh          # 构建 + 打包 + 安装到 /Applications + 注册小组件扩展
open /Applications/MacStats.app

# 只出可分发包、不安装（→ dist/MacStats.zip）
bash scripts/bundle.sh --archive
```

首次打开会在菜单栏出现一个 `CPU · 内存` 的小读数，桌面上出现面板。

- 左键菜单栏图标：显示 / 隐藏面板
- 右键面板：始终置顶、固定在桌面、点击穿透、刷新间隔（0.5 / 1 / 2 / 5 秒）、新建实例、一键清理后台闲置进程
- 面板右下角的 🗑 按钮：同样是一键清理（鼠标悬停时才显现）
- 拖动面板空白处移动，右下角缩放柄改变尺寸，版式随尺寸在「极简 / 紧凑 / 标准 / 详细」间自动切换
- 偏好写在应用的 `com.macstats.app` 偏好域里，退出再开保持原位

## 能看什么

| 指标 | 面板显示 | 口径 |
|---|---|---|
| CPU | 总占用大数字 + 用户/系统 + 90 秒趋势线 + 每核心竖条 | `host_processor_info` 差分，与活动监视器同源 |
| 内存 | 已用/总量、压力条、App / 联动 / 压缩构成、缓存 | `vm_statistics64` 换算，见[口径对齐](#和活动监视器对到什么程度) |
| 能耗 | CPU 能量计数折算的瓦数、电池电量与充电状态 | `ri_energy_nj` 差分；缺计数时退回占用估算并标记 |
| 磁盘 | 读/写速率、可用空间 | `IOBlockStorageDriver` 累计字节差分 |
| 网络 | 上下行速率、主接口 | `NET_RT_IFLIST2` 64 位计数差分，速率不计 `lo0` |
| GPU | 利用率大数字 + 90 秒趋势线 + 显存占用/核心数 | `IOAccelerator` 的 `PerformanceStatistics`（`Device Utilization %`、`In use system memory`），与活动监视器 GPU 页签同源 |
| 进程 | 内存占用最高的 3 个（大尺寸小组件 5 个） | `proc_pid_rusage` 的 `ri_phys_footprint` |

<p align="center">
  <img src="docs/widget-medium.png" alt="WidgetKit 中尺寸：CPU 主板与内存、磁盘、网络、能耗，有 GPU 时再加一格 GPU" width="620" />
  <img src="docs/widget-small.png" alt="WidgetKit 小尺寸：CPU 大数字与趋势线" width="280" />
</p>

## 24 小时历史与持续高负载提醒

标准与详细面板多一条「过去 24 小时」：CPU、内存、GPU 三根曲线，各带 24 小时峰值。
采样仍是每秒一次，落盘按分钟取平均、按天写成 JSONL，放在
`~/Library/Application Support/MacStats/history/`——一天约 190 KB，默认保留 30 天。
设置 → 监控里可以改成 7 / 30 / 90 天，或一键清空。

「持续高负载提醒」默认关闭。打开后，CPU ≥ 90%、内存 ≥ 85%、磁盘 ≥ 90%
**连续 3 次采样**才发通知，同一指标 10 分钟内不重复——单次尖峰不会打扰你。

## 一键清理后台闲置进程

菜单栏右键（或面板右键）→「一键清理后台闲置进程…」。它只找**遗留孤儿**：由你启动、父进程已经退出、没有终端、没有子进程、不持有套接字，并且 10 分钟没有 CPU 活动的后台进程。先给清单和预计释放量，确认后才发 `SIGTERM`；3 秒没退出的保持运行，不会升级成 `SIGKILL`。

永远不动的几类：

| 类别 | 判据 |
|---|---|
| 系统进程 | 路径在 `/System`、`/usr`、`/Library` 等，或名字在系统界面进程名单里 |
| App 及其子进程 | 可执行路径含 `.app/` |
| 终端里的命令 | `proc_bsdinfo.e_tdev` 指向真实 tty |
| 当前前台 App | `NSWorkspace.frontmostApplication` |
| 别人在用的子进程 | 父进程还活着（ppid ≠ 1） |
| 还在提供服务 | 持有任何 TCP / UDP / Unix 套接字 |
| 你勾选的白名单 | 菜单里的「清理白名单」按进程名或 `argv[0]`（`ps` 里显示的名字）保护；勾上的名字带 ✓ 留在列表里，再点一次就取消，菜单底部还有「清空白名单」 |

### 每条进程都有人话说明

确认框里每个进程都会写清楚「它是什么」和「影响」（结束它会发生什么），例如：

- `npm run dev`：本地开发服务器，改代码会自动刷新——结束它，本地网页会打不开、热更新停止。
- `github-mcp-server`：给 AI 助手提供工具能力的 MCP 服务——结束它，AI 会少一项工具能力，重开那个工具即可。
- 认不出来的：直说「一个叫 xxx 的后台命令，没有窗口和图标」，并注明结束它不影响系统。

说明在 `ProcessGlossary.swift` 里，按 `argv[0]` → 可执行名 → 安装路径三层匹配，纯函数、不执行任何东西。

所以它在忙碌的机器上经常给出「没有可清理的进程」——这是设计结果，不是失效。真正会命中的是崩溃后遗留的孤立 `node` / `python` / 脚本进程。僵尸（Z 状态）不在此列：它已经退出，只能由父进程回收。

只读检查（不杀任何进程）：

```bash
cd src && .build/debug/macstatsDiag --cleanup-dry-run
```

## 设置窗口

菜单栏右键 →「设置…」（或 ⌘,）打开一个标准设置窗口，三页：

| 页 | 内容 |
|---|---|
| 显示 | 显示桌面小组件、面板形态（极简条 / 标准面板）、始终置顶、点击穿透、刷新间隔 |
| 后台清理 | 列出你的后台进程，每条带一句人话说明；勾选即保护（再点取消），可搜索、可手动输入进程名加保护、可刷新或清空 |
| 通用 | 登录时启动、版本 |

右键菜单只保留常用操作：显示/隐藏、展开/收成、添加桌面小组件、一键清理、清理白名单、打开活动监视器、设置、退出。

## 两种形态

同一个采样层，两种宿主：

| | 桌面面板 | 系统小组件（WidgetKit） |
|---|---|---|
| 刷新 | 每秒重绘 | 系统按预算调度，约 60 秒一轮 |
| 位置 | 任意拖动，可开多个实例 | 桌面排版网格，随系统布局 |
| 入口 | 菜单栏图标 / `open MacStats.app` | 右键桌面 →「编辑小组件」→ 搜「MacStats」 |
| 尺寸 | 拖拽自由缩放，四档版式 | 小 / 中 / 大 / 特大固定档 |
| 前提 | 无 | 有效签名 + 装进 `/Applications` + `_NSExtensionMain` 入口 |

想要「看起来是活的」，用面板；想要「和别人小组件排在一起」，用系统小组件。两者读同一份快照，不会出现两个口径。

## 和活动监视器对到什么程度

对照方法是把活动监视器与面板放在同一屏，用辅助访问（AX）读活动监视器里的数值，与同一刻的采样结果逐项比：

| 项 | 结果 |
|---|---|
| 内存：已使用 / 已缓存 / App / 联动 / 压缩 | 残差 ≤ 0.2 GB（活动监视器自身 5 秒刷新缓存所致） |
| 磁盘：累计读 / 累计写 | 逐字节一致 |
| 网络：累计收 / 累计发 | 逐字节一致（十进制 GB） |
| 进程内存 | 同一 PID 对到 0.0 MB |
| CPU | 稳定负载下差 1～3 个百分点（采样窗口相位差） |

<p align="center">
  <img src="docs/monitor-compare.png" alt="上半部分是活动监视器的内存页，下半部分是同一刻的 MacStats 面板" width="700" />
</p>

为此改过三处「想当然」的实现：

- **网络累计必须用 IFMIB 的 64 位计数。** `NET_RT_IFLIST2` 里的 `ifi_ibytes` 只填低 32 位，回绕后本机 122.9 GB 的 `lo0` 被读成 2.6 GB。累计值含 `lo0`（活动监视器也算），速率列排除它（否则内核环回流量会让速率大 60 倍）。
- **「已使用」不等于「App + 联动 + 压缩」。** 活动监视器的已使用 = 物理 − (free − speculative) − 文件缓存；已缓存文件 = 文件缓存 + 可清除页。照它的定义实现，而不是照直觉。
- **能耗不是「能耗影响」。** 活动监视器那一列是无量纲的相对分数，无法复刻；面板给的是物理瓦数，并在格子里标注「CPU 能量计数」，不和分数混用。

## 实现方式

三层，没有一层依赖 UI：

```
MacStatsCore  采样与换算（纯逻辑、可单测）
      ↓
WidgetData    快照 + 90 点环形历史
      ↓
SwiftUI 视图  面板 / WidgetKit 两种宿主共用同一套组件
```

- **采样**：Mach（`host_processor_info`、`host_statistics64`）、IOKit（磁盘统计、电源）、`sysctl(NET_RT_IFLIST2)`、`sysctl(vm.swapusage)`、libproc（`proc_listpids` / `proc_pid_rusage`）。全部公开接口，不需要 sudo，不关 SIP，不用私有框架。
- **速率类指标取最近 5 个采样的滑动平均**，对齐活动监视器默认的 5 秒窗口，也顺带压掉闪烁。
- **面板是桌面层 `NSPanel`**：不抢焦点、跟随所有桌面空间、`nonactivatingPanel`，所以点它不会把你正在用的窗口踢下去。
- **数据不出本机**：没有网络请求，没有遥测，没有账号，不读用户文件；只通过公开接口读系统计数器，写一个本地 JSON 给小组件扩展用。

## 命令

| 目的 | 命令 |
|---|---|
| 构建 + 打包 + 安装 | `bash scripts/bundle.sh` |
| 单元测试 | `cd src && swift test` |
| 采样自检 | `cd src && swift build && .build/debug/macstatsDiag --self-check` |
| 打印原始口径 | `cd src && .build/debug/macstatsDiag --raw` |
| 清理候选（只读） | `cd src && .build/debug/macstatsDiag --cleanup-dry-run` |
| 验证白名单匹配 | `cd src && .build/debug/macstatsDiag --cleanup-dry-run --whitelist <进程名>` |
| JSON 快照 | `cd src && .build/debug/macstatsDiag --json` |
| 离屏渲染面板 | `MacStats.app/Contents/MacOS/MacStats --snapshot docs/snapshot.png` |
| 离屏渲染四档小组件 | `bash scripts/preview-widget.sh` |

## 项目结构

```
src/Sources/MacStatsCore/    采样、内存换算、环形历史、格式化、进程清理规则（无 UI 依赖）
src/Sources/MacStats/        SwiftUI 面板、菜单栏 App、右侧菜单、离屏渲染
src/Sources/MacStatsWidget/  WidgetKit 扩展：时间线数据源 + 四档视图
src/Sources/MacStatsDiag/    诊断 CLI（--json / --raw / --self-check）
src/Tests/                   XCTest，103 项
assets/MacStats.icns         应用图标（打包时拷进 Contents/Resources）
scripts/bundle.sh            release 构建、组装 appex、签名、安装、注册
docs/                        口径对照、架构、需求与界面截图
```

## 系统小组件

扩展打包在 `MacStats.app/Contents/PlugIns/MacStatsWidget.appex`，四档尺寸各自排版。想让它出现在小组件库里，三条缺一不可——这三条都是踩过坑之后写下来的：

1. **扩展要有有效签名，并且沙盒化。** `pkd` 不接受 ad-hoc 签名；就算用了真证书，appex 缺 `com.apple.security.app-sandbox` 也会被 `rejecting; … plug-ins must be sandboxed` 静默丢掉。免费的个人团队证书（Xcode → Settings → Accounts 登录 Apple ID）就够。
2. **App 必须装在 `/Applications`，而且只能注册这一份。** `chronod` 只从系统应用目录发现宿主；放在项目目录或用户级 Applications 目录时日志是 `Ignoring restricted or unknown extension`。两处同名注册会让 launchd 建两个 XPC 实例，chronod 反而连不上实体进程。`bundle.sh` 已经按这个前提安装并清理旧注册。
3. **appex 的入口点必须是 `_NSExtensionMain`。** 这是 Xcode 的 `LD_ENTRY_POINT` 默认值；用 SwiftPM 默认入口时进程能起来、能打印 `main [WidgetBundle]`，但永远不建立宿主 XPC 会话，约 15 ms 后被判死且没有崩溃报告。`src/Package.swift` 里已用 `linkerSettings` 固定。

沙盒后扩展读不到主程序的 `UserDefaults`，所以数据走容器里的同一份 JSON：主程序把快照写到应用支持目录下的 `MacStats/widget-feed.json`，并在扩展容器存在时补写一份；扩展拿不到新鲜快照时自己采一次。

写盘和叫醒扩展都按「看得见的变化」节流：最快 30 秒一次，界面数字没变样就只在 60 秒心跳时推一次；扩展容器不存在（没添加过小组件）时一步都不做。这样空闲时不再为每帧浮点抖动反复写盘、唤醒 `chronod`。

若 `security find-identity -v -p codesigning` 显示 `0 valid identities`，通常是钥匙串缺 Apple 的 WWDR G3 中间证书；从 Xcode 自带资源里导入 `AppleWWDRCA-2030.cer` 即可。

改完扩展记得提 `CFBundleVersion`：`chronod` 按版本号缓存 descriptor，版本不变会一直显示旧的。

## 常见问题

<details>
<summary><strong>为什么小组件一分钟才动一次？</strong></summary>

WidgetKit 不是渲染循环，是「定时快照」：时间线给一条数据，到期再来问下一次。主程序只在显示值变化时请求 `reloadAllTimelines()`（最快 30 秒一次，空闲时 60 秒心跳），`chronod` 还会按预算再节流（日志里带 `budgeted-1`）。第三方小组件拿不到秒级刷新，系统时钟那种是系统自己的特权。

要实时看数，用桌面面板（每秒刷新）。

</details>

<details>
<summary><strong>为什么「内存占用最高」里看不到 WindowServer？</strong></summary>

其它用户的进程（如 `_windowserver`）没有读取权限：`proc_pid_rusage` 返回 EPERM，`proc_pidinfo` 返回 0 字节。活动监视器带 Apple 签名特权，所以能看到全部。这是权限边界，不是算错。

</details>

<details>
<summary><strong>数值和活动监视器仍有一个点上的差？</strong></summary>

活动监视器每 5 秒刷新一次，显示的是上次刷新的快照；面板每秒刷新。同一刻对比时内存会有 ≤ 0.2 GB 残差，速率与 CPU 有窗口相位差。等一个刷新周期再比就一致了。

</details>

<details>
<summary><strong>会不会上传数据？</strong></summary>

不会。没有网络请求、没有遥测、没有账号，也不读用户文件；只通过公开接口读系统计数器，写一个本地 JSON 给小组件扩展用。

</details>

<details>
<summary><strong>支持 Intel Mac 吗？</strong></summary>

代码只用公开接口，理论上是通用的，但只在 arm64 + macOS 26 上实测过；Intel 上 CPU 与能耗的换算没有校准数据。欢迎带着对照结果提 issue。

</details>

## 已知限制

- **系统小组件约 60 秒一跳**，这是 WidgetKit 的调度上限，程序无法绕过。
- **能耗是物理瓦数**，不是活动监视器的「能耗影响」分数，两者没有量纲对应。
- **进程列表只覆盖当前用户**，且按内存排序，面板显示前 3、采样层最多保留 24 条。
- **清理不碰文件缓存与显存**：释放文件缓存要 `sudo purge`，显存只能靠退出占用它的 App；面板只读 GPU 利用率与显存占用，不提供释放。
- **清理不处理真正的僵尸进程**：Z 状态已经退出，只能由父进程回收，杀父进程风险更大。
- **被 launchd 保活的任务会自动重新拉起**（哪怕是 `launchctl submit` 提交的临时任务，实测 `runs = 2`）。
  这类清理只腾出退出到重启之间的那点时间，内存很快会回来；日常遇到的比例不高，因为服务类进程大多卡在套接字规则上。
- **历史只在本机、只到分钟**：按分钟聚合写成 JSONL，保留 7 / 30 / 90 天可选；没有云端同步，也没有秒级回放。
- **告警只看三项**：CPU / 内存 / 磁盘，连续 3 次超阈值才提醒，默认关闭；不监控温度、风扇与单进程异常。
- **不做远程监控**：所有读数与历史都留在本机，不上报网络。

## 文档

- [口径对照](docs/monitor-alignment.md)：每一项数值是怎么对到活动监视器的，含实测数据。
- [架构](docs/architecture.md)：分层、数据流与关键取舍。
- [需求](docs/requirements.md)：范围、非目标与验收标准。

## 许可

本项目以 [MIT 许可证](LICENSE) 发布。你可以自由使用、修改、分发，包括商业用途，只需保留版权声明与许可证全文。
