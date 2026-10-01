import Foundation
import Testing
@testable import MulchCore

@Suite struct ScannerTests {
    let buildRule = Rule(
        id: "build", title: "Build", group: .code,
        target: .projectArtifacts(["build": ["pubspec.yaml"], "dist": ["package.json"]]), minAgeDays: 14
    )

    @Test func artifactsNeedTheirManifest() async throws {
        let fx = try Fixture()
        defer { fx.cleanup() }
        try fx.file("Code/app/pubspec.yaml")
        try fx.file("Code/app/build/out.bin")
        try fx.file("Code/docs/build/index.html")
        try fx.age("Code", days: 30)

        let report = await fx.engine(rules: [buildRule]).scan(config: .test())
        let found = report.rules.flatMap(\.findings).map(\.title)
        #expect(found == ["~/Code/app/build"])
        #expect(report.autoFindings.count == 1)
    }

    @Test func recentlyUsedProjectsAreLeftAlone() async throws {
        let fx = try Fixture()
        defer { fx.cleanup() }
        try fx.file("Code/web/package.json")
        try fx.file("Code/web/dist/app.js")
        try fx.age("Code", days: 30)
        try fx.file("Code/web/dist/fresh.js")

        let finding = try #require(await fx.engine(rules: [buildRule]).scan(config: .test()).rules.first?.findings.first)
        #expect(finding.status == .tooRecent(days: 0))
    }

    @Test func neverPathsAreNotScanned() async throws {
        let fx = try Fixture()
        defer { fx.cleanup() }
        try fx.file("Code/keep/pubspec.yaml")
        try fx.file("Code/keep/build/out.bin")
        try fx.age("Code", days: 30)

        let report = await fx.engine(rules: [buildRule]).scan(config: .test(never: ["~/Code/keep"]))
        #expect(report.rules.flatMap(\.findings).isEmpty)
    }

    @Test func keepNewestKeepsTheNewestOfEachProduct() throws {
        let fx = try Fixture()
        defer { fx.cleanup() }
        for name in ["chromium-1208", "chromium-1234", "ffmpeg-1011"] { try fx.file("pw/\(name)/bin") }

        let stale = fx.engine(rules: []).scanner.olderSiblings("~/pw", .versionPerProduct).map { $0.url.lastPathComponent }
        #expect(stale == ["chromium-1208"])
    }

    @Test func versionsBeatModificationDates() throws {
        let fx = try Fixture()
        defer { fx.cleanup() }
        try fx.file("ndk/29.0.14206865/bin")
        try fx.age("ndk/29.0.14206865", days: 30)
        try fx.file("ndk/28.2.13676358/bin")
        try fx.file("ndk/CACHEDIR.TAG")

        let scanner = fx.engine(rules: []).scanner
        #expect(scanner.olderSiblings("~/ndk", .version).map { $0.url.lastPathComponent } == ["28.2.13676358"])
        #expect(scanner.olderSiblings("~/ndk", .modified).map { $0.url.lastPathComponent } == ["29.0.14206865"])
    }

    @Test func blockedAppsWinOverAge() {
        #expect(Scanner.status(block: "Cursor is open", minAgeDays: nil, newest: nil, now: .now) == .blocked("Cursor is open"))
        let old = Date(timeIntervalSinceNow: -20 * 86_400)
        #expect(Scanner.status(block: nil, minAgeDays: 14, newest: old, now: .now) == .eligible)
        #expect(Scanner.status(block: nil, minAgeDays: 30, newest: old, now: .now) == .tooRecent(days: 20))
    }

    @Test func parsesToolSizes() {
        #expect(HumanBytes.parse("5.463GB (95%)") == 5_463_000_000)
        #expect(HumanBytes.parse("242.9MB") == 242_900_000)
        #expect(HumanBytes.parse("0B") == 0)
        #expect(HumanBytes.parse("1KiB") == 1024)
        #expect(HumanBytes.parse("n/a") == nil)
    }
}
