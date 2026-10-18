import Foundation

/// Distance on the Earth's surface.
public enum Geo {
    static let earthRadiusMeters = 6_371_000.0

    /// Great-circle distance in metres between two fixes (haversine formula).
    public static func distance(_ a: LocationSample, _ b: LocationSample) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusMeters * asin(min(1, sqrt(h)))
    }
}
