#!/bin/bash
# MacStats 一条命令发布（0.4 D3）。
#
# 用法：
#   bash scripts/release.sh [--dry-run|--prepare|--publish] [--yes]
#
#   --dry-run（默认）  跑测试 / 归档 / 签名 / sha 校验，打印将要执行的 tag / push /
#                     gh release 命令；不写 tag、不 push、不建 Release。允许脏树（只告警）。
#   --prepare          跑测试 / 归档，把 version / test_count / zip_bytes 写进 docs/_meta.json，
#                     调用 scripts/check-docs.py --fix，打印 git diff；不 commit / tag / push。
#   --publish          严格前置检查（干净 main + meta 匹配 + 无同名 tag）后打 tag、push、
#                     gh release create，并做匿名下载 sha 校验；必须同时传 --yes。
#                     若本次归档字节数与 docs/_meta.json 不一致（签名值每次不同），
#                     先把 meta 对齐到本次归档并提交，再打 tag——保证 meta 与上传包一致。
#
# 安全：
#   - 不使用 set -x；不读取 / 不打印任何 token（gh 认证交给现有 gh 登录）；
#   - 发布是外部操作：--publish 必须显式传入，且必须带 --yes。
#
# 依赖：VERSION（版本单一来源）、BUILD（构建号，由 bundle.sh 读取）、
#       docs/release-notes-<VERSION>.md、scripts/bundle.sh、scripts/check-docs.py（可选）。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION=""
NOTES=""
BRANCH=""
TEST_COUNT=""
ZIP_BYTES=""
CHECK_DOCS_RC=0
MODE="dry-run"
MODE_SET=""
ASSUME_YES=0
LOCK_HELD=0

LOCK="$ROOT/.build-lock"
TEST_LOG="/tmp/macstats-tests.log"
APP="$ROOT/MacStats.app"
ZIP="$ROOT/dist/MacStats.zip"
SHA="$ROOT/dist/MacStats.zip.sha256"
DOWNLOAD_URL="https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip"
EXPECTED_REMOTE_SLUG="yichensunjoe/macstats"

