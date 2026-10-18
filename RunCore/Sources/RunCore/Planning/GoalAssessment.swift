import Foundation

public enum GoalAssessment: Equatable, Sendable {
    case reachable
    /// The goal time needs more improvement than the plan length allows. `suggestedWeeks` is a
    /// plan length that would allow it, or nil when even the longest plan would not.
    case ambitious(suggestedWeeks: Int?)
}
