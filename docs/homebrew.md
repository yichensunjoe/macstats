# 用 Homebrew 安装

仓库根目录带 `Casks/macstats.rb`，可以直接把这个仓库当 tap：

```bash
brew tap yichensunjoe/macstats https://github.com/yichensunjoe/macstats
brew install --cask macstats
```

升级与卸载：

```bash
brew upgrade --cask macstats
brew uninstall --cask macstats
```

说明：

- cask 指向 `releases/latest/download/MacStats.zip`，跟着最新 Release 走，
  所以用 `version :latest` + `sha256 :no_check`。
- Homebrew 不会替你去掉 Gatekeeper 的隔离属性。首次启动仍可能被拦，
  右键 →「打开」一次即可，详见 `docs/install.md`。
- 没有提交到 homebrew-cask 官方仓库：那边要求公证，当前签名做不到。
