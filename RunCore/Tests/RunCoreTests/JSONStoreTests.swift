import XCTest
@testable import RunCore

final class JSONStoreTests: XCTestCase {

    private var directory: URL!
    private var store: JSONStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("runcore-\(UUID().uuidString)")
        store = JSONStore(directory: directory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSaveThenLoad() throws {
        let workout = SampleWorkouts.runWalk(on: Date(timeIntervalSince1970: 1_800_000_000))
        try store.save(workout, as: "workout.json")
        XCTAssertEqual(store.load(Workout.self, from: "workout.json"), workout)
    }

    func testMissingFileLoadsAsNil() {
        XCTAssertNil(store.load(Workout.self, from: "nope.json"))
    }

    func testCorruptFileIsSetAside() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("workout.json"))

        XCTAssertNil(store.load(Workout.self, from: "workout.json"))

        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertFalse(names.contains("workout.json"))
        XCTAssertEqual(names.filter { $0.hasPrefix("workout.json.corrupt-") }.count, 1)
    }

    func testDeleteRemovesFile() throws {
        try store.save(RunMode.treadmill, as: "mode.json")
        store.delete("mode.json")
        XCTAssertNil(store.load(RunMode.self, from: "mode.json"))
    }

    func testRunStoreReturnsNewestFirst() throws {
        let runs = RunStore(store: store)
        let older = RunRecord(mode: .treadmill, startedAt: Date(timeIntervalSince1970: 1_800_000_000), durationSeconds: 600, distanceMeters: 1600)
        let newer = RunRecord(mode: .treadmill, startedAt: Date(timeIntervalSince1970: 1_800_100_000), durationSeconds: 900, distanceMeters: 2400)
        try runs.save(older)
        try runs.save(newer)

        XCTAssertEqual(runs.all().map(\.id), [newer.id, older.id])
    }
}
