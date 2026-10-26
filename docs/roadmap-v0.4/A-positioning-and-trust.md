# A · 定位与信任

> 上位文档：[`docs/roadmap-v0.4.md`](../roadmap-v0.4.md)。本文只回答三件事：**为谁做、叫什么、怎么装。**
> 这是唯一必须先由人拍板的轨道；没拍板前，A 的代码/文案任务不要开工。

---

## 1. 目的与非目标

### 目的

让一个明确的目标用户在**不需要你在旁边解释**的情况下，完成“知道这是什么 → 敢下载 → 装得上 → 第一次打开看到数”的全过程。

### 非目标

- 不追求同时服务开发者和非技术用户。
- 不做 App Store 上架、内购、账号系统。
- 不因改名而改 Bundle ID（除非用户明确要求一次品牌断代）。
- 不重写 10 份翻译正文；翻译只同步机械部分（版本/测试数/下载链接/大小），由 D 的脚本维护。

---

## 2. 现状事实

| 项 | 现状 | 影响 |
|---|---|---|
| 产品名 | 仓库/README 叫 **MacStats**；`CFBundleDisplayName` 是 **系统监视小组件** | Finder/启动台显示的是描述词，不是品牌；朋友之间无法口口相传 |
| Bundle ID | `com.macstats.app`；扩展 `com.macstats.app.widget` | 改它 = 丢偏好与小组件身份；本方案不动 |
| 同名冲突 | `macstats.app` 是另一个付费产品，SEO 已铺 | 搜 “MacStats” 会被它压住；需要限定词或新名 |
| 安装 | Release zip → 拖进 `/Applications` → 右键打开；可选 `xattr` / Homebrew | 开发者可接受；非技术用户会被 Gatekeeper 吓退 |
| 签名 | Apple Development，无 Developer ID，`spctl` rejected | 公证是“入场券”，不是“优化项” |
| 首屏 | 已有下载按钮与三步安装；标题是“把活动监视器钉在桌面上” | 方向对；但受众不清，标题同时像对开发者和普通人说话 |
| 反馈入口 | 无 Issue 模板 / Discussions | 发布后反馈会散在评论里，无法归类 |

---

## 3. 两类受众，只能先选一类

| 维度 | 开发者 / 技术型 prosumer | 非技术 Mac 用户 |
|---|---|---|
| 他们雇它做什么 | 不切窗口就能确认机器状态；桌面好看、可定制 | 卡的时候告诉我为什么、该关什么 |
| 现在用什么 | 活动监视器、Stats、iStat Menus | 活动监视器（看不懂）、重启 |
| 触发场景 | 编译、跑容器、导出视频、长时间开一堆窗口 | 风扇响、机器烫、网页卡 |
| 安装容忍度 | 能接受 GitHub zip、右键打开、Homebrew | 只接受双击安装、已公证、最好 App Store |
| 渠道 | r/macapps、Hacker News、V2EX、GitHub | 小红书、少数派、B 站、朋友推荐 |
| 最有说服力的证据 | 1 秒刷新、四档版式、与 AM 同口径、103 项测试 | “谁在吃 CPU”的一句人话、告警、安装三步 |
| 价格敏感度 | 免费开源最好；可接受买断 | 可接受 $5–15 买断，但必须先敢装 |
| 反馈方式 | Issue、HN/Reddit 评论 | 私信、评论、退款/卸载 |
| 什么会杀死转化 | 数字和 AM 对不上、CPU 占用高 | “无法验证开发者”、找不到下载、装完不知道看哪 |

### 推荐：先开发者，两周后再评估

理由：

1. 零预算，渠道免费且与现状一致；
2. 现有安装路径（GitHub + 右键）对开发者不是障碍；
3. 开发者的反馈更具体（数字、崩溃、性能），适合修产品；
4. 非技术用户需要公证 + DMG + 中文引导，是一整条独立产品线，不该和第一轮实验混在一起。

**切换条件**：如果 H1 明确选非技术用户，则 A3/A4/A5 全部按“公证 + 双击 + 中文首屏”重做；不要在未公证时对这类用户说“三步安装”。

---

## 4. 名字：现在决定，代价最低

### 4.1 候选

