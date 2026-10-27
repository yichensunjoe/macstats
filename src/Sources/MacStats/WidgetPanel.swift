import AppKit

/// 承载小组件的无边框面板：不抢焦点、可拖动、可缩放、跟随所有桌面空间。
final class WidgetPanel: NSPanel {
    /// 右键菜单由外部（AppDelegate）构造，面板只负责弹出来。
    /// SwiftUI 的 `.contextMenu` 在不抢焦点的面板上经常弹不出来，所以走 AppKit 这条路。
    var contextMenuProvider: (() -> NSMenu)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// 背景拖动的入口。
    ///
    /// 面板内容整块是 SwiftUI 的 `NSHostingView`，而 `isMovableByWindowBackground` 的自动拖动
    /// 在这条路径上不会生效（实测：纯 NSView 内容的面板能拖，同样配置的 SwiftUI 面板拖不动，
    /// 桌面层与常规层都一样）。非交互区域里的 mouseDown 会冒泡到窗口，所以在这里自己发起拖动。
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            rightMouseDown(with: event)
            return
        }
        performDrag(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = contextMenuProvider?() else {
            super.rightMouseDown(with: event)
            return
        }
        let point = contentView?.convert(event.locationInWindow, from: nil) ?? .zero
        menu.popUp(positioning: nil, at: point, in: contentView)
    }
}
