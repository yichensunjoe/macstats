import SwiftUI

/// 小组件配色，与悬浮面板保持同一套色相。
enum Palette {
    static let cpu = Color(hex: 0x5B9BFF)
    static let memory = Color(hex: 0x3EDC81)
    static let energy = Color(hex: 0xFFB13B)
    static let disk = Color(hex: 0xC089FF)
    static let network = Color(hex: 0x35D6C8)
    static let gpu = Color(hex: 0xFF7AB6)

    static let primary = Color.white.opacity(0.95)
    static let secondary = Color.white.opacity(0.55)
    static let tertiary = Color.white.opacity(0.38)
    static let track = Color.white.opacity(0.14)

    /// 部件底板：系统会给它套上圆角与间距，所以这里只负责填充。
    static let backdrop = LinearGradient(
        colors: [Color(hex: 0x11151A), Color(hex: 0x0A0C10)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
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
