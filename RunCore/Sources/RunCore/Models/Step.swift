import Foundation

/// One step of a workout as authored. Contiguous steps sharing a `repeatGroup` repeat
/// together `repeatCount` times, e.g. 6 x (run, walk). See `StepExpander`.
public struct Step: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var kind: StepKind
    public var measure: StepMeasure
    /// nil means no target, e.g. an open effort.
    public var targetPaceSecondsPerMile: Int?
    public var repeatGroup: Int?
    public var repeatCount: Int?

    public init(
        id: UUID = UUID(),
        kind: StepKind,
        measure: StepMeasure,
        targetPaceSecondsPerMile: Int? = nil,
        repeatGroup: Int? = nil,
        repeatCount: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.measure = measure
        self.targetPaceSecondsPerMile = targetPaceSecondsPerMile
        self.repeatGroup = repeatGroup
        self.repeatCount = repeatCount
    }
}
