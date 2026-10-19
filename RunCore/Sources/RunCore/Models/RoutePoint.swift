import Foundation

public struct RoutePoint: Codable, Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var timestamp: Date
    /// True on the first point after a pause, where the line on the map breaks. nil otherwise,
    /// so routes saved before it existed decode unchanged and files stay small.
    public var startsSegment: Bool?

    public init(latitude: Double, longitude: Double, timestamp: Date, startsSegment: Bool? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.startsSegment = startsSegment
    }
}
