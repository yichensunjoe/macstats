# E · 并行执行与文件所有权

> 上位文档：[`docs/roadmap-v0.4.md`](../roadmap-v0.4.md)。
> 读者：负责调度多个 agent 的执行者。本文只讲“怎么并行不打架”，不复述产品判断。

---

## 1. 基本原则

1. **先契约，后并行**：`ProcessAttribution`（B0）先合并；其他人依赖它，不各自造类型。
2. **一个文件同一时间只有一个 writer**：并行的是文件，不是同一段代码。
3. **波次屏障**：同一波次内只编辑、不互相等；波次结束由协调者统一构建/测试/提交。
4. **agent 不直接 commit/push**：同一 worktree 的 git index 是共享的，并发 `git add` 会互相污染；由协调者按切片提交。除非该 agent 在独立 worktree 里工作。
5. **不替别人修文件**：发现别人的切片导致测试失败，报告给协调者，不要越界改。
6. **不执行发布**：`release.sh --publish`、`git push`、`gh release` 只能由用户授权后的协调者执行。

---

## 2. 文件所有权矩阵

> “独占”= 本切片期间只有这个 owner 能改；“只读”= 可以读，不能写。

### 2.1 B 轨道（代码）

| 文件 | Owner | 只读 | 备注 |
|---|---|---|---|
| `src/Sources/MacStatsCore/ProcessAttribution.swift` | B0 | 全体 | 新建；契约先合并 |
| `src/Tests/MacStatsCoreTests/ProcessAttributionTests.swift` | B0 | 全体 | 新建 |
| `src/Sources/MacStatsCore/HistoryStore.swift` | B1 | B2/B4/B5 | schema + 分钟聚合 |
| `src/Tests/MacStatsCoreTests/HistoryStoreTests.swift` | B1 | 全体 | — |
| `src/Sources/MacStatsCore/HistoryAnalysis.swift` | B2 | B4 | 新建；纯函数 |
| `src/Tests/MacStatsCoreTests/HistoryAnalysisTests.swift` | B2 | 全体 | 新建 |
| `src/Sources/MacStatsCore/ProcessRanking.swift` | B3 | B5 | 新建；纯函数 |
| `src/Sources/MacStatsCore/Metrics.swift` | B3 | B5 | 只加 optional 字段 |
| `src/Sources/MacStatsCore/SystemSampler.swift` | B3 | B5 | 截断前取 top CPU |
| `src/Tests/MacStatsCoreTests/ProcessRankingTests.swift` | B3 | 全体 | 新建 |
| `src/Tests/MacStatsCoreTests/ModelTests.swift` | B3 | 全体 | 加旧 JSON 兼容测试 |
| `src/Sources/MacStats/WidgetView.swift` | B4 | 全体 | 峰值按钮 + popover |
| `src/Sources/MacStatsCore/Localization.swift` | **B6a（Wave 2）→ B4（Wave 3）** | B5/B6 | 严格串行，单 writer |
| `src/Tests/MacStatsCoreTests/LocalizationTests.swift` | B6a → B4 | 全体 | 同上 |
| `src/Sources/MacStats/AppDelegate.swift` | **B5（Wave 3）→ B6b（Wave 4）** | B6a | B6b 只加一个调用点 |
| `src/Sources/MacStatsCore/ThresholdAlerts.swift` | B5 | B4 | culprit 字段 |
| `src/Tests/MacStatsCoreTests/ThresholdAlertsTests.swift` | B5 | 全体 | 如不存在则新建 |
| `src/Sources/MacStats/ProcessDialogs.swift` | B6a | B6b | 文案；B6b 只加测量展示 |
| `src/Sources/MacStatsCore/ProcessCleanup.swift` | B6a | B6b | 只改 `freedBytes` 注释 |
| `src/Sources/MacStatsCore/CleanupMeasurement.swift` | B6b | 全体 | 新建；可选任务 |

### 2.2 A / C / D（文档与运维）

