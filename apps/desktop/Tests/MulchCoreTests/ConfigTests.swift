import Foundation
import Testing
@testable import MulchCore

@Suite struct ConfigTests {
    @Test func missingKeysUseDefaults() throws {
        let fx = try Fixture()
        defer { fx.cleanup() }
        let file = JSONFile.config(home: fx.home)
        try fx.file(".config/mulch/config.json")
        try Data(#"{"codeRoots": ["~/Dev"]}"#.utf8).write(to: file.url)

        let config = file.load()
        #expect(config.codeRoots == ["~/Dev"])
        #expect(config.never == Config.defaultNever)
        #expect(config.intervalDays == 7)
    }

    @Test func brokenFileFallsBackAndIsKept() throws {
        let fx = try Fixture()
        defer { fx.cleanup() }
        let file = JSONFile.config(home: fx.home)
        try fx.file(".config/mulch/config.json")
        try Data("{nope".utf8).write(to: file.url)

        #expect(file.load() == Config())
        #expect(fx.exists(".config/mulch/config.json.broken"))
    }

    @Test func overridesOnlyStoreDifferences() {
        let rule = BuiltInRules.all[0]
        var config = Config()
        config.setMode(.ask, for: rule)
        #expect(config.effective([rule]).first?.mode == .ask)
        config.setMode(rule.defaultMode, for: rule)
        #expect(config.overrides.isEmpty)
    }

    @Test func weeklyScheduleSurvivesRelaunch() {
        let now = Date.now
        let recent = Run(date: now.addingTimeInterval(-2 * 86_400), trigger: .scheduled, freedBytes: 1, removedCount: 1, failureCount: 0)
        let manual = Run(date: now.addingTimeInterval(-9 * 86_400), trigger: .manual, freedBytes: 1, removedCount: 1, failureCount: 0)

        #expect(SweepSchedule.isDue(history: [], intervalDays: 7, now: now))
        #expect(!SweepSchedule.isDue(history: [recent], intervalDays: 7, now: now))
        #expect(SweepSchedule.isDue(history: [manual], intervalDays: 7, now: now))
    }
}
