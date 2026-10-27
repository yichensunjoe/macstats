# 0001 · 定位与信任（H1–H6 决策记录）

> 决策日期：2026-10-26（H2 于 2026-10-27 修订，见文末）
> 拍板人：用户（在会话中逐项选择）
> 上位文档：[`docs/roadmap-v0.4.md`](../roadmap-v0.4.md) §6、[`A · 定位与信任`](../roadmap-v0.4/A-positioning-and-trust.md)

## 决策表

| ID | 决策项 | 选择 | 理由 / 影响 |
|---|---|---|---|
| **H1** | 未来两周服务谁 | **开发者 / 技术型 prosumer** | 零预算、渠道免费、能接受右键打开；拿到真实用户反馈后再评估是否为另一类人投入公证成本。 |
| **H2** | 对外显示名 | **`MacStats Panel`**（2026-10-27 修订；原选择 `MacS`） | 查重后回退到备选：`MacS` 与 `Macs Fan Control` 等邻接，搜索与商标风险高。改名范围：`CFBundleDisplayName`、Cask `name`、10 份 README 标题、`docs/install.md`、`.appName/.menuAbout/.aboutSection`。**Bundle ID `com.macstats.app` 与下载文件名 `MacStats.zip` 不动**。 |
| **H3** | 第一个渠道 | **先不分发** | 用户明确本轮不做渠道投放；C 轨道整体暂缓，等用户重新授权。这意味着 A/D/B 的产出先作为"可发布状态"存在，不进入 7 天实验。 |
| **H4** | 是否现在公证 | **暂不做** | 与 H1（开发者）一致：开发者可接受右键打开。若将来切非技术用户或 H3 重启，再走 A4。 |
| **H5** | 版本节奏 | **先发 0.3.1（只修安装/文案/显示名），B 进 0.4**（2026-10-26 修订：取消 0.3.1，直接发 0.4，见文末） | 归因功能不阻塞发布；原计划 0.4 在 0.3.1 之后，现因 H3 暂缓与 B 全部完成改为直接 0.4。 |
| **H6** | 许可证 | **MIT** | 与 Stats 同为 MIT，便于采用与贡献；README 现有"保留所有权利"必须改成 MIT，C 的文案才可以说 open source。 |

## 由决策推导的执行边界

1. **A 轨道**：A2（显示名 `MacStats Panel`）→ A7（MIT 许可证）为必做；A3（安装文档）按开发者路径写；A5（首屏）在 H3 不分发的前提下可延后到重启分发前；A4（公证）不做；A6（Issue 模板）低优先，可随 A2 一起做。
2. **C 轨道**：整体暂缓（H3）。不做 GIF、不做渠道实验、不记 7 天数据；`docs/experiments/` 不创建。
3. **B 轨道**：照原计划推进（B1/B2/B3/B6a → B4/B5），与 H1/H3 无关。
4. **D 轨道**：D0/D1/D2/D3 已完成；D4（任务清单格式）可顺手做；D5（分支保护）需用户授权，暂不做。
5. **版本**：0.3.1 已取消；直接发 0.4（含 B1–B6 与 A/D 的产物），理由见文末修订。

## 风险与待确认

- **`MacS` 命名风险**：极短、与 `MacStats` 仅差两字符，且"MacS"可能已被其他项目/产品占用；改名后老用户搜索可能迷路。缓解：README 顶部保留"原名 MacStats"一行；若查重发现冲突，回退 `MacStats Panel`（H2 备选）只需改回一处 `CFBundleDisplayName` 与文档标题。
- **H3 不分发的后果**：0.4 的功能改进没有真实用户验证，决策门无法触发；这与方案 §7.1 的实验设计冲突，需用户后续重新授权。
- **H4 暂不公证**：非技术用户路径不可用；`docs/install.md` 必须继续明确写"未公证、首次启动需在系统设置里点「仍要打开」"，不得暗示双击可用。（2026-10-27 实测：macOS 15 起拦截弹窗已无「打开」按钮，"右键 → 打开"只在 macOS 14 及更早有效。）

## 修订：取消 0.3.1，直接发 0.4（2026-10-26）

原 H5 的前提是"C 先用 0.3 验证需求，B 不阻塞发布"。执行到 Wave 3 后，这个前提已经不成立：

1. **H3 已暂停分发**，C 轨道没有 7 天实验，0.3.1 原本要服务的"快速发布"没有对象。
2. **B0–B5、B6a 已全部落地**，175 项单测、`--self-check`、归档三校验均通过；归因功能不再是待做项，没有"被功能拖住"的风险。
3. 从 `v0.3` 拉分支只 cherry-pick 安装/文案/显示名，需要处理 10 份 README 与测试数的冲突，然后紧接着再发 0.4——多一次构建、多一次签名、多一次回滚面，收益为零。