| 文件 | Owner | 只读 | 备注 |
|---|---|---|---|
| `scripts/bundle.sh` | **D0 → A2 → A4** | 全体 | BUILD → 显示名 → 公证；严格串行 |
| `BUILD` | D0 | 全体 | 新建 |
| `Casks/macstats.rb` | A2 | 全体 | 只改 `name` |
| `README.md` | **A2 → A3 → A5 → A7 → D2 → B7** | 全体 | 名字 → 安装节 → 首屏 → 许可 → 数字 → 历史说明；严格串行 |
| `docs/readme/README_en.md` | A2 → A5 → A7 → D2 | 全体 | 同上 |
| `docs/readme/README_*.md`（其余 8 份） | A2（只改标题）→ A7（许可节）→ D2（数字/URL） | A5 | 不重写正文 |
| `LICENSE` | A7 | 全体 | 新建；按 H6；同时改 10 份 README 的许可节 |
| `docs/install.md` | A2 → A3 → A4 | 全体 | 产品名 → 安装路径 → 公证措辞 |
| `.github/workflows/ci.yml` | D1 | 全体 | 新建 |
| `.github/ISSUE_TEMPLATE/*` | A6 | 全体 | 新建；与 D1 不同子路径 |
| `scripts/check-docs.py` | D2 | 全体 | 新建 |
| `docs/_meta.json` | D2/D3 | 全体 | `--prepare` 写入 |
| `scripts/release.sh` | D3 | 全体 | 新建 |
| `docs/tasks.md` | D4 | 全体 | 本地忽略文件 |
| `docs/experiments/2026-10-launch.md` | C1/C5 | 全体 | 新建 |
| `docs/decisions/0001-positioning.md` | A1 | 全体 | 新建 |
| `docs/decisions/0002-launch-experiment.md` | C6 | 全体 | 新建 |
| `docs/demo.gif` | C2 | 全体 | 新建；<5 MB |
| `docs/release-notes-0.4.md` | B7 | 全体 | 新建 |
| `docs/requirements.md`、`docs/architecture.md` | B7 | 全体 | 只改与 B 相关的段落 |
| `docs/roadmap-v0.4*` | 协调者 | 全体 | 计划本身；worker 只读 |

---

## 3. 波次计划

> 时间以“agent 并行工作半天”为单位；不是日历天。波次之间必须过验收门。

### Wave 0 · 人工决策（阻塞）

- **H1** 受众、**H2** 显示名、**H3** 首渠道、**H4** 公证、**H5** 版本节奏、**H6** 许可证。
- 产出：`docs/decisions/0001-positioning.md`。
- 验收：六项都有明确选择；没有“待定”。
- **不开任何代码任务。**

### Wave 1 · 契约与护栏（4 路）

| 切片 | Owner | 文件 | 依赖 |
|---|---|---|---|
| B0 归因类型 | worker-b0 | `ProcessAttribution.swift` + 测试 | 无 |
| D0 BUILD | worker-d0 | `BUILD`、`bundle.sh` | 无 |
| D1 CI | worker-d1 | `.github/workflows/ci.yml` | D0 可选 |
| D2 文档检查 | worker-d2 | `scripts/check-docs.py`、`_meta.json` | 无 |

**验收门 G1**：

- `cd src && swift test --filter ProcessAttributionTests` 绿；
- `bash scripts/bundle.sh --archive` 后主程序与 appex `CFBundleVersion` 都等于 `BUILD`；
- `python3 scripts/check-docs.py` 能跑（允许因 A2/A5 未做而报“待更新”，但脚本本身不能崩）；
- CI YAML 语法可解析（`ruby -e 'require "yaml"; YAML.load_file(...)'` 或 GitHub 的 actionlint）。

**合并顺序**：B0 → D0 → D1 → D2。B0 必须先合并，Wave 2 才能开工。

### Wave 2 · 数据层与文案（6 个切片；A2/A3 串行）

