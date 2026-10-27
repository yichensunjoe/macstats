# 安装 MacStats Panel

## 需要什么

- macOS 15（Sequoia）或更新，Apple 芯片（arm64）
- 一块想常驻在桌面上的空间

> **下载的包叫 MacStats，装好后的显示名是 MacStats Panel。** Release 里的文件名是 `MacStats.zip`，
> 解压出来是 `MacStats.app`；Finder、启动台、菜单栏显示的是 MacStats Panel。同一个 App，
> Bundle ID 仍是 `com.macstats.app`，所以偏好和已经添加的小组件都不受影响。

## 三步装好

1. **下载** [MacStats.zip](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip)
   （校验文件：同目录下的 `MacStats.zip.sha256`）
2. 解压，把 `MacStats.app` **拖进 `/Applications`**
3. 在应用程序里 **右键 MacStats Panel →「打开」**，确认一次「打开」

面板会出现在桌面上，菜单栏同时出现 `CPU · 内存` 读数。放行只对这一次下载生效：
重新下载、覆盖安装或升级后可能再被拦一次，照旧右键 →「打开」。

> 第 2 步不能省：系统小组件（WidgetKit）只从 `/Applications` 发现扩展宿主，
> 放在下载目录或 `~/Applications` 里，小组件库中不会出现 MacStats Panel。

## 校验下载

建议装之前先校验（在下载目录里，`MacStats.zip` 与 `MacStats.zip.sha256` 两个文件同级）：

```bash
shasum -a 256 -c MacStats.zip.sha256
```

输出 `MacStats.zip: OK` 表示文件完整。校验失败就重新下载，不要继续安装。

## 为什么第一次要右键打开

MacStats Panel 用 **Apple Development** 证书签名，**没有做 Apple 公证**（公证需要付费的
Developer ID 证书）。从网络下载的包会被 Gatekeeper 拦下，提示「无法验证开发者」。

三种放行方式，任选一种：

1. **右键 →「打开」**（推荐，系统单次放行）；
2. **系统设置 → 隐私与安全性**，在底部提示里点「仍要打开」；
3. 终端里一次性清掉隔离属性：

```bash
xattr -dr com.apple.quarantine /Applications/MacStats.app
open /Applications/MacStats.app
```

这不是什么特殊手段，而是未付费公证的开源 App 的常规安装路径：源码、构建脚本和
签名步骤都在仓库里，可以自行核对，也可以[从源码构建](#从源码构建)。

## 可选：用 Homebrew 装

把仓库当 tap 用（cask 指向最新 Release，跟着版本走）：

```bash
brew tap yichensunjoe/macstats https://github.com/yichensunjoe/macstats
brew trust yichensunjoe/macstats     # Homebrew 5+ 对第三方 tap 要求显式信任
brew install --cask macstats
```

升级 `brew upgrade --cask macstats`，卸载 `brew uninstall --cask macstats`。
Homebrew 不会替你清隔离属性，首次启动仍可能需要右键放行；细节见 [Homebrew 说明](homebrew.md)。

## 装不上时先看这里

1. **Gatekeeper 拦截**：按上一节的三种方式之一放行。若提示「App 已损坏，无法打开」，
   通常是下载不完整——先跑 sha256 校验，失败就重新下载；校验通过仍报损坏，用第 3 种方式再打开。
2. **架构不对**：只提供 Apple 芯片（arm64）包，Intel Mac 无法运行，也不走 Rosetta。
   `uname -m` 输出应为 `arm64`。
3. **系统版本太低**：需要 macOS 15（Sequoia）或更新。`sw_vers -productVersion` 确认；
   低于 15 请先升级系统。
4. **系统小组件不出现**：确认 App 在 `/Applications`（不是下载目录或 `~/Applications`）、
   至少启动过一次，然后 `killall chronod NotificationCenter`，再打开一次 App。
   同一台机器只应注册一份 App。
5. **Homebrew 报 untrusted tap**：Homebrew 5 起第三方 tap 必须显式信任，先执行
   `brew trust yichensunjoe/macstats`，再 `brew install --cask macstats`；
   `brew untrust yichensunjoe/macstats` 可撤回信任。Homebrew 不会替你清隔离属性，
   首次启动仍可能需要右键放行。

## 系统小组件

装好并至少启动过一次之后：

1. 右键桌面 →「编辑小组件」
2. 搜索「系统监视」
3. 选小 / 中 / 大 / 特大，拖到桌面

小组件读主程序写出的快照（数值变化时最快 30 秒一次，空闲 60 秒心跳），
所以它不是每秒跳动的那种；要秒级刷新请用桌面面板本身。搜不到时见上一节第 4 条。

## 卸载

```bash
# 先退出 App（菜单栏图标 → 退出）
rm -rf /Applications/MacStats.app

# 用 Homebrew 装的：
brew uninstall --cask macstats
```

偏好与快照留在 `~/Library/Application Support/MacStats/` 和
`~/Library/Preferences/com.macstats.app.plist`，需要彻底清掉时一并删除。
桌面上的系统小组件从「编辑小组件」里移除即可，卸载主程序后系统会清掉扩展注册。

## 从源码构建

需要 Xcode Command Line Tools（Swift 6）：

```bash
git clone https://github.com/yichensunjoe/macstats.git
cd macstats
bash scripts/bundle.sh
```

`bundle.sh` 会构建、签名、装进 `/Applications` 并注册小组件扩展。
只想产出可分发包、不安装：

```bash
bash scripts/bundle.sh --archive   # → dist/MacStats.zip
```
