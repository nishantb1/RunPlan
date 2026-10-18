import Foundation

/// Target paces in seconds per mile. `goal` is nil when there is no goal time or race result
/// to derive it from.
public struct TrainingPaces: Equatable, Sendable {
    /// Conservative fixed paces for a runner with no goal time and no race result.
    public static let defaults = TrainingPaces(easy: 810, tempo: 720, interval: 660, goal: nil)

    public var easy: Int
    public var tempo: Int
    public var interval: Int
    public var goal: Int?

    public init(easy: Int, tempo: Int, interval: Int, goal: Int?) {
        self.easy = easy
        self.tempo = tempo
        self.interval = interval
        self.goal = goal
    }
}
