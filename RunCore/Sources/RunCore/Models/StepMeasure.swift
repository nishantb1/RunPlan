import Foundation

/// What ends a step: a duration, or a distance.
public enum StepMeasure: Codable, Equatable, Sendable {
    case time(seconds: Int)
    case distance(meters: Double)
}
