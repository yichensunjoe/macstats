import XCTest
@testable import MacStatsCore

final class LayoutTests: XCTestCase {
    /// 每档预设尺寸必须解析回同一档，否则「添加小组件」加出来的不是想要的样子。
    func testPresetSizesRoundTripToTheirLayout() {
        for layout in WidgetLayout.allCases {
            XCTAssertEqual(
                WidgetLayout.resolve(layout.presetSize), layout,
                "\(layout.displayName) 预设 \(layout.presetSize) 解析成了别的版式"
            )
        }
    }

    func testSmallSizesCollapseToMicro() {
        XCTAssertEqual(WidgetLayout.resolve(WidgetLayout.minimumSize), .micro)
        XCTAssertEqual(WidgetLayout.resolve(CGSize(width: 320, height: 120)), .micro)
        XCTAssertEqual(WidgetLayout.resolve(CGSize(width: 280, height: 400)), .micro)
    }

    func testMediumHeightsUseCompact() {
        XCTAssertEqual(WidgetLayout.resolve(CGSize(width: 340, height: 200)), .compact)
        XCTAssertEqual(WidgetLayout.resolve(CGSize(width: 372, height: 300)), .compact)
        // 拉宽但不拉高时仍是紧凑档，避免把卡片压扁。
        XCTAssertEqual(WidgetLayout.resolve(CGSize(width: 700, height: 240)), .compact)
    }

    func testWideTallWindowUsesExpanded() {
        XCTAssertEqual(WidgetLayout.resolve(CGSize(width: 600, height: 400)), .expanded)
        XCTAssertEqual(WidgetLayout.resolve(CGSize(width: 540, height: 380)), .expanded)
        // 够宽但不够高时退回标准档，否则第三列会很矮。
        XCTAssertEqual(WidgetLayout.resolve(CGSize(width: 700, height: 340)), .standard)
    }

    func testTileComposition() {
        XCTAssertTrue(WidgetLayout.micro.tiles.isEmpty)
        XCTAssertEqual(WidgetLayout.compact.tiles, [.cpu, .memory])
        XCTAssertEqual(WidgetLayout.standard.tiles.count, 7)
        XCTAssertTrue(WidgetLayout.standard.tiles.contains(.gpu))
        XCTAssertTrue(WidgetLayout.expanded.tiles.contains(.gpu))
        XCTAssertEqual(WidgetLayout.standard.columns, 2)
        XCTAssertEqual(WidgetLayout.expanded.columns, 3)
        XCTAssertEqual(WidgetLayout.expanded.processRows, 5)
        XCTAssertFalse(WidgetLayout.compact.showsPerCore)
        XCTAssertTrue(WidgetLayout.standard.showsPerCore)
    }

    /// 极简条与标准面板互相切换；其它版式先收成条。
    func testStripAndStandardToggleIntoEachOther() {
        XCTAssertEqual(WidgetLayout.toggled(.micro), .standard)
        XCTAssertEqual(WidgetLayout.toggled(.standard), .micro)
        XCTAssertEqual(WidgetLayout.toggled(.compact), .micro)
        XCTAssertEqual(WidgetLayout.toggled(.expanded), .micro)
    }

    /// 极简条固定六格（CPU / 内存 / GPU / 能耗 / 磁盘 / 网络），默认尺寸要能一行排开。
    func testStripPresetFitsAllSixNumbers() {
        XCTAssertGreaterThanOrEqual(WidgetLayout.micro.presetSize.width, 420)
        XCTAssertEqual(WidgetLayout.resolve(WidgetLayout.micro.presetSize), .micro)
    }

    /// 极简条的留白与圆角随宽度收放：窄条收紧、宽条放松，且始终限在舒适区间内。
    func testStripStyleAdaptsToWidth() {
        let narrow = MicroStripStyle.resolve(WidgetLayout.minimumSize)
        let preset = MicroStripStyle.resolve(WidgetLayout.micro.presetSize)
        let wide = MicroStripStyle.resolve(CGSize(width: 900, height: 80))

        XCTAssertLessThan(narrow.horizontalPadding, preset.horizontalPadding)
        XCTAssertLessThan(preset.horizontalPadding, wide.horizontalPadding)
        XCTAssertLessThan(narrow.separatorSpacing, preset.separatorSpacing)
        XCTAssertLessThan(narrow.cornerRadius, preset.cornerRadius)
        XCTAssertGreaterThanOrEqual(narrow.cornerRadius, 11)
        XCTAssertLessThanOrEqual(wide.cornerRadius, 26)
    }

    /// 留白不能吃掉内容，圆角不能超过短边的一半，分隔线也不能比面板还高。
    func testStripStyleStaysInsidePanel() {
        let sizes = [
            WidgetLayout.minimumSize,
            CGSize(width: 287, height: 157),
            CGSize(width: 372, height: 80),
            WidgetLayout.micro.presetSize,
            CGSize(width: 900, height: 80)
        ]
        for size in sizes {
            let style = MicroStripStyle.resolve(size)
            XCTAssertLessThan(style.horizontalPadding * 2, size.width, "\(size) 横向留白越界")
            XCTAssertLessThan(style.verticalPadding * 2, size.height, "\(size) 竖向留白越界")
            XCTAssertLessThanOrEqual(style.cornerRadius, min(size.width, size.height) / 2)
            XCTAssertLessThan(style.separatorHeight, size.height)
        }
    }

    /// 矮条收紧竖向留白、行距也更小；两行三列时放松，免得两行贴在一起。
    func testStripStyleTrimsPaddingForShortBars() {
        let short = MicroStripStyle.resolve(CGSize(width: 372, height: 76))
        let tall = MicroStripStyle.resolve(CGSize(width: 372, height: 157))
        XCTAssertLessThan(short.verticalPadding, tall.verticalPadding)
        XCTAssertLessThan(short.rowSpacing, tall.rowSpacing)
    }

    func testPresetSizeIsClampedToScreen() {
        let cramped = CGRect(x: 0, y: 0, width: 300, height: 200)
        let size = WidgetLayout.expanded.clamped(to: cramped)
        XCTAssertLessThanOrEqual(size.width, 276)
        XCTAssertLessThanOrEqual(size.height, 176)
        XCTAssertGreaterThanOrEqual(size.width, WidgetLayout.minimumSize.width)
    }
}
