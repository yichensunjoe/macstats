import Foundation

/// 给普通人看的进程说明：它是什么、结束它会怎样。
///
/// 只根据可执行名、`argv[0]`（列表里显示的名字）和路径判断，不执行任何东西。
/// 认不出来就老实说「一个后台命令」，不编造用途。
public struct ProcessExplanation: Sendable, Equatable {
    /// 这是什么（一两句，电脑小白也能懂）。
    public var summary: String
    /// 结束它会影响什么。
    public var impact: String

    public init(summary: String, impact: String) {
        self.summary = summary
        self.impact = impact
    }
}

public enum ProcessGlossary {
    /// 常见后台进程的说明表（键是可执行名，忽略大小写）。
    /// 只在「名字对得上」时命中；改名跑守护进程的（`argv[0]`）先走下面的模式匹配。
    private static let byName: [String: (String, String)] = [
        "node": (
            "用 Node.js 跑的后台程序。很多网页开发工具、AI 插件的后台服务都由它启动，它自己没有窗口。",
            "正在用它的开发服务器或插件会停掉；重新打开对应工具就会再启动。"
        ),
        "npm": (
            "Node.js 的包管理器，正在替某个项目安装依赖或执行脚本。",
            "正在安装或启动的项目会中断，重新执行那条命令即可。"
        ),
        "npx": (
            "临时运行一个 Node.js 小工具的启动器。",
            "那个小工具会停下来，下次需要时重新运行即可。"
        ),
        "pnpm": (
            "Node.js 的包管理器（pnpm），正在安装依赖或运行项目脚本。",
            "正在安装或启动的项目会中断，重新执行那条命令即可。"
        ),
        "yarn": (
            "Node.js 的包管理器（Yarn），正在安装依赖或运行项目脚本。",
            "正在安装或启动的项目会中断，重新执行那条命令即可。"
        ),
        "bun": (
            "Bun 运行时，正在跑某个 JavaScript/TypeScript 程序。",
            "正在跑的程序会停止，重新运行即可。"
        ),
        "deno": (
            "Deno 运行时，正在跑某个 JavaScript/TypeScript 程序。",
            "正在跑的程序会停止，重新运行即可。"
        ),
        "python": (
            "用 Python 写的后台程序。常见于数据处理、AI 模型服务、自动化脚本。",
            "正在用它的脚本或服务会停止；重新运行那个脚本即可。"
        ),
        "python3": (
            "用 Python 3 写的后台程序。常见于数据处理、AI 模型服务、自动化脚本。",
            "正在用它的脚本或服务会停止；重新运行那个脚本即可。"
        ),
        "uv": (
            "Python 的包管理与运行工具，正在后台准备环境或执行某个 Python 程序。",
            "正在准备的环境或程序会中断，重新执行那条命令即可。"
        ),
        "pip": (
            "Python 的包安装工具，正在安装或更新依赖。",
            "安装会中断，重新执行安装命令即可。"
        ),
        "conda": (
            "Python 环境管理器，正在安装包或切换环境。",
            "这次环境操作会中断，重新执行即可。"
        ),
        "esbuild": (
            "前端打包工具，把网页源码快速打包成浏览器能读的文件。通常被别的开发命令临时调用。",
            "正在进行的打包会中断；重新启动那个开发命令即可。"
        ),
        "vite": (
            "前端开发服务器，负责本地预览网页并在改代码时自动刷新。",
            "本地网页会打不开，热更新停止；重新运行开发命令即可。"
        ),
        "webpack": (
            "前端打包工具，正在编译网页资源。",
            "编译会中断，重新启动构建即可。"
        ),
        "tsc": (
            "TypeScript 编译器，正在把 TypeScript 转成 JavaScript。",
            "这次编译会中断，重新编译即可。"
        ),
        "bash": (
            "终端里的命令解释器。这里多半是某个脚本或工具借它在后台执行命令。",
            "这条后台脚本会停止；一般不影响系统，重跑脚本即可。"
        ),
        "zsh": (
            "终端里的命令解释器（macOS 默认）。这里多半是某个脚本在后台借用它。",
            "这条后台脚本会停止；一般不影响系统，重跑脚本即可。"
        ),
        "sh": (
            "最简单的命令解释器，通常是安装脚本或工具在后台借用它。",
            "这条后台脚本会停止；一般不影响系统，重跑脚本即可。"
        ),
        "git": (
            "版本管理工具，正在后台做拉取、推送或检查仓库。",
            "这次同步会中断，重新执行即可；代码不会丢。"
        ),
        "curl": (
            "命令行下载/请求工具，正在后台访问某个网址。",
            "这次下载或请求会中断，重新执行即可。"
        ),
        "wget": (
            "命令行下载工具，正在后台下载文件。",
            "下载会中断，可以从断点重新下载。"
        ),
        "rsync": (
            "文件同步工具，正在后台复制或同步文件。",
            "这次同步会中断；已复制好的文件不受影响，重跑即可。"
        ),
        "ssh": (
            "远程连接工具，正在后台保持一条到别的机器的连接。",
            "这条远程连接会断开，重新连接即可。"
        ),
        "ffmpeg": (
            "音视频处理工具，正在转码或压缩媒体文件。",
            "正在处理的文件会中断，未完成的部分需要重做。"
        ),
        "docker": (
            "容器工具，正在后台管理虚拟化的运行环境。",
            "正在运行的容器会断开，需要重新启动 Docker 和容器。"
        ),
        "redis-server": (
            "Redis 缓存数据库，给本地程序提供快速读写。",
            "依赖它的程序会连不上缓存，重启 Redis 即可恢复。"
        ),
        "mysqld": (
            "MySQL 数据库服务。",
            "依赖它的本地程序会连不上数据库，重启服务即可。"
        ),
        "postgres": (
            "PostgreSQL 数据库服务。",
            "依赖它的本地程序会连不上数据库，重启服务即可。"
        ),
        "mongod": (
            "MongoDB 数据库服务。",
            "依赖它的本地程序会连不上数据库，重启服务即可。"
        ),
        "java": (
            "Java 程序运行时，正在跑某个 Java 应用或开发工具。",
            "那个 Java 程序会停止，重新启动即可。"
        ),
        "ollama": (
            "本地大模型服务，负责在你自己电脑上跑 AI 模型。",
            "本地模型的回答会中断，重新打开 Ollama 即可。"
        ),
        "cloudflared": (
            "Cloudflare 隧道工具，把本机服务临时暴露到外网。",
            "外部访问会立刻断开，隧道需要重新启动。"
        ),
        "ngrok": (
            "内网穿透工具，把本机服务临时暴露到外网。",
            "外部访问会立刻断开，需要重新启动隧道。"
        ),
        "tailscale": (
            "虚拟局域网工具，让几台设备像在同一网络里互相访问。",
            "设备之间的远程连接会断开，重新连接即可。"
        ),
        "brew": (
            "Homebrew 包管理器，正在安装或升级命令行工具。",
            "这次安装会中断，重新执行即可。"
        ),
        "cargo": (
            "Rust 构建与包管理工具，正在编译代码或管理依赖。",
            "正在进行的编译或下载会中断，重新执行命令即可。"
        ),
        "rustc": (
            "Rust 官方编译器，正在把 Rust 源码编译为二进制文件。",
            "编译会中断，重新编译即可。"
        ),
        "clang": (
            "C/C++ 语言编译器，正在编译 C/C++ 源码。",
            "编译会中断，重新编译即可。"
        ),
        "swift": (
            "Swift 语言编译器与构建工具链，正在编译项目。",
            "编译会中断，重新编译即可。"
        )
    ]

