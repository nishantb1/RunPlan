import Foundation

/// `.warmup` and `.cooldown` bookend a workout; `.walk` and `.recovery` separate efforts.
public enum StepKind: String, Codable, CaseIterable, Sendable {
    case warmup
    case run
    case walk
    case recovery
    case cooldown
}