| 切片 | Owner | 文件 | 依赖 |
|---|---|---|---|
| B1 历史 schema | worker-b1 | `HistoryStore.swift` + 测试 | B0 |
| B2 峰值分析 | worker-b2 | `HistoryAnalysis.swift` + 测试 | B0 |
| B3 采样 top CPU | worker-b3 | `ProcessRanking.swift`、`Metrics.swift`、`SystemSampler.swift` + 测试 | B0 |
| B6a 清理文案 | worker-b6a | `ProcessDialogs.swift`、`Localization.swift`、`ProcessCleanup.swift`（注释） | 无 |
| A2 显示名 | worker-a2 | `bundle.sh`、Cask、10 份 README 标题、install | H1/H2、D0 |
| A3 安装文档 | worker-a3 | `docs/install.md`、README 安装节 | H1/H4；H4=现在时等 A4 |

**验收门 G2**：

- `swift test --filter HistoryStoreTests`、`--filter HistoryAnalysisTests`、`--filter ProcessRankingTests`、`--filter ModelTests` 全绿；
- `swift test` 全量仍 ≥103 项且全绿；
- 旧 JSONL fixture 能读；旧 `MetricSnapshot` JSON 能读；
- 清理结果文案不再出现“释放 / freed”；
- `bundle.sh` 的 `CFBundleDisplayName` 等于 H2 选择；
- 干净 Mac 按 `docs/install.md` 能走到面板出现。

**合并顺序**：B1 → B2 → B3 → B6a → A2 → A3。  
**README 串行**：A2（标题）→ A3（安装节）都改 `README.md`，不要同时开工；A5 在 Wave 3 接手首屏。  
**注意**：B6a 是 Wave 2 的 `Localization.swift` 唯一 writer；B4 在 Wave 3 接手，不要跨波次并行。

### Wave 3 · UI 与集成（5 路）

| 切片 | Owner | 文件 | 依赖 |
|---|---|---|---|
| B4 峰值 UI | worker-b4 | `WidgetView.swift`、`Localization.swift`、`LocalizationTests.swift` | B1/B2 |
| B5 集成/告警 | worker-b5 | `AppDelegate.swift`、`ThresholdAlerts.swift` + 测试 | B1/B3/B4 的 key |
| A5 首屏 | worker-a5 | `README.md`、`README_en.md` | A2、H1/H2 |
| A6 反馈入口 | worker-a6 | `.github/ISSUE_TEMPLATE/*` | H1 |
| D3 发布脚本（起） | worker-d3 | `scripts/release.sh` | D0/D1/D2 |

**B4/B5 的依赖处理**：

1. B4 先在 `Localization.swift` 加齐 B4+B5+B6 需要的 key（一次加完，避免反复抢文件）；
2. B5 在 B4 的 key 提交后再接线；
3. 如果 B5 先完成逻辑，可先用旧 key 占位，B4 合并后再替换；**不要**让 B5 直接改 `Localization.swift`。

**验收门 G3**：

- `swift test` 全绿；
- 372×640 / 600×660 快照无布局回归；
- 点击 CPU/内存峰值出现 popover；旧历史显示“当时未记录进程”；GPU 显示“暂未记录”；
- 实机 `yes > /dev/null` 触发一次 CPU 告警，通知含进程名；
- README 首屏 5 秒测试通过；
- 三个 Issue 模板出现。

**合并顺序**：B4 → B5 → A5 → A6 → D3。

### Wave 4 · 收尾（6 路）

| 切片 | Owner | 文件 | 依赖 |
|---|---|---|---|
| A4 公证（条件） | 用户 + worker-a4 | `bundle.sh`、`docs/install.md`、release notes | H4 = 现在；A2 之后；需 Apple 账号/2FA |
| A7 许可证 | worker-a7 | `LICENSE`、10 份 README 许可节 | H6；A5 之后 |
| B6b 清理测量（可选） | worker-b6b | `CleanupMeasurement.swift` + 测试、`AppDelegate.swift` 一个调用点 | B5/B6a |
| B7 文档与 0.4 notes | worker-b7 | `requirements.md`、`architecture.md`、`release-notes-0.4.md`、README 历史节 | B1–B6 |
| D3 发布脚本（完） | worker-d3 | `scripts/release.sh` | D1/D2 |
| C2 素材 | worker-c2 | `docs/demo.gif`、截图 | A5、B4（可选） |

