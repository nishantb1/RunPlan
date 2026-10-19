import Foundation

extension Array where Element == RoutePoint {
    /// The route split at each pause, so the map draws no line across ground covered while
    /// paused. Routes saved before pauses were marked come back as one segment. A GPS gap with
    /// no pause does not split it: that distance was counted, so the line shows it. A restore
    /// after a crash does split it, since the runner may have moved before the app reopened.
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

    /// True when some segment has two points or more, so the map has a line to draw.
    public var hasLine: Bool {
        segments.contains { $0.count > 1 }
    }
}
