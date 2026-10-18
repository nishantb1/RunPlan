import Foundation

/// A goal or race distance. v1 offers 5K and 10K only.
public enum RaceDistance: String, Codable, CaseIterable, Sendable {
    case fiveK
    case tenK

    public var meters: Double {
        switch self {
        case .fiveK: return 5000
        case .tenK: return 10000
        }
    }

    /// "5K" or "10K".
    public var displayName: String {
        switch self {
        case .fiveK: return "5K"
        case .tenK: return "10K"
        }
    }
}
