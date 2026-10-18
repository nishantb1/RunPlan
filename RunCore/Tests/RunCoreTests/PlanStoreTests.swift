import XCTest
@testable import RunCore

final class PlanStoreTests: XCTestCase {

    private var directory: URL!
    private var plans: PlanStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("runcore-\(UUID().uuidString)")
        plans = PlanStore(store: JSONStore(directory: directory))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testSaveThenLoad() throws {
        let plan = PlanGenerator.generate(makeProfile(fitness: .newRunner, weeks: 10), calendar: TestCalendar.utc)
        try plans.save(plan)
        XCTAssertEqual(plans.load(), plan)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("plan.json").path))
    }

    func testMissingPlanLoadsAsNil() {
        XCTAssertNil(plans.load())
    }
}
