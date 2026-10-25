import AppKit
import MacStatsCore

/// 右下角的缩放柄。
///
/// 无边框面板没有系统缩放边，这里补一个 22×22 的手柄：按住拖动改窗口尺寸，
/// 版式会随尺寸自动切换档位。
final class ResizeGripView: NSView {
    var minimumSize: NSSize = WidgetLayout.minimumSize
    var onResize: ((NSRect) -> Void)?

    private var startFrame: NSRect = .zero
    private var startMouse: NSPoint = .zero
    private var isHovering = false {
        didSet { needsDisplay = true }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    /// 面板背景是可拖动的（移动窗口），缩放柄上的拖动必须只用来改尺寸。
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseEntered(with event: NSEvent) { isHovering = true }
    override func mouseExited(with event: NSEvent) { isHovering = false }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        startFrame = window.frame
        startMouse = NSEvent.mouseLocation
        if ProcessInfo.processInfo.environment["MACSTATS_DEBUG"] != nil {
            FileHandle.standardError.write(Data("grip: down frame=\(startFrame)\n".utf8))
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - startMouse.x
        let dy = now.y - startMouse.y
        let limit = window.screen?.visibleFrame.size ?? NSSize(width: 4000, height: 4000)
        let width = min(max(startFrame.width + dx, minimumSize.width), limit.width)
        let height = min(max(startFrame.height - dy, minimumSize.height), limit.height)
        // 左上角固定，向右下拉伸。
        let frame = NSRect(
            x: startFrame.minX,
            y: startFrame.maxY - height,
            width: width,
            height: height
        )
        window.setFrame(frame, display: true)
        if ProcessInfo.processInfo.environment["MACSTATS_DEBUG"] != nil {
            FileHandle.standardError.write(Data("grip: resize to \(frame.size)\n".utf8))
        }
        onResize?(frame)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let alpha: CGFloat = isHovering ? 0.6 : 0.26
        NSColor.white.withAlphaComponent(alpha).setFill()
        let dot: CGFloat = 1.7
        let gap: CGFloat = 3.4
        for index in 0..<3 {
            let offset = CGFloat(index) * gap + 3
            let rect = NSRect(
                x: bounds.maxX - offset - dot,
                y: bounds.minY + offset - dot,
                width: dot,
                height: dot
            )
            NSBezierPath(ovalIn: rect).fill()
        }
    }
}
