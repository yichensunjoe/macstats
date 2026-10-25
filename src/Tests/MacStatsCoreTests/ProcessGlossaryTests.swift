import XCTest
@testable import MacStatsCore

final class ProcessGlossaryTests: XCTestCase {
    func testKnownRuntimeIsExplainedInPlainWords() {
        let node = ProcessGlossary.explain(name: "node", path: "/opt/homebrew/bin/node")
        XCTAssertTrue(node.summary.contains("Node.js"))
        XCTAssertTrue(node.impact.contains("重新"))

        let python = ProcessGlossary.explain(name: "python3", path: "/opt/homebrew/bin/python3")
        XCTAssertTrue(python.summary.contains("Python"))
    }

    /// argv[0] 自报的名字优先：同一个 node 二进制，叫 mcp 就是 AI 工具的后台服务。
    func testRenamedTitleWinsOverExecutable() {
        let mcp = ProcessGlossary.explain(name: "node", title: "github-mcp-server")
        XCTAssertTrue(mcp.summary.contains("MCP"))

        let devServer = ProcessGlossary.explain(name: "node", title: "npm run dev")
        XCTAssertTrue(devServer.summary.contains("开发服务器"))

        let preview = ProcessGlossary.explain(name: "node", title: "npm run preview --host 127.0.0.1 --port 4173")
        XCTAssertTrue(preview.summary.contains("预览"))
    }

    func testBuildToolsAreRecognized() {
        XCTAssertTrue(ProcessGlossary.explain(name: "esbuild").summary.contains("打包"))
        XCTAssertTrue(ProcessGlossary.explain(name: "uv").summary.contains("Python"))
        XCTAssertTrue(ProcessGlossary.explain(name: "bash").summary.contains("命令解释器"))
    }

    /// 名字认不出时按路径说个大概，但要注明来源，而不是瞎猜用途。
    func testPathHeuristics() {
        let brew = ProcessGlossary.explain(name: "wtf", path: "/opt/homebrew/bin/wtf")
        XCTAssertTrue(brew.summary.contains("Homebrew"))

        let nodeModules = ProcessGlossary.explain(name: "wtf", path: "/Users/me/app/node_modules/.bin/wtf")
        XCTAssertTrue(nodeModules.summary.contains("Node.js"))
    }

    /// 完全认不出来的，也必须给姓名、说明它没有窗口，并明确「结束不影响系统」。
    func testUnknownProcessGetsHonestFallback() {
        let unknown = ProcessGlossary.explain(name: "mystery", title: "mystery-daemon", path: "/Users/me/bin/mystery")
        XCTAssertTrue(unknown.summary.contains("mystery-daemon"))
        XCTAssertTrue(unknown.summary.contains("后台命令"))
        XCTAssertTrue(unknown.impact.contains("不受影响"))
        XCTAssertFalse(unknown.summary.isEmpty)
    }

    func testDisplayNamePrefersRenamedTitle() {
        XCTAssertEqual(ProcessGlossary.displayName(name: "node", title: "cliguard-daemon"), "cliguard-daemon")
        XCTAssertEqual(ProcessGlossary.displayName(name: "node", title: "node"), "node")
        XCTAssertEqual(ProcessGlossary.displayName(name: "node", title: ""), "node")
    }
}
