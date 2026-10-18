import Foundation

/// The onboarding answers a plan is generated from. Distances are in miles throughout v1.
public struct Profile: Codable, Equatable, Sendable {
    public static let daysPerWeekRange = 2...5
    public static let planWeeksRange = 6...16

    public var goal: Goal
    public var fitness: Fitness
    /// Unique and sorted Monday first by `init`; the generator re-sorts and removes duplicates, so
    /// later edits need not.
    public var runDays: [Weekday]
    public var planWeeks: Int
    public var startDate: Date

    public var daysPerWeek: Int { runDays.count }

    public init(goal: Goal, fitness: Fitness, runDays: [Weekday], planWeeks: Int, startDate: Date) {
        self.goal = goal
        self.fitness = fitness
        self.runDays = Array(Set(runDays)).sorted()
        self.planWeeks = planWeeks
        self.startDate = startDate
    }
}
