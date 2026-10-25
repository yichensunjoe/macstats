// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacStats",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "macstats", targets: ["MacStats"]),
        .executable(name: "macstatsDiag", targets: ["MacStatsDiag"]),
        // 系统「小组件库」里的扩展：打包时作为 MacStatsWidget.appex 塞进 app 的 PlugIns。
        .executable(name: "MacStatsWidget", targets: ["MacStatsWidget"]),
        .library(name: "MacStatsCore", targets: ["MacStatsCore"])
    ],
    targets: [
        .target(name: "MacStatsCore", path: "Sources/MacStatsCore"),
        .executableTarget(name: "MacStats", dependencies: ["MacStatsCore"], path: "Sources/MacStats"),
        .executableTarget(name: "MacStatsDiag", dependencies: ["MacStatsCore"], path: "Sources/MacStatsDiag"),
        // 扩展必须用 _NSExtensionMain 作为入口（Xcode 的 LD_ENTRY_POINT 默认值）。
        // 用 SwiftPM 默认入口时，进程能启动、也能打印 WidgetBundle，但不会建立宿主
        // XPC 会话，chronod 会在 ~15ms 后以 "connection to service with pid -1" 判死。
        .executableTarget(
            name: "MacStatsWidget",
            dependencies: ["MacStatsCore"],
            path: "Sources/MacStatsWidget",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"], .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(name: "MacStatsCoreTests", dependencies: ["MacStatsCore"], path: "Tests/MacStatsCoreTests")
    ]
)
