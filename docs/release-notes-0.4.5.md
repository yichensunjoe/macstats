## 把首次启动的说明改成真能照做的

**MacStats Panel 0.4.5**（仓库与包名仍是 MacStats；构建号见仓库根 `BUILD`）

这一版没有功能变更。它存在的理由只有一个：0.4.4 的 tag 快照里，首次启动的说明还是旧说法。

0.4.4 发布后我们发现，文案里「右键 App →「打开」」在 macOS 15 起已经行不通——Gatekeeper 的弹窗里
只有「完成」与「移到废纸篓」，没有「打开」。当天修好了仓库文档与 Release 正文，发布出去的
tag 快照却不会跟着变，已经按 tag 归档的人读到的仍是那句失效的指引。标签不改写，所以用这一版收口。

### 变更

- **首次启动路径改对**（主 README、9 份翻译 README、`docs/install.md`、Cask caveats）：
  被拦下时点弹窗里的「完成」，到 **系统设置 → 隐私与安全性 → 安全性** 点「仍要打开」；
  或在终端执行 `xattr -dr com.apple.quarantine /Applications/MacStats.app`。
- **「右键 →「打开」」标注为 macOS 14 及更早的做法**，并写明 macOS 15 起该弹窗的按钮变化。
- **构建号 8 → 9**：同一份代码的两次签名包用构建号区分，排查时不会混。

### 没有变化

代码、数据格式、偏好键、Bundle ID、面板与小组件的行文都与 0.4.4 一致；面板拖动、右键菜单、
缩放柄、24 小时历史、持续高负载提醒均按原样工作。

### 升级

- 从 0.4.4 覆盖安装：设置、面板位置、历史文件与已添加的小组件原样保留。
- **新构建会再被 Gatekeeper 拦一次**：放行按构建记录，不按版本号。按上面第一条路径放行即可，
  之后同一份包重装不再询问。

### 仍然如此

- 需要 macOS 15（Sequoia）+、Apple 芯片。
- 本包**未公证**（Apple Development 签名），原因与取舍见 `docs/install.md`。
- 系统小组件约 60 秒一跳，这是 WidgetKit 的调度上限。
- 历史只在本机、只到分钟；没有云端同步，也没有秒级回放。
- 面板仍在桌面图标层：全屏窗口盖住桌面时需要先露出桌面才能点到它，这是设计如此。

验证：`cd src && swift test` 176 项通过；`bash scripts/bundle.sh --archive` 后
`codesign --verify --deep --strict`、`unzip -t`、`shasum -a 256 -c` 全过；
包内 `CFBundleShortVersionString=0.4.5`、`CFBundleVersion=9`、`CFBundleDisplayName=MacStats Panel`；
`python3 scripts/check-docs.py` 0 错；发布后匿名下载 `latest` 的 sha256 与上传包一致。
