# 竞品分析与下一步计划（2026-10-26）

> 数据来自 2026-10-26 的公开页面、GitHub API、iTunes Search API 与 App Store 检索；
> 标「未核实」的条目没有拿到一手价格页。口径：只记录可复核的事实，不写推测。

## 一句话结论

「在桌面/菜单栏看 CPU 内存」这件事已经被两类产品占满：**免费开源的巨无霸（Stats）** 和
**2026 年冒出的一批付费独立 App（MacStats.app、Emerald Tools、CalmStat、MoniThor…）**。
我们唯一还没被占的位是：**一块常驻桌面、1 秒刷新、可任意拖拽缩放、口径逐项对齐活动监视器的仪表板**——
但现在**没有一个能直接下载的安装包**（v0.1 Release 的 assets 为空），所以这个位实际上没人看得见。

## 竞争地图

| 层级 | 产品 | 形态 | 价格 | 体量/信号 |
|---|---|---|---|---|
| 巨无霸 | **Stats**（exelban） | 菜单栏 + WidgetKit 小组件 | 免费，MIT | 42,810 ★，v3.0.23（2026-10-25 仍更新），自称 100M+ 下载、41 语言 |
| 老牌付费 | **iStat Menus 7**（Bjango） | 菜单栏 + 弹窗 | US$11.99 买断（第三方对比页 2026-10-23；官网价未核实），Setapp 含 | 传感器/风扇覆盖面最广，2008 年至今 |
| 直接同名 | **MacStats**（macstats.app） | 菜单栏 + 弹窗 | 免费 + Pro US$14.99 / 家庭 $39.99 买断 | 独立开发者，macOS 13+，Apple 芯片；有 compare/FAQ/权限页，SEO 已铺 |
| 桌面小组件派 | **Emerald Tools** | 菜单栏 + 桌面四角自绘小组件 | 未核实（App Store） | 9 项读数、最多 12 个/屏、1h/24h/30d/1y 历史、阈值尖峰与趋势预测 |
| 桌面小组件派 | **CalmStat** | 菜单栏 + 桌面小组件 | US$4.99 买断，7 天试用 | App Store 最新版 2026-10-22，自称空闲 <0.3% CPU |
| 菜单栏免费派 | **MoniThor** | 菜单栏 | 免费；Pro US$9.99 加传感器 | 6 指标 + 火花线，声称 1s 刷新、<30 MB |
| 小型付费 | Stats Panel $3.99、System Monitor $4.99、iPulse $9.99、McStats $1.99、iStatistica | 多为菜单栏/小组件 | 买断 | 评分样本均为 0，尚未形成口碑 |
| 开源小众 | MenuMeters（3,084 ★，2024 停更）、iGlance（2,492 ★，2023 停更）、deck / TopGUI / edgecontrol / MacPulse | 菜单栏或 WidgetKit | 免费 | 均 < 30 ★，多为个人练习 |
| 捆绑/顺带 | **Vorssaint**（25k ★ 套件，含系统监控）、**Mole**（TUI 清理+监控） | 菜单栏 / 终端 | 免费 | 靠「一个图标顶十个 App」吸量 |

## 逐家拆解

