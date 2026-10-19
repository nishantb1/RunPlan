import Foundation

extension Array where Element == RoutePoint {
    /// The route split at each pause, so the map draws no line across ground covered while
    /// paused. Routes saved before pauses were marked come back as one segment.
    public var segments: [[RoutePoint]] {
        var result: [[RoutePoint]] = []
        for point in self {
            if point.startsSegment == true || result.isEmpty {
                result.append([point])
            } else {
                result[result.count - 1].append(point)
            }
        }
        return result
    }
}
