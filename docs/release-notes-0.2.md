## 这次能直接装了

0.1 只有源码；0.2 起提供签好的 `MacStats.zip`，拖进 `/Applications` 就能用。

### 安装

1. 下载 `MacStats.zip`，解压
2. 把 `MacStats.app` 拖进 `/Applications`
3. 右键 App →「打开」放行一次（未公证，原因见 `docs/install.md`）

### 变更

- 新增 `VERSION` 单一版本源，主程序与小组件扩展统一为 0.2 (2)
- `scripts/bundle.sh --archive`：产出 `dist/MacStats.zip` + `.sha256`，不安装、不启动
- 归档前强制执行 `codesign --verify`，签名坏了不会发出包
- 新增安装文档、Homebrew cask 与校验值

### 仍然如此

- 需要 macOS 15+、Apple 芯片、Swift 6 工具链（仅源码构建）
- 系统小组件必须装在 `/Applications` 才会被 `chronod` 发现
- 本包未公证：首次启动需右键打开，或在终端执行
  `xattr -dr com.apple.quarantine /Applications/MacStats.app`

验证：91 项单测通过；`codesign --verify --deep --strict` 通过；
`unzip -t` 与 `shasum -a 256 -c` 通过。
