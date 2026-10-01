import Foundation

/// Bundle ids the catalog refers to.
enum Apps {
    static let chrome = "com.google.Chrome"
    static let brave = "com.brave.Browser"
    static let cursor = "com.todesktop.230313mzl4w4u92"
    static let vscode = "com.microsoft.VSCode"
    static let androidStudio = "com.google.android.studio"
    static let simulator = "com.apple.iphonesimulator"
}

/// The default rule catalog. Order matters: when two rules match the same path,
/// the earlier one claims it, so specific rules come before broad ones.
public enum BuiltInRules {
    public static let all: [Rule] = code + browsers + xcode + android + editors + packages + docker + system

    static let code: [Rule] = [
        Rule(
            id: "code.build", title: "Build output", group: .code,
            target: .projectArtifacts([
                "build": ["pubspec.yaml", "build.gradle", "build.gradle.kts", "package.json"],
                ".dart_tool": ["pubspec.yaml"],
                ".next": ["package.json"],
                ".turbo": ["package.json"],
                ".svelte-kit": ["package.json"],
                ".output": ["package.json"],
                "dist": ["package.json"],
                "target": ["Cargo.toml"],
                ".build": ["Package.swift"],
            ]),
            minAgeDays: 14
        ),
        Rule(
            id: "code.nodeModules", title: "node_modules", group: .code,
            target: .projectArtifacts(["node_modules": ["package.json"]]),
            minAgeDays: 60, defaultMode: .off
        ),
    ]

    static let browsers: [Rule] = [
        Rule(
            id: "browsers.clones", title: "Browser update leftovers", group: .browsers,
            target: .keepNewest("$X/*.code_sign_clone", .modified), minAgeDays: 1
        ),
        Rule(
            id: "browsers.chromeCache", title: "Chrome cache", group: .browsers,
            target: .paths(["~/Library/Caches/Google/Chrome"]),
            blockers: [.app(Apps.chrome, name: "Chrome")]
        ),
        Rule(
            id: "browsers.braveCache", title: "Brave cache", group: .browsers,
            target: .paths(["~/Library/Caches/BraveSoftware"]),
            blockers: [.app(Apps.brave, name: "Brave")]
        ),
    ]

    static let xcode: [Rule] = [
        Rule(
            id: "xcode.derivedData", title: "DerivedData", group: .xcode,
            target: .paths(["~/Library/Developer/Xcode/DerivedData/*"]), minAgeDays: 7
        ),
        Rule(
            id: "xcode.simulatorCaches", title: "Simulator caches", group: .xcode,
            target: .paths(["~/Library/Developer/CoreSimulator/Caches"]),
            blockers: [.app(Apps.simulator, name: "Simulator")]
        ),
        Rule(
            id: "xcode.unavailableSimulators", title: "Unavailable simulators", group: .xcode,
            target: .command(CommandSpec(tool: "xcrun", clean: ["simctl", "delete", "unavailable"], measure: .none))
        ),
        Rule(
            id: "xcode.deviceSupport", title: "Old iOS device support", group: .xcode,
            target: .keepNewest("~/Library/Developer/Xcode/iOS DeviceSupport", .version), defaultMode: .ask
        ),
    ]

    static let android: [Rule] = [
        Rule(
            id: "android.gradleCaches", title: "Gradle caches", group: .android,
            target: .paths(["~/.gradle/caches"]), defaultMode: .ask,
            blockers: [.app(Apps.androidStudio, name: "Android Studio"), .process("GradleDaemon", name: "Gradle")]
        ),
        Rule(
            id: "android.gradleWrappers", title: "Old Gradle versions", group: .android,
            target: .keepNewest("~/.gradle/wrapper/dists", .version), defaultMode: .ask
        ),
        Rule(
            id: "android.ndk", title: "Old Android NDKs", group: .android,
            target: .keepNewest("~/Library/Android/sdk/ndk", .version), defaultMode: .ask
        ),
    ]

    static let editors: [Rule] = [
        Rule(
            id: "editors.cursor", title: "Cursor snapshots and caches", group: .editors,
            target: .paths([
                "~/Library/Application Support/Cursor/snapshots",
                "~/Library/Application Support/Cursor/CachedData",
                "~/Library/Application Support/Cursor/Cache",
                "~/Library/Application Support/Cursor/logs",
            ]),
            blockers: [.app(Apps.cursor, name: "Cursor")]
        ),
        Rule(
            id: "editors.vscode", title: "VS Code caches", group: .editors,
            target: .paths([
                "~/Library/Application Support/Code/CachedData",
                "~/Library/Application Support/Code/Cache",
                "~/Library/Application Support/Code/logs",
            ]),
            blockers: [.app(Apps.vscode, name: "VS Code")]
        ),
        Rule(
            id: "editors.jetbrainsCaches", title: "JetBrains old version caches", group: .editors,
            target: .keepNewest("~/Library/Caches/JetBrains", .versionPerProduct)
        ),
        Rule(
            id: "editors.jetbrainsSettings", title: "JetBrains old version settings", group: .editors,
            target: .keepNewest("~/Library/Application Support/JetBrains", .versionPerProduct), defaultMode: .ask
        ),
    ]

    static let packages: [Rule] = [
        Rule(id: "packages.cocoapods", title: "CocoaPods cache", group: .packages, target: .paths(["~/Library/Caches/CocoaPods"])),
        Rule(id: "packages.swiftpm", title: "SwiftPM cache", group: .packages, target: .paths(["~/Library/Caches/org.swift.swiftpm"])),
        Rule(id: "packages.npm", title: "npm cache", group: .packages, target: .paths(["~/.npm/_cacache"])),
        Rule(id: "packages.bun", title: "Bun cache", group: .packages, target: .paths(["~/.bun/install/cache"])),
        Rule(
            id: "packages.dartServer", title: "Dart analysis cache", group: .packages,
            target: .paths(["~/.dartServer"]), minAgeDays: 30
        ),
        Rule(
            id: "packages.playwright", title: "Old Playwright browsers", group: .packages,
            target: .keepNewest("~/Library/Caches/ms-playwright", .versionPerProduct)
        ),
        Rule(
            id: "packages.pnpm", title: "pnpm store", group: .packages,
            target: .command(CommandSpec(tool: "pnpm", clean: ["store", "prune"], measure: .paths(["~/Library/pnpm/store"])))
        ),
        Rule(
            id: "packages.homebrew", title: "Homebrew downloads", group: .packages,
            target: .command(CommandSpec(tool: "brew", clean: ["cleanup", "--prune=all"], measure: .paths(["~/Library/Caches/Homebrew"])))
        ),
    ]

    static let docker: [Rule] = [
        Rule(
            id: "docker.prune", title: "Unused images and build cache", group: .docker,
            target: .command(CommandSpec(
                tool: "docker", clean: ["system", "prune", "-a", "-f"],
                measure: .output(["system", "df", "--format", "{{.Reclaimable}}"])
            )),
            defaultMode: .ask
        ),
    ]

    static let system: [Rule] = [
        Rule(
            id: "system.crashReports", title: "Crash reports", group: .system,
            target: .paths(["~/Library/Logs/DiagnosticReports/*"]), minAgeDays: 30
        ),
        Rule(
            id: "system.appCaches", title: "Caches of apps unused for 2 weeks", group: .system,
            target: .paths(["~/Library/Caches/*.*"]), minAgeDays: 14,
            blockers: [.itemBundleID], excluding: ["com.apple.*", "com.rafay99.mulch*"]
        ),
    ]
}
