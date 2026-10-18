import Foundation

/// Sums distance between used GPS fixes and keeps the route, ignoring jumps that imply an
/// impossible speed.
public struct DistanceAccumulator: Codable, Equatable, Sendable {
    /// About 2:41 per mile. Anything faster is a GPS jump, not running.
    public static let maxSpeedMetersPerSecond = 10.0

    public private(set) var totalMeters: Double = 0
    public private(set) var route: [RoutePoint] = []
    /// The reference fix. It is not advanced on a rejected jump, so the implied speed falls as
    /// time passes and a bad reference ages out instead of blocking every later fix.
    private var last: LocationSample?

    public init() {}

    /// Adds the distance from the previous fix and returns it. With `counting` false (paused)
    /// the fix only becomes the new reference point, so movement while paused is not counted.
    @discardableResult
    public mutating func add(_ sample: LocationSample, counting: Bool = true) -> Double {
        guard let previous = last else {
            last = sample
            if counting { route.append(sample.routePoint) }
            return 0
        }
        let seconds = sample.timestamp.timeIntervalSince(previous.timestamp)
        guard seconds > 0 else { return 0 }
        let meters = Geo.distance(previous, sample)
        guard meters / seconds <= Self.maxSpeedMetersPerSecond else { return 0 }

        last = sample
        guard counting else { return 0 }
        totalMeters += meters
        route.append(sample.routePoint)
        return meters
    }
}