| 方案 | 优点 | 缺点 | 建议 |
|---|---|---|---|
| 保持 `系统监视小组件` | 中文描述清楚；不用改 | 不是品牌；搜索结果是通用词；朋友无法口口相传 | 不推荐作为对外名 |
| `MacStats` | 与仓库/README 一致；短 | 与 macstats.app 冲突；搜索被压 | 可作为内部名；对外加限定词 |
| `MacStats Panel` | 与仓库同源、可搜索、点明“桌面面板”而非菜单栏 | 英文；比 MacStats 长 | **推荐（H1 选开发者时）** |
| 新名字 | 可彻底避开冲突 | 需查重、改所有文档/截图/Release；Bundle ID 若不改仍会残留旧名 | 仅在已有心仪且查重通过时 |

### 4.2 改名的两层成本

- **显示名（`CFBundleDisplayName`）**：便宜。改 `scripts/bundle.sh` 一处，重新打包即可；Finder/启动台/关于页跟着变。
- **Bundle ID（`com.macstats.app`）**：贵。改了会丢：
  - `~/Library/Preferences/com.macstats.app.plist` 里的偏好；
  - 小组件身份与已添加到桌面的实例；
  - 登录项、通知权限等系统记录。
  本方案**不动 Bundle ID**；如果将来要做，单独开一次“品牌断代”任务，带迁移脚本。

### 4.3 验收

- `defaults read "$PWD/MacStats.app/Contents/Info.plist" CFBundleDisplayName` 等于选定名。
- Finder/启动台显示选定名；README 标题、Release 标题、Cask `name` 一致。
- 仓库里不再出现“系统监视小组件”作为**应用**名（小组件库里的“系统监视”是另一个名字，可保留）。
- `CFBundleIdentifier` 仍为 `com.macstats.app`；偏好路径不变。

---

## 5. 安装路径：两种现实，二选一

### 5.1 开发者路径（H1 推荐）

保持现状，但把“为什么”写清楚：

1. 下载 zip → 解压 → 拖进 `/Applications`；
2. 右键 → 打开（Gatekeeper 单次放行）；
3. 可选：`xattr -dr com.apple.quarantine` 或 Homebrew。

文档必须同时给出：

- 校验：`shasum -a 256 -c MacStats.zip.sha256`；
- 未公证的原因（没有 Developer ID），以及源码可自行构建；
- 不把“右键打开”说成“绕过安全机制”，而是未付费公证开源 App 的常规路径。

### 5.2 非技术路径（H1 选另一类人时）

必须补齐：

1. Developer ID Application 证书（付费账号；若团队已付费，只需签发）；
2. `codesign --options runtime --timestamp` + `notarytool submit --wait` + `stapler staple`；
3. DMG（拖拽安装）或已公证 zip；
4. 首屏写“双击打开”，不再写右键；
5. `spctl -a -vv` 必须 `accepted`。

> 公证需要用户的 Apple 账号与 2FA，agent 不能独立完成；执行者要把这一步标成“人工 + 等待”，不要假装自动化。

---

## 6. 任务卡

### A1 · 决策记录（人工，0.5 天）

- **Owner**：用户 + 执行者（记录）
- **依赖**：无
- **产出**：`docs/decisions/0001-positioning.md`
- **内容**：
  - H1 受众（开发者 / 非技术）
  - H2 显示名（`MacStats` / `MacStats Panel` / 新名）
  - H3 首渠道（r/macapps / V2EX / 少数派 / 小红书）
  - H4 是否现在公证（是 / 等信号）
  - H5 版本节奏（0.3.1 先发 / 直接 0.4.0）
  - H6 许可证（MIT / Apache-2.0 / 保留所有权利）
  - 每条一句话理由 + 决策日期 + 谁拍的板
- **验收**：文件存在；六项都有明确选择；没有“待定”。
- **阻塞**：A2–A7、C 全部等它。

### A2 · 显示名落地（0.5 天）

- **Owner**：worker-a2
- **依赖**：A1（H2）
- **文件（独占）**：
  - `scripts/bundle.sh`（`CFBundleDisplayName`）
  - `Casks/macstats.rb`（`name`）
  - `README.md`（标题/首屏产品名）
  - `docs/readme/README_*.md`（9 份；只改一级标题/产品名，不改正文）
  - `docs/install.md`（产品名）
