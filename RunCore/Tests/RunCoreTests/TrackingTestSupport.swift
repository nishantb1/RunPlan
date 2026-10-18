import Foundation
@testable import RunCore

/// Fixed start time for tracking tests.
let trackStart = Date(timeIntervalSince1970: 1_800_000_000)

/// Metres per degree of latitude on the haversine sphere, so `north` gives exact distances.
let metersPerDegreeLatitude = Double.pi * 6_371_000 / 180

/// A fix `seconds` after `trackStart`, `meters` north of (0, 0).
func fix(at seconds: Double, north meters: Double, accuracy: Double = 5) -> LocationSample {
    LocationSample(
        latitude: meters / metersPerDegreeLatitude,
        longitude: 0,
        timestamp: trackStart.addingTimeInterval(seconds),
        horizontalAccuracy: accuracy
    )
}
