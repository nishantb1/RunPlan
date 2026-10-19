import XCTest
@testable import RunCore

final class ActiveWorkoutStoreTests: XCTestCase {

    private var directory: URL!
    private var store: JSONStore!
    private var checkpoints: ActiveWorkoutStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("runcore-\(UUID().uuidString)")
        store = JSONStore(directory: directory)
        checkpoints = ActiveWorkoutStore(store: store)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    /// An outdoor workout `seconds` in, having run north at 3 m/s.
    private func outdoorWorkout(after seconds: Int) -> ActiveWorkout {
        var tracker = OutdoorTracker()
        for second in 0...seconds {
            tracker.record(fix(at: Double(second), north: Double(3 * second)), now: trackStart.addingTimeInterval(Double(second)), counting: true)
        }
        let workout = Workout(date: trackStart, kind: .easy, title: "Easy", steps: [Step(kind: .run, measure: .time(seconds: 600))])
        return ActiveWorkout(workout: workout, mode: .outdoor, startedAt: trackStart, checkpoint: .init(), outdoor: tracker)
    }

    func testRouteIsKeptInItsOwnFile() throws {
        let active = outdoorWorkout(after: 20)
        try checkpoints.save(active, includingRoute: true)

        XCTAssertEqual(checkpoints.load(), active)
        XCTAssertEqual(store.load(ActiveWorkout.self, from: "active.json")?.outdoor?.route, [])
    }

    func testCheckpointWithoutTheRouteKeepsTheRouteLastSaved() throws {
        try checkpoints.save(outdoorWorkout(after: 20), includingRoute: true)
        let later = outdoorWorkout(after: 25)
        try checkpoints.save(later, includingRoute: false)

        let loaded = try XCTUnwrap(checkpoints.load())
        XCTAssertEqual(loaded.outdoor?.totalMeters, later.outdoor?.totalMeters)
        XCTAssertEqual(loaded.outdoor?.route.count, 21)
    }

    func testOlderCheckpointWithTheRouteInsideStillLoads() throws {
        let active = outdoorWorkout(after: 20)
        try store.save(active, as: "active.json")

        XCTAssertEqual(checkpoints.load(), active)
    }

    func testRouteFromAnotherWorkoutIsIgnored() throws {
        try checkpoints.save(outdoorWorkout(after: 20), includingRoute: true)
        var next = outdoorWorkout(after: 5)
        next.startedAt = trackStart.addingTimeInterval(3600)
        try checkpoints.save(next, includingRoute: false)

        XCTAssertEqual(checkpoints.load()?.outdoor?.route, [])
    }

    func testDeleteRemovesBothFiles() throws {
        try checkpoints.save(outdoorWorkout(after: 20), includingRoute: true)
        checkpoints.delete()

        XCTAssertNil(checkpoints.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("active-route.json").path))
    }
}
