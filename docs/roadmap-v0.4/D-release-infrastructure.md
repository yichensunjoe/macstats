# D · 发布护栏

> 上位文档：[`docs/roadmap-v0.4.md`](../roadmap-v0.4.md)。
> 目标：把“发一次版脱层皮”变成“一条命令 + 一次实机安装”。这不是工程洁癖；它是 C 能在一周内反复试的前提。

---

## 1. 为什么要做

这次 0.3 收口，实际发生过的固定成本：

- 10 份 README 手工同步安装段、版本号、测试数、下载大小；
- 271 个链接/锚点手工全检；
- `VERSION`、两个 plist、README、Cask 多处版本号；
- `bundle.sh --archive` → `codesign` → `unzip -t` → `shasum` → `gh release` → 匿名 `curl` 一串手工步骤；
- `BUILD` 在 `bundle.sh` 里硬编码为 3，发版要手改脚本。

这些每次发版都会重复。税越高，越不敢发；越不敢发，C 越拿不到反馈。

### 非目标

- 不做全自动“合并即发布”；发布仍需人授权。
- 不做公证自动化（需要 Apple 账号/2FA，归 A4）。
- 不做全量视觉回归；快照仍需人看。
- 不引入第三方 CI 服务；用 GitHub Actions。

---

## 2. 现状

| 项 | 现状 | 位置 |
|---|---|---|
| CI | 无 | 仓库无 `.github/` |
| 发布 | 手工命令串 | `HANDOFF.md` 的发布记录 |
| 版本 | `VERSION` = 0.3；`BUILD` 默认 3 | `VERSION`、`scripts/bundle.sh` |
| 文档同步 | 手工 | 10 份 README |
| 文档检查 | 手工链接/锚点全检 | 无脚本 |
| Cask | `version :latest` / `sha256 :no_check` | `Casks/macstats.rb` |

---

## 3. 任务卡

### D0 · Build 号单一来源（0.25 天）

- **Owner**：worker-d0
- **依赖**：无
- **文件（独占）**：
  - `BUILD`（新建，内容 `4`）
  - `scripts/bundle.sh`（读取 `BUILD`）
- **步骤**：
  1. 新增 `BUILD` 文件（纯数字，末尾换行）；
  2. `bundle.sh`：
     ```bash
     BUILD="$(tr -d '[:space:]' < "$ROOT/BUILD" 2>/dev/null || true)"
     BUILD="${MACSTATS_BUILD:-${BUILD:-1}}"
     ```
  3. 去掉硬编码 `3`；
  4. 文档里“Build 号”只提 `BUILD`，不再提脚本常量。
- **验收**：`bash scripts/bundle.sh --archive` 后，主程序与 appex 的 `CFBundleVersion` 都等于 `BUILD`；`MACSTATS_BUILD=99` 可覆盖。
- **注意**：不要用 `git rev-list --count`（CI shallow clone 会得到 1）；显式 `BUILD` 文件更稳。

### D1 · CI（0.5 天）

- **Owner**：worker-d1
- **依赖**：D0（可选；CI 也能用默认 BUILD）
- **文件（独占）**：
  - `.github/workflows/ci.yml`
- **触发**：`push` 到 `main`、`pull_request`、`workflow_dispatch`。
- **Job**：`runs-on: macos-15`，`timeout-minutes: 30`，`permissions: contents: read`。
- **步骤**：
  1. `actions/checkout@v4`；
  2. `swift --version`；
  3. `cd src && swift test`；
  4. `bash scripts/bundle.sh --archive`；
  5. `codesign --verify --deep --strict --verbose=2 MacStats.app`；
  6. `unzip -t dist/MacStats.zip`；
  7. `(cd dist && shasum -a 256 -c MacStats.zip.sha256)`；
  8. `python3 scripts/check-docs.py`（D2 产出；先合并 D2 或允许此步暂时 `continue-on-error`，但 0.4 发布前必须变硬）。
- **缓存**（可选）：
  ```yaml
  - uses: actions/cache@v4
    with:
      path: src/.build
      key: ${{ runner.os }}-swift-${{ hashFiles('src/Package.swift', 'src/Package.resolved') }}
  ```
- **YAML 骨架**：
  ```yaml
  name: CI
  on:
    push:
      branches: [main]
    pull_request:
    workflow_dispatch:
  permissions:
    contents: read
  jobs:
    test:
      runs-on: macos-15
      timeout-minutes: 30
      steps:
        - uses: actions/checkout@v4
        - name: Toolchain
          run: swift --version
        - name: Test
          run: cd src && swift test
        - name: Archive
          run: bash scripts/bundle.sh --archive
        - name: Verify archive
          run: |
            codesign --verify --deep --strict --verbose=2 MacStats.app
            unzip -t dist/MacStats.zip
            (cd dist && shasum -a 256 -c MacStats.zip.sha256)
        - name: Docs consistency
          run: python3 scripts/check-docs.py
  ```