### Stats：真正的对手，也是我们的天花板
- 强：免费、开源、42k 星、41 语言、7 年迭代；9 个模块 + 13 种菜单栏样式；Intel 也支持（macOS 12+）。
- 弱（可打）：菜单栏弹窗为主，**没有一块独立常驻的桌面面板**；桌面小组件受 `chronod` 拖累——
  issue [#2733](https://github.com/exelban/stats/issues/2733)「Widgets do not update or high disk writes」19 条讨论，
  作者因高负载/磁盘写入**默认关闭了小组件数据通信**，需手动到设置里打开；文档也把「小组件不显示数据」列为已知问题。
- 对我们的意义：不要正面比「指标数量/传感器」。要比**刷新确定性与版式自由度**。

### iStat Menus 7：护城河在传感器，不在界面
- 强：单温度探针、风扇转速与手动/曲线控制、按 App 的网络与磁盘、S.M.A.R.T.、近乎任意的告警规则、天气/世界时钟。
- 弱：买断 + 隔几年再收一次升级费；纯菜单栏弹窗；对「只想在桌面挂一块表」的人是过度配置。
- 对我们的意义：**短期不碰风扇与风扇控制**（需特权/私有接口，风险高、审核难），只在文案里承认差距。

### MacStats（macstats.app）：同名 + 同思路，最需要处理的冲突
- 定位与我们高度重叠：菜单栏 5 指标、**用大白话解释进程是什么**（我们的 `ProcessGlossary` 是同一招）、
  24h/7d/30d 历史、按自身基线做异常检测、AI 解释（Pro）。
- 它没有的：桌面常驻面板、自定义尺寸四档版式、WidgetKit 组件、一键清理孤儿进程。
- 风险：`macstats.app` 域名 + compare/FAQ 页面已经把「MacStats vs Stats vs iStat Menus」这个搜索词吃掉；
  我们同名仓库在搜索结果里必然被它压住。App Store 美区按 `macstats` 搜索**没有**它的条目（可能是站外分发），
  但品牌层面的混淆已经成立。

### Emerald Tools：功能上最接近我们「下一步」的产品
- 桌面四角自绘小组件（不是 WidgetKit），每屏最多 12 个，CPU/内存/Swap/磁盘/IO/网络/电池/GPU/热状态九项；
  点击原地展开；1h/24h/30d/1y 历史落盘；尖峰检测 + 最小二乘趋势预测 + 通知。
- 它固定「四角槽位 + 210×64 紧凑条 + 280 宽展开」，**不能任意拖到屏幕中间、也不能自由缩放**。
- 它的采样默认 2 秒——我们 1 秒，且四档版式随尺寸自动重排，这是可守的差异。

### 免费/低价长尾
CalmStat / MoniThor / Stats Panel / iPulse 的共同点：功能是 Stats 的子集，靠 App Store 或 standalone 收 4–10 美元。
评分样本都是 0，说明**这个品类现在的竞争不在评分，而在被发现**。

### 中文生态：需求存在，但没有本土化产品
- B 站检索「Mac 系统监控 小组件」：iStat Menus 7 教程 505 播放，活动监视器教程 11,330 播放，
  Widgetify（通用动态小组件，非系统监控）1,131 播放。
- 结论：有人在看「怎么监控」，但上榜的全是英文产品的汉化教程或系统自带功能；
  没有任何一款中文优先、以桌面常驻形态出现的系统监控工具。这是可用但不算大的空位。
- 本次未能核验小红书（OpenCLI 浏览器扩展未安装，doctor 报 warn），因此中文审美偏好的判断留待补测。

## 我们能守住的三个位

1. **确定性刷新**：桌面面板 1 秒重绘，不经过 `chronod`，不吃 WidgetKit 的调度预算。
   Stats 的公开 issue 正好证明这是真痛点。
2. **版式随尺寸长**：一块面板从 236×76 到 700×80 自动在极简/紧凑/标准/详细间切换，
   不是「固定槽位 + 点开看详情」。这是 Emerald / iStat / Stats 都没有的交互模型。
3. **口径可验证**：内存残差 ≤0.2 GB、磁盘/网络累计逐字节对齐、进程内存按 PID 对到 0.0 MB，
   并且有 91 项单测。竞品都只说「accurate」，我们把对照方法写成了文档（`docs/monitor-alignment.md`）。

## 我们明显缺的

| 缺口 | 现状 | 影响 |
|---|---|---|
| **可下载安装包** | v0.1 Release 的 `assets` 为空，只能 clone + `bundle.sh` | 转化率≈0，非开发者直接流失 |
| 首次体验 | 无 DMG/无拖拽安装、无公证说明、无 Homebrew cask | 会被 Gatekeeper 吓退 |
| 历史与告警 | 只有 90 秒趋势线 | 打不过 Emerald/iStat 的「昨天那次卡顿是什么」 |
| 传感器 | 无温度/风扇 | 与 iStat 差一整层，短期不补 |
| Intel | arm64 only | 放弃一部分存量机器（可接受，但要写明） |
| 品牌 | 与 macstats.app 同名 | 搜索被压、记忆点冲突 |
| 社区信号 | 0 ★ / 0 fork / 14 天 1 次浏览 / Release 0 下载 | 等于没发布 |

## 下一步计划

### P0 · 让它真的能装（本周，1–2 天）
1. `scripts/bundle.sh` 增加 `--archive` 产物：`MacStats-0.2.zip`（含已签名 `.app`）+ `ditto` 保留签名。
2. 打 `v0.2`，把 zip 挂到 Release assets；README 首屏加「下载 MacStats-0.2.zip → 拖进 /Applications」。
3. 写清签名状态：ad-hoc/开发者签名各自会发生什么、首次打开怎么放行；补一张 Gatekeeper 提示的说明图。
4. 加 `brew install --cask`（自建 tap 或提交 homebrew-cask），覆盖开发者人群。
5. 验收：一台没装过 Xcode 的 Mac（或新用户账户）从 Release 下载→拖入→打开→面板出现，全程 ≤3 步；
   `spctl -a -vv` 输出写进 HANDOFF。

### P1 · 补一个对手没有的「记忆」（1 周）
6. 采样落盘：1 分钟粒度留 24h、1 小时粒度留 30 天，SQLite 或按天 JSONL，容量上限 50 MB。
7. 面板加「过去 24 小时」卡片（CPU/内存/GPU 三线），尺寸够时才出现；详细版加「今日峰值」。
8. 阈值告警：CPU/内存/磁盘连续 N 次超阈值 → 通知，复用现有 `UNUserNotification` 通道。
9. 验收：跨重启历史还在；写入量 < 5 MB/天；面板常驻 CPU 增幅 <0.5%。

### P2 · 分发与定位（与 P0 并行，1 周）
10. 品牌决策：`MacStats` 与 macstats.app 同名冲突已成立。二选一——
    **加限定词**（如 `MacStats Panel` / `MacStats Desktop`，保留仓库名与已有 README）
    或 **改名**（新名字 + 旧仓库 README 顶部做跳转说明）。建议加限定词，代价最小。
11. README 首屏重写为「桌面常驻仪表，不是菜单栏监视器」：一句差异 + GIF（1 秒刷新 + 拖拽换版式）。
12. 写一页 `docs/why-not-widgetkit.md`：引 Stats #2733 的数据，说明我们为什么自绘窗口 + 30/60 秒快照写盘。
13. 发布节奏：r/macapps + Hacker News Show HN + V2EX + 少数派/小红书（中文优先是空位，
    Stats/iStat/Emerald 都是英文优先；B 站已有 iStat Menus 教程但无中文同类产品）。
14. 验收：发布后 7 天 ≥50 ★ 或 ≥300 次 Release 下载（取其一），Issue 模板与 Discussions 打开。

### 不做（本轮明确排除）
- 风扇控制、单温度探针：需要特权/私有接口，审核与稳定性风险高于收益。
- 付费上架与内购：先验证有人愿意装，再谈收费；当前 0 下载谈定价没有意义。
- Intel 支持：收益低、测试面大。

## 参考

- Stats：<https://github.com/exelban/stats>，<https://mac-stats.com/>，issue #2733
- iStat Menus：<https://bjango.com/mac/istatmenus/>
- MacStats（同名）：<https://macstats.app/>，<https://macstats.app/compare/>
- Emerald Tools：<https://emerald-tools.com/guides/mac-system-monitor-widgets/>
- CalmStat：<https://calmstat.com/en/>
- MoniThor：<https://monithor.dev/>
- App Store 价格/上架时间：iTunes Search API（`entity=macSoftware`, `country=us`）
