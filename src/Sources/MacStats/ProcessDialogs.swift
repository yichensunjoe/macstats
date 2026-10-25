import AppKit
import SwiftUI
import MacStatsCore

/// 清理相关的提示界面。用自定义窗口代替 `NSAlert`：
/// 每个进程都带「这是什么 / 结束它会怎样」，按钮和排版也和面板一致。
@MainActor
enum ProcessDialogs {
    static func confirm(_ plan: CleanupPlan) -> Bool {
        // 名单短时不留空白：一行按 84 点算，超过 470 才改为列表滚动。
        let height = min(470, 146 + CGFloat(plan.candidates.count) * 84)
        return present(ConfirmCleanupView(plan: plan), size: CGSize(width: 560, height: height), title: L10n.t(.cleanIdleProcesses)) == .OK
    }

    static func showResult(_ result: CleanupResult) {
        // 结果条数少时不留大片空白：按行数收高度，最多到 360。
        let rows = result.terminated.count + result.survived.count
        let height = min(360, max(210, 166 + CGFloat(rows) * 30 + (result.survived.isEmpty ? 0 : 40)))
        _ = present(ResultCleanupView(result: result), size: CGSize(width: 520, height: height), title: L10n.t(.cleanupResult))
    }

    static func showNothingToClean(scanned: Int, skipped: [CleanupSkipReason: Int]) {
        _ = present(NothingToCleanView(scanned: scanned, skipped: skipped), size: CGSize(width: 480, height: 286), title: L10n.t(.cleanIdleProcesses))
    }

    static func showMessage(title: String, message: String, details: String? = nil, isSuccess: Bool = true) {
        _ = present(
            MessageView(title: title, message: message, details: details, isSuccess: isSuccess),
            size: CGSize(width: 480, height: details == nil ? 190 : 280),
            title: title
        )
    }

    static func showError(title: String, message: String, details: String? = nil) {
        showMessage(title: title, message: message, details: details, isSuccess: false)
    }

    private static func present<V: View>(_ view: V, size: CGSize, title: String) -> NSApplication.ModalResponse {
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = []

        let screenHeight = NSScreen.main?.visibleFrame.height ?? 900
        let fitted = CGSize(width: size.width, height: min(size.height, max(160, screenHeight - 80)))

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: fitted),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = title
        window.styleMask = [.titled, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.setContentSize(fitted)
        window.center()
        NSApp.activate()
        // 进模态循环后再钉一次，免得宿主首帧排版把窗口改形。
        DispatchQueue.main.async {
            guard window.isVisible else { return }
            window.setContentSize(fitted)
        }
        defer { window.orderOut(nil) }
        return NSApp.runModal(for: window)
    }
}

// MARK: - 确认

private struct ConfirmCleanupView: View {
    let plan: CleanupPlan

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(plan.candidates) { candidate in
                        CandidateRow(candidate: candidate)
                        if candidate.id != plan.candidates.last?.id {
                            Divider().padding(.leading, 18)
                        }
                    }
                }
            }
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .onExitCommand { NSApp.stopModal(withCode: .cancel) }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.red)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.format(.confirmCleanupTitle, plan.candidates.count))
                    .font(.system(size: 16, weight: .semibold))
                Text(L10n.format(.confirmCleanupSubtitle, ByteFormat.memory(plan.estimatedBytes)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(L10n.t(.confirmCleanupNote))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button(L10n.t(.cancel)) { NSApp.stopModal(withCode: .cancel) }
                .keyboardShortcut(.cancelAction)
            Button(L10n.t(.cleanupNow)) { NSApp.stopModal(withCode: .OK) }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
        .padding(16)
    }
}

private struct CandidateRow: View {
    let candidate: CleanupCandidate

    private var explanation: ProcessExplanation {
        ProcessGlossary.explain(name: candidate.name, title: candidate.title, path: candidate.path, language: L10n.shared.resolvedLanguage)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(candidate.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("PID \(candidate.pid)")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                Text(explanation.summary)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.t(.candidateImpactPrefix) + explanation.impact)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(ByteFormat.processMemory(candidate.memoryBytes))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                Text(L10n.t(.candidateIdlePrefix) + DurationFormat.uptime(candidate.idleSeconds))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }
}

// MARK: - 结果

private struct ResultCleanupView: View {
    let result: CleanupResult

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 16, weight: .semibold))
                    Text(L10n.format(.resultFreedBytes, ByteFormat.memory(result.freedBytes)))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(18)

            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(result.terminated) { candidate in
                        row(candidate, symbol: "checkmark", tint: .green, note: L10n.t(.cleanupTerminated))
                    }
                    ForEach(result.survived) { candidate in
                        row(candidate, symbol: "exclamationmark.triangle.fill", tint: .orange, note: L10n.t(.cleanupStillRunning))
                    }
                }
            }
            Divider()

            HStack {
                if !result.survived.isEmpty {
                    Text(L10n.t(.resultSurvivedNote))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(L10n.t(.done)) { NSApp.stopModal(withCode: .OK) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private var title: String {
        result.survived.isEmpty
            ? L10n.format(.resultTerminatedOnly, result.terminated.count)
            : L10n.format(.resultTerminatedAndRunning, result.terminated.count, result.survived.count)
    }

    private func row(_ candidate: CleanupCandidate, symbol: String, tint: Color, note: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            Text(candidate.displayName)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Text(note)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
    }
}

// MARK: - 没有可清理的进程

private struct NothingToCleanView: View {
    let scanned: Int
    let skipped: [CleanupSkipReason: Int]

    private var skippedTotal: Int { skipped.values.reduce(0, +) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t(.nothingToClean))
                        .font(.system(size: 16, weight: .semibold))
                    Text(L10n.t(.nothingToCleanDesc))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(18)

            Divider()

            VStack(alignment: .leading, spacing: 9) {
                bullet(L10n.t(.nothingToCleanRule1))
                bullet(L10n.t(.nothingToCleanRule2))
                bullet(L10n.t(.nothingToCleanRule3))
                bullet(L10n.t(.nothingToCleanRule4))
                if scanned > 0 {
                    Text(L10n.format(.nothingToCleanScannedSummary, scanned, skippedTotal))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
            Divider()
            HStack {
                Spacer()
                Button(L10n.t(.ok)) { NSApp.stopModal(withCode: .OK) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 通用提示

private struct MessageView: View {
    let title: String
    let message: String
    let details: String?
    var isSuccess: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSuccess ? "checkmark.seal.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(isSuccess ? .green : .orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 15, weight: .semibold))
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(18)

            if let details {
                Divider()
                ScrollView {
                    Text(details)
                        .font(.system(size: 10).monospaced())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
            }

            Spacer(minLength: 0)
            Divider()
            HStack {
                Spacer()
                Button(L10n.t(.ok)) { NSApp.stopModal(withCode: .OK) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
