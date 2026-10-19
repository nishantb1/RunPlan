import XCTest
@testable import RunCore

final class DistanceAccumulatorTests: XCTestCase {

    func testSumsDistanceBetweenFixes() {
        var accumulator = DistanceAccumulator()
        for second in 0...10 {
            accumulator.add(fix(at: Double(second), north: Double(3 * second)))
        }
        XCTAssertEqual(accumulator.totalMeters, 30, accuracy: 1e-6)
        XCTAssertEqual(accumulator.route.count, 11)
    }

    func testIgnoresImpossibleJump() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0))
        accumulator.add(fix(at: 1, north: 3))
        XCTAssertEqual(accumulator.add(fix(at: 2, north: 503)), 0)
        accumulator.add(fix(at: 3, north: 6))
        XCTAssertEqual(accumulator.totalMeters, 6, accuracy: 1e-6)
        XCTAssertEqual(accumulator.route.count, 3)
    }

    func testPausedFixesMoveTheReferenceOnly() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0))
        accumulator.add(fix(at: 1, north: 3))
        accumulator.add(fix(at: 2, north: 6), counting: false)
        accumulator.add(fix(at: 3, north: 9), counting: false)
        accumulator.add(fix(at: 4, north: 12))
        XCTAssertEqual(accumulator.totalMeters, 6, accuracy: 1e-6)
        XCTAssertEqual(accumulator.route.count, 3)
    }

    func testAPauseStartsANewSegment() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0), counting: false)
        accumulator.add(fix(at: 1, north: 3))
        accumulator.add(fix(at: 2, north: 6))
        accumulator.add(fix(at: 3, north: 9), counting: false)
        accumulator.add(fix(at: 4, north: 12))
        accumulator.add(fix(at: 5, north: 15))

        XCTAssertEqual(accumulator.route.map(\.startsSegment), [nil, nil, true, nil])
        XCTAssertEqual(accumulator.route.segments.map(\.count), [2, 2])
    }

    func testAPauseWithNoFixesStillBreaksTheRouteAndCountsNothing() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0))
        accumulator.add(fix(at: 1, north: 3))
        // Paused with GPS lost, the runner walks 600 m in 5 minutes, then resumes.
        accumulator.breakRoute()
        accumulator.add(fix(at: 300, north: 603))
        accumulator.add(fix(at: 301, north: 606))

        XCTAssertEqual(accumulator.totalMeters, 6, accuracy: 1e-6)
        XCTAssertEqual(accumulator.route.map(\.startsSegment), [nil, nil, true, nil])
    }

    func testARejectedJumpWhilePausedStillBreaksTheRoute() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0))
        accumulator.add(fix(at: 1, north: 3))
        accumulator.add(fix(at: 2, north: 503), counting: false)
        accumulator.add(fix(at: 3, north: 6))

        XCTAssertEqual(accumulator.route.map(\.startsSegment), [nil, nil, true])
    }

    func testRouteWithoutPausesIsOneSegment() {
        let route = (0...4).map { fix(at: Double($0), north: Double(3 * $0)).routePoint }
        XCTAssertEqual(route.segments, [route])
        XCTAssertEqual([RoutePoint]().segments, [])
        XCTAssertTrue(route.hasLine)

        // A marked first point opens the only segment rather than an empty one before it.
        var marked = route
        marked[0].startsSegment = true
        XCTAssertEqual(marked.segments.count, 1)
    }

    func testRouteOfSinglePointsHasNoLine() {
        let points = (0...2).map { fix(at: Double($0), north: Double(30 * $0)).routePoint }
        let route = points.map { point -> RoutePoint in
            var marked = point
            marked.startsSegment = true
            return marked
        }
        XCTAssertEqual(route.segments.map(\.count), [1, 1, 1])
        XCTAssertFalse(route.hasLine)
    }

    func testUnmarkedPointsAndOlderFilesCodeWithoutTheMark() throws {
        let point = fix(at: 0, north: 0).routePoint
        let json = try JSONEncoder().encode(point)
        XCTAssertFalse(String(decoding: json, as: UTF8.self).contains("startsSegment"))
        XCTAssertEqual(try JSONDecoder().decode(RoutePoint.self, from: json), point)

        // A checkpoint written before the pause flag existed still decodes.
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0))
        let older = try JSONEncoder().encode(accumulator)
        XCTAssertFalse(String(decoding: older, as: UTF8.self).contains("pausedSinceLastPoint"))
        XCTAssertEqual(try JSONDecoder().decode(DistanceAccumulator.self, from: older), accumulator)
    }

    func testRecoversFromABadReferenceFix() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 500))
        XCTAssertEqual(accumulator.add(fix(at: 1, north: 0)), 0)
        accumulator.add(fix(at: 60, north: 0))
        XCTAssertEqual(accumulator.totalMeters, 500, accuracy: 1e-6)
        XCTAssertEqual(accumulator.route.count, 2)
    }

    func testFixWithNoElapsedTimeIsIgnored() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0))
        XCTAssertEqual(accumulator.add(fix(at: 0, north: 3)), 0)
        XCTAssertEqual(accumulator.totalMeters, 0)
    }
}
