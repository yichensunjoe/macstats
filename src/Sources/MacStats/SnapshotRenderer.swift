import AppKit
import SwiftUI
import MacStatsCore

/// 把小组件离屏渲染成 PNG。用于在没有窗口的环境里检查排版，也让 CI/人工核对同一份视图。
@MainActor
enum SnapshotRenderer {
    static func render(
        to path: String,
        layout: WidgetLayout = .standard,
        size: CGSize? = nil,
        samples: Int = 24,
        gap: TimeInterval = 0.2
    ) {
        // 离屏渲染的采样间隔只有 0.2 秒，节流会让能耗与进程停在首帧，因此关掉。
        let sampler = SystemSampler(config: SamplerConfig(processLimit: 24, processInterval: 0))
        var data = WidgetData()
        var cpuUser = MetricRing(capacity: 5)
        var cpuSystem = MetricRing(capacity: 5)
        _ = sampler.sample()
        for _ in 0..<max(2, samples) {
            Thread.sleep(forTimeInterval: gap)
            let snapshot = sampler.sample()
            data.cpu.append(snapshot.cpu.total)
            if let gpu = snapshot.gpu {
                data.gpu.append(gpu.utilization)
            }
            data.energy.append(snapshot.energy.watts ?? 0)
            data.diskRead.append(snapshot.disk.readBytesPerSecond)
            data.diskWrite.append(snapshot.disk.writeBytesPerSecond)
            data.networkIn.append(snapshot.network.bytesInPerSecond)
            data.networkOut.append(snapshot.network.bytesOutPerSecond)
            cpuUser.append(snapshot.cpu.user)
            cpuSystem.append(snapshot.cpu.system)
            // 与运行中的面板一致：速率类指标取 5 个采样的滑动平均。
            data.snapshot = snapshot.applying(WindowAverages(
                cpuTotal: data.cpu.mean(last: 5) ?? snapshot.cpu.total,
                cpuUser: cpuUser.mean(last: 5) ?? snapshot.cpu.user,
                cpuSystem: cpuSystem.mean(last: 5) ?? snapshot.cpu.system,
                energyWatts: data.energy.mean(last: 5) ?? 0,
                diskRead: data.diskRead.mean(last: 5) ?? 0,
                diskWrite: data.diskWrite.mean(last: 5) ?? 0,
                networkIn: data.networkIn.mean(last: 5) ?? 0,
                networkOut: data.networkOut.mean(last: 5) ?? 0,
                sampleCount: data.cpu.values.count
            ))
        }

        // 视图按实际尺寸选版式，离屏渲染必须给一个明确尺寸。
        // 显式传入尺寸时可渲染非预设宽度（例如检查极简条最窄时六格是否排得下）。
        let size = size ?? layout.presetSize
        let view = WidgetView(data: data, surface: .solid)
            .frame(width: size.width, height: size.height)
            .padding(30)
            .background(Color(hex: 0x3A4048))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage else {
            FileHandle.standardError.write(Data("snapshot: ImageRenderer 失败\n".utf8))
            exit(1)
        }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("snapshot: PNG 编码失败\n".utf8))
            exit(1)
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            print("snapshot: \(path) (\(image.width)x\(image.height))")
        } catch {
            FileHandle.standardError.write(Data("snapshot: 写入失败 \(error)\n".utf8))
            exit(1)
        }
    }
}