    public static func explain(
        name: String,
        title: String = "",
        path: String = "",
        language: ResolvedLanguage? = nil
    ) -> ProcessExplanation {
        let lang = language ?? L10n.shared.resolvedLanguage
        if lang == .en {
            return explainEn(name: name, title: title, path: path)
        } else {
            return explainZh(name: name, title: title, path: path)
        }
    }

    private static func explainZh(
        name: String,
        title: String,
        path: String
    ) -> ProcessExplanation {
        let raw = name.lowercased()
        // `python3.13` / `python3.11` 这类带小版本的名字归到 python3。
        let executable = raw.hasPrefix("python3.") ? "python3" : raw
        let display = displayName(name: name, title: title)
        let titleLower = title.lowercased()
        let pathLower = path.lowercased()

        // 1. 先看它自报的名字：开发服务器、MCP 服务这类只在 argv[0] 里看得出来。
        if titleLower.contains("webbridge") || titleLower.contains("browserbridge") {
            return ProcessExplanation(
                summary: "给 AI 工具当浏览器桥梁的后台服务，让 AI 能读取或操作你的浏览器。",
                impact: "AI 的网页操作能力会断开；重新打开那个 AI 工具即可。"
            )
        }
        if executable.contains("chatgpt") || titleLower.contains("chatgpt") {
            return ProcessExplanation(
                summary: "Chrome 浏览器里 ChatGPT 插件的后台部分，负责把网页内容和插件连起来。",
                impact: "浏览器里的 ChatGPT 插件会暂时失效；重开浏览器或插件即可恢复。"
            )
        }
        if titleLower.contains("mcp") {
            return ProcessExplanation(
                summary: "给 AI 助手/编辑器提供额外能力的后台服务（MCP 服务器），例如查 GitHub、读数据库、控制浏览器。",
                impact: "依赖它的 AI 助手会少一项工具能力；重新打开那个 AI 工具就会再启动。"
            )
        }
        if titleLower.hasPrefix("npm run dev") || titleLower.hasPrefix("pnpm dev") || titleLower.hasPrefix("yarn dev") {
            return ProcessExplanation(
                summary: "本地开发服务器：把某个网站或网页应用跑在你这台电脑上，改代码时会自动刷新。",
                impact: "本地网页会打不开、热更新停止；重新运行这条开发命令即可。"
            )
        }
        if titleLower.contains("preview") || titleLower.contains("serve") || titleLower.contains("--port") {
            return ProcessExplanation(
                summary: "本地预览/小型网站服务：把做好的网页或接口临时跑在本机，供浏览器访问。",
                impact: "本机的那个网页或接口会打不开；重新启动这条命令即可。"
            )
        }
        if titleLower.contains("uvicorn") || titleLower.contains("gunicorn") {
            return ProcessExplanation(
                summary: "Python 的网页服务，正在对外提供接口或页面。",
                impact: "调用这个服务的程序会连不上；重新启动服务即可。"
            )
        }
        if titleLower.contains("pytest") || titleLower.contains("jest") || titleLower.contains("vitest") {
            return ProcessExplanation(
                summary: "自动化测试，正在后台跑测试用例检查代码有没有问题。",
                impact: "这次测试会中断，重新跑测试即可；不会改动代码。"
            )
        }
        if titleLower.contains("jupyter") {
            return ProcessExplanation(
                summary: "Jupyter 笔记本服务，在浏览器里做数据分析用的。",
                impact: "正在运行的笔记本会断开，重新启动 Jupyter 即可。"
            )
        }

        // 2. 再看可执行名。
        if let entry = byName[executable] {
            return ProcessExplanation(summary: entry.0, impact: entry.1)
        }

        // 3. 名字认不出来时，用路径猜个大概，但说清楚是猜的。
        if pathLower.contains("/node_modules/") {
            return ProcessExplanation(
                summary: "某个 Node.js 项目的依赖在后台运行。项目里的工具（打包、测试、开发服务器）常这样启动。",
                impact: "依赖它的那个项目功能会停；重新运行项目的命令即可。"
            )
        }
        if pathLower.contains("/.nvm/") || pathLower.contains("/.volta/") {
            return ProcessExplanation(
                summary: "通过 Node 版本管理器安装的 Node.js 工具，在后台跑某个网页/脚本任务。",
                impact: "那个任务会停止；重新运行即可。"
            )
        }
        if pathLower.contains("site-packages") || pathLower.contains("/.pyenv/") || pathLower.contains("/venv/") {
            return ProcessExplanation(
                summary: "某个 Python 环境里的程序在后台运行，通常是数据处理或服务脚本。",
                impact: "这个 Python 程序会停止；重新运行即可。"
            )
        }
        if pathLower.contains("/opt/homebrew/") || pathLower.contains("/usr/local/") {
            return ProcessExplanation(
                summary: "用 Homebrew 安装的命令行工具「\(executable)」，正在后台执行某个任务。",
                impact: "这个任务会中断；重新执行那条命令即可。"
            )
        }
        if pathLower.contains("/library/developer/") {
            return ProcessExplanation(
                summary: "Xcode 的开发工具「\(executable)」，正在后台编译或索引项目。",
                impact: "正在进行的编译/索引会中断，重新构建即可。"
            )
        }

        // 4. 兜底：不猜用途，只描述看到的事实。
        return ProcessExplanation(
            summary: "一个叫「\(display)」的后台命令，没有窗口和图标。它由你之前打开过的某个程序或脚本启动。",
            impact: "结束它只会让这个后台命令停下；系统本身不受影响，需要时重新运行对应程序即可。"
        )
    }

