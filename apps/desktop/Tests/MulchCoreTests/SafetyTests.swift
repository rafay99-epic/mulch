import Foundation
import Testing
@testable import MulchCore

@Suite struct SafetyTests {
    @Test func protectionCoversNeverPathsTheirParentsAndHome() throws {
        let fx = try Fixture()
        defer { fx.cleanup() }
        try fx.file(".t3/worktrees/app/file")
        try fx.file("Code/app/build/file")
        let protection = Protection(["~/.t3/worktrees"], paths: fx.paths)

        #expect(protection.forbidsDeleting(fx.url(".t3/worktrees/app")))
        #expect(protection.forbidsDeleting(fx.url(".t3")))
        #expect(protection.forbidsDeleting(fx.home))
        #expect(!protection.forbidsDeleting(fx.url("Code/app/build")))
    }

    @Test func symlinksCannotEscapeTheirFolder() throws {
        let fx = try Fixture()
        defer { fx.cleanup() }
        try fx.file("outside/precious")
        try fx.file("cache/real/file")
        try FileManager.default.createSymbolicLink(at: fx.url("cache/link"), withDestinationURL: fx.url("outside"))

        #expect(Paths.isContained(fx.url("cache/real"), in: fx.url("cache")))
        #expect(!Paths.isContained(fx.url("cache/link"), in: fx.url("cache")))
    }

    @Test func cleanerDeletesOnlyWhatIsStillSafe() async throws {
        let fx = try Fixture()
        defer { fx.cleanup() }
        let rule = Rule(id: "logs", title: "Logs", group: .system, target: .paths(["~/logs/*"]))
        try fx.file("logs/old.log")
        try fx.file("logs/changed.log")
        try fx.age("logs", days: 10)

        let engine = fx.engine(rules: [rule])
        let report = await engine.scan(config: .test())
        #expect(report.autoFindings.count == 2)

        // Touched after the scan: must be refused.
        try fx.file("logs/changed.log", bytes: 10)
        let outcome = await engine.sweep(report, config: .test())

        #expect(!fx.exists("logs/old.log"))
        #expect(fx.exists("logs/changed.log"))
        #expect(outcome.removed == ["~/logs/old.log"])
        #expect(outcome.skipped.map(\.reason) == ["changed since the scan"])

        // Cleaning the same report again: the deleted item counts as gone, not skipped.
        let again = await engine.sweep(report, config: .test())
        #expect(again.gone == outcome.gone)
        #expect(again.removed.isEmpty)
        #expect(report.removing(outcome.gone).autoFindings.map(\.title) == ["~/logs/changed.log"])
    }

    @Test func cleanerHonoursRunningApps() async throws {
        let fx = try Fixture()
        defer { fx.cleanup() }
        let rule = Rule(
            id: "editor", title: "Editor", group: .editors, target: .paths(["~/editor/cache"]),
            blockers: [.app("com.example.editor", name: "Editor")]
        )
        try fx.file("editor/cache/blob")

        let idle = fx.engine(rules: [rule])
        let report = await idle.scan(config: .test())
        let busy = fx.engine(rules: [rule], running: ["com.example.editor"])
        let outcome = await busy.cleaner.clean(report.autoFindings, from: report, config: .test())

        #expect(fx.exists("editor/cache/blob"))
        #expect(outcome.skipped.map(\.reason) == ["Editor is open"])
    }
}
