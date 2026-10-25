import SwiftUI
import AppKit
import MacStatsCore

/// 小组件配色与字体。整体是深色半透明玻璃质感，与 macOS 桌面小组件接近。
@MainActor
enum Theme {
    static var accentStyle: AccentTintColor = .vibrant

    static var cpu: Color {
        accentStyle == .monochrome ? Color(hex: 0x93B5C6) : Color(hex: 0x5B9BFF)
    }
    static var memory: Color {
        accentStyle == .monochrome ? Color(hex: 0x88B395) : Color(hex: 0x3EDC81)
    }
    static var energy: Color {
        accentStyle == .monochrome ? Color(hex: 0xDEB078) : Color(hex: 0xFFB13B)
    }
    static var disk: Color {
        accentStyle == .monochrome ? Color(hex: 0xB8A8C8) : Color(hex: 0xC089FF)
    }
    static var network: Color {
        accentStyle == .monochrome ? Color(hex: 0x86C7C0) : Color(hex: 0x35D6C8)
    }
    static var gpu: Color {
        accentStyle == .monochrome ? Color(hex: 0xC8A8B8) : Color(hex: 0xFF7AB6)
    }

    static let primaryText = Color.white.opacity(0.95)
    static let secondaryText = Color.white.opacity(0.55)
    static let tertiaryText = Color.white.opacity(0.35)

    static let tileFill = Color.white.opacity(0.055)
    static let tileStroke = Color.white.opacity(0.075)
    static let track = Color.white.opacity(0.10)

    static func pressure(_ pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: memory
        case .warning: Color(hex: 0xFFD23B)
        case .critical: Color(hex: 0xFF5F56)
        }
    }

    static func load(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.45: cpu
        case ..<0.75: Color(hex: 0xFFC53B)
        default: Color(hex: 0xFF6B5B)
        }
    }

    static let widgetWidth: CGFloat = 372
    static let cornerRadius: CGFloat = 24

    static let valueFont = Font.system(size: 21, weight: .semibold, design: .rounded).monospacedDigit()
    static let captionFont = Font.system(size: 10, weight: .medium)
    static let labelFont = Font.system(size: 9.5, weight: .bold)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// 底板风格。`material` 用于真实窗口（系统模糊），`solid` 用于离屏渲染截图。
enum SurfaceStyle: Equatable {
    case material
    case solid
}

/// 小组件底板：系统材质 + 深色渐变 + 细描边。
struct WidgetBackground: View {
    var style: SurfaceStyle = .material
    /// 极简条按宽度微调圆角，常规面板仍用统一的大圆角。
    var cornerRadius: CGFloat = Theme.cornerRadius

    var body: some View {
        ZStack {
            if style == .material {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
            }
            LinearGradient(
                colors: [Color(hex: 0x12161C, opacity: 0.62), Color(hex: 0x0A0D12, opacity: 0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [Color.white.opacity(0.10), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
        )
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
    }
}
