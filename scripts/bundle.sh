#!/bin/bash
# 构建 MacStats（release）并打包成可双击启动的 MacStats.app。
# 只依赖 Xcode Command Line Tools（SwiftPM + 手写 Info.plist），不需要 Xcode 工程。
#
# 用法：
#   scripts/bundle.sh              打包到 <项目>/MacStats.app，再安装到 /Applications 并注册扩展
#   scripts/bundle.sh --archive    只出可分发包：dist/MacStats.zip + .sha256，不安装、不启动
#
# 版本取自仓库根的 VERSION 文件，构建号取自仓库根的 BUILD 文件（唯一来源）；
# 分别可用 MACSTATS_VERSION / MACSTATS_BUILD 覆盖；产物目录可用 MACSTATS_DIST 覆盖（默认 <项目>/dist）。
#
# 为什么必须装到 /Applications：chronod 只从系统应用目录发现小组件宿主，
# 放在 ~/Applications 或项目目录里会被记成 "Ignoring restricted or unknown extension"。
# 也正因为如此，脚本只注册 /Applications 那份：两处同时注册会让 launchd 建两个
# 同名 XPC 服务实例，chronod 连不上实体进程（pid -1）而判死。
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC="$ROOT/src"
APP="$ROOT/MacStats.app"
INSTALLED=/Applications/MacStats.app
WIDGET_ID="com.macstats.app.widget"

# 版本单一来源：仓库根的 VERSION。主程序与 appex 必须写同一个值，否则
# chronod 可能把扩展当成旧版本缓存起来。
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION" 2>/dev/null || true)"
VERSION="${MACSTATS_VERSION:-${VERSION:-0.1}}"
# 构建号单一来源：仓库根的 BUILD（纯数字，末尾换行）。发布时只改 BUILD，不再改脚本；
# 主程序与 appex 写同一个值。MACSTATS_BUILD 可临时覆盖（本地验证用），优先级高于 BUILD。
# 不用 git rev-list --count：CI 的 shallow clone 只有 1 个提交，会得到 1。
BUILD="$(tr -d '[:space:]' < "$ROOT/BUILD" 2>/dev/null || true)"
BUILD="${MACSTATS_BUILD:-${BUILD:-1}}"
DIST="${MACSTATS_DIST:-$ROOT/dist}"

ARCHIVE=0
for arg in "$@"; do
  case "$arg" in
    --archive) ARCHIVE=1 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "未知参数：$arg（可用：--archive）" >&2
      exit 2
      ;;
  esac
done

cd "$SRC"
echo "==> swift build -c release"
swift build -c release

BIN="$SRC/.build/release/MacStats"
WIDGET_BIN="$SRC/.build/release/MacStatsWidget"
for f in "$BIN" "$WIDGET_BIN"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: 未找到构建产物 $f" >&2
    exit 1
  fi
done

echo "==> 打包 $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MacStats"
# 图标：Finder / 关于面板 / 活动监视器都读这里，名字与 Info.plist 的 CFBundleIconFile 对应。
cp "$ROOT/assets/MacStats.icns" "$APP/Contents/Resources/MacStats.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MacStats</string>
  <key>CFBundleDisplayName</key><string>MacS</string>
  <key>CFBundleIdentifier</key><string>com.macstats.app</string>
  <key>CFBundleExecutable</key><string>MacStats</string>
  <key>CFBundleIconFile</key><string>MacStats.icns</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticTermination</key><false/>
  <key>NSSupportsSuddenTermination</key><false/>
</dict>
</plist>
PLIST

echo "==> 打包系统小组件扩展 MacStatsWidget.appex"
APPEX="$APP/Contents/PlugIns/MacStatsWidget.appex"
mkdir -p "$APPEX/Contents/MacOS" "$APPEX/Contents/Resources"
cp "$WIDGET_BIN" "$APPEX/Contents/MacOS/MacStatsWidget"

cat > "$APPEX/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MacStatsWidget</string>
  <key>CFBundleDisplayName</key><string>系统监视</string>
  <key>CFBundleIdentifier</key><string>$WIDGET_ID</string>
  <key>CFBundleExecutable</key><string>MacStatsWidget</string>
  <key>CFBundlePackageType</key><string>XPC!</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
  <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key><string>com.apple.widgetkit-extension</string>
  </dict>
</dict>
</plist>
PLIST

IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(.*\)"/\1/p' | head -1)"
if [ -n "$IDENTITY" ]; then
  echo "==> 签名（${IDENTITY}）"
  # 扩展必须带沙盒 entitlement，否则 pkd 会以 “plug-ins must be sandboxed” 丢弃整个插件。
  codesign --force --options runtime --timestamp=none \
    --entitlements "$HERE/MacStatsWidget.entitlements" -s "$IDENTITY" "$APPEX" >/dev/null
  codesign --force --options runtime --timestamp=none -s "$IDENTITY" "$APP" >/dev/null
  SIGNED=1
else
  echo "==> 没有代码签名身份，先做 ad-hoc 签名"
  codesign --force --deep -s - "$APP" >/dev/null 2>&1 || true
  SIGNED=0
fi

if [ "$ARCHIVE" = "1" ]; then
  echo "==> 校验签名"
  codesign --verify --deep --strict --verbose=2 "$APP"

  mkdir -p "$DIST"
  ZIP="$DIST/MacStats.zip"
  rm -f "$ZIP" "$ZIP.sha256"
  # 归档时间戳固定：cp 每次会把包内文件的 mtime 重置为当前时间，ditto 又把它写进 zip，
  # 于是同样的内容每次构建都差几个字节。固定后漂移只剩签名值本身（真机 ECDSA 签名每次
  # 不同，见 release.sh 的 sync_meta_for_publish）；签名只校验内容、不看 mtime，不影响 codesign。
  # 把所有条目（含目录，--sequesterRsrc 的 __MACOSX 条目也跟随它的 mtime）固定到同一时刻。
  ARCHIVE_STAMP="${MACSTATS_ARCHIVE_STAMP:-202001010000}"
  echo "==> 固定包内时间戳（${ARCHIVE_STAMP}）"
  find "$APP" -exec touch -h -t "$ARCHIVE_STAMP" {} +
  echo "==> 归档 $ZIP"
  # --keepParent 让解压出来就是 MacStats.app，而不是把内容散在下载目录。
  # --norsrc --noextattr：不生成 __MACOSX（那是 ditto 打包时新建的目录，时间戳是当下，
  # 会把上面固定好的时间重新打回不确定），也不带源的 quarantine/macl 等扩展属性。
  ditto -c -k --norsrc --noextattr --keepParent "$APP" "$ZIP"
  ( cd "$DIST" && shasum -a 256 "MacStats.zip" | tee "MacStats.zip.sha256" )

  echo "==> 产物"
  ls -lh "$ZIP"
  echo "==> Gatekeeper 评估（没有 Developer ID 时必然 rejected，属预期；见 docs/install.md）"
  spctl -a -vv "$APP" 2>&1 || true
  echo "==> 完成（未安装）：$ZIP"
  exit 0
fi

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

echo "==> 安装到 /Applications"
if [ ! -w /Applications ]; then
  echo "ERROR: /Applications 不可写，无法安装（系统小组件只从该目录发现扩展）" >&2
  exit 1
fi
# 清掉历史位置（~/Applications）留下的注册，避免同名服务指向旧包。
LEGACY="$HOME/Applications/MacStats.app"
if [ -d "$LEGACY" ]; then
  pluginkit -r "$LEGACY/Contents/PlugIns/MacStatsWidget.appex" 2>/dev/null || true
  "$LSREGISTER" -u "$LEGACY" 2>/dev/null || true
  rm -rf "$LEGACY"
fi
pkill -f "MacStats.app/Contents/MacOS/MacStats" 2>/dev/null || true
rm -rf "$INSTALLED"
ditto "$APP" "$INSTALLED"

register() {
  "$LSREGISTER" -f "$1" 2>/dev/null || true
  pluginkit -a "$1/Contents/PlugIns/MacStatsWidget.appex" 2>/dev/null || true
}
register "$INSTALLED"

open "$INSTALLED" || true

echo "==> 完成: $INSTALLED"

if [ "$SIGNED" = "0" ]; then
  cat <<'WARN'

注意：系统只会加载「有效签名」的 App Extension。当前机器没有任何代码签名身份，
WidgetKit 的插件守护进程（pkd）会忽略这个 ad-hoc 签名的 appex，
桌面「编辑小组件」里看不到「系统监视」。
修法：打开 Xcode → Settings → Accounts，用 Apple ID 登录（免费个人团队即可），
然后重新运行本脚本，签名会自动换成 "Apple Development: …"。
WARN
else
  if pluginkit -m -i "$WIDGET_ID" 2>/dev/null | grep -q "$WIDGET_ID"; then
    echo "    小组件扩展已注册：右键桌面 → 编辑小组件 → 搜索「系统监视」"
  else
    echo "    扩展暂未出现在 pluginkit 列表，可试：killall chronod NotificationCenter && open -a MacStats"
  fi
fi
