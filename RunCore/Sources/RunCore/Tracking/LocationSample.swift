import Foundation

/// One GPS fix as plain values, so tracking maths needs no CoreLocation.
public struct LocationSample: Codable, Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var timestamp: Date
    /// Radius of uncertainty in metres. Negative means the fix is invalid.
    public var horizontalAccuracy: Double

    public init(latitude: Double, longitude: Double, timestamp: Date, horizontalAccuracy: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
    }

    public var routePoint: RoutePoint {
        RoutePoint(latitude: latitude, longitude: longitude, timestamp: timestamp)
    }
}
