import Foundation

/// One week of a plan. `number` starts at 1; workouts are in date order.
public struct Week: Identifiable, Codable, Equatable, Sendable {
    public var number: Int
    public var kind: WeekKind
    public var workouts: [Workout]

    public var id: Int { number }

    public init(number: Int, kind: WeekKind, workouts: [Workout]) {
        self.number = number
        self.kind = kind
        self.workouts = workouts
    }
}
