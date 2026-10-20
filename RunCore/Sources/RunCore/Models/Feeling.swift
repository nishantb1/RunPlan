import Foundation

/// How a run felt, asked when it is saved. `.tooHard` holds a beginner plan at its step.
public enum Feeling: String, Codable, CaseIterable, Sendable {
    case tooEasy
    case justRight
    case tooHard

    public var displayName: String {
        switch self {
        case .tooEasy: return "Too easy"
        case .justRight: return "Just right"
        case .tooHard: return "Too hard"
        }
    }
}
