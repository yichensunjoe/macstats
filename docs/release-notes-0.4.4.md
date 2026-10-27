## 面板又能拖动了

**MacStats Panel 0.4.4**（仓库与包名仍是 MacStats；构建号见仓库根 `BUILD`）

0.4.3 及更早的面板按住背景拖不动窗口。这一版修好它；功能、数据与设置没有任何变化。

### 修复

- **面板拖动**：在面板的非交互区域按住左键即可移动窗口，位移等于拖拽距离。
  根因是面板内容整块由 SwiftUI 承载（`NSHostingView`），`isMovableByWindowBackground`
  的自动拖动在这条路径上不会触发——同样配置、纯 AppKit 内容的面板能拖，SwiftUI 的拖不动
  （桌面层与常规层都一样）。现在由 `WidgetPanel.mouseDown` 自己发起拖动。
- **交互不受影响**：按钮等自己消费点击的控件照常可点，右下角缩放柄照常可缩放，
  右键菜单与 Control+左键菜单照常弹出（Control+左键仍走菜单，不触发拖动）。

### 升级

- 从 0.4 / 0.4.1 / 0.4.2 / 0.4.3 升级：偏好键、历史文件格式、Bundle ID 均未变，
  面板位置、设置与已添加的小组件原样保留。

### 仍然如此

- 需要 macOS 15（Sequoia）+、Apple 芯片。
- 本包**未公证**（Apple Development 签名）。首次启动会被 Gatekeeper 拦下，弹窗只有
  「完成」与「移到废纸篓」——点「完成」，到 **系统设置 → 隐私与安全性** 点「仍要打开」，
  或在终端执行 `xattr -dr com.apple.quarantine /Applications/MacStats.app`。
  放行按构建记录，同一份包重装不会再问，换版本会再拦一次。
- 系统小组件约 60 秒一跳，这是 WidgetKit 的调度上限。
- 历史只在本机、只到分钟；没有云端同步，也没有秒级回放。
- 面板仍在桌面图标层：全屏窗口盖住桌面时需要先露出桌面才能点到它，这是设计如此。

验证：单测全过；真机拖拽位移 = 拖拽距离（100 pt），缩放柄、右键菜单与 Control+左键均正常；
`python3 scripts/check-docs.py` 0 错；`bash scripts/bundle.sh --archive` 后
`codesign --verify --deep --strict`、`unzip -t`、`shasum -a 256 -c` 全过，
包内 `CFBundleDisplayName` 为 `MacStats Panel`。