- **能抓**：编译失败、单测失败、签名/归档损坏、版本/测试数漂移、本地链接失效。
- **不能抓**：Gatekeeper 实机、公证、WidgetKit 调度、视觉排版、真实告警投递。不要假装 CI 全覆盖；这些留在 Wave 5 的人工验收。
- **验收**：
  - 在一个 PR 上 CI 绿；
  - 故意改坏一个测试，CI 红；恢复后绿；
  - 故意删一个 README 本地链接，文档检查红；恢复后绿。
- **注意**：CI 没有 Apple Development 证书，`bundle.sh` 会走 ad-hoc 签名；`codesign --verify` 仍应通过。不要把“CI 归档成功”说成“WidgetKit 可用”。

### D2 · 文档一致性检查（0.5 天）

- **Owner**：worker-d2
- **依赖**：无；与 A2/A5 协调 README 写入顺序
- **文件（独占）**：
  - `scripts/check-docs.py`（新建）
  - `docs/_meta.json`（新建；由 D3 的 `--prepare` 更新）
- **检查范围**：
  - `README.md`
  - `docs/readme/README_*.md`（9 份）
  - `docs/install.md`
- **检查项**：
  1. 下载链接必须是 `https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip`；
  2. 版本号与 `VERSION` 一致（`0.4` / `v0.4` 两种写法都接受）；
  3. 测试数与 `docs/_meta.json` 的 `test_count` 一致（badge 与正文）；
  4. zip 大小与 `zip_bytes` 一致（`2.4 MB` / `2,439,821` 两种写法按容差匹配）；
  5. 本地相对链接存在；页内锚点能在目标文件找到对应标题（GitHub slug 规则）；
  6. 不检查外链 HTTP（CI 里外链会抖）；需要时 `--external` 手动跑。
- **输出**：`file:line: expected ... got ...`，退出码 1；全过退出 0。
- **`--fix`（可选，后做）**：只替换版本号/测试数/大小/下载 URL 这四类 token，不改正文；替换前打印 diff，默认不写。
- **为什么不做整篇生成**：9 份翻译正文是人写的；脚本生成会制造新的不通顺。机械部分才该同步。
- **验收**：
  - 当前 10 份 README 全过；
  - 手动把英文 README 的测试数改成 99，脚本报 `README_en.md:...`；
  - 手动删一个本地链接，脚本报 404；
  - `--fix` 只改数字/URL，diff 可读。
- **注意**：`docs/_meta.json` 不存在时，允许从 `VERSION` 推导版本、从 `--test-count` 参数取测试数；CI 里必须显式提供，避免“猜”。

### D3 · 一条命令发布（1 天）

- **Owner**：worker-d3
- **依赖**：D0、D1、D2
- **文件（独占）**：
  - `scripts/release.sh`（新建）
  - `docs/_meta.json`（由 `--prepare` 写）
- **三种模式**：

| 模式 | 做什么 | 不做什么 |
|---|---|---|
| `--dry-run`（默认） | 检查分支/干净树/版本/说明文件；跑测试、归档、签名、sha；打印将要执行的 tag/release 命令 | 不写 tag、不 push、不建 Release |
| `--prepare` | 跑测试/归档；从测试输出解析总数写 `docs/_meta.json`；调用 `check-docs.py --fix`；打印 `git diff` | 不 commit、不 tag、不 push |
| `--publish` | 要求干净树 + `main` + meta 匹配；打 tag、push、`gh release create`；匿名下载校验 | 不自动改代码/文档；失败要人处理 |

- **`--publish` 的前置条件**：
  - 当前分支 `main`；
  - `git status --porcelain` 为空；
  - `VERSION` 是 `x.y` 或 `x.y.z`；
  - `docs/release-notes-$VERSION.md` 存在；
  - `docs/_meta.json.version == VERSION`；
  - 本地/远端都没有 `v$VERSION` tag；
  - 用户已明确授权发布（工作区规则：发布/推送是外部操作）。
- **流程**：
  1. `cd src && swift test 2>&1 | tee /tmp/macstats-tests.log`；
     测试总数取最后一条 `Executed N tests`：
     ```bash
     grep -Eo 'Executed [0-9]+ tests' /tmp/macstats-tests.log | tail -1 | grep -Eo '[0-9]+'
     ```
  2. `bash scripts/bundle.sh --archive`；
  3. `codesign --verify --deep --strict`；
  4. `unzip -t`；`shasum -a 256 -c`；
  5. `git tag -a "v$VERSION" -m "MacStats $VERSION"`；
  6. `git push origin main`；`git push origin "v$VERSION"`；
  7. `gh release create "v$VERSION" dist/MacStats.zip dist/MacStats.zip.sha256 --title "MacStats $VERSION" --notes-file "docs/release-notes-$VERSION.md"`；
  8. 匿名校验：
     ```bash
     curl -sIL -o /dev/null -w '%{http_code}\n' \
       https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip
     tmp="$(mktemp -d)"
     curl -sL -o "$tmp/MacStats.zip" \
       https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip
     (cd "$tmp" && shasum -a 256 MacStats.zip)
     rm -rf "$tmp"
     ```
     与 `dist/MacStats.zip.sha256` 比对。