    private static func explainEn(
        name: String,
        title: String,
        path: String
    ) -> ProcessExplanation {
        let raw = name.lowercased()
        let executable = raw.hasPrefix("python3.") ? "python3" : raw
        let display = displayName(name: name, title: title)
        let titleLower = title.lowercased()
        let pathLower = path.lowercased()

        if titleLower.contains("webbridge") || titleLower.contains("browserbridge") {
            return ProcessExplanation(
                summary: "Background bridge for AI tools to inspect or operate browser sessions.",
                impact: "AI browser integration will disconnect; relaunch tool when needed."
            )
        }
        if executable.contains("chatgpt") || titleLower.contains("chatgpt") {
            return ProcessExplanation(
                summary: "Background helper for ChatGPT browser integration.",
                impact: "Browser extension bridge will stop; restart browser or tool to reconnect."
            )
        }
        if titleLower.contains("mcp") {
            return ProcessExplanation(
                summary: "Model Context Protocol (MCP) server providing external tool capabilities to AI assistants.",
                impact: "Assigned tool capability will be unavailable until restarted."
            )
        }
        if titleLower.hasPrefix("npm run dev") || titleLower.hasPrefix("pnpm dev") || titleLower.hasPrefix("yarn dev") {
            return ProcessExplanation(
                summary: "Local web development server with hot-module reloading.",
                impact: "Local website will be unreachable; rerun your dev command to resume."
            )
        }
        if titleLower.contains("preview") || titleLower.contains("serve") || titleLower.contains("--port") {
            return ProcessExplanation(
                summary: "Local web server or preview service.",
                impact: "Local service will stop responding; rerun the command to restart."
            )
        }
        if titleLower.contains("uvicorn") || titleLower.contains("gunicorn") {
            return ProcessExplanation(
                summary: "Python ASGI/WSGI web application server.",
                impact: "API requests will fail until restarted."
            )
        }
        if titleLower.contains("pytest") || titleLower.contains("jest") || titleLower.contains("vitest") {
            return ProcessExplanation(
                summary: "Automated test runner executing test suites.",
                impact: "Active test execution will be aborted; code files remain unchanged."
            )
        }
        if titleLower.contains("jupyter") {
            return ProcessExplanation(
                summary: "Jupyter notebook server for interactive data science.",
                impact: "Active notebook connection will disconnect; restart Jupyter to continue."
            )
        }

        let enByName: [String: (String, String)] = [
            "node": ("Node.js JavaScript runtime background process without GUI.", "Running development server or plugin will terminate; relaunch when needed."),
            "npm": ("Node.js package manager running scripts or installing packages.", "Active install or script process will be cancelled."),
            "npx": ("Temporary Node.js package CLI runner.", "Running CLI utility will terminate."),
            "pnpm": ("pnpm package manager executing project scripts.", "Active build or script task will be cancelled."),
            "yarn": ("Yarn package manager executing project scripts.", "Active build or script task will be cancelled."),
            "bun": ("Bun JavaScript/TypeScript runtime running a background task.", "Running process will terminate."),
            "deno": ("Deno JavaScript/TypeScript runtime running a background task.", "Running process will terminate."),
            "python": ("Python background process commonly used for scripts, data pipelines, or ML.", "Running Python task will terminate; rerun script when needed."),
            "python3": ("Python 3 background process used for scripts, data pipelines, or ML.", "Running Python task will terminate; rerun script when needed."),
            "uv": ("Fast Python package and project manager running in the background.", "Active Python task will terminate."),
            "pip": ("Python package installer, currently installing or upgrading dependencies.", "Active package installation will be cancelled."),
            "conda": ("Conda package and environment manager, currently managing environments or packages.", "Active environment task will be cancelled."),
            "git": ("Git version control background process.", "Active git operation will be cancelled."),
            "docker": ("Docker virtualization runtime process.", "Active container tasks will stop."),
            "bash": ("Unix Bash command shell running without a terminal.", "Background shell script will terminate."),
            "zsh": ("Unix Zsh command shell running without a terminal.", "Background shell script will terminate."),
            "sh": ("Unix shell running without a terminal.", "Background script will terminate."),
            "esbuild": ("High-performance JavaScript bundler.", "Active build or watch process will stop."),
            "webpack": ("Webpack module bundler running in background.", "Active build or watch process will stop."),
            "vite": ("Vite frontend dev tooling process.", "Active development server will stop."),
            "tsc": ("TypeScript compiler, compiling TypeScript source into JavaScript.", "Active compilation task will stop."),
            "cargo": ("Rust build tool and package manager.", "Active build task will terminate."),
            "rustc": ("Rust compiler compiling source code.", "Active compilation task will stop."),
            "clang": ("C/C++ compiler compiling source files.", "Active compilation task will stop."),
            "swift": ("Swift compiler or toolchain process.", "Active compile task will stop."),
            "curl": ("Command-line HTTP transfer utility fetching a remote resource.", "Active network transfer will terminate; rerun command to restart."),
            "wget": ("Command-line download utility fetching files in background.", "Active download will be cancelled."),
            "rsync": ("Remote/local fast file synchronization utility.", "Active file synchronization will terminate."),
            "ssh": ("OpenSSH remote terminal or tunnel client.", "Active remote connection or tunnel will disconnect."),
            "ffmpeg": ("Audio/video multimedia processing engine encoding or transcoding media.", "Active media processing will abort."),
            "redis-server": ("Redis in-memory key-value caching database.", "Local services relying on Redis cache will disconnect until restarted."),
            "mysqld": ("MySQL relational database server.", "Local applications connecting to MySQL will fail until service restarts."),
            "postgres": ("PostgreSQL object-relational database server.", "Local applications connecting to PostgreSQL will fail until service restarts."),
            "mongod": ("MongoDB document database server.", "Local applications connecting to MongoDB will fail until service restarts."),
            "java": ("Java Virtual Machine (JVM) running background tasks.", "Running Java process will stop."),
            "ollama": ("Local large language model server executing on-device AI inference.", "Active local AI queries will terminate; relaunch Ollama to resume."),
            "cloudflared": ("Cloudflare tunnel client exposing local ports securely.", "External tunnel access will disconnect."),
            "ngrok": ("ngrok reverse proxy tunnel exposing localhost to public internet.", "External tunnel access will disconnect."),
            "tailscale": ("Tailscale mesh VPN client routing encrypted traffic.", "Mesh network connectivity will disconnect."),
            "brew": ("Homebrew package manager installing or upgrading command line tools.", "Active brew installation will be cancelled.")
        ]
        if let entry = enByName[executable] {
            return ProcessExplanation(summary: entry.0, impact: entry.1)
        }

        if pathLower.contains("/node_modules/") {
            return ProcessExplanation(
                summary: "Tool or dependency running from a Node.js project directory.",
                impact: "Corresponding project service will stop; rerun project command to restart."
            )
        }
        if pathLower.contains("/.nvm/") || pathLower.contains("/.volta/") {
            return ProcessExplanation(
                summary: "Node.js tool installed via Node version manager, running a background script or web task.",
                impact: "Background task will terminate; rerun command to restart."
            )
        }
        if pathLower.contains("site-packages") || pathLower.contains("/.pyenv/") || pathLower.contains("/venv/") {
            return ProcessExplanation(
                summary: "Python script or program running from an isolated virtual environment in the background.",
                impact: "Running Python task will terminate; rerun script when needed."
            )
        }
        if pathLower.contains("/opt/homebrew/") || pathLower.contains("/usr/local/") {
            return ProcessExplanation(
                summary: "Homebrew-installed command line tool '\(executable)' running in background.",
                impact: "Background command will terminate; system services unaffected."
            )
        }
        if pathLower.contains("/library/developer/") {
            return ProcessExplanation(
                summary: "Xcode developer tool '\(executable)' indexing or building projects.",
                impact: "Active build/index task will terminate; rebuild project to resume."
            )
        }

        return ProcessExplanation(
            summary: "A background process named '\(display)' with no GUI window or icon.",
            impact: "Will terminate the process. Core macOS system services are unaffected."
        )
    }

    /// 列表里给人看的名字：`ps` 里显示的名字（argv[0]）优先，和可执行名不同则一起给出。
    public static func displayName(name: String, title: String) -> String {
        guard !title.isEmpty, title.caseInsensitiveCompare(name) != .orderedSame else { return name }
        return title
    }
}