say() { printf '==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
print_cmd() { printf '    %s\n' "$*"; }
run() {
  printf '    $'
  printf ' %s' "$@"
  printf '\n'
  "$@"
}

usage() {
  cat <<'EOF'
用法：bash scripts/release.sh [--dry-run|--prepare|--publish] [--yes]

  --dry-run   默认模式。跑测试 / 归档 / 签名 / sha 校验，打印将要执行的
              tag / push / gh release 命令；不写 tag、不 push、不建 Release。
  --prepare   跑测试 / 归档，写 docs/_meta.json（version/test_count/zip_bytes），
              调用 scripts/check-docs.py --fix，打印 git diff；不 commit / tag / push。
  --publish   严格前置检查（干净 main + meta 匹配 + 无同名 tag）后打 tag、push、
              gh release create，并做匿名下载 sha 校验；必须同时传 --yes。
              meta 的 zip_bytes 与本次归档不一致时，会先更新并提交 docs/_meta.json。
  --yes       显式授权 --publish（发布是外部操作，需要人工确认）。
  -h, --help  显示本帮助。

示例：
  bash scripts/release.sh --dry-run
  bash scripts/release.sh --prepare
  bash scripts/release.sh --publish --yes
EOF
}

usage_error() { printf 'ERROR: %s\n' "$*" >&2; usage >&2; exit 2; }

cleanup() {
  if [ "$LOCK_HELD" = "1" ]; then
    rmdir "$LOCK" 2>/dev/null || true
    LOCK_HELD=0
  fi
}
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# ---------------------------------------------------------------------------
# 构建锁：同一时间只允许一个 swift build / swift test（见 docs/roadmap-v0.4/E §4）
# ---------------------------------------------------------------------------
acquire_lock() {
  say "获取构建锁（${LOCK}）"
  local i=1
  while [ "$i" -le 90 ]; do
    if mkdir "$LOCK" 2>/dev/null; then
      LOCK_HELD=1
      info "已获取构建锁（第 $i 次尝试）"
      return 0
    fi
    i=$((i + 1))
    sleep 5
  done
  die "构建锁被占用超过 7 分 30 秒（${LOCK}）；确认没有其他 agent 在构建后重试"
}

release_lock() {
  if [ "$LOCK_HELD" = "1" ]; then
    rmdir "$LOCK" 2>/dev/null || true
    LOCK_HELD=0
    info "已释放构建锁"
  fi
}

# ---------------------------------------------------------------------------
# 公共前置检查（三种模式都跑）
# ---------------------------------------------------------------------------
check_common() {
  [ -f "$ROOT/VERSION" ] || die "缺少 VERSION 文件"
  VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
  [ -n "$VERSION" ] || die "VERSION 文件为空"
  if ! printf '%s\n' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+(\.[0-9]+)?$'; then
    die "VERSION 格式不合法：${VERSION}（期望 x.y 或 x.y.z）"
  fi
  NOTES="$ROOT/docs/release-notes-$VERSION.md"
  [ -f "$NOTES" ] || die "缺少发布说明 docs/release-notes-$VERSION.md"
  say "版本：$VERSION"
  info "发布说明：docs/release-notes-$VERSION.md"
  if [ -f "$ROOT/BUILD" ]; then
    info "BUILD：$(tr -d '[:space:]' < "$ROOT/BUILD")（bundle.sh 的唯一构建号来源）"
  fi
}

worktree_dirty() {
  git status --porcelain 2>/dev/null | grep -v -E '^\?\? \.build-lock/$' || true
}

# strict：main + 干净树；warn：只告警（--dry-run）
check_branch_and_tree() {
  local strictness="$1"
  local dirty
  BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
  dirty="$(worktree_dirty)"
  if [ "$strictness" = "strict" ]; then
    [ "$BRANCH" = "main" ] || die "当前分支是 ${BRANCH}，正式发布 / 准备必须在 main 上"
    [ -z "$dirty" ] || die "工作树不干净：请先提交或清理（git status --porcelain 非空）"
    info "分支：main；工作树：干净"
  else
    [ "$BRANCH" = "main" ] || warn "当前分支是 ${BRANCH}；--dry-run 允许，正式发布必须在 main"
    [ -z "$dirty" ] || warn "工作树不干净；--dry-run 允许，正式发布要求干净树"
  fi
}

meta_field() {
  python3 -c 'import json, sys
try:
    data = json.load(open("docs/_meta.json", encoding="utf-8"))
except Exception:
    print("")
else:
    value = data.get(sys.argv[1], "") if isinstance(data, dict) else ""
    print("" if value is None else value)' "$1" 2>/dev/null || true
}

check_meta_version_strict() {
  [ -f "$ROOT/docs/_meta.json" ] || die "docs/_meta.json 不存在；请先跑 --prepare"
  local meta_version shown
  meta_version="$(meta_field version)"
  if [ "$meta_version" != "$VERSION" ]; then
    shown="$meta_version"
    [ -n "$shown" ] || shown="无法读取"
    die "docs/_meta.json 的 version（${shown}）与 VERSION（${VERSION}）不一致；请先跑 --prepare 并提交"
  fi
  info "docs/_meta.json version：${meta_version}（与 VERSION 一致）"
}

check_tags_absent() {
  if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null 2>&1; then
    die "本地已存在 tag v${VERSION}；发布不可重复，请先确认（或改 VERSION）"
  fi
  local remote_tags
  if ! remote_tags="$(git ls-remote --tags origin "refs/tags/v$VERSION" 2>/dev/null)"; then
    die "无法访问远端 origin（git ls-remote 失败）；发布前需要网络与远端可用"
  fi
  if [ -n "$remote_tags" ]; then
    die "远端已存在 tag v${VERSION}；发布不可重复"
  fi
  info "本地 / 远端均无 tag v$VERSION"
}

check_remote_and_gh() {
  local url
  url="$(git remote get-url origin 2>/dev/null || true)"
  [ -n "$url" ] || die "没有 origin 远端，无法发布"
  case "$url" in
    *"$EXPECTED_REMOTE_SLUG"*) : ;;
    *) die "origin 不是预期的 $EXPECTED_REMOTE_SLUG 仓库；拒绝发布（避免推到 fork）" ;;
  esac
  command -v gh >/dev/null 2>&1 || die "未安装 gh（GitHub CLI），无法创建 Release"
  if ! gh auth status >/dev/null 2>&1; then
    die "gh 未登录或登录失效；请先 gh auth login（脚本不读取 / 不打印 token）"
  fi
  info "origin 与 gh 认证检查通过"
}

