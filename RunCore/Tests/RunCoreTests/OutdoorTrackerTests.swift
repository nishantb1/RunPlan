import XCTest
@testable import RunCore

final class OutdoorTrackerTests: XCTestCase {

    private func at(_ seconds: Int) -> Date { trackStart.addingTimeInterval(Double(seconds)) }

    func testDistanceStepAndPaceCues() throws {
        let engine = WorkoutEngine(planSteps: [
            Step(kind: .run, measure: .distance(meters: 400), targetPaceSecondsPerMile: 600),
            Step(kind: .cooldown, measure: .time(seconds: 300)),
        ])
        engine.start(now: trackStart)
        var tracker = OutdoorTracker()
        var events: [(Int, OutdoorEvent)] = []

        for second in 0...134 {
            tracker.record(fix(at: Double(second), north: Double(3 * second)), now: at(second), counting: true)
            let snapshot = try XCTUnwrap(engine.snapshot(now: at(second)))
            events += tracker.events(for: snapshot, now: at(second)).map { (second, $0) }
            if second == 100 {
                XCTAssertEqual(try XCTUnwrap(tracker.stepMetersRemaining(for: snapshot)), 100, accuracy: 0.01)
                XCTAssertEqual(tracker.currentPace, 536)
            }
        }

        XCTAssertEqual(events.map { $0.0 }, [35, 65, 95, 125, 134])
        XCTAssertEqual(events.map { $0.1 }, [
            .paceCue(.slowDown), .paceCue(.slowDown), .paceCue(.slowDown), .paceCue(.slowDown), .stepDistanceReached,
        ])
    }

    func testSplitsAreAnnouncedEachMile() throws {
        let engine = WorkoutEngine(planSteps: [Step(kind: .run, measure: .time(seconds: 3600))])
        engine.start(now: trackStart)
        var tracker = OutdoorTracker()
        var splits: [Split] = []

        for second in 0...545 {
            tracker.record(fix(at: Double(second), north: Double(3 * second)), now: at(second), counting: true)
            let snapshot = try XCTUnwrap(engine.snapshot(now: at(second)))
            for case .split(let split) in tracker.events(for: snapshot, now: at(second)) {
                splits.append(split)
            }
        }

        XCTAssertEqual(splits, [Split(index: 1, distanceMeters: Pace.metersPerMile, durationSeconds: 536)])
        let final = tracker.finalSplits(elapsed: 545)
        XCTAssertEqual(final.count, 2)
        XCTAssertEqual(final[1].distanceMeters, 25.656, accuracy: 0.001)
        XCTAssertEqual(final[1].durationSeconds, 9)
    }

    func testNoPaceCueFromAStalePaceAfterGPSIsLost() throws {
        let engine = WorkoutEngine(planSteps: [
            Step(kind: .run, measure: .time(seconds: 600), targetPaceSecondsPerMile: 600),
        ])
        engine.start(now: trackStart)
        var tracker = OutdoorTracker()
        var events: [OutdoorEvent] = []

        for second in 0...20 {
            tracker.record(fix(at: Double(second), north: Double(3 * second)), now: at(second), counting: true)
            events += tracker.events(for: try XCTUnwrap(engine.snapshot(now: at(second))), now: at(second))
        }
        for second in 21...120 {
            events += tracker.events(for: try XCTUnwrap(engine.snapshot(now: at(second))), now: at(second))
        }

        XCTAssertEqual(events, [])
        XCTAssertFalse(tracker.hasSignal(now: at(120)))
    }

    func testRestartedStepMeasuresDistanceAfresh() throws {
        let engine = WorkoutEngine(planSteps: [
            Step(kind: .run, measure: .distance(meters: 400)),
            Step(kind: .cooldown, measure: .time(seconds: 300)),
        ])
        engine.start(now: trackStart)
        var tracker = OutdoorTracker()
        for second in 0...100 {
            tracker.record(fix(at: Double(second), north: Double(3 * second)), now: at(second), counting: true)
            _ = tracker.events(for: try XCTUnwrap(engine.snapshot(now: at(second))), now: at(second))
        }

        // Skip back on the first step restarts it with the same step index.
        engine.skipBack(now: at(100))
        tracker.restartStep()
        let snapshot = try XCTUnwrap(engine.snapshot(now: at(100)))
        XCTAssertEqual(snapshot.stepIndex, 0)
        _ = tracker.events(for: snapshot, now: at(100))
        XCTAssertEqual(try XCTUnwrap(tracker.stepMetersRemaining(for: snapshot)), 400, accuracy: 1e-6)
    }

    func testPausedFixesAddNothing() {
        var tracker = OutdoorTracker()
        tracker.record(fix(at: 0, north: 0), now: at(0), counting: true)
        tracker.record(fix(at: 1, north: 3), now: at(1), counting: true)
        tracker.record(fix(at: 2, north: 6), now: at(2), counting: false)
        tracker.record(fix(at: 3, north: 9), now: at(3), counting: false)
        XCTAssertEqual(tracker.totalMeters, 3, accuracy: 1e-6)
        tracker.record(fix(at: 4, north: 12), now: at(4), counting: true)
        XCTAssertEqual(tracker.totalMeters, 6, accuracy: 1e-6)
    }

    func testSignal() {
        var tracker = OutdoorTracker()
        XCTAssertFalse(tracker.hasSignal(now: at(0)))
        tracker.record(fix(at: 0, north: 0), now: at(0), counting: true)
        XCTAssertTrue(tracker.hasSignal(now: at(10)))
        XCTAssertFalse(tracker.hasSignal(now: at(11)))
        tracker.record(fix(at: 11, north: 3, accuracy: 50), now: at(11), counting: true)
        XCTAssertFalse(tracker.hasSignal(now: at(11)))
    }

    func testRoundTripsInsideActiveWorkout() throws {
        var tracker = OutdoorTracker()
        for second in 0...20 {
            tracker.record(fix(at: Double(second), north: Double(3 * second)), now: at(second), counting: true)
        }
        let workout = FreeRunlessWorkout.make()
        let active = ActiveWorkout(workout: workout, mode: .outdoor, startedAt: trackStart, checkpoint: .init(), outdoor: tracker)
        let decoded = try JSONDecoder().decode(ActiveWorkout.self, from: JSONEncoder().encode(active))
        XCTAssertEqual(decoded, active)

        let indoor = ActiveWorkout(workout: workout, mode: .treadmill, startedAt: trackStart, checkpoint: .init())
        let json = try JSONEncoder().encode(indoor)
        XCTAssertFalse(String(decoding: json, as: UTF8.self).contains("outdoor"))
        XCTAssertNil(try JSONDecoder().decode(ActiveWorkout.self, from: json).outdoor)
    }
}

/// A plain workout for checkpoint tests (free runs arrive in Task 6).
private enum FreeRunlessWorkout {
    static func make() -> Workout {
        Workout(date: trackStart, kind: .easy, title: "Easy", steps: [Step(kind: .run, measure: .time(seconds: 600))])
    }
}
