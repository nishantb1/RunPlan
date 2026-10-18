import Foundation

/// Distance and number of runs in one Monday-start week.
public struct WeeklyTotal: Equatable, Sendable {
    public let weekStart: Date
    public let meters: Double
    public let runs: Int

    public init(weekStart: Date, meters: Double, runs: Int) {
        self.weekStart = weekStart
        self.meters = meters
        self.runs = runs
    }
}