**结论**：0.3.1 不发布、不建 `release-notes-0.3.1.md`；`VERSION` 直接置 0.4，发布说明用已写好的 `docs/release-notes-0.4.md`。若将来重启分发且仍想要一个"只修文案"的快版本，再从 `v0.3` 单独切分支，不在当前 main 上倒推。

## 修订：H2 回退 `MacStats Panel`（2026-10-27）

查重结论（见下节）是「没有精确同名监控应用，但 `MacS` 不干净、不可防御」。用户据此拍板：**对外显示名回退
`MacStats Panel`**。这一版把决策落到实处：

- 改：`CFBundleDisplayName`、Cask `name`、`.appName` / `.menuAbout` / `.aboutSection`（中英）、
  10 份 README 标题与正文、`docs/install.md`、Issue 模板、`--help` 首行。
- 不改：`CFBundleIdentifier`（`com.macstats.app`）、仓库名 `macstats`、产物名 `MacStats.app` / `MacStats.zip`、
  系统小组件画廊名「系统监视」（`.widgetTitle`）、偏好键与历史目录。
- 已发布版本（0.4–0.4.2）仍显示 `MacS`，它们的历史发布说明保留原样；显示名以安装的版本为准，
  0.4.3 起统一为 `MacStats Panel`。
- 从 0.4.x 升级不丢偏好、不丢已添加的小组件（Bundle ID 未变）。

## 附：`MacS` 查重记录（2026-10-26）

**结论：没有发现同名的 Mac 系统监控应用；但 `MacS` 不是干净、可防御的名字，不建议在公开发布/推广中继续使用。**

| 查重面 | 方法 | 结果 |
|---|---|---|
| Mac App Store | iTunes Search API，`term=macs`，`entity=macSoftware`，US / CN / GB / DE / JP | **没有 `MacS` 精确同名**；CN/GB/DE/JP 各 167–194 条结果中精确命中 0，US 早先 37 条模糊结果中精确命中 0。商店搜索是模糊匹配，不能当作完整索引。 |
| GitHub | 仓库名精确匹配 `macs` | 已有 `checkra1n/macs`（Apple Silicon 计划）与 `KoljaWindeler/macs`（门禁系统），都不是系统监控；**没有 `MacS` 监控项目**。邻接项目：`crystalidea/macs-fan-control`（1.7k ★）、`iliyami/MacSai`（约 2k ★，Mac 清理工具）。 |
| Homebrew | cask token / name 含 `macs` | `macs-fan-control`、`mac-sai`；**没有 `macs` cask**。前者在 MacUpdate 有约 114 万下载、5,982 条评分。 |
| 域名 | RDAP + 页面 | `macs.app` 2018-05-08 注册、2027-05-08 到期，当前在线且页面标题为 `M.A.C.S.`；`getmacs.com` / `macs.io` 是停放页。 |
| 商标 | Justia `MacS` 检索 | 大量 `MACS` 记录，含 1974 年 Management and Computer Services（与 Wired 报道的 1985 年 Apple/MACS 和解案同名，是否同一主体未核实）、1996 年 Smith-Gardner、EU Miltenyi（class 42 含软件，但限定生物分离）。**未做正式商标检索，也未逐条核实法律状态。** |
| 产品页 | Exa / MacUpdate / Product Hunt | 未发现同名 Mac 监控产品；最接近的新品叫 `MacSentinel`，不是 `MacS`。 |

**风险**：

1. **搜索混淆**：`MacS` 与 `Macs` 只差一个字母，搜索引擎和 App Store 会模糊匹配到 Macs Fan Control、Macs Cue、MacSales 等；用户很难通过名字找到我们。
2. **商标弱**：`MacS` 描述性强、与 Apple 的 `Mac` 及既有 `MACS` 标记都近；在没有律师意见前，不适合把品牌资产押在它上面。
3. **域名已占**：`macs.app` 已被注册并在线，无法拿到最直觉的域名。

**建议**：

- 若 H3 维持"不分发"、只做个人/开发者本地使用：可以继续用 `MacS`，实际风险低，但不要公开推广或投放。
- 若要做公开分发：回退到 H2 备选 **`MacStats Panel`**，或另取一个 coined name 后重跑本表。`MacStats Panel` 仍靠近 `MacStats.app` 与 App Store 的 `Stats Panel`，但比 `MacS` 更可搜索，也不与 `Macs Fan Control` 直接混淆。
- 改名成本：显示名、Cask `name`、10 份 README 标题、`docs/install.md`、`.appName/.menuAbout` 等文案；**务必在 push/tag 前改完**，发布后改名要再发一版。

Sources: [Macs Fan Control](https://crystalidea.com/macs-fan-control)、[Mac Sai](https://github.com/iliyami/MacSai)、[macs.app](https://macs.app)、[Justia MACS](https://trademarks.justia.com/search?q=MacS)、[Wired: Apple/MACS 1985](https://www.wired.com/2007/01/steve-jobs-trad/)。
