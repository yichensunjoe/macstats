# MacStats 路线图 0.2 → 0.3

> 依据 `docs/competitive-analysis.md`（2026-10-26）。本文件只管「接下来做什么、怎么算做完」，
> 竞品事实与判断不在这里重复。

## 北极星

让一个不写代码的 Mac 用户，**三次操作内**在桌面上看到自己的 CPU / 内存 / GPU 读数。

当前不满足：v0.1 Release 没有任何可下载资产，README 只给 `git clone` + `bundle.sh`。
仓库 0 ★、0 fork、14 天 1 次浏览——不是产品问题，是分发问题。

7 天判据（0.2 发布后）：≥300 次 Release 下载 **或** ≥50 ★，二者取其一。

---

## M1 · 可安装（本次）

**目标**：`下载 zip → 拖进 /Applications → 右键打开` 三步可用；同时保留源码构建路径。

| # | 任务 | 落点 | 验收 |
|---|---|---|---|
| 1 | 版本单一来源 | `VERSION`（0.2），`bundle.sh` 读它写两处 plist | `defaults read …/CFBundleShortVersionString` = 0.2，主程序与 appex 一致 |
| 2 | 只出包模式 | `scripts/bundle.sh --archive` | 产出 `dist/MacStats.zip` + `.sha256`，不安装、不 `open` |
| 3 | 签名自检 | 归档前 `codesign --verify --deep --strict` | 主程序与 appex 均通过；失败即中断 |
| 4 | 安装文档 | `docs/install.md` | 三步 + 两种 Gatekeeper 放行 + 卸载 |
| 5 | README 首屏 | `README.md`、`docs/readme/README_en.md` | 首屏有下载按钮；下载链接指向 `releases/latest/download/MacStats.zip` |
| 6 | Homebrew | `Casks/macstats.rb`、`docs/homebrew.md` | `brew install --cask` 能拉到同一资产 |
| 7 | 发布 | tag `v0.2` + Release（zip、sha256、说明） | 匿名 `curl -sIL` 资产 200；下载后 `shasum -a 256 -c` 通过 |

**签名现实**：本机只有 `Apple Development`（Team `HGA4CHGL46`），没有 Developer ID，
所以**无法公证**，`spctl` 判定为 `rejected`。0.2 的安装文档必须写「首次右键 → 打开」，
不能宣称双击即开。这条在拿到 Developer ID（US$99/年）之前不会变。

**为什么仍要发**：未公证的开源包在 macOS 上是常态，右键打开可用；
比「必须装 Xcode」低一个数量级的门槛。

---

## M2 · 记忆与告警（0.3，约 1 周）

竞品里 Emerald Tools 已有 1h/24h/30d/1y 历史与趋势预测，Stats 有历史但被 `chronod` 拖累。
我们要的是「昨天那次卡顿是什么」，不是更多指标。

| # | 任务 | 落点 | 验收 |
|---|---|---|---|
| 1 | 采样落盘 | 新 `HistoryStore`（SQLite 或按天 JSONL，二选一，优先 JSONL 便于排查） | 1 分钟粒度留 24h、1 小时粒度留 30 天；目录 ≤50 MB；写入 <5 MB/天 |
| 2 | 面板历史卡 | `WidgetView` / `History.swift` | 尺寸够时出现「过去 24 小时」三线（CPU/内存/GPU）；详细版加今日峰值 |
| 3 | 阈值告警 | 复用 `UNUserNotification` | CPU/内存/磁盘连续 N 次超阈值 → 通知；可在设置里关闭 |
| 4 | 设置页 | 新增「历史」分区 | 保留天数、清空历史、导出 CSV（可选） |
| 5 | 开销回归 | `macstatsDiag` | 常驻 CPU 增幅 <0.5%，内存增幅 <20 MB |

风险：磁盘写入与常驻开销是同类产品的通病（Stats #2733）。先在 `macstatsDiag` 里加
「24 小时模拟采样」统计写入字节数，再决定粒度。

### M2 完成情况（0.3，2026-10-26）

| 项 | 结果 |
|---|---|
| 落盘 | `HistoryStore` 按分钟平均、按天写 JSONL 到 `~/Library/Application Support/MacStats/history/`；实测 133 字节/点，约 190 KB/天，30 天 ≈5.6 MB |
| 面板 | 标准/详细新增「过去 24 小时」卡（CPU/内存/GPU 三曲线 + 峰值）；空历史时提示「刚开始记录」 |
| 告警 | `ThresholdAlertEvaluator`：连续 3 次超阈值 + 10 分钟冷却；CPU 90% / 内存 85% / 磁盘 90%，默认关闭 |
| 设置 | 监控页新增「历史与告警」：开关、7/30/90 天保留、占用大小、清空确认 |
| 开销 | 实测 0.1% CPU / 98 MB RSS（与 0.2 持平）；跨分钟才写盘，退出时 flush |
| 测试 | 103 项（新增 7 项历史 + 5 项告警），全部通过 |

与原计划的差异：30 天保留的是分钟点文件（不是降采样成小时），体积仍远低于 50 MB 上限；
小时聚合 `hourly(days:)` 已实现但暂未被 UI 使用，留给 30 天曲线。

---

## M3 · 品牌与分发（与 M2 并行）

| # | 任务 | 说明 |
|---|---|---|
| 1 | 名字决策 | `macstats.app` 已占同名。建议加限定词（`MacStats Panel`）保仓库名；改名成本更高 |
| 2 | README 重写 | 定位改成「桌面常驻仪表，不是菜单栏监视器」；首图换成 1 秒刷新 + 拖拽换版式的 GIF |
| 3 | 差异页 | `docs/why-not-widgetkit.md`：引 Stats #2733，解释自绘窗口 + 30/60 秒快照写盘 |
| 4 | 发布 | r/macapps、Show HN、V2EX、少数派；中文优先是空位（B 站只有 iStat 汉化教程） |
| 5 | 反馈通道 | Issue 模板（bug / 功能 / 安装问题）+ Discussions |

---

## 明确不做

- 风扇控制、单温度探针：要特权或私有接口，审核与稳定性风险高于收益。
- App Store 上架与内购：先证明有人愿意装，再谈收费。
- Intel 支持：收益低、测试面大；继续在 README 写明 arm64 + macOS 15+。

---

## 发布检查清单（每次）

```bash
cd src && swift test                     # 91 项
cd .. && bash scripts/bundle.sh --archive
codesign --verify --deep --strict --verbose=2 MacStats.app
unzip -t dist/MacStats.zip
defaults read "$PWD/MacStats.app/Contents/Info.plist" CFBundleShortVersionString
shasum -a 256 -c dist/MacStats.zip.sha256
```

发布后（不带登录态）：

```bash
curl -sIL https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip | head -1
curl -sL  https://github.com/yichensunjoe/macstats/releases/download/v0.2/MacStats.zip.sha256
```

## 回滚

- 删除 Release 与 tag；README 下载段回退到源码构建。
- `dist/` 是构建产物，已加入 `.gitignore`，可随时删除。