- **不要动**：`CFBundleIdentifier`、`WIDGET_ID`、`MacStats.app/Contents/Info.plist`（构建产物，重新生成）。
- **步骤**：
  1. 改 `bundle.sh` 的 `CFBundleDisplayName`；
  2. 改 Cask `name`；
  3. 改 10 份 README 的一级标题与首屏产品名；8 份翻译只改标题行，正文留给 D2 只同步数字/链接；
  4. 全局搜索旧名，确认只剩小组件库的“系统监视”；
  5. `bash scripts/bundle.sh --archive`，核对 plist。
- **验收**：
  - `defaults read "$PWD/MacStats.app/Contents/Info.plist" CFBundleDisplayName` = 选定名；
  - `grep -R "系统监视小组件"` 只出现在历史/日志/说明里，不作为应用名；
  - README 首屏 3 秒内能看出产品名与用途。
- **验证命令**：
  ```bash
  cd projects/active/P087-macstats-widget
  bash scripts/bundle.sh --archive
  defaults read "$PWD/MacStats.app/Contents/Info.plist" CFBundleDisplayName
  grep -R "系统监视小组件" README.md docs/readme docs/install.md scripts Casks || true
  ```
- **风险**：老用户找不到旧名 → README 顶部加一行“原名 MacStats / 系统监视小组件”。

### A3 · 安装文档对齐（0.5 天）

- **Owner**：worker-a3
- **依赖**：A1（H1/H4）
- **文件（独占）**：`docs/install.md`、`README.md` 的安装节
- **步骤**：
  1. 按 H1 选择“开发者路径”或“非技术路径”；
  2. 写清三步、两种 Gatekeeper 放行、校验、卸载；
  3. 加“装不上时先看这里”的 5 条排查（拦截、架构、系统版本、小组件不出现、Homebrew trust）；
  4. 如果 H4 = 现在公证，先等 A4 完成再改“双击”措辞。
- **验收**：在一台没装过 Xcode 的 Mac / 新用户账户上，按文档从 Release 下载到面板出现，全程不需要终端（开发者路径允许一次右键）。
- **验证**：录屏或截图 3 张（下载页、右键菜单、面板出现），放进 `docs/` 或 PR 描述。

### A4 · 公证（条件任务，1 天 + 等待）

- **Owner**：用户（证书/账号）+ worker-a4（脚本/文档）
- **依赖**：A1（H4 = 现在做）
- **文件**：`scripts/bundle.sh`、`docs/install.md`、`docs/release-notes-*.md`
- **步骤**：
  1. 确认 Developer ID Application 证书在钥匙串；
  2. `codesign --force --options runtime --timestamp --entitlements ...`（主程序与 appex）；
  3. `ditto` 出 zip → `xcrun notarytool submit --wait`；
  4. `xcrun stapler staple MacStats.app`；
  5. `spctl -a -vv` 应为 `accepted`；
  6. 更新安装文档为“双击打开”。
- **验收**：干净 Mac 下载后双击直接打开；`spctl` accepted；`stapler validate` 通过。
- **注意**：不要把 Apple ID / 专用密码写进仓库或日志；用 `notarytool` 的钥匙串 profile。

### A5 · 首屏与证据（0.5 天）

- **Owner**：worker-a5
- **依赖**：A1（H1/H2）、A2
- **文件（独占）**：`README.md`、`docs/readme/README_en.md`（首屏 + 1–2 段）
- **结构**：
  1. 一句话：给谁 + 解决什么（例：`MacStats Panel — 一块常驻桌面的实时仪表，1 秒刷新，口径对齐活动监视器。`）
  2. 三个证据：1 秒刷新 / 四档版式 / AM 同口径（各一句，不堆形容词）；
  3. 下载按钮 + 三步安装；
  4. 20 秒 GIF（C2 产出；先用占位图，发布前替换）；
  5. 一句“未公证，首次右键打开”（开发者路径）或“已公证，双击打开”（非技术路径）。
