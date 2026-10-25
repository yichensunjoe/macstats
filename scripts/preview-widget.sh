#!/bin/bash
# 离屏渲染系统小组件的四档形态，输出到 docs/。
#
# 系统只肯加载有效签名的 appex，所以没签名身份时小组件库是看不到的；
# 这个脚本直接复用扩展的视图代码 + 示例数据渲成 PNG，用来检查排版 / 更新截图。
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SRC="$ROOT/src"
OUT="${1:-$ROOT/docs}"

cd "$SRC"
swift build >/dev/null

PRODUCTS=".build/out/Products/Debug"
[ -d ".build/out/Products/Release" ] && PRODUCTS=".build/out/Products/Release"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/main.swift" <<'SWIFT'
import AppKit
import SwiftUI
import WidgetKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

let application = NSApplication.shared
application.setActivationPolicy(.prohibited)

let shapes: [(String, WidgetFamily, CGSize)] = [
    ("small", .systemSmall, CGSize(width: 170, height: 170)),
    ("medium", .systemMedium, CGSize(width: 364, height: 170)),
    ("large", .systemLarge, CGSize(width: 364, height: 382)),
    ("xlarge", .systemExtraLarge, CGSize(width: 764, height: 382))
]

MainActor.assumeIsolated {
    let entry = StatsEntry.placeholder
    for (name, family, size) in shapes {
        let view = WidgetEntryView(entry: entry, familyOverride: family)
            .frame(width: size.width, height: size.height)
            .background(Palette.backdrop)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            print("渲染失败: \(name)")
            continue
        }
        let path = "\(outDir)/widget-\(name).png"
        try? png.write(to: URL(fileURLWithPath: path))
        print(path)
    }
}
SWIFT

xcrun swiftc -O -target arm64-apple-macos15.0 \
  -I "$PRODUCTS" -L "$PRODUCTS" -lMacStatsCore \
  Sources/MacStatsWidget/Palette.swift \
  Sources/MacStatsWidget/WidgetEntryView.swift \
  Sources/MacStatsWidget/StatsTimelineProvider.swift \
  "$TMP/main.swift" \
  -framework WidgetKit -framework SwiftUI -framework AppKit \
  -o "$TMP/render"

mkdir -p "$OUT"
"$TMP/render" "$OUT"
