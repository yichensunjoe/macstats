#!/usr/bin/env python3
"""MacStats 文档一致性检查（0.4 D2）。

检查范围：
    README.md、docs/readme/README_*.md（9 份翻译）、docs/install.md

检查项：
    1. 下载链接：出现 latest/download/MacStats.zip 时必须是规范 URL；
    2. 版本号：正文出现的 0.x / v0.x 版本 token 必须等于 VERSION（未出现不报错）；
    3. 测试数：徽章 tests-N passing 与正文 XCTest，N 项/cases 必须等于 _meta.json 的 test_count；
    4. zip 大小：2.4 MB（±0.05 MB，按 10^6 字节）与 2,439,821 字节两种写法必须与 zip_bytes 一致；
    5. 本地相对链接必须存在；页内锚点必须能在目标 Markdown 找到对应标题（GitHub slug 规则）；
    6. 外链 HTTP 默认不检查，--external 时才探测（网络错误只告警，HTTP 4xx/5xx 记为错误）；
    7. README 结构对齐：10 份 README 的 H2/H3 数量必须与 README.md 一致；安装章必须是三步、
       同一组命令，并带齐六条排障及其关键技术声明（arm64/Rosetta、killall、pluginkit、brew trust）。

输出：
    file:line: expected ... got ...；有错退出码 1，全过 0；末尾打印汇总。

--fix：
    只替换版本 / 测试数 / 大小 / 下载 URL 四类 token，默认不写盘。
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

DOWNLOAD_URL = "https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip"
SIZE_TOLERANCE_MB = 0.05
BYTES_PER_MB = 1_000_000
MIN_ZIP_MB = 0.5  # 小于这个值的 MB 数字是「0.0 MB 进程内存」这类口径描述，不是包体大小
EXTERNAL_TIMEOUT = 10

FENCE = "\x60\x60\x60"

VERSION_TOKEN_RE = re.compile(r"(?<![0-9A-Za-z_.])[vV]?(0\.\d+(?:\.\d+)?)(?![0-9])")
UNIT_AFTER_RE = re.compile(
    r"\s*(?:%|GB|MB|KB|TB|GiB|MiB|KiB|B|ms|s|秒|分钟|分|倍|项|个|件|次|回|Hz|GHz|MHz)"
)
BADGE_RE = re.compile(r"tests-(\d+)(?:%20|\s|-)passing")
XCTEST_RE = re.compile(r"XCTest[^0-9\n]{0,16}?(\d+)")
SIZE_MB_RE = re.compile(
    r"(?<![\d.,])(\d{1,3}[.,]\d{1,3})\s*(МБ|мб|MB|mb|Mb)(?![A-Za-zА-Яа-я])"
)
SIZE_BYTES_RE = re.compile(r"(?<![\d.,])(\d{1,3}(?:,\d{3})+|\d{7,9})(?![\d.,])")
URL_RE = re.compile(r"https?://[^\s<>\"')\]]+")
MD_LINK_RE = re.compile(r"!?\[[^\]\n]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
HTML_ATTR_RE = re.compile(
    r"<(?:img|a)\b[^>]*?\b(?:src|href)\s*=\s*\"([^\"]+)\"", re.IGNORECASE
)
HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*#*\s*$")
INLINE_CODE_RE = re.compile(r"\x60[^\x60\n]*\x60")
NUMBERED_ITEM_RE = re.compile(r"^\s*(\d+)\.\s+")
BOLD_ITEM_RE = re.compile(r"^\s*(\d+)\.\s+\*\*")

# 10 份 README 的安装章骨架：三步安装、同一组命令、六条排障。
# 共享骨架与具体语言无关，所以按命令与数字校验，而不比对译文。
INSTALL_STEP_COUNT = 3
TROUBLESHOOTING_ITEM_COUNT = 6
INSTALL_REQUIRED_TOKENS = (
    "MacStats.zip",
    "/Applications",
    "xattr -dr com.apple.quarantine",
    "brew install --cask macstats",
    "brew trust yichensunjoe/macstats",
    "shasum -a 256 -c",
    "uname -m",
    "sw_vers -productVersion",
    "killall chronod NotificationCenter",
    "lsregister",
    "pluginkit",
    "arm64",
    "Rosetta",
    "macOS 15",
)
TROUBLESHOOTING_ITEM_TOKENS = {
    1: ("Gatekeeper",),
    2: ("arm64", "Rosetta"),
    4: ("killall chronod NotificationCenter",),
    5: ("lsregister", "pluginkit"),
    6: ("brew trust", "brew untrust"),
}


@dataclass
class Issue:
    path: Path
    line: int
    message: str
    severity: str = "error"


@dataclass
class Fix:
    path: Path
    line: int
    start: int
    end: int
    old: str
    new: str


def rel_path(root: Path, path: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def github_slug(text: str) -> str:
    """GitHub 标题锚点规则：小写、去标点、空格换连字符；保留各语言字母与数字。"""
    text = text.strip().lower()
    kept = []
    for char in text:
        if char in " -_":
            kept.append(char)
        elif unicodedata.category(char)[0] in ("L", "N", "M"):
            kept.append(char)
    return "".join(kept).replace(" ", "-")


def fetch_status(url: str) -> tuple[int | None, str | None]:
    """返回 (HTTP 状态码, 错误说明)；网络层失败返回 (None, 说明)。"""
    headers = {"User-Agent": "macstats-check-docs/0.4 (+https://github.com/yichensunjoe/macstats)"}
    for method in ("HEAD", "GET"):
        request = urllib.request.Request(url, method=method, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=EXTERNAL_TIMEOUT) as response:
                return int(response.status), None
        except urllib.error.HTTPError as exc:
            if method == "HEAD" and exc.code in (403, 405, 501):
                continue
            return int(exc.code), None
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            if method == "HEAD":
                continue
            return None, str(getattr(exc, "reason", exc))
    return None, "request failed"


class DocChecker:
    def __init__(self, root, version, test_count, zip_bytes, external=False, collect_fixes=False):
        self.root = root
        self.version = version
        self.test_count = test_count
        self.zip_bytes = zip_bytes
        self.external = external
        self.collect_fixes = collect_fixes
        self.issues = []
        self.fixes = []
        self.slug_cache = {}
        self.heading_cache = {}
        self.stats = {
            "files": 0,
            "local_links": 0,
            "anchors": 0,
            "external": 0,
            "external_skipped": 0,
            "badges": 0,
        }

    @property
    def errors(self):
        return [issue for issue in self.issues if issue.severity == "error"]

    def add(self, path, line, message, severity="error"):
        self.issues.append(Issue(Path(path), int(line), message, severity))

    def add_fix(self, path, line, start, end, old, new):
        if self.collect_fixes and old != new:
            self.fixes.append(Fix(Path(path), int(line), int(start), int(end), old, new))

    def doc_paths(self):
        paths = [self.root / "README.md"]
        paths.extend(sorted((self.root / "docs/readme").glob("README_*.md")))
        paths.append(self.root / "docs/install.md")
        return paths

    def run(self):
        for path in self.doc_paths():
            self.check_file(path)
        self.check_readme_structure()

    # ---- 单文件检查 -------------------------------------------------
    def check_file(self, path):
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as exc:
            self.add(path, 1, "expected readable UTF-8 file, got " + str(exc))
            return
        self.stats["files"] += 1
        in_fence = False
        for line_no, line in enumerate(text.splitlines(), 1):
            self.check_urls(path, line_no, line)
            self.check_versions(path, line_no, line)
            self.check_test_counts(path, line_no, line)
            self.check_sizes(path, line_no, line)
            stripped = line.lstrip()
            if stripped.startswith(FENCE) or stripped.startswith("~~~"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            scan = INLINE_CODE_RE.sub("", line)
            for match in MD_LINK_RE.finditer(scan):
                self.check_link(path, line_no, match.group(1))
            for match in HTML_ATTR_RE.finditer(scan):
                self.check_link(path, line_no, match.group(1))

    def check_urls(self, path, line_no, line):
        for match in URL_RE.finditer(line):
            url = match.group(0).rstrip(".,;:")
            if "releases/latest/download/" in url or url.endswith("MacStats.zip"):
                if url != DOWNLOAD_URL:
                    self.add(path, line_no, "expected download URL " + DOWNLOAD_URL + ", got " + url)
                    self.add_fix(path, line_no, match.start(), match.start() + len(url), url, DOWNLOAD_URL)

    def check_versions(self, path, line_no, line):
        url_spans = [(m.start(), m.end()) for m in URL_RE.finditer(line)]
        for match in VERSION_TOKEN_RE.finditer(line):
            if any(start <= match.start() < end for start, end in url_spans):
                continue  # URL 里的 tag 由下载链接检查负责，避免重复报错
            raw = match.group(0)
            token = match.group(1)
            if self.is_measurement(line, match):
                continue
            if token == self.version:
                continue
            self.add(path, line_no, "expected version " + self.version + ", got " + token)
            if raw[:1] in ("v", "V"):
                new_raw = raw[:1] + self.version
            else:
                new_raw = self.version
            self.add_fix(path, line_no, match.start(), match.end(), raw, new_raw)

    @staticmethod
    def is_measurement(line, match):
        before = line[: match.start()]
        after = line[match.end():]
        stripped_before = before.rstrip()
        if stripped_before and stripped_before[-1] in "≤≥<>±≈~":
            return True
        if UNIT_AFTER_RE.match(after):
            return True
        if re.match(r"\s*/\s*\d", after):
            return True
        if re.search(r"\d\s*/\s*$", before):
            return True
        if re.match(r"\s*[×xX]\s*\d", after):
            return True
        if re.match(r"\s*[–—-]\s*\d", after):
            return True
        return False

    def check_test_counts(self, path, line_no, line):
        for match in BADGE_RE.finditer(line):
            got = int(match.group(1))
            if got != self.test_count:
                self.add(path, line_no, "expected test count " + str(self.test_count) + " (badge), got " + str(got))
                self.add_fix(path, line_no, match.start(1), match.end(1), match.group(1), str(self.test_count))
        match = XCTEST_RE.search(line)
        if match:
            got = int(match.group(1))
            if got != self.test_count:
                self.add(path, line_no, "expected test count " + str(self.test_count) + " (XCTest line), got " + str(got))
                self.add_fix(path, line_no, match.start(1), match.end(1), match.group(1), str(self.test_count))

    def check_sizes(self, path, line_no, line):
        expected_mb = self.zip_bytes / BYTES_PER_MB
        for match in SIZE_MB_RE.finditer(line):
            raw = match.group(1)
            unit = match.group(2)
            try:
                value = float(raw.replace(",", "."))
            except ValueError:
                continue
            if value < MIN_ZIP_MB:
                continue
            if abs(value - expected_mb) <= SIZE_TOLERANCE_MB:
                continue
            self.add(
                path,
                line_no,
                "expected zip size {:.1f} MB (±{} MB), got {} {}".format(expected_mb, SIZE_TOLERANCE_MB, raw, unit),
            )
            new_value = "{:.1f}".format(expected_mb)
            if "," in raw:
                new_value = new_value.replace(".", ",")
            self.add_fix(path, line_no, match.start(1), match.end(1), raw, new_value)
        for match in SIZE_BYTES_RE.finditer(line):
            raw = match.group(1)
            value = int(raw.replace(",", ""))
            if not (1_000_000 <= value <= 50_000_000):
                continue
            if value == self.zip_bytes:
                continue
            self.add(
                path,
                line_no,
                "expected zip size {:,} bytes, got {}".format(self.zip_bytes, raw),
            )
            new_value = "{:,}".format(self.zip_bytes) if "," in raw else str(self.zip_bytes)
            self.add_fix(path, line_no, match.start(1), match.end(1), raw, new_value)

    # ---- 链接与锚点 -------------------------------------------------
    def check_link(self, path, line_no, target):
        target = target.strip()
        if not target:
            return
        if target.startswith(("http://", "https://")):
            self.stats["external"] += 1
            if "shields.io" in target or "badgen" in target:
                self.stats["badges"] += 1
                return
            if not self.external:
                self.stats["external_skipped"] += 1
                return
            self.check_external(path, line_no, target)
            return
        if target.startswith(("mailto:", "tel:")):
            return
        if target.startswith("#"):
            self.check_anchor(path, path, line_no, urllib.parse.unquote(target[1:]))
            return
        path_part, _, fragment = target.partition("#")
        path_part = urllib.parse.unquote(path_part)
        target_path = (path.parent / path_part).resolve()
        self.stats["local_links"] += 1
        if not target_path.exists():
            self.add(path, line_no, "expected local link target " + path_part + ", got missing file")
            return
        if fragment and target_path.suffix.lower() == ".md":
            self.check_anchor(path, target_path, line_no, urllib.parse.unquote(fragment))

    def check_anchor(self, source, target_path, line_no, fragment):
        if not fragment:
            return
        self.stats["anchors"] += 1
        slugs = self.heading_slugs(target_path)
        if fragment in slugs:
            return
        self.add(
            source,
            line_no,
            "expected anchor #" + fragment + " in " + rel_path(self.root, target_path) + ", got no matching heading",
        )

    def heading_slugs(self, path):
        cached = self.slug_cache.get(path)
        if cached is not None:
            return cached
        slugs = set()
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            self.slug_cache[path] = slugs
            return slugs
        seen = {}
        in_fence = False
        for line in text.splitlines():
            stripped = line.lstrip()
            if stripped.startswith(FENCE) or stripped.startswith("~~~"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            match = HEADING_RE.match(line)
            if not match:
                continue
            base = github_slug(match.group(2))
            count = seen.get(base, 0)
            seen[base] = count + 1
            slugs.add(base if count == 0 else base + "-" + str(count))
        self.slug_cache[path] = slugs
        return slugs

    def check_external(self, path, line_no, url):
        status, error = fetch_status(url)
        if error is not None:
            self.add(path, line_no, "external check skipped: " + error + " (" + url + ")", severity="warning")
            self.stats["external_skipped"] += 1
            return
        if status is not None and status >= 400:
            self.add(path, line_no, "expected external link " + url + " to return 2xx/3xx, got HTTP " + str(status))

    # ---- README 结构对齐 -------------------------------------------
    def readme_paths(self):
        return [self.root / "README.md"] + sorted((self.root / "docs/readme").glob("README_*.md"))

    def iter_headings(self, path):
        cached = self.heading_cache.get(path)
        if cached is not None:
            return cached
        cached = []
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            self.heading_cache[path] = cached
            return cached
        in_fence = False
        for line_no, line in enumerate(text.splitlines(), 1):
            stripped = line.lstrip()
            if stripped.startswith(FENCE) or stripped.startswith("~~~"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            match = HEADING_RE.match(line)
            if match:
                cached.append((line_no, len(match.group(1)), match.group(2)))
        self.heading_cache[path] = cached
        return cached

    def check_readme_structure(self):
        """README 结构对齐：标题数量与安装章骨架必须 10 份一致。"""
        paths = self.readme_paths()
        reference = paths[0]
        counts = {}
        for path in paths:
            headings = self.iter_headings(path)
            counts[path] = {
                2: sum(1 for _, level, _ in headings if level == 2),
                3: sum(1 for _, level, _ in headings if level == 3),
            }
        if reference not in counts:
            return
        for level, label in ((2, "H2"), (3, "H3")):
            expected = counts[reference][level]
            for path in paths[1:]:
                got = counts[path][level]
                if got == expected:
                    continue
                headings = self.iter_headings(path)
                line = next((line for line, lvl, _ in headings if lvl == level), 1)
                self.add(
                    path,
                    line,
                    "expected {} {} sections ({}, translated READMEs must match), got {}".format(
                        expected, label, rel_path(self.root, reference), got
                    ),
                )
        for path in paths:
            self.check_install_chapter(path)

    def check_install_chapter(self, path):
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except OSError:
            return
        headings = self.iter_headings(path)
        start = next((line for line, level, _ in headings if level == 2), None)
        if start is None:
            self.add(path, 1, "expected an install chapter (first H2), got none")
            return
        end = next((line for line, level, _ in headings if level == 2 and line > start), len(lines) + 1)
        chapter = lines[start - 1:end - 1]
        chapter_first_line = start

        steps = []
        in_fence = False
        for line in chapter:
            stripped = line.lstrip()
            if stripped.startswith(FENCE) or stripped.startswith("~~~"):
                in_fence = not in_fence
                break  # 安装步骤在第一个代码块之前
            match = NUMBERED_ITEM_RE.match(line)
            if match:
                steps.append(int(match.group(1)))
        if steps != list(range(1, INSTALL_STEP_COUNT + 1)):
            self.add(
                path,
                chapter_first_line,
                "expected install steps 1-{} before the command block, got {}".format(
                    INSTALL_STEP_COUNT, steps or "none"
                ),
            )

        item_lines = {}
        in_fence = False
        for offset, line in enumerate(chapter, start):
            stripped = line.lstrip()
            if stripped.startswith(FENCE) or stripped.startswith("~~~"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            match = BOLD_ITEM_RE.match(line)
            if match:
                item_lines.setdefault(int(match.group(1)), (offset, line))
        if sorted(item_lines) != list(range(1, TROUBLESHOOTING_ITEM_COUNT + 1)):
            self.add(
                path,
                chapter_first_line,
                "expected {} troubleshooting items numbered 1-{}, got {}".format(
                    TROUBLESHOOTING_ITEM_COUNT,
                    TROUBLESHOOTING_ITEM_COUNT,
                    sorted(item_lines) or "none",
                ),
            )

        joined = "\n".join(chapter)
        for token in INSTALL_REQUIRED_TOKENS:
            if token not in joined:
                self.add(path, chapter_first_line, "expected install chapter to mention " + token + ", got missing")
        for number, tokens in TROUBLESHOOTING_ITEM_TOKENS.items():
            entry = item_lines.get(number)
            if entry is None:
                continue
            line_no, text = entry
            for token in tokens:
                if token not in text:
                    self.add(
                        path,
                        line_no,
                        "expected troubleshooting item {} to mention {}, got missing".format(number, token),
                    )

    # ---- 输出 -------------------------------------------------------
    def report(self):
        ordered = sorted(self.issues, key=lambda item: (rel_path(self.root, item.path), item.line, item.message))
        for issue in ordered:
            shown = rel_path(self.root, issue.path)
            if issue.severity == "warning":
                print("{}:{}: warning: {}".format(shown, issue.line, issue.message))
            else:
                print("{}:{}: {}".format(shown, issue.line, issue.message))
        stats = self.stats
        print(
            "summary: {files} files, {local} local links, {anchors} anchors, "
            "{external} external links ({skipped} skipped, {badges} badges ignored), {errors} error(s)".format(
                files=stats["files"],
                local=stats["local_links"],
                anchors=stats["anchors"],
                external=stats["external"],
                skipped=stats["external_skipped"],
                badges=stats["badges"],
                errors=len(self.errors),
            )
        )


def apply_fixes(root, fixes):
    by_path = {}
    for fix in fixes:
        by_path.setdefault(fix.path, []).append(fix)
    for path, items in by_path.items():
        text = path.read_text(encoding="utf-8")
        lines = text.splitlines(keepends=True)
        for fix in sorted(items, key=lambda item: (item.line, item.start), reverse=True):
            index = fix.line - 1
            if index < 0 or index >= len(lines):
                continue
            raw = lines[index]
            ending = ""
            if raw.endswith("\r\n"):
                body, ending = raw[:-2], "\r\n"
            elif raw.endswith("\n"):
                body, ending = raw[:-1], "\n"
            else:
                body = raw
            if body[fix.start:fix.end] != fix.old:
                continue
            lines[index] = body[: fix.start] + fix.new + body[fix.end:] + ending
        path.write_text("".join(lines), encoding="utf-8")


def resolve_config(root, args):
    errors = []
    warnings = []
    version_path = root / "VERSION"
    if not version_path.exists():
        return None, None, None, ["VERSION:1: expected VERSION file, got missing"], warnings
    version = version_path.read_text(encoding="utf-8").strip()
    if not version:
        return None, None, None, ["VERSION:1: expected non-empty version, got empty"], warnings

    test_count = args.test_count
    zip_bytes = args.zip_bytes
    meta_path = root / "docs/_meta.json"
    if meta_path.exists():
        try:
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            errors.append("docs/_meta.json:1: expected valid JSON, got " + str(exc))
            return None, None, None, errors, warnings
        if not isinstance(meta, dict):
            errors.append("docs/_meta.json:1: expected JSON object, got non-object")
            return None, None, None, errors, warnings
        meta_version = meta.get("version")
        if meta_version != version:
            errors.append(
                "docs/_meta.json:1: expected version " + version + " (from VERSION), got " + str(meta_version)
            )
        value = meta.get("test_count")
        if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
            errors.append("docs/_meta.json:1: expected test_count to be a positive integer, got " + repr(value))
        else:
            test_count = value
        value = meta.get("zip_bytes")
        if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
            errors.append("docs/_meta.json:1: expected zip_bytes to be a positive integer, got " + repr(value))
        else:
            zip_bytes = value
    else:
        warnings.append("warning: docs/_meta.json 不存在，回退到 VERSION / --test-count / --zip-bytes")
        if test_count is None:
            errors.append("docs/_meta.json:1: expected docs/_meta.json with test_count, got missing (请提供 --test-count)")
        if zip_bytes is None:
            dist_zip = root / "dist/MacStats.zip"
            if dist_zip.exists():
                zip_bytes = dist_zip.stat().st_size
                warnings.append("warning: zip_bytes 取自 dist/MacStats.zip = " + str(zip_bytes))
            else:
                errors.append("docs/_meta.json:1: expected docs/_meta.json with zip_bytes, got missing (请提供 --zip-bytes)")
    return version, test_count, zip_bytes, errors, warnings


def build_parser():
    parser = argparse.ArgumentParser(
        prog="check-docs.py",
        description="MacStats 文档一致性检查（README / 翻译 README / install.md）。",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "检查项：\n"
            "  1. 下载链接必须是 https://github.com/yichensunjoe/macstats/releases/latest/download/MacStats.zip；\n"
            "  2. 正文出现的 0.x / v0.x 版本 token 必须等于 VERSION（未出现不报错）；\n"
            "  3. 测试数徽章与正文 XCTest 行必须等于 docs/_meta.json 的 test_count；\n"
            "  4. zip 大小 2.4 MB（±0.05 MB，按 10^6 字节）或 2,439,821 字节必须与 zip_bytes 一致；\n"
            "  5. 本地相对链接必须存在，页内锚点必须能在目标 Markdown 找到对应标题；\n"
            "  6. 外链默认不检查，--external 时才发 HTTP 请求（网络错误仅告警）；\n"
            "  7. 10 份 README 的 H2/H3 数量一致，安装章为三步 + 六条排障（含固定命令）。\n"
            "\n"
            "退出码：0 全过；1 有错误；2 用法错误。\n"
        ),
    )
    parser.add_argument(
        "--fix",
        action="store_true",
        help="只替换版本/测试数/大小/下载 URL 四类 token 并写盘；默认只检查不写盘",
    )
    parser.add_argument("--external", action="store_true", help="额外探测 http(s) 外链（默认跳过，CI 不开启）")
    parser.add_argument("--test-count", type=int, metavar="N", help="docs/_meta.json 缺失时回退的测试总数")
    parser.add_argument("--zip-bytes", type=int, metavar="N", help="docs/_meta.json 缺失时回退的 zip 字节数")
    parser.add_argument("--root", metavar="PATH", help="仓库根目录（默认取脚本所在目录的上一级）")
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    root = Path(args.root).resolve() if args.root else Path(__file__).resolve().parent.parent
    version, test_count, zip_bytes, errors, warnings = resolve_config(root, args)
    for message in warnings:
        print(message)
    if errors:
        for message in errors:
            print(message)
        print("summary: 0 files checked, 0 links, 0 anchors, " + str(len(errors)) + " error(s)")
        return 1

    checker = DocChecker(root, version, test_count, zip_bytes, external=args.external, collect_fixes=args.fix)
    checker.run()
    if args.fix and checker.fixes:
        print("fix: " + str(len(checker.fixes)) + " replacement(s) pending")
        for fix in sorted(checker.fixes, key=lambda item: (rel_path(root, item.path), item.line, item.start)):
            print("  {}:{}: {!r} -> {!r}".format(rel_path(root, fix.path), fix.line, fix.old, fix.new))
        apply_fixes(root, checker.fixes)
        print("fix: written; re-checking")
        checker = DocChecker(root, version, test_count, zip_bytes, external=args.external, collect_fixes=False)
        checker.run()
    checker.report()
    if checker.errors:
        return 1
    print("check-docs: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
