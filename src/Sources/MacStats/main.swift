import AppKit
import SwiftUI
import MacStatsCore

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.contains("--help") || arguments.contains("-h") {
    print("""
    MacStats Panel (MacStats)

    用法:
      MacStats                      启动菜单栏应用与桌面小组件
      MacStats --snapshot <path> [micro|compact|standard|expanded] [宽x高]
                                    采样后把某个版式渲染成 PNG（用于检查排版，不弹出窗口）
    """)
    exit(0)
}

if let index = arguments.firstIndex(of: "--snapshot"), index + 1 < arguments.count {
    let layout = arguments.count > index + 2
        ? (WidgetLayout(rawValue: arguments[index + 2]) ?? .standard)
        : .standard
    var size: CGSize?
    if arguments.count > index + 3 {
        let parts = arguments[index + 3].lowercased().split(separator: "x")
        if parts.count == 2, let width = Double(parts[0]), let height = Double(parts[1]) {
            size = CGSize(width: width, height: height)
        }
    }
    SnapshotRenderer.render(to: arguments[index + 1], layout: layout, size: size)
    exit(0)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.setActivationPolicy(.accessory)
application.delegate = delegate
application.run()
