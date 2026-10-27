## 源码与安装包对齐

**MacS 0.4.1**（原名 MacStats；构建号见仓库根 `BUILD`）

0.4 的功能没有任何变化。这次只做一件事：让 `v0.4.1` 这个 tag 上的源码，和随它发布的安装包，
出自同一份代码，并且都能在同一套工具链上构建通过。

### 修了什么

- **`HistoryStore.Bucket` 的访问级别**：成员初始化器原本被同文件的 `private var` 拖成 `private`，
  在较旧的 Swift 上编译不过。改为 `fileprivate` 类型并显式写 `fileprivate init(start:)`。
- **`AppIcon.image` 的主线程隔离**：全局静态 `NSImage?` 在较旧 Swift 上要求显式标注，
  已加 `@MainActor`（它本来就只在 AppDelegate 与关于页的主线程使用）。
- **`ProcessGlossaryTests` 不再依赖系统语言**：原来按中文文案断言却走系统语言解析，
  英文环境（CI）下会误报失败；现在显式传 `.zhHans`，与产品行为无关。

前两项只在 CI 的较旧 Swift 上暴露，本机 Swift 6.4 无法复现；第三项是测试自身的缺陷。

### 升级

- 与 0.4 完全兼容：偏好键、历史文件格式、Bundle ID（`com.macstats.app`）都没动，
  设置、面板位置与已添加的小组件原样保留。
- 从 0.4 升级没有收益，也没有损失；已装 0.4 可跳过本版。

### 仍然如此

- 需要 macOS 15（Sequoia）+、Apple 芯片。
- 本包**未公证**（Apple Development 签名）：首次启动需右键 App →「打开」，
  或在终端执行 `xattr -dr com.apple.quarantine /Applications/MacStats.app`。
- 系统小组件约 60 秒一跳，这是 WidgetKit 的调度上限。
- 历史只在本机、只到分钟；没有云端同步，也没有秒级回放。

验证：单测全过；`python3 scripts/check-docs.py` 0 错；`bash scripts/bundle.sh --archive` 后
`codesign --verify --deep --strict`、`unzip -t`、`shasum -a 256 -c` 全过；
GitHub Actions 在 `v0.4.1` 对应提交上通过。