- **验收**：找 3 个目标用户看 5 秒，能说出“这是桌面上的系统监控”和“给 Mac 用的”；说不出来就重写标题。
- **不要**：同时写“给开发者”和“给小白”；不要用“最强/终极/一键释放”这类词。

### A6 · 反馈入口（0.5 天）

- **Owner**：worker-a6
- **依赖**：A1
- **文件（独占）**：
  - `.github/ISSUE_TEMPLATE/bug.yml`
  - `.github/ISSUE_TEMPLATE/install.yml`
  - `.github/ISSUE_TEMPLATE/feature.yml`
  - `.github/ISSUE_TEMPLATE/config.yml`
  - `.github/DISCUSSION_TEMPLATE/`（可选）
- **内容**：
  - bug：macOS 版本、芯片、MacStats 版本、复现步骤、截图、是否公证安装；
  - install：卡在哪一步、Gatekeeper 提示截图、是否试过右键/xattr；
  - feature：想解决的问题，不是“加个 XX 指标”；
  - config：留一个“使用问题”指向 Discussions。
- **验收**：新建 Issue 页面出现三个模板；每份模板不超过 6 个必填项；`config.yml` 链接可点。
- **风险**：模板太重会吓退反馈 → 必填项只留“版本/芯片/发生了什么”。
### A7 · 许可证落地（0.25 天，C 之前）

- **Owner**：worker-a7
- **依赖**：A1（H6）
- **文件（独占）**：
  - `LICENSE`（新建，按 H6 选 MIT / Apache-2.0）
  - `README.md` / `docs/readme/README_*.md`（10 份）的“许可”节
- **步骤**：
  1. 按 H6 放入标准许可证全文（不要改条款）；
  2. 10 份 README 的“许可”节改成许可证名 + 链接；8 份翻译的措辞可保留，但事实必须一致；
  3. 如果 H6 = 保留所有权利：**不要**创建 `LICENSE`，把 C 的文案改成“免费下载、源码公开、保留所有权利”，不得写“open source / 开源”。
- **验收**：若 H6 选 MIT/Apache，GitHub 仓库页显示许可证且 README 许可节与 `LICENSE` 一致；若保留所有权利，README 明确写“保留所有权利”且不创建 `LICENSE`。C 的文案与实际一致。
- **为什么放在 C 之前**：现在 README 写的是“暂未指定开源许可证，默认保留所有权利”，而 C 的帖子模板原本写了“Free and open source (MIT)”。不先定许可证，就是在发布页上说假话。


---

## 7. 完成定义

- [ ] `docs/decisions/0001-positioning.md` 存在，H1–H6 全部有明确选择。
- [ ] 显示名在 `bundle.sh`、Cask、10 份 README、install 文档一致。
- [ ] `LICENSE` 与 README 许可节一致；C 的文案与实际许可证一致。
- [ ] 一台干净 Mac 按文档走通；开发者路径不需要终端，非技术路径双击可开。
- [ ] 首屏 5 秒测试通过（3 个目标用户）。
- [ ] 三个 Issue 模板可用。
- [ ] 没有改 Bundle ID；偏好与小组件身份保留。

---

## 8. 风险与回滚

| 风险 | 回滚 |
|---|---|
| 改名后老用户找不到 | README 顶部加“原名 MacStats”；显示名改回 `MacStats`；Bundle ID 未动，偏好不丢 |
| 公证流程卡住（账号/2FA） | 回到开发者路径；文档明确写“未公证”，不要把非技术用户骗进来 |
| 首屏同时讨好两类人 | 只保留 H1 选中的那一类；另一类的话术移到 `docs/` 长文 |
| 翻译 README 与中文首屏不一致 | 中英先改；其余 8 份由 D2 脚本只同步数字/链接，正文等有需求再翻译 |
| Issue 模板太重 | 必填项压到 3 个；其余用“可选” |

---

## 9. 交接给 C 的东西

A 完成后，C 需要：

- 一句话定位（给谁、解决什么）；
- 选定显示名与统一写法；
- 首屏文案 + 3 个证据；
- 安装路径的准确说法（右键 or 双击）；
- 首图/GIF 的素材位置；
- 反馈入口链接（Issue / Discussions）。

把这些填进 [C](C-distribution-experiment.md) 的“发布包”清单，不要只留在聊天里。
