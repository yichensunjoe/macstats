# C · 分发实验

> 上位文档：[`docs/roadmap-v0.4.md`](../roadmap-v0.4.md)。
> 目标不是“发一条帖子”，而是用一周时间回答：**目标用户看到它，会不会下载、会不会留下反馈。**
> 这是一个有假设、有指标、有停止条件的实验；不是营销活动。

---

## 1. 假设与判据

### 假设

目标受众（由 H1 决定）看到 20 秒演示后，愿意在 7 天内下载，并留下至少 5 条可引用的反馈。

### 判据（启发式，不是统计显著）

| 结果 | 决定 |
|---|---|
| ≥50 下载且 ≥5 条反馈 | 继续：开第二个渠道；按反馈排 0.4.1 |
| 20–49 下载或 1–4 条反馈 | 只改一个变量（标题 / GIF / 渠道），再试一次；不碰产品 |
| <20 下载 | 停止加功能；找 5 个目标用户聊 15 分钟，重做 A |
| 安装失败 ≥30% | 先修 A（安装/公证/说明），不判断需求 |

**下载数** = Release 资产 `download_count` 的增量，减去发布前基线和自己的校验下载。  
**反馈数** = Issue / 邮件 / 私信 / 评论里能引用的一句话；不是“点赞”。

---

## 2. 发布前基线（C1）

在发任何帖子之前，先把基线写进 `docs/experiments/2026-10-launch.md`（新建）：

```bash
cd projects/active/P087-macstats-widget
gh api repos/yichensunjoe/macstats/releases \
  --jq '.[] | {tag: .tag_name, assets: [.assets[] | {name, downloads: .download_count}]}'
gh api repos/yichensunjoe/macstats/traffic/views
gh api repos/yichensunjoe/macstats/traffic/clones
gh api repos/yichensunjoe/macstats/traffic/popular/referrers
```

记录：

- 日期/时间（含时区）；
- 当前 Release 各资产下载数；
- 14 天 views / clones / referrers；
- 当前 stars / forks（只作背景，不作主指标）；
- 本次发布使用的版本与 zip sha256。

> 注意：GitHub traffic 只保留 14 天；发布后每天记一次，否则窗口过了就没了。

---

## 3. 素材（C2）

### 3.1 20 秒 GIF 分镜

| 时间 | 画面 | 字幕（可选） |
|---|---|---|
| 0–3s | 桌面上一块面板，CPU/内存数字在跳 | `1 秒刷新，不经过 WidgetKit` |
| 3–8s | 拖右下角变宽：极简条 → 标准 → 详细，卡片自动重排 | `拖多大，就长多少` |
| 8–14s | 点“过去 24 小时”的 CPU 峰值 → popover 显示 `15:20 · 92%` + `Xcode 78%` | `不只告诉你高，还告诉你是谁` |
| 14–18s | 回到面板，鼠标划过菜单栏读数 | `口径对齐活动监视器` |
| 18–20s | 结束卡：产品名 + `github.com/yichensunjoe/macstats` | `免费 / 开源 / macOS 15+` |

如果 B 还没做完：8–14s 换成“历史曲线 + 峰值数字”，字幕改成“过去 24 小时，随时回看”。**不要把发布绑在 B 上。**

### 3.2 录制与压缩

录制前：

- 用干净桌面/中性壁纸；关掉通知、聊天窗口、个人文件名；
- 面板只放目标指标，不露真实主机名；
- 先让历史积累至少几小时，或设置 `MACSTATS_HISTORY_DIR` 指向一份演示历史（`--snapshot` 已支持该环境变量）。

录制：

```bash
# 只录屏幕，Ctrl+C 停止；先确认 ffmpeg 是否存在
command -v ffmpeg || echo "需要 ffmpeg（brew install ffmpeg）"
screencapture -v /tmp/macstats-demo.mov
```

转 GIF（720 宽、15fps、调色板，控制在 5 MB 内）：

```bash
ffmpeg -i /tmp/macstats-demo.mov -vf "fps=15,scale=720:-1:flags=lanczos,palettegen" /tmp/palette.png
ffmpeg -i /tmp/macstats-demo.mov -i /tmp/palette.png \
  -lavfi "fps=15,scale=720:-1:flags=lanczos [x]; [x][1:v] paletteuse" \
  docs/demo.gif
ls -lh docs/demo.gif
```

如果超过 5 MB：降到 600 宽 / 12fps，或剪到 15 秒；不要为了清晰度把首屏拖慢。

### 3.3 静态图

复用现有：

- `docs/live-window.png`（完整面板）
- `docs/compact-strip.png` / `docs/compact-strip-narrow.png`（极简条宽窄）
- `docs/widget-xlarge.png`（系统小组件）

如需重拍，用 `--snapshot` 出图，保证版本/数字一致。

### 3.4 文案素材

首屏一句话（A5 产出）直接复用；帖子正文按下面模板，不要写“最强/终极/重新定义”。

---

## 4. 渠道与文案（C3）

### 4.1 渠道顺序

