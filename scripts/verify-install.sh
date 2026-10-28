#!/bin/bash
# 无头安装自检：一条命令核对已安装 MacStats 的版本、哈希、签名与关于页架构文案。
# 只读文件 + codesign + strings，不弹窗口、不截屏、不需要辅助功能授权。
#
# 用法：
#   scripts/verify-install.sh                  # 校验 /Applications/MacStats.app
#   scripts/verify-install.sh --app <路径>     # 校验指定的 .app（例如 dist 解出来的副本）
#   scripts/verify-install.sh --quiet          # 只打印失败项与总结
#
# 关联：安装器是 scripts/bundle.sh；版本取 VERSION、构建号取 BUILD，脚本据此比对包内 plist。
# 退出码：0 全部通过；1 有项未通过；2 未安装或参数错误。
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
APP="/Applications/MacStats.app"
QUIET=0
CHECKS=0
FAILED=0

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --app)
      if [ $# -lt 2 ]; then
        echo "ERROR: --app 需要一个 .app 路径" >&2
        exit 2
      fi
      APP="$2"
      shift 2
      ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "ERROR: 未知参数 $1（可用：--app <路径> / --quiet）" >&2
      exit 2
      ;;
  esac
done

ok() {
  CHECKS=$((CHECKS + 1))
  [ "$QUIET" = "1" ] || printf 'ok   %s\n' "$1"
}
bad() {
  CHECKS=$((CHECKS + 1))
  FAILED=$((FAILED + 1))
  printf 'FAIL %s\n' "$1"
}
skip() {
  CHECKS=$((CHECKS + 1))
  [ "$QUIET" = "1" ] || printf 'skip %s\n' "$1"
}

PLIST="$APP/Contents/Info.plist"
BIN="$APP/Contents/MacOS/MacStats"
if [ ! -f "$PLIST" ] || [ ! -f "$BIN" ]; then
  echo "ERROR: 找不到 $APP（先执行 bash scripts/bundle.sh）" >&2
  exit 2
fi

if [ "$QUIET" != "1" ]; then
  echo "==> 校验 $APP"
fi

# 1) 版本与构建号：必须与仓库根的单一来源一致，避免装到旧包。
INSTALLED_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST" 2>/dev/null || true)"
INSTALLED_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST" 2>/dev/null || true)"
SRC_VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION" 2>/dev/null || true)"
SRC_BUILD="$(tr -d '[:space:]' < "$ROOT/BUILD" 2>/dev/null || true)"

if [ -z "$INSTALLED_VERSION" ]; then
  bad "包内缺少 CFBundleShortVersionString"
elif [ -n "$SRC_VERSION" ] && [ "$INSTALLED_VERSION" != "$SRC_VERSION" ]; then
  bad "版本不一致：安装 $INSTALLED_VERSION / VERSION $SRC_VERSION"
else
  ok "版本 $INSTALLED_VERSION 与仓库 VERSION 一致"
fi

if [ -z "$INSTALLED_BUILD" ]; then
  bad "包内缺少 CFBundleVersion"
elif [ -n "$SRC_BUILD" ] && [ "$INSTALLED_BUILD" != "$SRC_BUILD" ]; then
  bad "构建号不一致：安装 $INSTALLED_BUILD / BUILD $SRC_BUILD（旧构建或未重跑 bundle.sh）"
else
  ok "构建号 $INSTALLED_BUILD 与仓库 BUILD 一致"
fi

# 2) 签名：安装包必须自洽（未公证是既定策略，不在这里判失败）。
if codesign --verify --deep --strict "$APP" >/dev/null 2>&1; then
  IDENTITY="$(codesign -dv --verbose=2 "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
  ok "签名有效（${IDENTITY:-ad-hoc}）"
else
  bad "签名校验失败：codesign --verify --deep --strict"
fi

# 3) 哈希：与仓库内本次构建的 MacStats.app 比对，证明装的就是这一份。
INSTALLED_HASH="$(shasum -a 256 "$BIN" | awk '{print $1}')"
LOCAL_BIN="$ROOT/MacStats.app/Contents/MacOS/MacStats"
if [ "$QUIET" != "1" ]; then
  echo "     sha256 $INSTALLED_HASH  $BIN"
fi
if [ -f "$LOCAL_BIN" ]; then
  LOCAL_HASH="$(shasum -a 256 "$LOCAL_BIN" | awk '{print $1}')"
  if [ "$INSTALLED_HASH" = "$LOCAL_HASH" ]; then
    ok "哈希与仓库内 MacStats.app 一致"
  else
    bad "哈希不一致：安装 $INSTALLED_HASH / 仓库 $LOCAL_HASH（装的不是本次构建）"
  fi
else
  skip "仓库内没有 MacStats.app，跳过哈希比对（先跑 bundle.sh 才有基准）"
fi

# 4) 架构文案：arm64-only 发行包只能说 Apple Silicon，旧说法必须彻底消失。
# 按原始字节检索（grep -a），不依赖 strings 对 Mach-O 段的划分——追加在
# 代码签名之后的字符串也要能命中，否则漂移可能溜过检查。
if LC_ALL=C grep -a -F -q -- "macOS 15+ (Apple Silicon)" "$BIN"; then
  ok "关于页文案含「macOS 15+ (Apple Silicon)」"
else
  bad "包内找不到「macOS 15+ (Apple Silicon)」"
fi
if LC_ALL=C grep -a -F -q -- "Apple Silicon & Intel" "$BIN"; then
  bad "包内仍有旧文案「Apple Silicon & Intel」"
else
  ok "旧文案「Apple Silicon & Intel」已不存在"
fi

echo
if [ "$FAILED" -eq 0 ]; then
  echo "PASS: $CHECKS 项全部通过（$APP）"
  exit 0
fi
echo "FAIL: $FAILED/$CHECKS 项未通过（$APP）"
exit 1
