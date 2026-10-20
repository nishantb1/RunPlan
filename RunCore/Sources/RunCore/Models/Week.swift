import Foundation

/// One week of a plan. `number` starts at 1; workouts are in date order.
public struct Week: Identifiable, Codable, Equatable, Sendable {
    public var number: Int
    public var kind: WeekKind
    public var workouts: [Workout]
    /// The beginner ladder step the week is built from; nil outside the beginner 5K plan.
    public var ladderStep: Int?

    public var id: Int { number }

    public init(number: Int, kind: WeekKind, workouts: [Workout], ladderStep: Int? = nil) {
        self.number = number
        self.kind = kind
        self.workouts = workouts
        self.ladderStep = ladderStep
    }
}
