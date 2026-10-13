import Foundation

/// A single step after repeat groups have been expanded into a flat, ordered sequence.
public struct FlatStep: Equatable, Sendable {
    public let sourceStepID: UUID
    public let kind: StepKind
    /// nil for a distance step, which has no planned duration.
    public let durationSeconds: Int?
    public let distanceMeters: Double?
    public let targetPaceSecondsPerMile: Int?

    /// True for a distance step: it ends only when something advances it.
    public var isOpenEnded: Bool { durationSeconds == nil }

    public init(
        sourceStepID: UUID,
        kind: StepKind,
        durationSeconds: Int?,
        distanceMeters: Double?,
        targetPaceSecondsPerMile: Int?
    ) {
        self.sourceStepID = sourceStepID
        self.kind = kind
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.targetPaceSecondsPerMile = targetPaceSecondsPerMile
    }
}
