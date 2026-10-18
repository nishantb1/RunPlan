import Foundation

/// What ends a step: a duration, a distance, or the runner ending the workout (`open`, used
/// by free runs).
public enum StepMeasure: Codable, Equatable, Sendable {
    case time(seconds: Int)
    case distance(meters: Double)
    case open
}