check_meta_consistency() {
  if [ ! -f "$ROOT/docs/_meta.json" ]; then
    warn "docs/_meta.json 不存在；发布前应先用 --prepare 生成"
    return 0
  fi
  local meta_version meta_test_count meta_zip_bytes
  meta_version="$(meta_field version)"
  meta_test_count="$(meta_field test_count)"
  meta_zip_bytes="$(meta_field zip_bytes)"
  if [ "$meta_version" != "$VERSION" ]; then
    warn "docs/_meta.json 的 version=$meta_version 与 VERSION=$VERSION 不一致；发布前请先跑 --prepare"
  fi
  if [ -n "$TEST_COUNT" ] && [ "$meta_test_count" != "$TEST_COUNT" ]; then
    warn "docs/_meta.json 的 test_count=$meta_test_count 与本次实测 $TEST_COUNT 不一致；README 徽章可能已漂移"
  fi
  if [ -n "$ZIP_BYTES" ] && [ "$meta_zip_bytes" != "$ZIP_BYTES" ]; then
    warn "docs/_meta.json 的 zip_bytes=$meta_zip_bytes 与本次归档 $ZIP_BYTES 不一致；README 包体大小可能已漂移"
  fi
}

# ---------------------------------------------------------------------------
# 测试 / 归档 / 校验
# ---------------------------------------------------------------------------
run_tests() {
  say "运行单元测试（cd src && swift test 2>&1 | tee ${TEST_LOG}）"
  if ! ( cd "$ROOT/src" && swift test 2>&1 | tee "$TEST_LOG" ); then
    die "swift test 失败（日志：${TEST_LOG}）"
  fi
  TEST_COUNT="$(grep -Eo 'Executed [0-9]+ tests?' "$TEST_LOG" | tail -1 | grep -Eo '[0-9]+' || true)"
  [ -n "$TEST_COUNT" ] || die "无法从 $TEST_LOG 解析测试总数（未找到 Executed N tests）"
  say "测试通过：$TEST_COUNT 项"
}

run_archive() {
  say "构建并归档（bash scripts/bundle.sh --archive）"
  if ! bash "$ROOT/scripts/bundle.sh" --archive; then
    die "bundle.sh --archive 失败"
  fi
  [ -d "$APP" ] || die "未找到 $APP"
  [ -f "$ZIP" ] || die "未找到 $ZIP"
  [ -f "$SHA" ] || die "未找到 $SHA"
  say "校验签名（codesign --verify --deep --strict）"
  if ! codesign --verify --deep --strict --verbose=2 "$APP"; then
    die "codesign --verify 失败"
  fi
  say "校验归档完整性（unzip -t）"
  if ! unzip -t "$ZIP" >/dev/null; then
    die "unzip -t 失败：$ZIP 已损坏"
  fi
  info "unzip -t：OK"
  say "校验 sha256（shasum -a 256 -c）"
  if ! ( cd "$ROOT/dist" && shasum -a 256 -c "MacStats.zip.sha256" ); then
    die "shasum -a 256 -c 失败"
  fi
  ZIP_BYTES="$(wc -c < "$ZIP" | tr -d '[:space:]')"
  [ -n "$ZIP_BYTES" ] || die "无法读取 $ZIP 字节数"
  say "归档产物：dist/MacStats.zip（${ZIP_BYTES} 字节）"
}