| H1 | 第一渠道 | 第二渠道（一周后） | 备注 |
|---|---|---|---|
| 开发者/技术型 | **r/macapps** | V2EX macOS / 分享创造 | 英文优先；HN 只在有强钩子时再试 |
| 中文技术型 | **V2EX** | 少数派 | 中文优先是竞品空位 |
| 非技术 Mac 用户 | **小红书** | 少数派 / B 站 | **必须先公证**，否则不要发 |

**一次只开一个渠道。** 同时发五个，成了不知道哪个成的，败了烧掉五个首发窗口。

> 下面模板里的 `MacStats` 统一替换成 H2 选定的显示名；如果选 `MacStats Panel`，标题和正文都要跟着改。

### 4.2 r/macapps 模板

**Title**：

> I built a desktop panel for macOS CPU/memory/GPU — 1s refresh, four layouts, matches Activity Monitor

**Body**：

```text
I wanted a system monitor that stays on the desktop instead of living in a menu bar popover,
so I built MacStats.

What it is:
- An always-on desktop panel: CPU, memory, GPU, energy, disk, network.
- Refreshes every second (a plain NSPanel, not WidgetKit).
- Drag it from a one-line strip to a detailed panel; the layout reflows at four sizes.
- Numbers are checked against Activity Monitor (memory residual <= 0.2 GB, disk/network byte-for-byte).
- Also ships a WidgetKit widget for the desktop gallery, but the live panel is the main thing.

Install:
- Free to download; source is public on GitHub. License: {{LICENSE}}.
- macOS 15+, Apple silicon.
- The build is not notarized yet, so first launch is right-click -> Open. README has the details.

I'd love feedback on two things:
1. Do the numbers match Activity Monitor on your machine?
2. When your Mac feels slow, does the panel tell you what's causing it?

Repo: https://github.com/yichensunjoe/macstats
```

`{{LICENSE}}` 在发布前替换：H6 = MIT 写 `MIT`，Apache-2.0 写 `Apache-2.0`，保留所有权利写 `all rights reserved`。
如果 H6 是“保留所有权利”，**不要**写 “open source”；改成 “source is public, all rights reserved”。

不要写“please star”；不要贴下载直链绕过 README；不要在多个 subreddit 同一天重复发。

### 4.3 V2EX 模板

**标题**：

> [分享] MacStats：常驻桌面的系统监控面板，1 秒刷新、四档版式

**正文**：

```text
做这个的起因很简单：活动监视器够全，但它是个窗口，要开、要点、要切前台。
我想在桌面上放一块表，瞥一眼就知道机器吃紧没有。

它是什么：
- 桌面常驻 NSPanel，CPU / 内存 / GPU / 能耗 / 磁盘 / 网络六项。
- 1 秒刷新，不走 WidgetKit 的时间线，所以数字是真的在跳。
- 拖宽/拖窄会在极简、紧凑、标准、详细四档之间自动重排，不是固定槽位。
- 口径按活动监视器对：内存残差 <= 0.2 GB，磁盘/网络累计逐字节一致。
- 另有系统小组件，但主形态是桌面面板。

安装：
- 免费下载，源码公开（许可证：{{LICENSE}}）；macOS 15+ / Apple 芯片。
- 目前没有公证，首次需要右键 -> 打开；README 里有校验和另一种放行方式。

想请教两件事：
1. 你机器上的数和活动监视器对得上吗？
2. 卡的时候，它有没有告诉你是谁在吃资源？

仓库：https://github.com/yichensunjoe/macstats
```

发在 `分享创造` 或 macOS 节点前，先读该节点置顶规则；不要一帖多版。

### 4.4 小红书模板（仅公证后）

**标题**：

> Mac 卡的时候，桌面这块小表会告诉你是谁在吃 CPU

**正文**：

```text
不是菜单栏里藏一个数字，是直接钉在桌面上的一块表。

CPU、内存、GPU、磁盘、网络，一秒跳一次；
拖宽一点会自己摊开成详细面板，拖窄就变成一条指示灯。

最喜欢的是历史回看：
下午三点那阵卡，点一下峰值，能看到当时是哪个 App 在吃 CPU。

macOS 15+ / Apple 芯片，免费下载、源码公开。
（已公证，双击即可打开；安装包在 GitHub Release。）
```

配图：首图用 GIF 截帧（面板 + 峰值 popover），第二张极简条宽窄对比，第三张安装三步。标签不超过 5 个，不写“最强”。

### 4.5 许可证口径（发布前必查）

README 现在写的是“暂未指定开源许可证，默认保留所有权利”，而旧文案模板写了 “Free and open source (MIT)”。
两者只能有一个是真的：

- H6 = MIT / Apache-2.0：A7 放 `LICENSE`，README 许可节改对；帖子可以写 “open source”。
- H6 = 保留所有权利：不创建 `LICENSE`；帖子写 “free to download, source is public, all rights reserved”，不要写 “open source / 开源”。

发布前用这条命令核对：

```bash
grep -n -A2 -iE 'license|许可' README.md docs/readme/README_en.md
ls LICENSE 2>/dev/null || true
```

### 4.6 Show HN（不第一波）

只有满足以下条件再发：

