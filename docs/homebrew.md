# 用 Homebrew 安装

仓库根目录带 `Casks/macstats.rb`，可以直接把这个仓库当 tap：

```bash
brew tap yichensunjoe/macstats https://github.com/yichensunjoe/macstats
brew trust yichensunjoe/macstats     # Homebrew 5+ 对第三方 tap 要求显式信任
brew install --cask macstats
```

升级与卸载：

```bash
brew upgrade --cask macstats
brew uninstall --cask macstats
```

说明：

- Homebrew 5 起，未在官方仓库里的 tap 必须先 `brew trust <tap>`，否则会报
  「Refusing to load cask … from untrusted tap」。信任只影响本机这一条 tap，
  `brew untrust yichensunjoe/macstats` 可撤回。
- cask 指向 `releases/latest/download/MacStats.zip`，跟着最新 Release 走，
  所以用 `version :latest` + `sha256 :no_check`。
- Homebrew 不会替你去掉 Gatekeeper 的隔离属性。首次启动仍会被拦：
  到 系统设置 → 隐私与安全性 点「仍要打开」，或在终端 `xattr -dr com.apple.quarantine`，详见 `docs/install.md`。
- 没有提交到 homebrew-cask 官方仓库：那边要求公证，当前签名做不到。