# ---------------------------------------------------------------------------
# --dry-run
# ---------------------------------------------------------------------------
print_publish_plan() {
  say "以下命令在 --publish --yes 时执行（本次 --dry-run 不执行）"
  print_cmd "git tag -a \"v$VERSION\" -m \"MacStats $VERSION\""
  print_cmd "git push origin main"
  print_cmd "git push origin \"v$VERSION\""
  print_cmd "gh release create \"v$VERSION\" dist/MacStats.zip dist/MacStats.zip.sha256 --title \"MacStats $VERSION\" --notes-file docs/release-notes-$VERSION.md"
  print_cmd "curl -sIL -o /dev/null -w '%{http_code}' $DOWNLOAD_URL   # 期望 200"
  print_cmd "curl -sL -o <tmp>/MacStats.zip $DOWNLOAD_URL && shasum -a 256 <tmp>/MacStats.zip   # 与 dist/MacStats.zip.sha256 比对"
  say "发布仍需满足：--yes + 干净 main + docs/_meta.json.version==$VERSION + 本地 / 远端无 v$VERSION tag"
  if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null 2>&1; then
    warn "本地已存在 tag v${VERSION}；--publish 会被拒绝（发布不可重复）"
  else
    info "本地 tag v${VERSION}：不存在（符合发布前置）"
  fi
}

probe_latest() {
  say "匿名探测 GitHub latest 下载（失败仅告警，不影响 --dry-run）"
  local code shown
  code="$(curl -sIL --max-time 10 -o /dev/null -w '%{http_code}' "$DOWNLOAD_URL" 2>/dev/null || true)"
  shown="$code"
  [ -n "$shown" ] || shown="000"
  if [ "$code" = "200" ]; then
    info "latest 当前可访问：HTTP 200（可能是旧版本，属正常）"
  else
    warn "匿名探测 latest 未返回 200（当前 ${shown}）；--dry-run 继续"
  fi
}

do_dry_run() {
  say "模式：--dry-run（默认；不写 tag、不 push、不建 Release）"
  check_branch_and_tree warn
  acquire_lock
  run_tests
  run_archive
  release_lock
  check_meta_consistency
  print_publish_plan
  probe_latest
  say "dry-run 完成：未执行任何 tag / push / Release 操作；产物在 dist/ 与 MacStats.app（均被 .gitignore 忽略）"
}

# ---------------------------------------------------------------------------
# --prepare
# ---------------------------------------------------------------------------
write_meta() {
  say "写入 docs/_meta.json（version=$VERSION, test_count=$TEST_COUNT, zip_bytes=${ZIP_BYTES}）"
  cat > "$ROOT/docs/_meta.json" <<EOF
{
  "version": "$VERSION",
  "test_count": $TEST_COUNT,
  "zip_bytes": $ZIP_BYTES
}
EOF
  local rc=0
  python3 - "$ROOT/docs/_meta.json" "$VERSION" "$TEST_COUNT" "$ZIP_BYTES" <<'PY' || rc=$?
import json
import sys

path, version, test_count, zip_bytes = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
with open(path, encoding="utf-8") as handle:
    meta = json.load(handle)
assert list(meta.keys()) == ["version", "test_count", "zip_bytes"], "键序不对"
assert meta["version"] == version, "version 不一致"
assert meta["test_count"] == test_count, "test_count 不一致"
assert meta["zip_bytes"] == zip_bytes, "zip_bytes 不一致"
print("docs/_meta.json 校验通过：version=%s test_count=%d zip_bytes=%d" % (version, test_count, zip_bytes))
PY
  if [ "$rc" != "0" ]; then
    die "docs/_meta.json 写入后校验失败（rc=${rc}）"
  fi
}

