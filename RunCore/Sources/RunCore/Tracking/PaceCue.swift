import Foundation

/// `.speedUp` when running slower than the target, `.slowDown` when faster.
public enum PaceCue: String, Codable, Sendable {
    case speedUp
    case slowDown
}
