import Foundation

/// What the plan builds towards. A nil `targetSeconds` means "just finish".
public struct Goal: Codable, Equatable, Sendable {
    public var distance: RaceDistance
    public var targetSeconds: Int?

    public init(distance: RaceDistance, targetSeconds: Int? = nil) {
        self.distance = distance
        self.targetSeconds = targetSeconds
    }
}