**验收门 G4**：

- 全量 `swift test`、`macstatsDiag --self-check`、`--cleanup-dry-run` 全过；
- `bash scripts/bundle.sh --archive` + `codesign` + `unzip -t` + `shasum` 全过；
- `python3 scripts/check-docs.py` 全过；
- `bash scripts/release.sh --dry-run` 通过；
- 干净 Mac 安装 + 峰值点击 + 告警 + 清理文案实机核对；
- `LICENSE` 与 README 许可节一致；C 的许可证口径不再声称未选定的许可证；
- GIF <5 MB，首屏能看懂。

**合并顺序**：A4（若做）→ A7 → B6b → B7 → D3 → C2。

### Wave 5 · 发布与实验（串行）

- 协调者/用户：`release.sh --publish`（需授权）；
- C3：发第一个渠道；
- C4/C5：24h/72h/7d 记录；
- C6：第 7 天写 `0002-launch-experiment.md`；
- 按判据决定是否开第二渠道、是否进 0.4.1。

---

## 4. 并行工作模式

### 模式 A（推荐，≤4 个 agent）

**同一个 worktree + 文件独占 + 构建锁**。

- 所有 agent 在 `projects/active/P087-macstats-widget` 工作；
- 只改自己矩阵里的文件；
- 同一时间只允许一个 `swift build` / `swift test`：
  ```bash
  # 抢构建锁；抢不到就等
  mkdir .build-lock 2>/dev/null || { echo "build busy"; exit 75; }
  trap 'rmdir .build-lock' EXIT
  cd src && swift test --filter <YourTests>
  ```
  `.build-lock` 不提交；
- 波次结束由协调者跑全量测试并提交。

### 模式 B（>4 个 agent 或需要独立构建）

**每个切片一个 git worktree**，放在项目内 `.worktrees/<slice>`（不提交；加到 `.git/info/exclude`）。

```bash
cd projects/active/P087-macstats-widget
git worktree add .worktrees/b1 -b feat/0.4-b1-history
cd .worktrees/b1
# 在该目录编辑/构建/测试；完成后由协调者按顺序合并
```

- 适合 B1/B3 这种要反复编译的切片；
- 合并回 `feat/0.4` 或 `main` 时按 §5 顺序；
- 不要让两个 worktree 同时改同一文件；
- 完成后 `git worktree remove .worktrees/b1`（确认无未提交改动）。

### 不推荐

- 多个 agent 同时 `git add` / `git commit` 同一个 worktree；
- 多个 agent 同时跑 `swift build` 同一个 `.build`；
- 在共享 worktree 里切分支/重置；
- 用 `pkill -f swift` 清理构建（会杀到别的 agent）。

---

## 5. 分支、提交与合并

### 分支

- 集成分支：`feat/0.4`（从 `main` 切出）；
- 切片分支（模式 B）：`feat/0.4-b0-contract`、`feat/0.4-b1-history`……；
- 发布前把 `feat/0.4` 合并回 `main`，跑完整验收，再打 tag；
- 不 force push、不改写已推送历史。

### 提交

- 一个切片一个提交；消息 `<type>: <简述>` ≤72 字符；
- 例：`feat: history samples keep top CPU processes`、`fix: stop claiming RSS sum as freed memory`、`chore: add macOS CI`；
- 不提交：`dist/`、`MacStats.app/`、`.build/`、`docs/_meta.json` 之外的临时文件、密钥、日志；
- `AGENTS.md`、`HANDOFF.md`、`REUSE_AND_PITFALL_LOG.md`、`docs/tasks.md` 是本地忽略文件，不进入仓库提交（按项目 `.gitignore`）。

### 合并顺序

1. B0
2. D0 → D1 → D2
3. B1 → B2 → B3 → B6a
4. A2 → A3
5. B4 → B5
6. A5 → A6
7. B6b（可选）→ B7 → D3
8. C 文档/素材

冲突处理：

- 同一文件被两个切片改了：停下来，协调者指定一个 owner，另一个把改动写成 patch/说明；
- 契约需要变：B0 owner 改类型并通知所有依赖；不要在各自文件里加“临时字段”；
- 测试因别人未完成而红：不要修别人的文件；在波次门统一处理。

