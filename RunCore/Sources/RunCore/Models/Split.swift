import Foundation

/// One mile split of a recorded run. `index` starts at 1.
public struct Split: Codable, Equatable, Sendable {
    public var index: Int
    public var distanceMeters: Double
    public var durationSeconds: Int

    public init(index: Int, distanceMeters: Double, durationSeconds: Int) {
        self.index = index
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
    }
}
