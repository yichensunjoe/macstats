## 这次能回答「是谁」

**MacS 0.4**（原名 MacStats；构建号见仓库根 `BUILD`）

0.3 的历史只知道「什么时候高」；0.4 起，点开 24 小时峰值就能看到「当时是谁」。

### 新增

- **历史点记录 top 3 进程**：每个分钟点额外保存该分钟 CPU 最高的最多 3 个进程
  （名字 / CPU / 内存）。同一秒的同名进程先合并，再按分钟取峰值——问的是「那阵卡是谁」，
  峰值比一分钟平均更接近元凶。旧历史没有这个字段，读出来是「未记录」，不回填、不伪造。
- **峰值可点开**：标准与详细面板的历史卡上，CPU / 内存 / GPU 的 24 小时峰值文字变成按钮
  （外观不变），点开浮层显示该峰值的时间、数值，以及**当时 CPU 最高的 3 个进程**
  （名字、CPU%、内存，每条附一句人话解释）。
  - **GPU 归因暂未记录**：当前采样拿不到可靠的 per-process GPU 占用，浮层如实写「暂未记录」，不猜。
  - **0.4 之前的历史没有进程**：显示「当时未记录进程（0.4 之前的历史）」，不拿当前进程列表顶替。
- **告警带进程名**：持续高负载通知的正文带当时的进程名——CPU 事件取 CPU 第一名、内存事件取
  内存第一名（两者分开排名，不复用同一个第一名），副标题是该进程的一句人话解释；
  磁盘事件没有进程归因，只报数值。阈值、连续 3 次、10 分钟冷却、默认关闭全部不变。
- **清理文案诚实化**：确认框与结果框不再说「释放 / freed」。结果框只报
  「这些进程终止前的内存合计为 X；系统实际回收量可能不同。」——RSS 求和不是系统实际回收量，
  先把话说准，测量留到有用户反馈之后。

### 变更

- **显示名改为 MacS**（原名 MacStats）：Finder、启动台、菜单栏、面板标题都显示 MacS；
  下载文件名仍是 `MacStats.zip` / `MacStats.app`，Bundle ID 仍是 `com.macstats.app`，
  偏好与已添加的小组件不受影响。
- **许可证改为 MIT**：README 与 10 份翻译 README 的许可节同步；可自由使用、修改、分发，含商业用途。
- 面板标题改用 App 显示名，不再复用小组件画廊名（「系统监视」仍是系统小组件库里的名字）。
- 测试数 103 → 175 项。

### 发布基础设施（0.4 起用）

- **CI**（`.github/workflows/ci.yml`）：push / PR 跑 `swift test`、归档、`codesign --verify`、
  `unzip -t`、`shasum -c`；`check-docs.py` 已接入但暂为 `continue-on-error`，0.4 发布前转硬。
  注意 CI 没有 Developer ID，走 ad-hoc 签名，只证明包完整，不代表 WidgetKit 真机可用。
- **BUILD 单一来源**：仓库根新增 `BUILD` 文件，`bundle.sh` 从这里读构建号
  （`MACSTATS_BUILD` 仍可覆盖）；发版只改 `BUILD`，不再改脚本。
- **文档一致性检查**（`scripts/check-docs.py`）：检查下载链接、版本号、测试数、包体大小、
  本地链接与页内锚点，抓 10 份 README 的机械漂移。
- **一条命令发布**（`scripts/release.sh`）：`--dry-run`（默认，只打印计划）、
  `--prepare`（刷新 `docs/_meta.json` 并修 README 数字）、`--publish`（需 `--yes`、
  干净 main、meta 匹配、无同名 tag）。发布仍是人工授权步骤，不会自动推送。

### 升级

- 偏好键没有改动，0.3 的设置、面板位置与已添加的小组件原样保留。
- 历史文件向后兼容：旧 JSONL 没有 `topProcesses` 键，照常读回；新点才开始带进程归因。
- 显示名变了但 Bundle ID 没变，所以偏好与小组件不会丢。

### 仍然如此

- 需要 macOS 15（Sequoia）+、Apple 芯片。
- 本包**未公证**（Apple Development 签名）：首次启动需右键 App →「打开」，
  或在终端执行 `xattr -dr com.apple.quarantine /Applications/MacStats.app`。
- 系统小组件约 60 秒一跳，这是 WidgetKit 的调度上限。
- 历史只在本机、只到分钟；没有云端同步，也没有秒级回放。
- 清理只动后台遗留孤儿，SIGTERM 后 3 秒没退出的保持运行，不升级成 SIGKILL。

验证：175 项单测全过；`macstatsDiag --self-check` 全 ok；`python3 scripts/check-docs.py` 0 错；
`bash scripts/bundle.sh --archive` 后 `codesign --verify --deep --strict`、`unzip -t`、
`shasum -a 256 -c` 全过；主程序与 appex 的 `CFBundleVersion` 均为 4。
