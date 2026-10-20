import XCTest
@testable import RunCore

final class WorkoutBuilderTests: XCTestCase {

    private let date = TestCalendar.date(2026, 11, 3)
    private let paces = TrainingPaces(easy: 573, tempo: 508, interval: 483, goal: 483)

    private func builder(_ distance: RaceDistance = .fiveK) -> WorkoutBuilder {
        WorkoutBuilder(paces: paces, goal: Goal(distance: distance, targetSeconds: 1500))
    }

    func testScalingRoundsHalvesUp() {
        XCTAssertEqual(Scaling.round(15, times: 3, over: 10), 5)
        XCTAssertEqual(Scaling.round(18, times: 3, over: 4), 14)
        XCTAssertEqual(Scaling.round(22, times: 1, over: 2), 11)
    }

    func testEasyRun() {
        let workout = builder().easy(minutes: 25, on: date)
        XCTAssertEqual(workout.kind, .easy)
        XCTAssertEqual(workout.title, "Easy run · 25 min")
        XCTAssertEqual(workout.date, date)
        XCTAssertEqual(shapes(workout), [StepShape(.run, .time(seconds: 1500), pace: 573)])
    }

    func testLongRun() {
        let workout = builder().longRun(minutes: 33, on: date)
        XCTAssertEqual(workout.kind, .longRun)
        XCTAssertEqual(workout.title, "Long run · 33 min")
        XCTAssertEqual(shapes(workout), [StepShape(.run, .time(seconds: 1980), pace: 573)])
    }

    func testTempo() {
        let workout = builder().tempo(level: 22, on: date)
        XCTAssertEqual(workout.kind, .tempo)
        XCTAssertEqual(workout.title, "Tempo · 11 min")
        XCTAssertEqual(shapes(workout), [
            StepShape(.warmup, .time(seconds: 420), pace: 573),
            StepShape(.run, .time(seconds: 660), pace: 508),
            StepShape(.cooldown, .time(seconds: 240), pace: 573),
        ])
    }

    func testFiveKIntervals() {
        let workout = builder().intervals(level: 20, on: date)
        XCTAssertEqual(workout.kind, .intervals)
        XCTAssertEqual(workout.title, "Intervals · 3 × 2:00")
        XCTAssertEqual(shapes(workout), [
            StepShape(.warmup, .time(seconds: 330), pace: 573),
            StepShape(.run, .time(seconds: 120), pace: 483, group: 1, count: 3),
            StepShape(.recovery, .time(seconds: 90), pace: 573, group: 1, count: 3),
            StepShape(.cooldown, .time(seconds: 240), pace: 573),
        ])
    }

    func testTenKIntervals() {
        let workout = builder(.tenK).intervals(level: 15, on: date)
        XCTAssertEqual(workout.title, "Intervals · 2 × 3:00")
        XCTAssertEqual(shapes(workout), [
            StepShape(.warmup, .time(seconds: 240), pace: 573),
            StepShape(.run, .time(seconds: 180), pace: 483, group: 1, count: 2),
            StepShape(.recovery, .time(seconds: 90), pace: 573, group: 1, count: 2),
            StepShape(.cooldown, .time(seconds: 180), pace: 573),
        ])
    }

    func testIntervalsLastAsLongAsTempo() {
        for distance in RaceDistance.allCases {
            for level in 15...50 {
                XCTAssertEqual(
                    plannedSeconds(builder(distance).intervals(level: level, on: date)),
                    plannedSeconds(builder(distance).tempo(level: level, on: date)),
                    "\(distance) level \(level)"
                )
            }
        }
    }

    func testWalkRunLongSessionHasExtraRep() {
        let workout = builder().walkRun(WalkRunLevel.ladder[0], extraRep: true, on: date)
        XCTAssertEqual(workout.kind, .walkRun)
        XCTAssertEqual(workout.title, "Run-walk · 9 × 1:00")
        XCTAssertEqual(shapes(workout), [
            StepShape(.warmup, .time(seconds: 300), pace: 1200),
            StepShape(.run, .time(seconds: 60), pace: 573, group: 1, count: 9),
            StepShape(.walk, .time(seconds: 90), pace: 1200, group: 1, count: 9),
            StepShape(.cooldown, .time(seconds: 300), pace: 1200),
        ])
        XCTAssertTrue(workout.treadmillTargetsOnly)
    }

    func testTimeTrial() {
        let workout = builder().timeTrial(afterWalkRun: false, on: date)
        XCTAssertEqual(workout.kind, .timeTrial)
        XCTAssertEqual(workout.title, "5K time trial")
        XCTAssertEqual(shapes(workout), [
            StepShape(.warmup, .time(seconds: 600), pace: 573),
            StepShape(.run, .distance(meters: 5000), pace: 483),
            StepShape(.cooldown, .time(seconds: 300), pace: 573),
        ])
        XCTAssertFalse(workout.treadmillTargetsOnly)
    }

    func testTimeTrialAfterWalkRunHasTreadmillSpeedsOnly() {
        let workout = builder(.tenK).timeTrial(afterWalkRun: true, on: date)
        XCTAssertEqual(workout.title, "10K time trial")
        XCTAssertEqual(shapes(workout), [
            StepShape(.warmup, .time(seconds: 300), pace: 1200),
            StepShape(.run, .distance(meters: 10000), pace: 573),
            StepShape(.cooldown, .time(seconds: 300), pace: 1200),
        ])
        XCTAssertTrue(workout.treadmillTargetsOnly)
    }

    func testLadderRunningTimeNeverDrops() {
        let running = WalkRunLevel.ladder.map { $0.runSeconds * $0.repeats }
        XCTAssertEqual(running, running.sorted())
        XCTAssertEqual(running.last, 1440)
        XCTAssertEqual(WalkRunLevel.startIndex(for: .newRunner), 0)
        XCTAssertEqual(WalkRunLevel.startIndex(for: .runsFiveMinutes), 4)
        XCTAssertNil(WalkRunLevel.startIndex(for: .runsTwentyMinutes))
        XCTAssertNil(WalkRunLevel.startIndex(for: .recentRace(distance: .fiveK, seconds: 1800)))
    }
}