run_check_docs_fix() {
  CHECK_DOCS_RC=0
  local checker="$ROOT/scripts/check-docs.py"
  if [ ! -f "$checker" ]; then
    warn "未找到 scripts/check-docs.py，跳过文档自动修复（--prepare 只更新了 docs/_meta.json）"
    return 0
  fi
  if ! python3 "$checker" --help 2>/dev/null | grep -q -- '--fix'; then
    warn "scripts/check-docs.py 没有 --fix 参数，跳过文档自动修复（请手动核对 README 数字）"
    return 0
  fi
  say "调用 python3 scripts/check-docs.py --fix"
  if python3 "$checker" --fix; then
    CHECK_DOCS_RC=0
  else
    CHECK_DOCS_RC=$?
    warn "check-docs.py --fix 退出码 $CHECK_DOCS_RC"
  fi
}

show_prepare_diff() {
  say "变更预览（docs/_meta.json 与 README 系列；仅打印，不 commit）"
  run git diff --stat -- docs/_meta.json README.md docs/readme
  run git diff -- docs/_meta.json README.md docs/readme
  say "当前工作树状态（git status --porcelain）"
  git status --porcelain || true
}

do_prepare() {
  say "模式：--prepare（更新 docs/_meta.json 与文档数字；不 commit / tag / push）"
  check_branch_and_tree strict
  acquire_lock
  run_tests
  run_archive
  release_lock
  write_meta
  run_check_docs_fix
  show_prepare_diff
  if [ "$CHECK_DOCS_RC" != "0" ]; then
    die "check-docs.py --fix 后仍有错误（退出码 ${CHECK_DOCS_RC}），请按上面的输出手动修复后重跑"
  fi
  say "--prepare 完成：未 commit / 未 tag / 未 push；确认上面的 diff 后由人提交"
}

# ---------------------------------------------------------------------------
# --publish
# ---------------------------------------------------------------------------
publish_failed() {
  printf 'ERROR: %s\n' "$1" >&2
  printf '\n' >&2
  printf '发布流程已中止。以下回滚命令需人工确认后执行（脚本不会自动回滚）：\n' >&2
  printf '  gh release delete "v%s" --yes\n' "$VERSION" >&2
  printf '  git push --delete origin "v%s"\n' "$VERSION" >&2
  printf '  git tag -d "v%s"\n' "$VERSION" >&2
  printf '已推送的 main 不回滚；用新提交修。\n' >&2
  printf '提示：先检查 tag / Release 是否已创建，不要盲目重跑 --publish。\n' >&2
  exit 1
}

# 归档字节无法跨构建稳定：真机签名使用 ECDSA，每次签名的 signatureValue 都不同
# （同一份内容 CDHash 相同、签名值不同）。所以发布时不试图让 zip 逐字节一致，
# 而是保证 docs/_meta.json 记录的就是本次真正上传的那个包，并在打 tag 前提交。
sync_meta_for_publish() {
  local meta_bytes
  meta_bytes="$(meta_field zip_bytes)"
  if [ "$meta_bytes" = "$ZIP_BYTES" ]; then
    info "docs/_meta.json zip_bytes 与本次归档一致（${ZIP_BYTES}）"
    return 0
  fi
  say "docs/_meta.json zip_bytes=${meta_bytes:-无法读取} 与本次归档 ${ZIP_BYTES} 不一致；对齐后提交"
  write_meta
  git add docs/_meta.json
  git commit -m "chore: sync release metadata with archive" >/dev/null
  info "已提交 docs/_meta.json（$(git rev-parse --short HEAD)）"
  if [ ! -f "$ROOT/scripts/check-docs.py" ]; then
    warn "未找到 scripts/check-docs.py，跳过 meta 变更后的文档校验"
    return 0
  fi
  say "校验文档一致性（meta 变更后）"
  if ! python3 "$ROOT/scripts/check-docs.py"; then
    die "check-docs 失败；meta 已提交但与 README 不一致，请修正后重跑 --publish"
  fi
}

