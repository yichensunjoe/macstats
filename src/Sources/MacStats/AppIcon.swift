import AppKit

/// 打包后图标随 `CFBundleIconFile` 放在 Contents/Resources；
/// `swift run` 没有 app 包，读不到就回落到关于页的矢量占位图。
enum AppIcon {
    static let image: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MacStats", withExtension: "icns") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()
}
