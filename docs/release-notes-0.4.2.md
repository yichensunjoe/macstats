## 这次只改发布工程

**MacS 0.4.2**（原名 MacStats；构建号见仓库根 `BUILD`）

App 的功能、界面、数据格式与 0.4.1 完全相同。这次发布的内容是发布流程本身，并借这次真实发布
验证新流程能把元数据与上传包对齐。

### 变更

- **归档不再带时间噪声**：打包前把包内所有条目的 mtime 固定到 `2020-01-01 00:00`，
  并改用 `ditto --norsrc --noextattr`，不再生成时间戳为“打包当下”的 `__MACOSX` 容器，
  也不携带源文件的 quarantine / macl 等扩展属性。同样的已签名产物连续打包，sha256 一致。
- **包体略小**：去掉扩展属性后，`MacStats.zip` 从约 2.52 MB 降到约 2.51 MB。
- **发布元数据自洽**：`release.sh --publish` 在归档后比较 `docs/_meta.json` 的 `zip_bytes`，
  不一致就更新、只提交该文件、跑 `check-docs`，然后才打 tag。tag 里的 meta 必然等于本次上传的包。
  （真机签名用 ECDSA，每次签名的 `signatureValue` 都不同，所以重新签名的 zip 无法逐字节复现；
  这里保证的是“记录的就是发出去的那个包”，不是“每次构建都一样”。）

### 升级

- 与 0.4.1 完全兼容：偏好键、历史文件格式、Bundle ID（`com.macstats.app`）都没动。
- 从 0.4.1 升级没有收益，也没有损失；已装 0.4.1 可跳过本版。

### 仍然如此

- 需要 macOS 15（Sequoia）+、Apple 芯片。
- 本包**未公证**（Apple Development 签名）：首次启动需右键 App →「打开」，
  或在终端执行 `xattr -dr com.apple.quarantine /Applications/MacStats.app`。
- 系统小组件约 60 秒一跳，这是 WidgetKit 的调度上限。
- 历史只在本机、只到分钟；没有云端同步，也没有秒级回放。

验证：单测全过；`python3 scripts/check-docs.py` 0 错；`bash scripts/bundle.sh --archive` 后
`codesign --verify --deep --strict`、`unzip -t`、`shasum -a 256 -c` 全过；
GitHub Actions 在 `v0.4.2` 对应提交上通过。
