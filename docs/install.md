# 安装 MacS

## 需要什么

- macOS 15（Sequoia）或更新，Apple 芯片（arm64）
- 一块想常驻在桌面上的空间

## 三步装好

1. **下载** [MacStats.zip](https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip)
   （校验文件：同目录下的 `MacStats.zip.sha256`）
2. 解压，把 `MacStats.app` **拖进 `/Applications`**
3. 在应用程序里 **右键 MacS → 打开**，确认一次「打开」

面板会出现在桌面上，菜单栏同时出现 `CPU · 内存` 读数。之后从启动台双击即可，不再需要右键。

> 第 2 步不能省：系统小组件（WidgetKit）只从 `/Applications` 发现扩展宿主，
> 放在下载目录或 `~/Applications` 里，小组件库中不会出现 MacS。

## 为什么第一次要右键打开

MacS 目前用 **Apple Development** 证书签名，**没有做 Apple 公证**（公证需要付费的
Developer ID 证书）。从网络下载的包会被 Gatekeeper 拦下，提示「无法验证开发者」。

右键 → 打开 是系统给的单次放行方式。也可以在终端里一次性清掉隔离属性：

```bash
xattr -dr com.apple.quarantine /Applications/MacStats.app
open /Applications/MacStats.app
```

这不是「绕过安全机制的建议」，而是未付费公证的开源 App 的常规安装路径；
源码、构建脚本和签名步骤都在仓库里，可以自行核对或从源码构建。

## 校验下载

```bash
shasum -a 256 -c MacStats.zip.sha256
```

输出 `MacStats.zip: OK` 即文件完整。

## 系统小组件

装好并至少启动过一次之后：

1. 右键桌面 →「编辑小组件」
2. 搜索「系统监视」
3. 选小 / 中 / 大 / 特大，拖到桌面

小组件读主程序写出的快照（数值变化时最快 30 秒一次，空闲 60 秒心跳），
所以它不是每秒跳动的那种；要秒级刷新请用桌面面板本身。

如果小组件库搜不到 MacS：确认 App 在 `/Applications`、已启动过一次，
然后 `killall chronod NotificationCenter` 再打开一次 App。

## 卸载

```bash
# 先退出 App（菜单栏图标 → 退出）
rm -rf /Applications/MacStats.app
```

偏好与快照留在 `~/Library/Application Support/MacStats/` 和
`~/Library/Preferences/com.macstats.app.plist`，需要彻底清掉时一并删除。

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