- **失败回滚**（需用户授权）：
  ```bash
  gh release delete "v$VERSION" --yes
  git push --delete origin "v$VERSION"
  git tag -d "v$VERSION"
  ```
  已推送的 `main` 不回滚；用新提交修。
- **验收**：
  - `bash scripts/release.sh --dry-run` 在干净 main 上通过；
  - `--prepare` 生成的 `docs/_meta.json` 与 zip/测试数一致；
  - 下一次真实发布用 `--publish`，全程 ≤5 分钟；
  - 发布后匿名 `latest` 200 且 sha 一致。
- **安全**：
  - 不使用 `set -x`；不打印 token；
  - 依赖 `gh auth` 的现有登录，不把 token 写进脚本/环境文件；
  - `--publish` 必须显式传入，不能默认发布。

### D4 · 任务清单与假设格式（0.25 天）

- **Owner**：worker-d4
- **依赖**：无
- **文件**：`docs/tasks.md`（本地忽略文件，不提交）
- **步骤**：
  1. 把“后续”改成“下一阶段（0.4）”，链接本方案；
  2. 每条任务写三行：为什么现在 / 怎么算成功 / 不做会怎样；
  3. 标记已完成的翻译 README 项；
  4. 把 30 天视图、多屏记忆移到“暂缓”，写明触发条件。
- **验收**：任务清单不再只有“加功能”，每条都有验收与不做的理由。

### D5 · 分支保护（可选，需用户授权）

- 在 GitHub 仓库设置里把 `CI / test` 设为 main 的 required check；
- 需要管理员权限，agent 不自动改；
- 如果开启，合并前必须绿；紧急修复也不能绕过（除非用户明确要求）。

---

## 4. 发布检查清单（0.4 起用）

```bash
cd projects/active/P087-macstats-widget

# 1. 版本与构建号
cat VERSION BUILD

# 2. 测试
cd src && swift test
cd ..

# 3. 归档 + 签名
bash scripts/bundle.sh --archive
codesign --verify --deep --strict --verbose=2 MacStats.app
defaults read "$PWD/MacStats.app/Contents/Info.plist" CFBundleShortVersionString
defaults read "$PWD/MacStats.app/Contents/Info.plist" CFBundleVersion

# 4. 包完整性
unzip -t dist/MacStats.zip
(cd dist && shasum -a 256 -c MacStats.zip.sha256)

# 5. 文档一致性
python3 scripts/check-docs.py

# 6. 发布（需授权）
bash scripts/release.sh --dry-run
bash scripts/release.sh --publish
```

发布后：

```bash
curl -sIL https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip | head -1
curl -sL  https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip.sha256
```

---

## 5. 完成定义

- [ ] `BUILD` 是唯一构建号来源；主程序与 appex 一致。
- [ ] `.github/workflows/ci.yml` 在 PR 上绿；故意破坏能红。
- [ ] `check-docs.py` 能抓版本/测试数/大小/链接漂移；当前 10 份 README 全过。
- [ ] `release.sh --dry-run` 通过；`--prepare` 能生成一致的 meta；`--publish` 在下一次真实发布中验证。
- [ ] 发布全程 ≤5 分钟（不含等待 CI）。
- [ ] 没有把证书、token、`dist/`、`.build/` 提交进仓库。

---

## 6. 风险与回滚

| 风险 | 缓解 | 回滚 |
|---|---|---|
| CI 太慢/额度 | 缓存 `.build`；只跑一个 job；不做矩阵 | 暂时改为 `workflow_dispatch` 手动触发 |
| 无签名身份导致 CI 归档“假成功” | CI 只验证 ad-hoc 完整性；不声称 WidgetKit 可用 | 以本机 `bundle.sh` 为准 |
| 文档检查误报 | 白名单 + 只检查四类 token；外链不跑 | 把检查降为 `continue-on-error`，修好再变硬 |
| 发布脚本误发 | `--dry-run` 默认；`--publish` 需干净 main + 用户授权 | 删 Release/tag；main 用新提交修 |
| meta 与 README 不同步 | `--prepare` 打印 diff；CI 检查 | 回退 meta 与 README 到上一提交 |
| 版本号写错 | `VERSION` 单一来源；tag 前校验 | 删 tag/Release，改 VERSION 重发 |

---

## 7. 给多 agent 的边界

- D1/D2/D3 可以并行开工，但 **D3 依赖 D0/D1/D2 的接口**；先让 D2 定 `check-docs.py` 的退出码与 `_meta.json` 格式。
- `.github/` 目录同时被 D1（workflow）和 A6（Issue 模板）使用；两者文件不同，可并行，但不要让两个 agent 同时创建 `.github/` 根目录导致覆盖。
- 任何 agent 都不应执行 `release.sh --publish`；这是用户授权后的串行步骤。