verify_anonymous_download() {
  say "匿名下载校验（releases/latest）"
  local code="" i tmp actual expected
  for i in 1 2 3 4 5 6 7 8 9 10; do
    code="$(curl -sIL --max-time 15 -o /dev/null -w '%{http_code}' "$DOWNLOAD_URL" 2>/dev/null || true)"
    if [ "$code" = "200" ]; then
      break
    fi
    info "第 $i 次探测 HTTP ${code}，等待 Release 生效（6 秒后重试）"
    sleep 6
  done
  if [ "$code" != "200" ]; then
    publish_failed "匿名下载 latest 返回 HTTP ${code}（期望 200）"
  fi
  tmp="$(mktemp -d)"
  if ! curl -sL --max-time 180 -o "$tmp/MacStats.zip" "$DOWNLOAD_URL"; then
    case "$tmp" in
      /tmp/*|/var/folders/*) rm -rf "$tmp" ;;
    esac
    publish_failed "匿名下载 MacStats.zip 失败"
  fi
  actual="$(shasum -a 256 "$tmp/MacStats.zip" | awk '{print $1}')"
  expected="$(awk '{print $1}' "$SHA")"
  case "$tmp" in
    /tmp/*|/var/folders/*) rm -rf "$tmp" ;;
  esac
  if [ -z "$expected" ]; then
    publish_failed "无法读取 $SHA 中的 sha256"
  fi
  if [ "$actual" != "$expected" ]; then
    publish_failed "匿名下载 sha256 不一致（期望 ${expected}，实际 ${actual}）"
  fi
  info "sha256 一致：$actual"
}

publish_steps() {
  say "创建本地 tag v$VERSION"
  run git tag -a "v$VERSION" -m "MacStats $VERSION" || publish_failed "git tag 失败"
  say "推送 main"
  run git push origin main || publish_failed "git push origin main 失败"
  say "推送 tag v$VERSION"
  run git push origin "v$VERSION" || publish_failed "git push origin v$VERSION 失败"
  say "创建 GitHub Release"
  run gh release create "v$VERSION" "$ZIP" "$SHA" --title "MacStats $VERSION" --notes-file "$NOTES" || publish_failed "gh release create 失败"
  verify_anonymous_download
  say "发布完成：v$VERSION"
  info "Release：https://github.com/yichensunjoe/macstats/releases/tag/v$VERSION"
  info "匿名下载校验通过（HTTP 200 + sha256 与 dist 一致）"
  info "后续：更新 Cask / 渠道文案、记录 HANDOFF；如需回滚见上面的命令"
}

do_publish() {
  say "模式：--publish（外部操作：tag + push + gh release；已收到 --yes 授权）"
  check_branch_and_tree strict
  check_meta_version_strict
  check_remote_and_gh
  check_tags_absent
  acquire_lock
  run_tests
  run_archive
  release_lock
  check_meta_consistency
  sync_meta_for_publish
  publish_steps
}

# ---------------------------------------------------------------------------
# 入口
# ---------------------------------------------------------------------------
parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run|--prepare|--publish)
        if [ -n "$MODE_SET" ] && [ "$MODE_SET" != "$1" ]; then
          usage_error "只能指定一种模式（已有 ${MODE_SET}，又出现 $1）"
        fi
        MODE="$(printf '%s' "$1" | sed 's/^--//')"
        MODE_SET="$1"
        ;;
      --yes)
        ASSUME_YES=1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        usage_error "未知参数：$1"
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  if [ "$MODE" = "publish" ] && [ "$ASSUME_YES" != "1" ]; then
    printf 'ERROR: 拒绝发布：--publish 必须显式同时传 --yes（发布是外部操作，需要人工授权）。\n' >&2
    printf '提示：确认要发布时用 bash scripts/release.sh --publish --yes\n' >&2
    exit 2
  fi
  if [ "$MODE" != "publish" ] && [ "$ASSUME_YES" = "1" ]; then
    warn "--yes 只对 --publish 有意义；本次模式 $MODE 忽略"
  fi
  say "MacStats 发布脚本（${MODE}）"
  check_common
  case "$MODE" in
    dry-run) do_dry_run ;;
    prepare) do_prepare ;;
    publish) do_publish ;;
    *) die "未知模式：$MODE" ;;
  esac
}

main "$@"
