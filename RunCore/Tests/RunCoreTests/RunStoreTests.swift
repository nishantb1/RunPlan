import XCTest
@testable import RunCore

final class RunStoreTests: XCTestCase {

    private var directory: URL!
    private var store: JSONStore!
    private var runs: RunStore!

    private let route = [
        RoutePoint(latitude: 51.5, longitude: -0.1, timestamp: trackStart),
        RoutePoint(latitude: 51.501, longitude: -0.1, timestamp: trackStart.addingTimeInterval(30)),
    ]

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("runcore-\(UUID().uuidString)")
        store = JSONStore(directory: directory)
        runs = RunStore(store: store)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func outdoorRun() -> RunRecord {
        RunRecord(mode: .outdoor, startedAt: trackStart, durationSeconds: 600, distanceMeters: 1609.344, route: route)
    }

    func testRouteIsStoredSeparately() throws {
        let record = outdoorRun()
        try runs.save(record)

        let listed = try XCTUnwrap(runs.all().first)
        XCTAssertEqual(listed.id, record.id)
        XCTAssertEqual(listed.route, [])
        XCTAssertEqual(runs.route(for: listed), route)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("routes/\(record.id.uuidString).json").path))
    }

    func testOlderRecordWithItsRouteInsideStillHasItsRoute() throws {
        let record = outdoorRun()
        try store.save(record, as: "records/\(record.id.uuidString).json")

        let listed = try XCTUnwrap(runs.all().first)
        XCTAssertEqual(listed.route, [])
        XCTAssertEqual(runs.route(for: listed), route)
    }

    func testSavingAListedOlderRecordKeepsItsRoute() throws {
        let record = outdoorRun()
        try store.save(record, as: "records/\(record.id.uuidString).json")

        var listed = try XCTUnwrap(runs.all().first)
        listed.notes = "Windy"
        try runs.save(listed)

        XCTAssertEqual(runs.route(for: listed), route)
        XCTAssertEqual(runs.all().first?.notes, "Windy")
    }

    func testOlderRecordsRoutesMoveToTheirOwnFiles() throws {
        let record = outdoorRun()
        try store.save(record, as: "records/\(record.id.uuidString).json")
        let treadmill = RunRecord(mode: .treadmill, startedAt: trackStart.addingTimeInterval(3600), durationSeconds: 600, distanceMeters: 0)
        try runs.save(treadmill)

        runs.moveEmbeddedRoutes()

        XCTAssertEqual(store.load([RoutePoint].self, from: "routes/\(record.id.uuidString).json"), route)
        XCTAssertEqual(store.load(RunRecord.self, from: "records/\(record.id.uuidString).json")?.route, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("routes/\(treadmill.id.uuidString).json").path))
        XCTAssertEqual(runs.all().count, 2)
    }

    func testRunWithoutRouteWritesNoRouteFile() throws {
        let record = RunRecord(mode: .treadmill, startedAt: trackStart, durationSeconds: 600, distanceMeters: 0)
        try runs.save(record)
        XCTAssertEqual(runs.route(for: record), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("routes").path))
    }

    func testDeletingEverything() throws {
        try runs.save(outdoorRun())
        let plans = PlanStore(store: store)
        try plans.save(PlanGenerator.generate(makeProfile(), calendar: TestCalendar.utc))

        runs.deleteAll()
        plans.delete()

        XCTAssertEqual(runs.all(), [])
        XCTAssertNil(plans.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("routes").path))
    }
}
