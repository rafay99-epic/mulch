import Foundation

/// User settings, stored as JSON at `~/.config/mulch/config.json` so it can be
/// shared between Macs through dotfiles. Missing keys fall back to defaults.
public struct Config: Codable, Sendable, Equatable {
    public struct Override: Codable, Sendable, Equatable {
        public var mode: Mode?
        public var minAgeDays: Int?

        public init(mode: Mode? = nil, minAgeDays: Int? = nil) {
            self.mode = mode
            self.minAgeDays = minAgeDays
        }
    }

    public static let defaultNever = [
        "~/.t3/worktrees",
        "~/.android/avd",
        "~/Library/Developer/CoreSimulator/Devices",
    ]

    public var codeRoots: [String]
    public var never: [String]
    public var intervalDays: Int
    public var overrides: [String: Override]
    public var onboarded: Bool

    public init(
        codeRoots: [String] = ["~/Code"],
        never: [String] = Config.defaultNever,
        intervalDays: Int = 7,
        overrides: [String: Override] = [:],
        onboarded: Bool = false
    ) {
        self.codeRoots = codeRoots
        self.never = never
        self.intervalDays = intervalDays
        self.overrides = overrides
        self.onboarded = onboarded
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Config()
        codeRoots = try c.decodeIfPresent([String].self, forKey: .codeRoots) ?? defaults.codeRoots
        never = try c.decodeIfPresent([String].self, forKey: .never) ?? defaults.never
        intervalDays = try c.decodeIfPresent(Int.self, forKey: .intervalDays) ?? defaults.intervalDays
        overrides = try c.decodeIfPresent([String: Override].self, forKey: .overrides) ?? defaults.overrides
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? defaults.onboarded
    }

    /// The catalog with this config's overrides applied.
    public func effective(_ rules: [Rule]) -> [EffectiveRule] {
        rules.map { rule in
            let override = overrides[rule.id]
            return EffectiveRule(
                rule: rule,
                mode: override?.mode ?? rule.defaultMode,
                minAgeDays: override?.minAgeDays ?? rule.minAgeDays
            )
        }
    }

    public mutating func setMode(_ mode: Mode, for rule: Rule) {
        overrides[rule.id, default: Override()].mode = mode == rule.defaultMode ? nil : mode
        prune(rule.id)
    }

    public mutating func setMinAge(_ days: Int?, for rule: Rule) {
        overrides[rule.id, default: Override()].minAgeDays = days == rule.minAgeDays ? nil : days
        prune(rule.id)
    }

    private mutating func prune(_ id: String) {
        if overrides[id] == Override() { overrides[id] = nil }
    }
}

/// One finished sweep, kept for the history chart.
public struct Run: Codable, Sendable, Identifiable, Equatable {
    public enum Trigger: String, Codable, Sendable { case scheduled, manual }

    public let date: Date
    public let trigger: Trigger
    public let freedBytes: Int64
    public let removedCount: Int
    public let failureCount: Int

    public var id: Date { date }

    public init(date: Date, trigger: Trigger, freedBytes: Int64, removedCount: Int, failureCount: Int) {
        self.date = date
        self.trigger = trigger
        self.freedBytes = freedBytes
        self.removedCount = removedCount
        self.failureCount = failureCount
    }

    public init(date: Date, trigger: Trigger, outcome: Outcome) {
        self.init(
            date: date,
            trigger: trigger,
            freedBytes: outcome.freedBytes,
            removedCount: outcome.removed.count,
            failureCount: outcome.failures.count
        )
    }
}

/// When the weekly sweep should next run. Kept separate from the OS scheduler
/// so a reboot or relaunch never resets the clock.
public enum SweepSchedule {
    public static func lastScheduled(in history: [Run]) -> Date? {
        history.last { $0.trigger == .scheduled }?.date
    }

    public static func nextDate(history: [Run], intervalDays: Int, now: Date) -> Date {
        guard let last = lastScheduled(in: history) else { return now }
        return last.addingTimeInterval(TimeInterval(intervalDays) * 86_400)
    }

    public static func isDue(history: [Run], intervalDays: Int, now: Date) -> Bool {
        nextDate(history: history, intervalDays: intervalDays, now: now) <= now
    }
}