---

## 6. 验收门与命令

### 每个切片（本地）

```bash
cd projects/active/P087-macstats-widget/src
swift build
swift test --filter <SliceTests>
```

### 每个波次（协调者）

```bash
cd projects/active/P087-macstats-widget

# 1. 全量测试
cd src && swift test
cd ..

# 2. 诊断
cd src && .build/debug/macstatsDiag --self-check
cd ..
cd src && .build/debug/macstatsDiag --cleanup-dry-run
cd ..

# 3. 归档与完整性
bash scripts/bundle.sh --archive
codesign --verify --deep --strict --verbose=2 MacStats.app
unzip -t dist/MacStats.zip
(cd dist && shasum -a 256 -c MacStats.zip.sha256)

# 4. 文档
python3 scripts/check-docs.py

# 5. 发布预演（Wave 4 起）
bash scripts/release.sh --dry-run
```

### 视觉

```bash
cd src
swift build -c release
.build/release/MacStats --snapshot 372x640 /tmp/p087-standard.png
.build/release/MacStats --snapshot 600x660 /tmp/p087-expanded.png
```

（以 `SnapshotRenderer.swift` 的实际参数为准；如参数不同，按现有文档命令执行。）

### 人工

- 干净用户账户/未装过 Xcode 的 Mac：下载 → 安装 → 面板出现；
- 点 CPU/内存峰值 → popover 出现 → 关闭；
- 打开告警 → `yes > /dev/null` 30 秒 → 通知含进程名；
- 清理：确认框文案不含“释放”；`--cleanup-dry-run` 不误选系统/终端/有子进程的进程。

---

## 7. Agent 任务简报模板

派活时直接复制，减少来回：

```text
你是 <切片 ID>（<标题>）。
只改这些文件（独占）：<路径列表>。
只读：<路径列表>。
依赖：<已完成切片/契约>。
契约：<结构体/函数签名/字段语义>。
步骤：<3–6 条>。
验收：<可执行命令 + 预期>。
不要做：<越界项、别改的文件、别跑的命令>。
完成后报告：改了哪些文件、跑了哪些测试、截图/日志、遗留风险。
```

**不要**在简报里写“顺便优化一下”“看着办”；每个切片只解决一件事。

---

## 8. RACI

| 事项 | 用户 | 协调者 | 轨道 lead | worker |
|---|---|---|---|---|
| H1–H6 决策 | A | R | C | I |
| 契约 B0 | I | A | R | R |
| 代码切片 | I | A | C | R |
| 波次验收 | I | R | C | I |
| 发布/推送 | A | R | C | I |
| 渠道发帖 | A | R | C | I |
| Apple 证书/公证 | A/R | C | C | I |

（A=批准，R=负责，C=咨询，I=知情。）

---

## 9. 失败与升级

- **构建锁抢不到**：等 5 分钟；仍抢不到，报告协调者，不要杀进程。
- **测试红且不是自己文件**：记录失败命令/输出，报告协调者；不要改别人的测试。
- **契约冲突**：停在 B0，协调者决定是否扩展契约；不要各自加字段。
- **数据/隐私疑问**：默认不存路径、用户名、命令行；需要新增字段先问。
- **发布失败**：不要重试 `--publish` 第二次；先检查 tag/Release 是否已创建，按 D3 回滚步骤处理。
- **社区负面反馈**：C4 处理；不要在产品里连夜加功能。

---

## 10. 完成定义（执行层）

- [ ] Wave 0 的 ADR 存在且六项无“待定”。
- [ ] G1–G4 每道门都有记录（命令、结果、失败项）。
- [ ] 每个切片一个提交，提交信息能看出改了什么。
- [ ] 没有并发写同一文件；`Localization.swift`、`AppDelegate.swift`、`bundle.sh`、`README.md`、`LICENSE` 的串行顺序被遵守。
- [ ] 全量测试、归档、文档检查、dry-run 全过。
- [ ] 发布与发帖均由用户授权，未自动执行。
