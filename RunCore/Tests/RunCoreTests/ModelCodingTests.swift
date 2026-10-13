import XCTest
@testable import RunCore

final class ModelCodingTests: XCTestCase {

    private func roundTrip<T: Codable & Equatable>(_ value: T, file: StaticString = #filePath, line: UInt = #line) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        XCTAssertEqual(decoded, value, file: file, line: line)
    }

    func testStepRoundTripsBothMeasures() throws {
        try roundTrip(Step(kind: .run, measure: .time(seconds: 90), targetPaceSecondsPerMile: 766, repeatGroup: 1, repeatCount: 6))
        try roundTrip(Step(kind: .run, measure: .distance(meters: 5000), targetPaceSecondsPerMile: nil))
    }

    func testWorkoutRoundTrips() throws {
        try roundTrip(SampleWorkouts.runWalk(on: Date(timeIntervalSince1970: 1_800_000_000)))
    }

    func testRunRecordRoundTrips() throws {
        let record = RunRecord(
            workoutID: UUID(),
            mode: .outdoor,
            startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            durationSeconds: 1800,
            distanceMeters: 5000,
            perceivedEffort: 3,
            notes: "Felt good",
            splits: [Split(index: 1, distanceMeters: 1609.344, durationSeconds: 590)],
            route: [RoutePoint(latitude: 32.98, longitude: -96.75, timestamp: Date(timeIntervalSince1970: 1_800_000_010))]
        )
        try roundTrip(record)
    }

    func testSampleWorkoutShape() {
        let workout = SampleWorkouts.runWalk()
        XCTAssertEqual(workout.kind, .walkRun)
        XCTAssertEqual(workout.steps.map(\.kind), [.warmup, .run, .walk, .cooldown])
        XCTAssertEqual(workout.steps[1].repeatGroup, 1)
        XCTAssertEqual(workout.steps[2].repeatGroup, 1)
        XCTAssertEqual(workout.steps[1].repeatCount, 6)
        XCTAssertEqual(workout.steps[1].measure, .time(seconds: 90))
        XCTAssertEqual(workout.steps[1].targetPaceSecondsPerMile, 766)
    }
}
