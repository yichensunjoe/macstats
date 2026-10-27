## 显示名改回 MacStats Panel

**MacStats Panel 0.4.3**（仓库与包名仍是 MacStats；构建号见仓库根 `BUILD`）

0.4 起对外显示名曾改为 `MacS`。查重后发现它与 `Macs Fan Control`、`Mac Sai`、`macs.app`
等既有产品邻接，搜索与商标风险偏高，因此回退到方案里的备选名 **`MacStats Panel`**。
功能、数据与设置没有任何变化。

### 变更

- **显示名**：Finder、启动台、菜单栏、面板标题、「关于」窗口都显示 **MacStats Panel**；
  Cask 的 `name` 同步。**Bundle ID 仍是 `com.macstats.app`**，偏好与已添加的小组件不受影响。
- **安装包文件名不变**：仍是 `MacStats.zip` / `MacStats.app`，校验文件仍是 `MacStats.zip.sha256`。
- **系统小组件画廊名不变**：仍是「系统监视」/ `System Stats`，它本来就不是应用名。
- 10 份 README、安装文档与 Issue 模板同步改名；历史发布说明（0.4–0.4.2）保留当时的 `MacS` 记录。

### 升级

- 从 0.4 / 0.4.1 / 0.4.2 升级：偏好键、历史文件格式、Bundle ID 均未变，设置与小组件原样保留。
- 已装旧版仍会显示 `MacS`，直到换上本版；两版可以随时互装，数据不迁移、不丢失。
- 名字只是显示层：仓库名 `macstats`、Cask token `macstats`、可执行文件名 `MacStats` 都没改。

### 仍然如此

- 需要 macOS 15（Sequoia）+、Apple 芯片。
- 本包**未公证**（Apple Development 签名）：首次启动需右键 App →「打开」，
  或在终端执行 `xattr -dr com.apple.quarantine /Applications/MacStats.app`。
- 系统小组件约 60 秒一跳，这是 WidgetKit 的调度上限。
- 历史只在本机、只到分钟；没有云端同步，也没有秒级回放。

验证：单测全过；`python3 scripts/check-docs.py` 0 错；`bash scripts/bundle.sh --archive` 后
`codesign --verify --deep --strict`、`unzip -t`、`shasum -a 256 -c` 全过，
包内 `CFBundleDisplayName` 为 `MacStats Panel`。
