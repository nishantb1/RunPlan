import Foundation

/// One run's average pace, for the pace trend.
public struct PacePoint: Equatable, Sendable {
    public let date: Date
    public let secondsPerMile: Int

    public init(date: Date, secondsPerMile: Int) {
        self.date = date
        self.secondsPerMile = secondsPerMile
    }
}
