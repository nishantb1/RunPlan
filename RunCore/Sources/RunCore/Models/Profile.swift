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

    /// Beginner 5K plans need 8 weeks or more, Runna's minimum, to reach continuous running.
    public static let beginnerMinimumWeeks = 8

    public var daysPerWeek: Int { runDays.count }

    /// The plan lengths onboarding offers for a goal and fitness.
    public static func planWeeksRange(goal: RaceDistance, fitness: Fitness) -> ClosedRange<Int> {
        guard goal == .fiveK, BeginnerLadder.startStep(for: fitness) != nil else { return planWeeksRange }
        return beginnerMinimumWeeks...planWeeksRange.upperBound
    }

    public init(goal: Goal, fitness: Fitness, runDays: [Weekday], planWeeks: Int, startDate: Date) {
        self.goal = goal
        self.fitness = fitness
        self.runDays = Array(Set(runDays)).sorted()
        self.planWeeks = planWeeks
        self.startDate = startDate
    }
}
