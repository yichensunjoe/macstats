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
3. 第一次打开会被 Gatekeeper 拦下，弹窗标题是「未打开“MacStats.app”」，按钮只有
   「完成」和「移到废纸篓」。点「完成」，然后去 **系统设置 → 隐私与安全性 → 安全性**，
   点「仍要打开」，按提示确认（可能要输登录密码或 Touch ID）；
   不想用图形界面就走下一节第 2 种方式（终端清隔离属性）。

面板会出现在桌面上，菜单栏同时出现 `CPU · 内存` 读数。
放行按**构建**记录：同一份构建重装不会再问，换了版本会重新拦一次。

> 第 2 步不能省：系统小组件（WidgetKit）只从 `/Applications` 发现扩展宿主，
> 放在下载目录或 `~/Applications` 里，小组件库中不会出现 MacStats Panel。

## 校验下载

建议装之前先校验（在下载目录里，`MacStats.zip` 与 `MacStats.zip.sha256` 两个文件同级）：

```bash
shasum -a 256 -c MacStats.zip.sha256
```

输出 `MacStats.zip: OK` 表示文件完整。校验失败就重新下载，不要继续安装。

## 为什么第一次要放行

MacStats Panel 用 **Apple Development** 证书签名，**没有做 Apple 公证**（公证需要付费的
Developer ID 证书）。从网络下载的包会被 Gatekeeper 拦下，提示「Apple 无法验证…是否包含恶意软件」。

两种放行方式，任选一种：

1. **系统设置 → 隐私与安全性**：在「安全性」区域会列出被拦下的 MacStats.app，点**「仍要打开」**
   并确认。macOS 15 起这是唯一不碰终端的路径。
2. 终端里一次性清掉隔离属性（推荐给用终端的人，实测可用）：

```bash
xattr -dr com.apple.quarantine /Applications/MacStats.app
open /Applications/MacStats.app
```

> **「右键 →「打开」」在 macOS 14 及更早有效，macOS 15 起不再有效。**
> 实测（macOS 27）：拦截弹窗里只有「完成」与「移到废纸篓」，没有「打开」按钮，
> 右键「打开」只会再看到同一个弹窗。别点「移到废纸篓」——那会把 App 删掉。

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
Homebrew 不会替你清隔离属性，首次启动仍要按上一节放行（系统设置里点「仍要打开」，或清隔离属性）；
细节见 [Homebrew 说明](homebrew.md)。

## 装不上时先看这里

1. **Gatekeeper 拦截**：按上一节两种方式之一放行（系统设置里点「仍要打开」，或终端清隔离属性）。
   若提示「App 已损坏，无法打开」，通常是下载不完整——先跑 sha256 校验，失败就重新下载；
   校验通过仍报损坏，用清隔离属性的方式再打开。
2. **架构不对**：只提供 Apple 芯片（arm64）包，Intel Mac 无法运行，也不走 Rosetta。
   `uname -m` 输出应为 `arm64`。
3. **系统版本太低**：需要 macOS 15（Sequoia）或更新。`sw_vers -productVersion` 确认；
   低于 15 请先升级系统。
4. **系统小组件不出现**：确认 App 在 `/Applications`（不是下载目录或 `~/Applications`）、
   至少启动过一次，然后 `killall chronod NotificationCenter`，再打开一次 App。
   同一台机器只应注册一份 App。
5. **升级后小组件还停在旧版本**：把新的 `MacStats.app` 覆盖进 `/Applications` 不会自动刷新扩展注册，
   系统可能继续按旧构建记录加载小组件。先退出并重开一次 App；仍然如此就在终端强制重新注册：

   ```bash
   /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/MacStats.app
   pluginkit -a /Applications/MacStats.app/Contents/PlugIns/MacStatsWidget.appex
   pluginkit -m -v -i com.macstats.app.widget    # 输出的版本号应已是新版本
   ```

   版本号变了但桌面上的小组件还是旧样子，就从「编辑小组件」里移除再重新添加一次。
   仍不生效时重启一次，`pkd` 会在开机时重建扩展索引。
6. **Homebrew 报 untrusted tap**：Homebrew 5 起第三方 tap 必须显式信任，先执行
   `brew trust yichensunjoe/macstats`，再 `brew install --cask macstats`；
   `brew untrust yichensunjoe/macstats` 可撤回信任。Homebrew 不会替你清隔离属性，
   首次启动仍要按上一节放行。

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
