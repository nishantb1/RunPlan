import Foundation

/// The runner's current fitness, chosen in onboarding.
public enum Fitness: Codable, Equatable, Sendable {
    case newRunner
    /// Can run about 5 minutes without stopping.
    case runsFiveMinutes
    /// Can run 20 minutes or more without stopping.
    case runsTwentyMinutes
    /// Has a recent race or time-trial result.
    case recentRace(distance: RaceDistance, seconds: Int)
}
