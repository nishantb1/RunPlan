import XCTest
@testable import RunCore

final class GeoTests: XCTestCase {

    private func sample(_ latitude: Double, _ longitude: Double) -> LocationSample {
        LocationSample(latitude: latitude, longitude: longitude, timestamp: trackStart, horizontalAccuracy: 5)
    }

    func testHaversineDistance() {
        XCTAssertEqual(Geo.distance(sample(0, 0), sample(0.001, 0)), 111.195, accuracy: 0.001)
        XCTAssertEqual(Geo.distance(sample(51.5, 0), sample(51.5, 0.001)), 69.220, accuracy: 0.001)
        XCTAssertEqual(Geo.distance(sample(51.5, -0.1), sample(51.5, -0.1)), 0)
        XCTAssertEqual(Geo.distance(fix(at: 0, north: 0), fix(at: 1, north: 3)), 3, accuracy: 1e-9)
    }

    func testFilterAcceptsAccurateRecentFixes() {
        let now = trackStart.addingTimeInterval(5)
        XCTAssertTrue(SampleFilter.accepts(fix(at: 0, north: 0, accuracy: 20), now: now))
        XCTAssertTrue(SampleFilter.accepts(fix(at: 5, north: 0, accuracy: 0), now: now))
    }

    func testFilterRejectsInaccurateInvalidOrStaleFixes() {
        let now = trackStart.addingTimeInterval(5)
        XCTAssertFalse(SampleFilter.accepts(fix(at: 5, north: 0, accuracy: 20.5), now: now))
        XCTAssertFalse(SampleFilter.accepts(fix(at: 5, north: 0, accuracy: -1), now: now))
        XCTAssertFalse(SampleFilter.accepts(fix(at: -0.5, north: 0), now: now))
    }

    func testSampleMakesRoutePoint() {
        let point = fix(at: 3, north: 0).routePoint
        XCTAssertEqual(point, RoutePoint(latitude: 0, longitude: 0, timestamp: trackStart.addingTimeInterval(3)))
    }
}
