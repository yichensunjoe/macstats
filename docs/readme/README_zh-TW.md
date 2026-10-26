<div align="center">

[简体中文](../../README.md) · [English](README_en.md) · **繁體中文** · [日本語](README_ja.md) · [한국어](README_ko.md) · [Deutsch](README_de.md) · [Español](README_es.md) · [Français](README_fr.md) · [Русский](README_ru.md) · [Português (Brasil)](README_pt-BR.md)

# MacS

### 把「活動監視器」釘在桌面上的一塊即時儀表。

**CPU、記憶體、GPU、能耗、磁碟、網路，一眼看完；數值口徑逐項對齊活動監視器。**

[![macOS](https://img.shields.io/badge/macOS-15%2B-1d1d1f?style=flat-square&logo=apple&logoColor=white)](#安裝)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)](#實作方式)
[![tests](https://img.shields.io/badge/tests-175%20passing-3fb950?style=flat-square)](#指令)
[![dependencies](https://img.shields.io/badge/dependencies-none-4c8eda?style=flat-square)](#實作方式)

[安裝](#安裝) · [能看什麼](#能看什麼) · [兩種形態](#兩種形態) · [口徑對齊](#和活動監視器對到什麼程度) · [常見問題](#常見問題) · [限制](#已知限制)

**[下載 MacStats.zip](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip)** · 拖進 `/Applications`，首次右鍵 →「打開」

</div>

---

## 安裝

[**下載 MacStats.zip**](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip)（約 2.4 MB，macOS 15+ / Apple 晶片）

1. 解壓縮，把 `MacStats.app` 拖進 `/Applications`
2. 右鍵 MacStats →「打開」，確認一次（**未公證**，原因與另一種放行方式見[安裝說明](../install.md)）
3. 面板會出現在桌面；想要系統小工具，右鍵桌面 →「編輯小工具」→ 搜「系统监视」（小工具在系統中的名稱）

```bash
# 可選：清掉下載隔離屬性，之後雙擊即可
xattr -dr com.apple.quarantine /Applications/MacStats.app

# 或者用 Homebrew
brew tap yichensunjoe/macstats https://github.com/yichensunjoe/macstats
brew trust yichensunjoe/macstats      # Homebrew 5+ 需要明確信任第三方 tap
brew install --cask macstats
```

下載校驗：`shasum -a 256 -c MacStats.zip.sha256`（校驗檔在 Release 裡）。

<p align="center">
  <img src="../live-window.png" alt="MacStats 桌面面板：CPU、記憶體、GPU、能耗、磁碟、網路與記憶體佔用最高的程序" width="460" />
</p>

macOS 內建的活動監視器資訊夠完整，但它是一個視窗：要開啟、要點分頁、要切到前景。MacStats 把同樣六個指標做成一塊常駐桌面的深色面板——每秒取樣、隨視窗尺寸自動換版型，另外提供 WidgetKit 系統小工具，讓你可以在桌面排版裡放一塊小的。

它不追求「多」：指標就是活動監視器那五項，加上一項它沒有單獨列出的 GPU 使用率與統一記憶體用量，再加 90 秒趨勢線、每核心使用率、記憶體組成，以及記憶體佔用最高的 3 個程序。真正花時間的地方不是畫介面，而是**把每個數字算成和活動監視器一樣的數字**——同一刻截圖對照，記憶體殘差 ≤ 0.2 GB，磁碟與網路的累計讀寫逐位元組一致。

<p align="center">
  <img src="../compact-strip.png" alt="極簡條拉寬：CPU、記憶體、GPU、能耗、磁碟、網路六項一行排開" width="620" />
  <br />
  <img src="../compact-strip-narrow.png" alt="極簡條收窄：同樣六項自動折成兩行三列" width="330" />
</p>

**拖成一條就是極簡版。** 沒有卡片、沒有趨勢線，六個指標一行排開，貼在選單列下面當指示燈。面板窄到一行排不下時自動折成兩行三列，六個指標始終都在。整個面板以 1 秒更新時約佔單核 1%、常駐記憶體 80 MB 上下（arm64 + macOS 26 實測），這一檔的繪製最輕。新裝預設就是這一檔；右鍵 →「展開為標準面板」攤開成完整面板，再點同一項切回條狀。

> [!NOTE]
> 桌面懸浮面板開箱即用。系統「小工具庫」裡的那一份需要有效的 Apple Development 簽章，而且必須安裝到 `/Applications`——這兩條是 `chronod` 的硬性要求，不是選項，詳見[系統小工具](#系統小工具)。

## 從原始碼建置

需要 macOS 15 或更新版本、Xcode 命令列工具（Swift 6）。沒有第三方相依套件，也不需要 Xcode 專案檔。

```bash
git clone https://github.com/yichensunjoe/macstats.git
cd macstats
bash scripts/bundle.sh          # 建置 + 打包 + 安裝到 /Applications + 註冊小工具擴充
open /Applications/MacStats.app
```

第一次開啟時，選單列會出現一個 `CPU · 記憶體` 的小讀數，桌面上也會出現面板。

- 左鍵點選單列圖示：顯示 / 隱藏面板
- 右鍵點面板：永遠置頂、固定在桌面、點擊穿透、更新間隔（1 / 2 / 5 秒）、新增實例
- 拖曳面板空白處移動，右下角縮放手柄改變尺寸，版型隨尺寸在「極簡 / 緊湊 / 標準 / 詳細」間自動切換
- 偏好設定存在應用的 `com.macstats.app` 偏好網域，結束再開仍保持原位

## 能看什麼

| 指標 | 面板顯示 | 口徑 |
|---|---|---|
| CPU | 總使用率大數字 + 使用者/系統 + 90 秒趨勢線 + 每核心長條 | `host_processor_info` 差分，與活動監視器同源 |
| 記憶體 | 已用/總量、壓力條、App / 聯動 / 壓縮組成、快取 | `vm_statistics64` 換算，見[口徑對齊](#和活動監視器對到什麼程度) |
| 能耗 | CPU 能量計數換算的瓦數、電池電量與充電狀態 | `ri_energy_nj` 差分；缺少計數時退回使用率估算並標記 |
| 磁碟 | 讀/寫速率、可用空間 | `IOBlockStorageDriver` 累計位元組差分 |
| 網路 | 上/下行速率、主要介面 | `NET_RT_IFLIST2` 64 位元計數差分，速率不計 `lo0` |
| GPU | 使用率大數字 + 90 秒趨勢線 + 統一記憶體用量 / 核心數 | `IOAccelerator` 的 `PerformanceStatistics`（`Device Utilization %`、`In use system memory`），與活動監視器 GPU 分頁同源 |
| 程序 | 記憶體佔用最高的 3 個（大尺寸小工具 5 個） | `proc_pid_rusage` 的 `ri_phys_footprint` |

<p align="center">
  <img src="../widget-medium.png" alt="WidgetKit 中尺寸：CPU 主機板與記憶體、磁碟、網路、能耗、GPU（有 GPU 時）五個格子" width="620" />
  <img src="../widget-small.png" alt="WidgetKit 小尺寸：CPU 大數字與趨勢線" width="280" />
</p>

## 兩種形態

同一個取樣層，兩種宿主：

| | 桌面面板 | 系統小工具（WidgetKit） |
|---|---|---|
| 更新 | 每秒重繪 | 系統依預算排程，約 60 秒一輪 |
| 位置 | 任意拖曳，可開多個實例 | 桌面排版格線，隨系統佈局 |
| 入口 | 選單列圖示 / `open MacStats.app` | 右鍵桌面 →「編輯小工具」→ 搜尋「MacStats」 |
| 尺寸 | 拖曳自由縮放，四段版型 | 小 / 中 / 大 / 特大固定規格 |
| 前提 | 無 | 有效簽章 + 安裝到 `/Applications` + `_NSExtensionMain` 入口 |

想要「看起來是活的」，用面板；想要「和其他小工具排在一起」，用系統小工具。兩者讀同一份快照，不會出現兩種口徑。

## 和活動監視器對到什麼程度

對照方法：把活動監視器與面板放在同一螢幕，用輔助使用（AX）讀取活動監視器裡的數值，與同一刻的取樣結果逐項比較：

| 項目 | 結果 |
|---|---|
| 記憶體：已使用 / 已快取 / App / 聯動 / 壓縮 | 殘差 ≤ 0.2 GB（活動監視器自身 5 秒更新快取所致） |
| 磁碟：累計讀 / 累計寫 | 逐位元組一致 |
| 網路：累計收 / 累計送 | 逐位元組一致（十進位 GB） |
| 程序記憶體 | 同一 PID 對到 0.0 MB |
| CPU | 穩定負載下差 1～3 個百分點（取樣視窗相位差） |

<p align="center">
  <img src="../monitor-compare.png" alt="上半部是活動監視器的記憶體頁，下半部是同一刻的 MacStats 面板" width="700" />
</p>

為此修正過三處「想當然」的實作：

- **網路累計必須用 IFMIB 的 64 位元計數。** `NET_RT_IFLIST2` 裡的 `ifi_ibytes` 只填低 32 位元，回繞後本機 122.9 GB 的 `lo0` 被讀成 2.6 GB。累計值含 `lo0`（活動監視器也算），速率欄位排除它（否則核心迴路流量會讓速率大 60 倍）。
- **「已使用」不等於「App + 聯動 + 壓縮」。** 活動監視器的已使用 = 實體 − (free − speculative) − 檔案快取；已快取檔案 = 檔案快取 + 可清除頁。照它的定義實作，而不是照直覺。
- **能耗不是「能耗影響」。** 活動監視器那一欄是無因次的相對分數，無法複製；面板給的是實體瓦數，並在格子裡標註「CPU 能量計數」，不和分數混用。

## 實作方式

三層，沒有任何一層相依於 UI：

```
MacStatsCore  取樣與換算（純邏輯、可單元測試）
      ↓
WidgetData    快照 + 90 點環形歷史
      ↓
SwiftUI 檢視  面板 / WidgetKit 兩種宿主共用同一套元件
```

- **取樣**：Mach（`host_processor_info`、`host_statistics64`）、IOKit（磁碟統計、電源）、`sysctl(NET_RT_IFLIST2)`、`sysctl(vm.swapusage)`、libproc（`proc_listpids` / `proc_pid_rusage`）。全部公開介面，不需要 sudo，不關 SIP，不用私有框架。
- **速率類指標取最近 5 次取樣的移動平均**，對齊活動監視器預設的 5 秒視窗，也順帶壓掉閃爍。
- **面板是桌面層 `NSPanel`**：不搶焦點、跟隨所有桌面空間、`nonactivatingPanel`，所以點它不會把你正在用的視窗壓到背景。
- **資料不出本機**：沒有網路請求、沒有遙測、沒有帳號、不讀使用者檔案；只透過公開介面讀系統計數器，寫一份本機 JSON 給小工具擴充使用。

## 指令

| 目的 | 指令 |
|---|---|
| 建置 + 打包 + 安裝 | `bash scripts/bundle.sh` |
| 單元測試 | `cd src && swift test` |
| 取樣自檢 | `cd src && swift build && .build/debug/macstatsDiag --self-check` |
| 列印原始計數 | `cd src && .build/debug/macstatsDiag --raw` |
| JSON 快照 | `cd src && .build/debug/macstatsDiag --json` |
| 離屏渲染面板 | `MacStats.app/Contents/MacOS/MacStats --snapshot docs/snapshot.png` |
| 離屏渲染四種小工具 | `bash scripts/preview-widget.sh` |

## 專案結構

```
src/Sources/MacStatsCore/    取樣、記憶體換算、環形歷史、格式化（無 UI 相依）
src/Sources/MacStats/        SwiftUI 面板、選單列 App、右鍵選單、離屏渲染
src/Sources/MacStatsWidget/  WidgetKit 擴充：時間軸資料源 + 四段檢視
src/Sources/MacStatsDiag/    診斷 CLI（--json / --raw / --self-check）
src/Tests/                   XCTest，175 項
scripts/bundle.sh            release 建置、組裝 appex、簽章、安裝、註冊
docs/                        口徑對照、架構、需求與介面截圖
```

## 系統小工具

擴充打包在 `MacStats.app/Contents/PlugIns/MacStatsWidget.appex`，四種尺寸各自排版。要讓它出現在小工具庫裡，三件事缺一不可——這三條都是踩過坑之後寫下來的：

1. **擴充要有有效簽章，並且沙盒化。** `pkd` 不接受 ad-hoc 簽章；就算用了真憑證，appex 缺少 `com.apple.security.app-sandbox` 也會被 `rejecting; … plug-ins must be sandboxed` 靜默丟棄。免費的個人團隊憑證（Xcode → Settings → Accounts 登入 Apple ID）就夠。
2. **App 必須安裝在 `/Applications`，而且只能註冊這一份。** `chronod` 只從系統應用程式目錄尋找宿主；放在專案目錄或使用者層級的 Applications 目錄時，日誌會是 `Ignoring restricted or unknown extension`。兩處同名註冊會讓 launchd 建立兩個 XPC 實例，chronod 反而連不上實體程序。`bundle.sh` 已按這個前提安裝並清理舊註冊。
3. **appex 的進入點必須是 `_NSExtensionMain`。** 這是 Xcode 的 `LD_ENTRY_POINT` 預設值；用 SwiftPM 預設進入點時，程序能起來、能印出 `main [WidgetBundle]`，但永遠不建立宿主 XPC 工作階段，約 15 ms 後被判定死亡且沒有當機報告。`src/Package.swift` 已用 `linkerSettings` 固定。

沙盒化之後，擴充讀不到主程序的 `UserDefaults`，所以資料走容器裡的同一份 JSON：主程序每 2 秒重寫應用程式支援目錄下的 `MacStats/widget-feed.json`，並在擴充容器存在時補寫一份；擴充拿不到新鮮快照時自己取樣一次。

若 `security find-identity -v -p codesigning` 顯示 `0 valid identities`，通常是鑰匙圈缺少 Apple 的 WWDR G3 中間憑證；從 Xcode 內建資源匯入 `AppleWWDRCA-2030.cer` 即可。

改完擴充記得提升 `CFBundleVersion`：`chronod` 依版本號快取 descriptor，版本不變會一直顯示舊的。

## 常見問題

<details>
<summary><strong>為什麼小工具一分鐘才動一次？</strong></summary>

WidgetKit 不是渲染迴圈，而是「定時快照」：時間軸提供一筆資料，到期後再問下一筆。主程式雖然每 15 秒請求一次 `reloadAllTimelines()`，`chronod` 仍會依預算節流（日誌裡帶 `budgeted-1`）。第三方小工具拿不到秒級更新，系統時鐘那種是系統自己的特權。

要即時看數字，用桌面面板（每秒更新）。

</details>

<details>
<summary><strong>為什麼「記憶體佔用最高」裡看不到 WindowServer？</strong></summary>

其他使用者的程序（例如 `_windowserver`）沒有讀取權限：`proc_pid_rusage` 回傳 EPERM，`proc_pidinfo` 回傳 0 位元組。活動監視器帶有 Apple 簽章特權，所以看得到全部。這是權限邊界，不是算錯。

</details>

<details>
<summary><strong>數值和活動監視器還是差一點？</strong></summary>

活動監視器每 5 秒更新一次，顯示的是上次更新的快照；面板每秒更新。同一刻對比時記憶體會有 ≤ 0.2 GB 殘差，速率與 CPU 有視窗相位差。等一個更新週期再比就一致了。

</details>

<details>
<summary><strong>會不會上傳資料？</strong></summary>

不會。沒有網路請求、沒有遙測、沒有帳號，也不讀使用者檔案；只透過公開介面讀系統計數器，寫一份本機 JSON 給小工具擴充使用。

</details>

<details>
<summary><strong>支援 Intel Mac 嗎？</strong></summary>

程式只用公開介面，理論上是通用的，但只在 arm64 + macOS 26 上實測過；Intel 上 CPU 與能耗的換算沒有校準資料。歡迎帶著對照結果提 issue。

</details>

## 已知限制

- **系統小工具約 60 秒一跳**，這是 WidgetKit 的排程上限，程式無法繞過。
- **能耗是實體瓦數**，不是活動監視器的「能耗影響」分數，兩者沒有單位對應。
- **程序清單只涵蓋目前使用者**，且依記憶體排序，面板顯示前 3、取樣層最多保留 24 筆。
- **歷史只在本機、只到分鐘**：按分鐘聚合寫成 JSONL，可保留 7 / 30 / 90 天；沒有雲端同步，也沒有秒級回放。
- **告警只看三項**：CPU / 記憶體 / 磁碟，連續 3 次超閾值才提醒，預設關閉；不監控溫度、風扇與單一程序異常。
- **不做遠端監控**：所有讀數與歷史都留在本機，不上報網路。

## 文件

- [口徑對照](../monitor-alignment.md)：每一項數值如何對到活動監視器，含實測資料。
- [架構](../architecture.md)：分層、資料流與關鍵取捨。
- [需求](../requirements.md)：範圍、非目標與驗收標準。

## 授權

本專案以 [MIT 授權條款](../../LICENSE) 發布。你可以自由使用、修改、散布，包括商業用途，只需保留著作權聲明與授權條款全文。