- 第一渠道 ≥50 下载且反馈正向；
- 有一句能站住的钩子（“1 秒刷新，不走 WidgetKit 的 60 秒时间线”）；
- README 首屏、GIF、安装路径已经稳定；
- 能当天回复评论。

标题格式：`Show HN: MacStats – A 1s-refresh desktop panel for macOS system stats`。不要买票、不要请人 upvote。

---

## 5. 发布与响应（C4）

### 发布前 10 分钟检查

- [ ] 安装链接指向 `releases/latest/download/MacStats.zip`，匿名 `curl -sIL` 200；
- [ ] README 首屏有下载按钮、GIF、三步安装；
- [ ] 帖子里的版本/大小/测试数与实际一致；
- [ ] 没有残留 `{{LICENSE}}`、`{{VERSION}}` 之类占位符；
- [ ] 未公证的说明写在帖子或首条评论里，不藏；
- [ ] Issue 模板可用；
- [ ] 基线已记录。

### 发布后 24 小时

- 每 2–3 小时看一次评论；**当天回复所有问题**，尤其是安装失败；
- 安装失败：让对方贴 macOS 版本、芯片、Gatekeeper 截图；能远程定位就定位，不能就记进反馈表；
- 数字质疑：请对方用同一时刻截图对比；如果是真偏差，记 Issue，不在评论里争；
- 不要删差评；不要和竞品粉丝吵架；不要承诺“下周就加”。

### 反馈记录模板

`docs/experiments/2026-10-launch.md`：

| 日期 | 渠道 | 原话（可引用） | 类型 | 动作 | Issue |
|---|---|---|---|---|---|
| 2026-10-xx | r/macapps | “memory numbers match AM on my M2” | 数字 | 无 | — |
| 2026-10-xx | V2EX | “right-click still blocked” | 安装 | 补文档 | #12 |

类型只有五类：`安装 / 数字 / 功能 / 信任 / 性能`。不要按“用户情绪”分类。

---

## 6. 测量与决策（C5/C6）

### 24h / 72h / 7d 记录

每次记录同样五项：

1. Release 资产下载数（增量，扣自测）；
2. GitHub views / clones / referrers；
3. 帖子浏览量/评论数（平台给的数）；
4. 新增 Issue 数、反馈条数；
5. 安装失败条数与占比。

### 第 7 天复盘

写 `docs/decisions/0002-launch-experiment.md`：

- 结果：下载数、反馈数、安装失败占比；
- 判据落在哪一档；
- 决定：继续 / 改一个变量 / 停止加功能；
- 下一步具体动作（不超过 3 条）；
- 偏差：哪些数据拿不到、哪些是猜测。

### 失败诊断（<20 下载时按顺序查）

1. **有没有曝光**：帖子浏览量 <100 → 渠道/时间/标题问题，不是产品；
2. **有曝光没下载**：首图/GIF 没让人看懂，或安装说明吓人；
3. **有下载没反馈**：帖子没问具体问题；改成“数字对得上吗/卡的时候有没有告诉你原因”；
4. **安装失败多**：A 的锅，先修安装/公证，不要继续发；
5. **有人说“像 Stats”**：差异没被看见；换 GIF 的第一个镜头，先演“拖拽变版式”，不要先演指标。

**不要在失败后立刻加功能。** 失败通常不是功能不够，是承诺不清或渠道不对。

---

## 7. 完成定义

- [ ] 基线已记录（下载、views、referrers、stars）。
- [ ] 20 秒 GIF 完成，<5 MB，首屏能看懂“桌面面板 + 1 秒刷新 + 拖拽变版式”。
- [ ] 一个渠道的帖子已发；标题/正文与 H1 受众一致。
- [ ] 发布后 24 小时回复了所有安装/数字问题。
- [ ] 7 天数据已记；反馈表至少 5 行（如果只有 2 行，如实写）。
- [ ] `docs/decisions/0002-launch-experiment.md` 已写，决定明确。
- [ ] 没有刷票、没有多社区同日重复发、没有删差评。

---

## 8. 风险与边界

| 风险 | 处理 |
|---|---|
| 被当成广告/自我推广 | 先读社区规则；正文多讲“怎么做的/哪里不准”，少讲“快下载” |
| 未公证被骂 | 帖子/首条评论主动说明；把“右键打开”写清楚；非技术渠道先公证 |
| 下载数被自己污染 | 发布前记基线；校验下载单独记；复盘时扣除 |
| 评论里出现安全质疑 | 给源码、构建脚本、签名命令；不争论，给可复现步骤 |
| 只有点赞没有下载 | 点赞不是判据；看下载和反馈；必要时换渠道 |
| 一周后没人理 | 正常；记录数据，按判据停，不要用“再发五个地方”掩盖 |

---

## 9. 交接给下一轮

C 结束后，下一轮只需要三样东西：

1. 一页实验结果（下载、反馈、安装失败、决定）；
2. 5 条可引用的用户原话；
3. 一个按证据排序的下一步（最多 3 项）。

不要用“感觉用户喜欢”替代数据；也不要用一次下载量替代长期留存。
