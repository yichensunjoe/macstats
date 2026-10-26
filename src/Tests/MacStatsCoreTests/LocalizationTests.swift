import XCTest
@testable import MacStatsCore

final class LocalizationTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        L10n.shared.setLanguage(.system)
    }

    func testLanguageResolution() {
        L10n.shared.setLanguage(.zhHans)
        XCTAssertEqual(L10n.shared.resolvedLanguage, .zhHans)
        XCTAssertEqual(L10n.t(.settings), "设置")

        L10n.shared.setLanguage(.en)
        XCTAssertEqual(L10n.shared.resolvedLanguage, .en)
        XCTAssertEqual(L10n.t(.settings), "Settings")
    }

    func testAllKeysHaveTranslationsInBothLanguages() {
        for lang in [ResolvedLanguage.zhHans, ResolvedLanguage.en] {
            L10n.shared.setLanguage(lang == .zhHans ? .zhHans : .en)
            for key in L10nKey.allCases {
                let text = L10n.t(key)
                XCTAssertFalse(text.isEmpty, "Language \(lang) missing translation for key \(key)")
            }
        }
    }

    func testFormatStrings() {
        L10n.shared.setLanguage(.zhHans)
        XCTAssertEqual(L10n.format(.uptime, "2小时"), "已运行 2小时")
        XCTAssertEqual(L10n.format(.totalAmount, "16 GB"), "共 16 GB")
        XCTAssertEqual(L10n.format(.cleanupSuccess, 4), "成功终止 4 个进程")
        XCTAssertEqual(L10n.format(.protectedCount, 2), "2 项已保护")

        L10n.shared.setLanguage(.en)
        XCTAssertEqual(L10n.format(.uptime, "2 hrs"), "Uptime 2 hrs")
        XCTAssertEqual(L10n.format(.totalAmount, "16 GB"), "Total 16 GB")
        XCTAssertEqual(L10n.format(.cleanupSuccess, 4), "Successfully terminated 4 processes")
        XCTAssertEqual(L10n.format(.protectedCount, 2), "2 protected")
    }

    func testLocalizedLayoutNames() {
        L10n.shared.setLanguage(.zhHans)
        XCTAssertEqual(WidgetLayout.micro.localizedName, "极简条")
        XCTAssertEqual(WidgetLayout.compact.localizedName, "紧凑面板")
        XCTAssertEqual(WidgetLayout.standard.localizedName, "标准面板")
        XCTAssertEqual(WidgetLayout.expanded.localizedName, "详细面板")

        L10n.shared.setLanguage(.en)
        XCTAssertEqual(WidgetLayout.micro.localizedName, "Micro Bar")
        XCTAssertEqual(WidgetLayout.compact.localizedName, "Compact Panel")
        XCTAssertEqual(WidgetLayout.standard.localizedName, "Standard Panel")
        XCTAssertEqual(WidgetLayout.expanded.localizedName, "Expanded Panel")

        // Unlocalized displayName remains intact for backwards compatibility
        XCTAssertEqual(WidgetLayout.micro.displayName, "极简")
    }

    func testBilingualProcessGlossary() {
        let zhExplanation = ProcessGlossary.explain(name: "node", language: .zhHans)
        XCTAssertTrue(zhExplanation.summary.contains("Node.js"))
        XCTAssertTrue(zhExplanation.impact.contains("开发服务") || zhExplanation.impact.contains("前端"))

        let enExplanation = ProcessGlossary.explain(name: "node", language: .en)
        XCTAssertTrue(enExplanation.summary.contains("Node.js"))
        XCTAssertTrue(enExplanation.impact.contains("development server") || enExplanation.impact.contains("plugin"))

        let unknownZh = ProcessGlossary.explain(name: "nonexistent_daemon_xyz", language: .zhHans)
        XCTAssertTrue(unknownZh.summary.contains("nonexistent_daemon_xyz"))
        XCTAssertTrue(unknownZh.impact.contains("系统本身不受影响"))

        let unknownEn = ProcessGlossary.explain(name: "nonexistent_daemon_xyz", language: .en)
        XCTAssertTrue(unknownEn.summary.contains("nonexistent_daemon_xyz"))
        XCTAssertTrue(unknownEn.impact.contains("Core macOS system services are unaffected"))

        // Path heuristics parity across languages
        let pyenvZh = ProcessGlossary.explain(name: "custom_worker", path: "/Users/me/.pyenv/versions/3.11/bin/custom_worker", language: .zhHans)
        XCTAssertTrue(pyenvZh.summary.contains("Python"))
        let pyenvEn = ProcessGlossary.explain(name: "custom_worker", path: "/Users/me/.pyenv/versions/3.11/bin/custom_worker", language: .en)
        XCTAssertTrue(pyenvEn.summary.contains("Python"))

        let nvmZh = ProcessGlossary.explain(name: "custom_tool", path: "/Users/me/.nvm/versions/node/v20/bin/custom_tool", language: .zhHans)
        XCTAssertTrue(nvmZh.summary.contains("Node"))
        let nvmEn = ProcessGlossary.explain(name: "custom_tool", path: "/Users/me/.nvm/versions/node/v20/bin/custom_tool", language: .en)
        XCTAssertTrue(nvmEn.summary.contains("Node"))

        // Newly aligned tools present in both languages
        let tools = ["cargo", "rustc", "clang", "swift", "pip", "conda", "brew", "redis-server", "tailscale"]
        for tool in tools {
            let zh = ProcessGlossary.explain(name: tool, language: .zhHans)
            XCTAssertFalse(zh.summary.isEmpty, "Missing Chinese glossary summary for \(tool)")
            XCTAssertFalse(zh.impact.isEmpty, "Missing Chinese glossary impact for \(tool)")

            let en = ProcessGlossary.explain(name: tool, language: .en)
            XCTAssertFalse(en.summary.isEmpty, "Missing English glossary summary for \(tool)")
            XCTAssertFalse(en.impact.isEmpty, "Missing English glossary impact for \(tool)")
        }
    }

    func testNewFormatKeys() {
        L10n.shared.setLanguage(.zhHans)
        XCTAssertEqual(L10n.format(.confirmCleanupTitle, 3), "清理 3 个后台闲置进程？")
        XCTAssertEqual(L10n.format(.confirmCleanupSubtitle, "50 MB"), "这些进程终止前的内存合计约 50 MB。只会请它们正常退出，不会强制结束。")
        XCTAssertEqual(L10n.format(.resultTerminatedOnly, 5), "已清理 5 个进程")
        XCTAssertEqual(L10n.format(.resultTerminatedAndRunning, 5, 2), "已清理 5 个，2 个仍在运行")
        XCTAssertEqual(L10n.format(.nothingToCleanScannedSummary, 100, 95), "这次扫了 100 个进程，95 个按上面的规则排除了。")
        XCTAssertEqual(L10n.format(.statusToolTip, "12%", "45%", "8.5 W"), "CPU 12% · 内存 45% · 能耗 8.5 W")

        L10n.shared.setLanguage(.en)
        XCTAssertEqual(L10n.format(.confirmCleanupTitle, 3), "Terminate 3 idle processes?")
        XCTAssertEqual(L10n.format(.confirmCleanupSubtitle, "50 MB"), "Their reported footprint is about 50 MB. Sends SIGTERM for graceful exit.")
        XCTAssertEqual(L10n.format(.resultTerminatedOnly, 5), "Terminated 5 processes")
        XCTAssertEqual(L10n.format(.resultTerminatedAndRunning, 5, 2), "Terminated 5, 2 still running")
        XCTAssertEqual(L10n.format(.nothingToCleanScannedSummary, 100, 95), "Scanned 100 processes; 95 excluded by safety rules.")
        XCTAssertEqual(L10n.format(.statusToolTip, "12%", "45%", "8.5 W"), "CPU 12% · Memory 45% · Energy 8.5 W")
    }

    /// B6a：清理相关界面不再承诺「已释放」内存。
    /// `CleanupResult.freedBytes` 只是候选进程终止前的 RSS 合计，不是系统实际回收量；
    /// 文案必须说清楚，否则活动监视器数字对不上会毁掉整块面板的可信度。
    /// E §6 验收门要求「清理：确认框文案不含「释放」」，所以确认框副标题也纳入断言。
    func testCleanupResultCopyDoesNotPromiseFreedMemory() {
        // key 仍在，且中英都有非空文案（只改文案值，不改 key 名）。
        for key in [L10nKey.resultFreedBytes, L10nKey.confirmCleanupSubtitle] {
            XCTAssertTrue(L10nKey.allCases.contains(key))
            for lang in [ResolvedLanguage.zhHans, ResolvedLanguage.en] {
                let template = L10n.string(key, lang: lang)
                XCTAssertFalse(template.isEmpty, "Missing \(key) for \(lang)")
            }
        }

        // 清理确认框与结果框用到的全部 key 都不出现「释放 / freed」。
        let cleanupCopyKeys: [L10nKey] = [
            .confirmCleanupTitle,
            .confirmCleanupSubtitle,
            .confirmCleanupNote,
            .cleanupResult,
            .resultTerminatedOnly,
            .resultTerminatedAndRunning,
            .resultFreedBytes,
            .resultSurvivedNote,
            .cleanupTerminated,
            .cleanupStillRunning,
            .done
        ]
        for lang in [ResolvedLanguage.zhHans, ResolvedLanguage.en] {
            L10n.shared.setLanguage(lang == .zhHans ? .zhHans : .en)
            for key in cleanupCopyKeys {
                let text = L10n.string(key, lang: lang)
                XCTAssertFalse(text.contains("释放"), "\(lang) 清理文案 \(key) 仍出现「释放」：\(text)")
                XCTAssertFalse(text.lowercased().contains("freed"), "\(lang) cleanup copy \(key) still says freed: \(text)")
            }
        }

        L10n.shared.setLanguage(.zhHans)
        XCTAssertEqual(
            L10n.format(.resultFreedBytes, "1.2 GB"),
            "这些进程终止前的内存合计为 1.2 GB；系统实际回收量可能不同。"
        )
        // 确认框副标题只报 RSS 合计，不再承诺释放量。
        XCTAssertEqual(
            L10n.format(.confirmCleanupSubtitle, "1.2 GB"),
            "这些进程终止前的内存合计约 1.2 GB。只会请它们正常退出，不会强制结束。"
        )
        // 结果框标题保持「已清理 N 个进程」。
        XCTAssertEqual(L10n.format(.resultTerminatedOnly, 5), "已清理 5 个进程")

        L10n.shared.setLanguage(.en)
        XCTAssertEqual(
            L10n.format(.resultFreedBytes, "1.2 GB"),
            "Their reported footprint was 1.2 GB; actual reclaim may differ."
        )
        XCTAssertEqual(
            L10n.format(.confirmCleanupSubtitle, "1.2 GB"),
            "Their reported footprint is about 1.2 GB. Sends SIGTERM for graceful exit."
        )
        XCTAssertEqual(L10n.format(.resultTerminatedOnly, 5), "Terminated 5 processes")
    }

    func testAppAppearanceAndAccentTintColor() {
        XCTAssertEqual(AppAppearance.allCases.count, 3)
        XCTAssertEqual(AccentTintColor.allCases.count, 2)

        L10n.shared.setLanguage(.zhHans)
        XCTAssertEqual(AppAppearance.system.displayName, "跟随系统")
        XCTAssertEqual(AppAppearance.dark.displayName, "深色模式")
        XCTAssertEqual(AppAppearance.light.displayName, "浅色模式")
        XCTAssertEqual(AccentTintColor.vibrant.displayName, "经典多彩")
        XCTAssertEqual(AccentTintColor.monochrome.displayName, "极简浅灰")

        L10n.shared.setLanguage(.en)
        XCTAssertEqual(AppAppearance.system.displayName, "Follow System")
        XCTAssertEqual(AppAppearance.dark.displayName, "Dark Mode")
        XCTAssertEqual(AppAppearance.light.displayName, "Light Mode")
        XCTAssertEqual(AccentTintColor.vibrant.displayName, "Vibrant Multi-color")
        XCTAssertEqual(AccentTintColor.monochrome.displayName, "Monochrome Slate")
    }

    func testCleanupSkipReasonLocalization() {
        for lang in [ResolvedLanguage.zhHans, ResolvedLanguage.en] {
            L10n.shared.setLanguage(lang == .zhHans ? .zhHans : .en)
            for reason in CleanupSkipReason.allCases {
                XCTAssertFalse(reason.localizedName.isEmpty, "Missing localized name for skip reason \(reason) in \(lang)")
            }
        }
    }
}
