import Foundation

/// Where a given elapsed time lands within a run of steps.
public struct StepResolution: Equatable, Sendable {
    public let index: Int
    public let elapsedInStep: TimeInterval
    /// nil for an open-ended step.
    public let remainingInStep: TimeInterval?
    public let isOpenEnded: Bool
    /// True once elapsed time has run past the end of every timed step.
    public let isPastEnd: Bool
}
