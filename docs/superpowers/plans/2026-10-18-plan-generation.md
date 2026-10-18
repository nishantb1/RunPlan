# Plan Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** RunPlan generates a 5K or 10K training plan from onboarding answers, shows it week by week with today's workout on top, lets each workout be edited, and marks workouts done when their run is saved.

**Architecture:** All plan logic lives in `RunCore` and is unit-tested on Linux: profile and plan models, `PaceCalculator` (Riegel-based paces and a goal check), `WorkoutBuilder` (one function per workout kind), and `PlanGenerator` (week kinds, run-day roles, walk-run ladder, 10 percent progression). The app adds an onboarding flow, a Plan tab, a Runs tab and a workout editor on top, storing the plan as `plan.json` next to the run records.

**Tech Stack:** Swift 6.4 in WSL (Ubuntu 24.04), xtool 1.22.2, SwiftUI (iOS 17), XCTest. No third-party packages.

**Spec:** `docs/superpowers/specs/2026-10-12-runplan-design.md`, build stage 3 (sections "Data model", "Plan generator", "Screens" 1 and 2, "Testing").

---

## Conventions for every task

Run from Git Bash on Windows:

```bash
# Unit tests (RunCore only, runs on Linux)
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 -u nishant -- bash -lc \
  "cd /mnt/c/Users/bobba/Documents/RunPlan/RunCore && swift test 2>&1 | tail -15"

# App build for iPhone (no Apple login needed)
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 -u nishant -- bash -lc \
  "cd /mnt/c/Users/bobba/Documents/RunPlan && xtool dev build 2>&1 | tr '\r' '\n' | tail -15"
```

These are called **TEST** and **BUILD** below. To run one test class, add `--filter <ClassName>` after `swift test`.

Rules carried over from stage 2: one type per file (small private helper views may share their screen's file), value types where possible, no force unwrapping outside tests, no SwiftUI/UIKit/AVFoundation imports in `RunCore`. Everything `RunCore` exposes to the app is `public`. Commit after each task with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

`RunCore` tasks (1 to 5, and the first half of 9) are test-first. App tasks (6 to 9) have no unit tests; they are verified with BUILD, and on the phone at the end (Task 10).

## Design decisions fixed by this plan

These numbers were prototyped in Python against every profile the tests cover (2 goal distances × 5 fitness levels × 2 to 5 days × 6 to 16 weeks). Build weeks never grow by more than 10 percent plus one minute of rounding per workout (worst case 12 percent), and cutback weeks never exceed 80 percent of the week before (worst case 79 percent).

- **Paces** hang off 5K pace: intervals at 5K pace, tempo 25 s/mi slower, easy 90 s/mi slower. Times convert between distances with Riegel's formula, `t2 = t1 × (d2 / d1)^1.06`. The reference is the goal time, else a recent race; with neither, fixed defaults (easy 13:30, tempo 12:00, intervals 11:00 /mi) and no goal pace.
- **Goal check:** improvement of 1 percent per training week is treated as plausible. Current ability is the race result, or a typical 5K for the fitness level (45:00 new, 40:00 five minutes, 35:00 twenty minutes), converted to the goal distance.
- **Week kinds:** the last week is the taper, every fourth other week is a cutback, the rest are build weeks.
- **Run-day roles:** run days are ordered Monday first. The last is the long run, the first is the quality session, the others are easy. With 2 days there is a quality session and a long run.
- **Walk-run ladder:** new runners start on rung 0, five-minute runners on rung 4. They climb one rung per build week, a cutback or taper week repeats the previous rung, and after the last rung the plan switches to running. Walk-run steps have no pace targets.

  | Rung | Run | Walk | Reps | Running per session |
  |---|---|---|---|---|
  | 0 | 1:00 | 1:30 | 8 | 8:00 |
  | 1 | 1:30 | 1:30 | 7 | 10:30 |
  | 2 | 2:00 | 1:30 | 6 | 12:00 |
  | 3 | 3:00 | 1:30 | 5 | 15:00 |
  | 4 | 4:00 | 1:00 | 5 | 20:00 |
  | 5 | 6:00 | 1:00 | 4 | 24:00 |
  | 6 | 8:00 | 1:00 | 3 | 24:00 |

  Each session adds a 5 minute walk warm-up and cool-down. The long-run day gets one extra rep.
- **Running weeks:** the week's easy-run length starts at 20 minutes (30 with a race result) and grows by `× 11 / 10` (integer division) each build week, capped at 40 minutes (5K) or 50 (10K). A cutback week uses 75 percent of it. The long run is 1.5 times that, capped at 60 or 90 minutes. A taper week has easy runs at 60 percent and ends in the time trial.
- **Quality sessions** alternate intervals and tempo, intervals first. A tempo session at level `L` minutes is a warm-up, tempo block and cool-down of 30, 50 and 20 percent of `L`. An intervals session fills the same block with reps (2:00 for 5K, 3:00 for 10K) and 90 second recoveries, between 2 and 8 reps. Its warm-up absorbs the remainder, so both sessions last exactly as long. Every level from 15 to 50 matches.
- **All scaling is integer arithmetic** rounding halves up (`Scaling.round`), so plans are identical on Linux and iOS.
- **Measures:** everything is timed except the time trial, which is a distance step at the goal distance. Timed steps suit treadmill mode, where distance steps must be advanced by hand.
- **Storage:** the profile is stored inside `plan.json`, not in a separate `profile.json`. `Profile.daysPerWeek` is derived from `runDays`, and the spec's fixed `units` field is omitted. Task 10 records these deviations in the spec.

## File structure

```
RunCore/Sources/RunCore/
  Models/   RaceDistance.swift Goal.swift Fitness.swift Weekday.swift Profile.swift      (new)
            WeekKind.swift Week.swift Plan.swift Workout+RepeatGroups.swift            (new)
  Planning/ Scaling.swift TrainingPaces.swift GoalAssessment.swift PaceCalculator.swift (new)
            WalkRunLevel.swift WorkoutBuilder.swift PlanGenerator.swift                (new)
  Storage/  PlanStore.swift                                                            (new)
RunCore/Tests/RunCoreTests/
  PlanTestSupport.swift PlanModelTests.swift PaceCalculatorTests.swift                 (new)
  WorkoutBuilderTests.swift PlanGeneratorTests.swift PlanTests.swift                   (new)
  PlanStoreTests.swift WorkoutRepeatGroupTests.swift                                   (new)
Sources/RunPlan/
  App/AppModel.swift RootView.swift                                                    (modify)
  Onboarding/OnboardingModel.swift OnboardingView.swift DurationPicker.swift
             PlanPreviewView.swift                                                     (new)
  Plan/PlanView.swift WorkoutRow.swift WorkoutEditView.swift StepEditor.swift          (new)
  Runs/RunsView.swift                                                                  (new)
  Workout/WorkoutDetailView.swift                                                      (modify)
  Home/HomeView.swift                                                                  (delete)
README.md, docs/superpowers/specs/2026-10-12-runplan-design.md                         (modify)
```

---

### Task 1: Profile and plan models

**Goal:** Codable value types for the onboarding answers and the plan: `RaceDistance`, `Goal`, `Fitness`, `Weekday`, `Profile`, `WeekKind`, `Week`, `Plan`.

**Files:**
- Create: `RunCore/Sources/RunCore/Models/RaceDistance.swift`, `Goal.swift`, `Fitness.swift`, `Weekday.swift`, `Profile.swift`, `WeekKind.swift`, `Week.swift`, `Plan.swift`
- Create: `RunCore/Tests/RunCoreTests/PlanTestSupport.swift`, `RunCore/Tests/RunCoreTests/PlanModelTests.swift`

**Acceptance Criteria:**
- [ ] A profile with a race result, and one with a "just finish" goal, round-trip through JSON unchanged
- [ ] `Profile` keeps `runDays` sorted Monday first and derives `daysPerWeek`
- [ ] Duplicate run days are removed
- [ ] `Weekday(of:calendar:)` matches the calendar, and `Weekday.allCases` runs Monday to Sunday
- [ ] A `Plan` round-trips through JSON unchanged

**Verify:** TEST → `Executed N tests, with 0 failures`

**Steps:**

- [ ] **Step 1: Write the shared test support file**

`RunCore/Tests/RunCoreTests/PlanTestSupport.swift`:

```swift
import Foundation
@testable import RunCore

/// A step without its random ID, so generated steps can be compared with expected ones.
struct StepShape: Equatable, CustomStringConvertible {
    var kind: StepKind
    var measure: StepMeasure
    var pace: Int?
    var group: Int?
    var count: Int?

    init(_ kind: StepKind, _ measure: StepMeasure, pace: Int? = nil, group: Int? = nil, count: Int? = nil) {
        self.kind = kind
        self.measure = measure
        self.pace = pace
        self.group = group
        self.count = count
    }

    init(_ step: Step) {
        self.init(step.kind, step.measure, pace: step.targetPaceSecondsPerMile, group: step.repeatGroup, count: step.repeatCount)
    }

    var description: String {
        "\(kind) \(measure) pace:\(pace.map(String.init) ?? "-") group:\(group.map(String.init) ?? "-") count:\(count.map(String.init) ?? "-")"
    }
}

func shapes(_ workout: Workout) -> [StepShape] {
    workout.steps.map { StepShape($0) }
}

/// Planned seconds of a workout's timed steps after repeats are expanded. Distance steps count as zero.
func plannedSeconds(_ workout: Workout) -> Int {
    StepExpander.expand(workout.steps).compactMap(\.durationSeconds).reduce(0, +)
}

enum TestCalendar {
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

/// A profile starting Monday 2 November 2026. Defaults: 5K to finish, runs 20 minutes,
/// Tuesday, Thursday and Saturday, 8 weeks.
func makeProfile(
    goal: Goal = Goal(distance: .fiveK),
    fitness: Fitness = .runsTwentyMinutes,
    runDays: [Weekday] = [.tuesday, .thursday, .saturday],
    weeks: Int = 8
) -> Profile {
    Profile(goal: goal, fitness: fitness, runDays: runDays, planWeeks: weeks, startDate: TestCalendar.date(2026, 11, 2))
}
```

- [ ] **Step 2: Write the failing model tests**

`RunCore/Tests/RunCoreTests/PlanModelTests.swift`:

```swift
import XCTest
@testable import RunCore

final class PlanModelTests: XCTestCase {

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }

    func testProfileWithRaceResultRoundTrips() throws {
        let profile = makeProfile(
            goal: Goal(distance: .tenK, targetSeconds: 3300),
            fitness: .recentRace(distance: .fiveK, seconds: 1620),
            weeks: 10
        )
        XCTAssertEqual(try roundTrip(profile), profile)
    }

    func testJustFinishGoalRoundTrips() throws {
        let profile = makeProfile(goal: Goal(distance: .fiveK), fitness: .newRunner)
        XCTAssertNil(profile.goal.targetSeconds)
        XCTAssertEqual(try roundTrip(profile), profile)
    }

    func testRunDaysAreKeptMondayFirst() {
        let profile = makeProfile(runDays: [.sunday, .monday, .wednesday])
        XCTAssertEqual(profile.runDays, [.monday, .wednesday, .sunday])
        XCTAssertEqual(profile.daysPerWeek, 3)
    }

    func testDuplicateRunDaysAreRemoved() {
        let profile = makeProfile(runDays: [.saturday, .tuesday, .saturday])
        XCTAssertEqual(profile.runDays, [.tuesday, .saturday])
        XCTAssertEqual(profile.daysPerWeek, 2)
    }

    func testWeekdayMatchesCalendar() {
        XCTAssertEqual(Weekday(of: TestCalendar.date(2026, 11, 2), calendar: TestCalendar.utc), .monday)
        XCTAssertEqual(Weekday(of: TestCalendar.date(2026, 11, 8), calendar: TestCalendar.utc), .sunday)
        XCTAssertEqual(Weekday.allCases.first, .monday)
        XCTAssertEqual(Weekday.allCases.last, .sunday)
        XCTAssertTrue(Weekday.saturday < .sunday)
        XCTAssertEqual(Weekday.thursday.name, "Thursday")
    }

    func testRaceDistances() {
        XCTAssertEqual(RaceDistance.fiveK.meters, 5000)
        XCTAssertEqual(RaceDistance.tenK.displayName, "10K")
    }

    func testPlanRoundTrips() throws {
        let workout = SampleWorkouts.runWalk(on: TestCalendar.date(2026, 11, 3))
        let plan = Plan(profile: makeProfile(), weeks: [Week(number: 1, kind: .build, workouts: [workout])])
        XCTAssertEqual(try roundTrip(plan), plan)
        XCTAssertEqual(plan.weeks[0].id, 1)
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: TEST with `--filter PlanModelTests`
Expected: build errors such as `cannot find 'Goal' in scope`.

- [ ] **Step 4: Write the models**

`RunCore/Sources/RunCore/Models/RaceDistance.swift`:

```swift
import Foundation

/// A goal or race distance. v1 offers 5K and 10K only.
public enum RaceDistance: String, Codable, CaseIterable, Sendable {
    case fiveK
    case tenK

    public var meters: Double {
        switch self {
        case .fiveK: return 5000
        case .tenK: return 10000
        }
    }

    /// "5K" or "10K".
    public var displayName: String {
        switch self {
        case .fiveK: return "5K"
        case .tenK: return "10K"
        }
    }
}
```

`RunCore/Sources/RunCore/Models/Goal.swift`:

```swift
import Foundation

/// What the plan builds towards. A nil `targetSeconds` means "just finish".
public struct Goal: Codable, Equatable, Sendable {
    public var distance: RaceDistance
    public var targetSeconds: Int?

    public init(distance: RaceDistance, targetSeconds: Int? = nil) {
        self.distance = distance
        self.targetSeconds = targetSeconds
    }
}
```

`RunCore/Sources/RunCore/Models/Fitness.swift`:

```swift
import Foundation

/// The runner's current fitness, chosen in onboarding.
public enum Fitness: Codable, Equatable, Sendable {
    case newRunner
    /// Can run about 5 minutes without stopping.
    case runsFiveMinutes
    /// Can run 20 minutes or more without stopping.
    case runsTwentyMinutes
    /// Has a recent race or time-trial result.
    case recentRace(distance: RaceDistance, seconds: Int)
}
```

`RunCore/Sources/RunCore/Models/Weekday.swift`:

```swift
import Foundation

/// A day of the week. Raw values match `Calendar` weekday numbers (1 is Sunday), while
/// `allCases` and sorting run Monday first.
public enum Weekday: Int, Codable, CaseIterable, Comparable, Sendable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    public init(of date: Date, calendar: Calendar) {
        self = Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .monday
    }

    /// 0 for Monday through 6 for Sunday.
    public var mondayFirstIndex: Int {
        (rawValue + 5) % 7
    }

    public var name: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.mondayFirstIndex < rhs.mondayFirstIndex
    }
}
```

`RunCore/Sources/RunCore/Models/Profile.swift`:

```swift
import Foundation

/// The onboarding answers a plan is generated from. Distances are in miles throughout v1.
public struct Profile: Codable, Equatable, Sendable {
    public static let daysPerWeekRange = 2...5
    public static let planWeeksRange = 6...16

    public var goal: Goal
    public var fitness: Fitness
    /// Unique and sorted Monday first by `init`; the generator re-sorts, so later edits need not.
    public var runDays: [Weekday]
    public var planWeeks: Int
    public var startDate: Date

    public var daysPerWeek: Int { runDays.count }

    public init(goal: Goal, fitness: Fitness, runDays: [Weekday], planWeeks: Int, startDate: Date) {
        self.goal = goal
        self.fitness = fitness
        self.runDays = Array(Set(runDays)).sorted()
        self.planWeeks = planWeeks
        self.startDate = startDate
    }
}
```

`RunCore/Sources/RunCore/Models/WeekKind.swift`:

```swift
import Foundation

/// `.cutback` is an easier week every fourth week; `.taper` is the last week, ending in the
/// time trial.
public enum WeekKind: String, Codable, CaseIterable, Sendable {
    case build
    case cutback
    case taper

    public var displayName: String {
        switch self {
        case .build: return "Build"
        case .cutback: return "Cutback"
        case .taper: return "Taper"
        }
    }
}
```

`RunCore/Sources/RunCore/Models/Week.swift`:

```swift
import Foundation

/// One week of a plan. `number` starts at 1; workouts are in date order.
public struct Week: Identifiable, Codable, Equatable, Sendable {
    public var number: Int
    public var kind: WeekKind
    public var workouts: [Workout]

    public var id: Int { number }

    public init(number: Int, kind: WeekKind, workouts: [Workout]) {
        self.number = number
        self.kind = kind
        self.workouts = workouts
    }
}
```

`RunCore/Sources/RunCore/Models/Plan.swift`:

```swift
import Foundation

/// A generated training plan and the profile it was generated from.
public struct Plan: Codable, Equatable, Sendable {
    public var profile: Profile
    public var weeks: [Week]

    public init(profile: Profile, weeks: [Week]) {
        self.profile = profile
        self.weeks = weeks
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass, including the 6 in `PlanModelTests`.

- [ ] **Step 6: Commit**

```bash
git add RunCore/Sources/RunCore/Models RunCore/Tests/RunCoreTests/PlanTestSupport.swift RunCore/Tests/RunCoreTests/PlanModelTests.swift
git commit -m "Add profile and plan models" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Pace calculator and goal check

**Goal:** `PaceCalculator` derives easy, tempo, interval and goal paces and judges whether a goal time is plausible in the chosen plan length.

**Files:**
- Create: `RunCore/Sources/RunCore/Planning/TrainingPaces.swift`, `GoalAssessment.swift`, `PaceCalculator.swift`
- Create: `RunCore/Tests/RunCoreTests/PaceCalculatorTests.swift`

**Acceptance Criteria:**
- [ ] A 25:00 5K goal gives easy 573, tempo 508, intervals 483 and goal 483 s/mi
- [ ] A 50:00 10K goal gives easy 553, tempo 488, intervals 463 and goal 483 s/mi
- [ ] "Just finish" with a 30:00 5K race and a 10K goal gives easy 669, tempo 604, intervals 579 and goal 604
- [ ] "Just finish" with no race uses the defaults, with no goal pace
- [ ] Goal check: 28:00 from a 30:00 5K in 8 weeks is reachable; 26:00 suggests 14 weeks; a new runner aiming for 25:00 gets no suggestion

**Verify:** TEST with `--filter PaceCalculatorTests` → `Executed 9 tests, with 0 failures`

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/PaceCalculatorTests.swift`:

```swift
import XCTest
@testable import RunCore

final class PaceCalculatorTests: XCTestCase {

    func testEquivalentTimeUsesRiegel() {
        XCTAssertEqual(PaceCalculator.equivalentTime(seconds: 1800, from: .fiveK, to: .tenK), 3753)
        XCTAssertEqual(PaceCalculator.equivalentTime(seconds: 1500, from: .fiveK, to: .fiveK), 1500)
    }

    func testPaceOverDistance() {
        XCTAssertEqual(PaceCalculator.pace(seconds: 1500, over: .fiveK), 483)
        XCTAssertEqual(PaceCalculator.pace(seconds: 3000, over: .tenK), 483)
    }

    func testPacesFromFiveKGoal() {
        let paces = PaceCalculator.paces(goal: Goal(distance: .fiveK, targetSeconds: 1500), fitness: .newRunner)
        XCTAssertEqual(paces, TrainingPaces(easy: 573, tempo: 508, interval: 483, goal: 483))
    }

    func testPacesFromTenKGoal() {
        let paces = PaceCalculator.paces(goal: Goal(distance: .tenK, targetSeconds: 3000), fitness: .runsTwentyMinutes)
        XCTAssertEqual(paces, TrainingPaces(easy: 553, tempo: 488, interval: 463, goal: 483))
    }

    func testJustFinishUsesRaceResult() {
        let paces = PaceCalculator.paces(
            goal: Goal(distance: .tenK),
            fitness: .recentRace(distance: .fiveK, seconds: 1800)
        )
        XCTAssertEqual(paces, TrainingPaces(easy: 669, tempo: 604, interval: 579, goal: 604))
    }

    func testJustFinishWithNoRaceUsesDefaults() {
        let paces = PaceCalculator.paces(goal: Goal(distance: .fiveK), fitness: .runsTwentyMinutes)
        XCTAssertEqual(paces, .defaults)
        XCTAssertNil(paces.goal)
    }

    func testGoalCheckFromRaceResult() {
        let race = Fitness.recentRace(distance: .fiveK, seconds: 1800)
        XCTAssertEqual(PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK, targetSeconds: 1680), fitness: race)), .reachable)
        XCTAssertEqual(
            PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK, targetSeconds: 1560), fitness: race)),
            .ambitious(suggestedWeeks: 14)
        )
    }

    func testGoalCheckFromFitnessLevel() {
        XCTAssertEqual(
            PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK, targetSeconds: 1500), fitness: .newRunner, weeks: 16)),
            .ambitious(suggestedWeeks: nil)
        )
        XCTAssertEqual(
            PaceCalculator.assess(makeProfile(goal: Goal(distance: .tenK, targetSeconds: 4200), fitness: .runsTwentyMinutes, weeks: 12)),
            .reachable
        )
        XCTAssertEqual(PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK), fitness: .newRunner)), .reachable)
    }

    func testGoalCheckIsExactAtWholePercentBoundaries() {
        let race = Fitness.recentRace(distance: .fiveK, seconds: 1800)
        XCTAssertEqual(
            PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK, targetSeconds: 1548), fitness: race, weeks: 8)),
            .ambitious(suggestedWeeks: 14)
        )
        XCTAssertEqual(
            PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK, targetSeconds: 1512), fitness: race, weeks: 16)),
            .reachable
        )
        XCTAssertEqual(
            PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK, targetSeconds: 1494), fitness: race, weeks: 16)),
            .ambitious(suggestedWeeks: nil)
        )
        XCTAssertEqual(
            PaceCalculator.assess(makeProfile(goal: Goal(distance: .fiveK, targetSeconds: 1980), fitness: race, weeks: 8)),
            .reachable
        )
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: TEST with `--filter PaceCalculatorTests`
Expected: build errors such as `cannot find 'PaceCalculator' in scope`.

- [ ] **Step 3: Write the implementation**

`RunCore/Sources/RunCore/Planning/TrainingPaces.swift`:

```swift
import Foundation

/// Target paces in seconds per mile. `goal` is nil when there is no goal time or race result
/// to derive it from.
public struct TrainingPaces: Equatable, Sendable {
    /// Conservative fixed paces for a runner with no goal time and no race result.
    public static let defaults = TrainingPaces(easy: 810, tempo: 720, interval: 660, goal: nil)

    public var easy: Int
    public var tempo: Int
    public var interval: Int
    public var goal: Int?

    public init(easy: Int, tempo: Int, interval: Int, goal: Int?) {
        self.easy = easy
        self.tempo = tempo
        self.interval = interval
        self.goal = goal
    }
}
```

`RunCore/Sources/RunCore/Planning/GoalAssessment.swift`:

```swift
import Foundation

public enum GoalAssessment: Equatable, Sendable {
    case reachable
    /// The goal time needs more improvement than the plan length allows. `suggestedWeeks` is a
    /// plan length that would allow it, or nil when even the longest plan would not.
    case ambitious(suggestedWeeks: Int?)
}
```

`RunCore/Sources/RunCore/Planning/PaceCalculator.swift`:

```swift
import Foundation

/// Training paces and the goal check. Paces are in seconds per mile.
///
/// Times at different distances are related with Riegel's formula, t2 = t1 × (d2 / d1)^1.06.
/// Training paces hang off 5K pace: intervals at 5K pace, tempo 25 s/mi slower, easy 90 s/mi
/// slower.
public enum PaceCalculator {
    static let riegelExponent = 1.06
    static let tempoOffset = 25
    static let easyOffset = 90
    /// Improvement per training week that the goal check treats as plausible, in percent.
    static let weeklyImprovementPercent = 1
    /// Assumed typical 5K times, in seconds, for runners without a race result.
    static let newRunnerFiveKSeconds = 2700
    static let fiveMinuteRunnerFiveKSeconds = 2400
    static let twentyMinuteRunnerFiveKSeconds = 2100

    /// The time at `to` equivalent to `seconds` at `from`.
    public static func equivalentTime(seconds: Int, from: RaceDistance, to: RaceDistance) -> Int {
        Int((Double(seconds) * pow(to.meters / from.meters, riegelExponent)).rounded())
    }

    /// Average pace for covering `distance` in `seconds`.
    public static func pace(seconds: Int, over distance: RaceDistance) -> Int {
        Int((Double(seconds) / Pace.miles(fromMeters: distance.meters)).rounded())
    }

    /// Paces from the goal time, or from a recent race when the goal is to finish. With
    /// neither, the conservative defaults.
    public static func paces(goal: Goal, fitness: Fitness) -> TrainingPaces {
        let fiveKSeconds: Int
        let goalPace: Int
        if let target = goal.targetSeconds {
            fiveKSeconds = equivalentTime(seconds: target, from: goal.distance, to: .fiveK)
            goalPace = pace(seconds: target, over: goal.distance)
        } else if case .recentRace(let distance, let seconds) = fitness {
            fiveKSeconds = equivalentTime(seconds: seconds, from: distance, to: .fiveK)
            goalPace = pace(seconds: equivalentTime(seconds: seconds, from: distance, to: goal.distance), over: goal.distance)
        } else {
            return .defaults
        }
        let fiveKPace = pace(seconds: fiveKSeconds, over: .fiveK)
        return TrainingPaces(
            easy: fiveKPace + easyOffset,
            tempo: fiveKPace + tempoOffset,
            interval: fiveKPace,
            goal: goalPace
        )
    }

    /// Whether the goal time is plausible in the profile's `planWeeks` from the runner's current ability.
    public static func assess(_ profile: Profile) -> GoalAssessment {
        guard let target = profile.goal.targetSeconds else { return .reachable }
        let current = currentTime(at: profile.goal.distance, fitness: profile.fitness)
        guard current > 0, target > 0 else { return .reachable }
        // Needed improvement as a fraction is 1 - target / current. Compare and round up in whole
        // percent with integers so exact boundaries are exact.
        let allowedPercent = weeklyImprovementPercent * profile.planWeeks
        if 100 * target >= (100 - allowedPercent) * current {
            return .reachable
        }
        let neededPercent = (100 * (current - target) + current - 1) / current
        let weeks = (neededPercent + weeklyImprovementPercent - 1) / weeklyImprovementPercent
        return .ambitious(suggestedWeeks: Profile.planWeeksRange.contains(weeks) ? weeks : nil)
    }

    /// What the runner could run `distance` in today: their race result scaled to that
    /// distance, or a typical time for their fitness level.
    static func currentTime(at distance: RaceDistance, fitness: Fitness) -> Int {
        switch fitness {
        case .recentRace(let raceDistance, let seconds):
            return equivalentTime(seconds: seconds, from: raceDistance, to: distance)
        case .newRunner:
            return equivalentTime(seconds: newRunnerFiveKSeconds, from: .fiveK, to: distance)
        case .runsFiveMinutes:
            return equivalentTime(seconds: fiveMinuteRunnerFiveKSeconds, from: .fiveK, to: distance)
        case .runsTwentyMinutes:
            return equivalentTime(seconds: twentyMinuteRunnerFiveKSeconds, from: .fiveK, to: distance)
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add RunCore/Sources/RunCore/Planning RunCore/Tests/RunCoreTests/PaceCalculatorTests.swift
git commit -m "Add pace calculator and goal check" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Workout builder and walk-run ladder

**Goal:** One function per planned workout kind (easy, long run, tempo, intervals, walk-run, time trial), plus the walk-run ladder, with intervals and tempo sessions of equal length at every level.

**Files:**
- Create: `RunCore/Sources/RunCore/Planning/Scaling.swift`, `WalkRunLevel.swift`, `WorkoutBuilder.swift`
- Create: `RunCore/Tests/RunCoreTests/WorkoutBuilderTests.swift`

**Acceptance Criteria:**
- [ ] Each workout kind produces the exact steps, paces and title in the tests
- [ ] An intervals session lasts exactly as long as a tempo session at every level from 15 to 50, for both distances
- [ ] Running time per walk-run session never drops from one rung to the next
- [ ] Walk-run sessions have no pace targets

**Verify:** TEST with `--filter WorkoutBuilderTests` → `Executed 11 tests, with 0 failures`

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/WorkoutBuilderTests.swift`:

```swift
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
            StepShape(.warmup, .time(seconds: 300)),
            StepShape(.run, .time(seconds: 60), group: 1, count: 9),
            StepShape(.walk, .time(seconds: 90), group: 1, count: 9),
            StepShape(.cooldown, .time(seconds: 300)),
        ])
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
    }

    func testTimeTrialAfterWalkRunHasNoTargets() {
        let workout = builder(.tenK).timeTrial(afterWalkRun: true, on: date)
        XCTAssertEqual(workout.title, "10K time trial")
        XCTAssertEqual(shapes(workout), [
            StepShape(.warmup, .time(seconds: 300)),
            StepShape(.run, .distance(meters: 10000)),
            StepShape(.cooldown, .time(seconds: 300)),
        ])
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: TEST with `--filter WorkoutBuilderTests`
Expected: build errors such as `cannot find 'WorkoutBuilder' in scope`.

- [ ] **Step 3: Write the implementation**

`RunCore/Sources/RunCore/Planning/Scaling.swift`:

```swift
import Foundation

/// Integer scaling with halves rounded up, so plan lengths are exact and identical on every
/// platform.
enum Scaling {
    /// `value × numerator / denominator`, rounded to the nearest whole number. Inputs must be
    /// non-negative and `denominator` positive.
    static func round(_ value: Int, times numerator: Int, over denominator: Int) -> Int {
        (2 * value * numerator + denominator) / (2 * denominator)
    }
}
```

`RunCore/Sources/RunCore/Planning/WalkRunLevel.swift`:

```swift
import Foundation

/// One rung of the walk-run ladder: `repeats` × (run, walk), in seconds.
struct WalkRunLevel: Equatable, Sendable {
    /// Running time per session rises or holds on every rung, ending at 3 × 8 minutes, after
    /// which the plan switches to continuous running.
    static let ladder: [WalkRunLevel] = [
        WalkRunLevel(runSeconds: 60, walkSeconds: 90, repeats: 8),
        WalkRunLevel(runSeconds: 90, walkSeconds: 90, repeats: 7),
        WalkRunLevel(runSeconds: 120, walkSeconds: 90, repeats: 6),
        WalkRunLevel(runSeconds: 180, walkSeconds: 90, repeats: 5),
        WalkRunLevel(runSeconds: 240, walkSeconds: 60, repeats: 5),
        WalkRunLevel(runSeconds: 360, walkSeconds: 60, repeats: 4),
        WalkRunLevel(runSeconds: 480, walkSeconds: 60, repeats: 3),
    ]

    let runSeconds: Int
    let walkSeconds: Int
    let repeats: Int

    /// The rung a runner starts on, or nil when they can already run 20 minutes.
    static func startIndex(for fitness: Fitness) -> Int? {
        switch fitness {
        case .newRunner: return 0
        case .runsFiveMinutes: return 4
        case .runsTwentyMinutes, .recentRace: return nil
        }
    }
}
```

`RunCore/Sources/RunCore/Planning/WorkoutBuilder.swift`:

```swift
import Foundation

/// Builds each kind of planned workout. `level` is the week's easy-run length in minutes. A
/// tempo session and an intervals session at the same level last exactly as long for levels
/// 15 to 50 (the generator's range), so alternating them leaves weekly volume unchanged. Below
/// 15 the minimum warm-up makes intervals slightly longer.
struct WorkoutBuilder {
    static let walkWarmupSeconds = 300
    static let walkCooldownSeconds = 300
    static let trialWarmupSeconds = 600
    static let trialCooldownSeconds = 300
    static let recoverySeconds = 90
    static let minimumWarmupSeconds = 180
    static let intervalRepeats = 2...8

    let paces: TrainingPaces
    let goal: Goal

    /// Interval rep length: 2 minutes for a 5K goal, 3 for 10K.
    var repSeconds: Int {
        switch goal.distance {
        case .fiveK: return 120
        case .tenK: return 180
        }
    }

    func easy(minutes: Int, on date: Date) -> Workout {
        Workout(date: date, kind: .easy, title: "Easy run · \(minutes) min", steps: [
            Step(kind: .run, measure: .time(seconds: minutes * 60), targetPaceSecondsPerMile: paces.easy),
        ])
    }

    func longRun(minutes: Int, on date: Date) -> Workout {
        Workout(date: date, kind: .longRun, title: "Long run · \(minutes) min", steps: [
            Step(kind: .run, measure: .time(seconds: minutes * 60), targetPaceSecondsPerMile: paces.easy),
        ])
    }

    func tempo(level: Int, on date: Date) -> Workout {
        let parts = Self.tempoParts(level: level)
        return Workout(date: date, kind: .tempo, title: "Tempo · \(parts.block / 60) min", steps: [
            Step(kind: .warmup, measure: .time(seconds: parts.warmup), targetPaceSecondsPerMile: paces.easy),
            Step(kind: .run, measure: .time(seconds: parts.block), targetPaceSecondsPerMile: paces.tempo),
            Step(kind: .cooldown, measure: .time(seconds: parts.cooldown), targetPaceSecondsPerMile: paces.easy),
        ])
    }

    /// Reps and recoveries filling the tempo block; the warm-up absorbs what is left over.
    func intervals(level: Int, on date: Date) -> Workout {
        let parts = Self.tempoParts(level: level)
        let cycle = repSeconds + Self.recoverySeconds
        let fitted = Scaling.round(parts.block, times: 1, over: cycle)
        let repeats = min(max(fitted, Self.intervalRepeats.lowerBound), Self.intervalRepeats.upperBound)
        let warmup = max(Self.minimumWarmupSeconds, parts.warmup + parts.block - repeats * cycle)
        return Workout(date: date, kind: .intervals, title: "Intervals · \(repeats) × \(Pace.clock(repSeconds))", steps: [
            Step(kind: .warmup, measure: .time(seconds: warmup), targetPaceSecondsPerMile: paces.easy),
            Step(kind: .run, measure: .time(seconds: repSeconds), targetPaceSecondsPerMile: paces.interval, repeatGroup: 1, repeatCount: repeats),
            Step(kind: .recovery, measure: .time(seconds: Self.recoverySeconds), targetPaceSecondsPerMile: paces.easy, repeatGroup: 1, repeatCount: repeats),
            Step(kind: .cooldown, measure: .time(seconds: parts.cooldown), targetPaceSecondsPerMile: paces.easy),
        ])
    }

    /// Walking warm-up, `level.repeats` × (run, walk), walking cool-down. The long session gets
    /// one extra rep. No pace targets: a new runner goes by feel.
    func walkRun(_ level: WalkRunLevel, extraRep: Bool, on date: Date) -> Workout {
        let repeats = level.repeats + (extraRep ? 1 : 0)
        return Workout(date: date, kind: .walkRun, title: "Run-walk · \(repeats) × \(Pace.clock(level.runSeconds))", steps: [
            Step(kind: .warmup, measure: .time(seconds: Self.walkWarmupSeconds)),
            Step(kind: .run, measure: .time(seconds: level.runSeconds), repeatGroup: 1, repeatCount: repeats),
            Step(kind: .walk, measure: .time(seconds: level.walkSeconds), repeatGroup: 1, repeatCount: repeats),
            Step(kind: .cooldown, measure: .time(seconds: Self.walkCooldownSeconds)),
        ])
    }

    /// The goal distance as one open-ended run. After a walk-run phase the warm-up and
    /// cool-down are walks and there are no targets.
    func timeTrial(afterWalkRun: Bool, on date: Date) -> Workout {
        let distance = StepMeasure.distance(meters: goal.distance.meters)
        let steps: [Step]
        if afterWalkRun {
            steps = [
                Step(kind: .warmup, measure: .time(seconds: Self.walkWarmupSeconds)),
                Step(kind: .run, measure: distance),
                Step(kind: .cooldown, measure: .time(seconds: Self.walkCooldownSeconds)),
            ]
        } else {
            steps = [
                Step(kind: .warmup, measure: .time(seconds: Self.trialWarmupSeconds), targetPaceSecondsPerMile: paces.easy),
                Step(kind: .run, measure: distance, targetPaceSecondsPerMile: paces.goal),
                Step(kind: .cooldown, measure: .time(seconds: Self.trialCooldownSeconds), targetPaceSecondsPerMile: paces.easy),
            ]
        }
        return Workout(date: date, kind: .timeTrial, title: "\(goal.distance.displayName) time trial", steps: steps)
    }

    /// Warm-up, tempo block and cool-down in seconds: 30, 50 and 20 percent of `level` minutes.
    static func tempoParts(level: Int) -> (warmup: Int, block: Int, cooldown: Int) {
        (
            warmup: Scaling.round(level, times: 3, over: 10) * 60,
            block: Scaling.round(level, times: 1, over: 2) * 60,
            cooldown: Scaling.round(level, times: 1, over: 5) * 60
        )
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add RunCore/Sources/RunCore/Planning RunCore/Tests/RunCoreTests/WorkoutBuilderTests.swift
git commit -m "Add workout builder and walk-run ladder" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Plan generator

**Goal:** `PlanGenerator.generate(_:calendar:)` turns a profile into dated weeks of workouts following the rules in "Design decisions fixed by this plan".

**Files:**
- Create: `RunCore/Sources/RunCore/Planning/PlanGenerator.swift`
- Create: `RunCore/Tests/RunCoreTests/PlanGeneratorTests.swift`

**Acceptance Criteria:**
- [ ] The worked examples (a 20-minute runner, a new runner, a five-minute runner) match exactly
- [ ] For every goal × fitness × 2 to 5 days × 6 to 16 weeks: week count and kinds are right; each week has one workout per run day, in date order, inside its 7 days; the plan ends in exactly one time trial at the goal distance; walk-run steps have no targets
- [ ] Running build weeks grow by at most 10 percent plus 60 s per workout; running cutback weeks are at most 80 percent of the previous build week plus 60 s per workout
- [ ] The same profile always gives the same plan, apart from IDs

**Verify:** TEST with `--filter PlanGeneratorTests` → `Executed 7 tests, with 0 failures`

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/PlanGeneratorTests.swift`:

```swift
import XCTest
@testable import RunCore

final class PlanGeneratorTests: XCTestCase {

    private func generate(_ profile: Profile) -> Plan {
        PlanGenerator.generate(profile, calendar: TestCalendar.utc)
    }

    func testTwentyMinuteRunnerPlan() {
        let plan = generate(makeProfile())
        let easy = 810, tempo = 720, interval = 660

        XCTAssertEqual(plan.weeks.map(\.kind), [.build, .build, .build, .cutback, .build, .build, .build, .taper])

        let week1 = plan.weeks[0].workouts
        XCTAssertEqual(week1.map(\.date), [TestCalendar.date(2026, 11, 3), TestCalendar.date(2026, 11, 5), TestCalendar.date(2026, 11, 7)])
        XCTAssertEqual(week1.map(\.kind), [.intervals, .easy, .longRun])
        XCTAssertEqual(shapes(week1[0]), [
            StepShape(.warmup, .time(seconds: 330), pace: easy),
            StepShape(.run, .time(seconds: 120), pace: interval, group: 1, count: 3),
            StepShape(.recovery, .time(seconds: 90), pace: easy, group: 1, count: 3),
            StepShape(.cooldown, .time(seconds: 240), pace: easy),
        ])
        XCTAssertEqual(shapes(week1[1]), [StepShape(.run, .time(seconds: 1200), pace: easy)])
        XCTAssertEqual(shapes(week1[2]), [StepShape(.run, .time(seconds: 1800), pace: easy)])

        let week2 = plan.weeks[1].workouts
        XCTAssertEqual(week2.map(\.kind), [.tempo, .easy, .longRun])
        XCTAssertEqual(shapes(week2[0]), [
            StepShape(.warmup, .time(seconds: 420), pace: easy),
            StepShape(.run, .time(seconds: 660), pace: tempo),
            StepShape(.cooldown, .time(seconds: 240), pace: easy),
        ])
        XCTAssertEqual(plannedSeconds(week2[2]), 1980)

        let cutback = plan.weeks[3].workouts
        XCTAssertEqual(cutback.map(\.kind), [.tempo, .easy, .longRun])
        XCTAssertEqual(cutback.map(plannedSeconds), [1080, 1080, 1620])

        let taper = plan.weeks[7].workouts
        XCTAssertEqual(taper.map(\.date), [TestCalendar.date(2026, 12, 22), TestCalendar.date(2026, 12, 24), TestCalendar.date(2026, 12, 26)])
        XCTAssertEqual(taper.map(\.kind), [.easy, .easy, .timeTrial])
        XCTAssertEqual(plannedSeconds(taper[0]), 1080)
        XCTAssertEqual(shapes(taper[2]), [
            StepShape(.warmup, .time(seconds: 600), pace: easy),
            StepShape(.run, .distance(meters: 5000)),
            StepShape(.cooldown, .time(seconds: 300), pace: easy),
        ])
    }

    func testNewRunnerClimbsWalkRunLadderThenRuns() {
        let plan = generate(makeProfile(fitness: .newRunner, weeks: 12))

        XCTAssertEqual(shapes(plan.weeks[0].workouts[0]), [
            StepShape(.warmup, .time(seconds: 300)),
            StepShape(.run, .time(seconds: 60), group: 1, count: 8),
            StepShape(.walk, .time(seconds: 90), group: 1, count: 8),
            StepShape(.cooldown, .time(seconds: 300)),
        ])
        XCTAssertEqual(plan.weeks[0].workouts[2].steps[1].repeatCount, 9)

        // Week 4 is a cutback and repeats week 3's rung.
        XCTAssertEqual(shapes(plan.weeks[3].workouts[0]), shapes(plan.weeks[2].workouts[0]))

        for week in plan.weeks[0..<9] {
            XCTAssertEqual(Set(week.workouts.map(\.kind)), [.walkRun], "week \(week.number)")
        }
        XCTAssertEqual(plan.weeks[9].workouts.map(\.kind), [.intervals, .easy, .longRun])
        XCTAssertEqual(plan.weeks[11].workouts.map(\.kind), [.easy, .easy, .timeTrial])
        XCTAssertEqual(plan.weeks[11].workouts[2].steps[0].measure, .time(seconds: 600))
    }

    func testFiveMinuteRunnerStartsMidLadder() {
        let plan = generate(makeProfile(goal: Goal(distance: .tenK), fitness: .runsFiveMinutes, runDays: [.wednesday, .sunday], weeks: 6))

        XCTAssertEqual(plan.weeks[0].workouts[0].steps[1].measure, .time(seconds: 240))
        XCTAssertEqual(plan.weeks[0].workouts[0].steps[1].repeatCount, 5)
        XCTAssertEqual(plan.weeks[3].workouts.map(\.kind), [.intervals, .longRun])
        XCTAssertEqual(plan.weeks[3].workouts.map(plannedSeconds), [960, 1380])
        XCTAssertEqual(plan.weeks[5].workouts.map(\.kind), [.easy, .timeTrial])
        XCTAssertEqual(plan.weeks[5].workouts[1].steps[1].measure, .distance(meters: 10000))
    }

    func testEveryProfileGivesAValidPlan() {
        let goals = [
            Goal(distance: .fiveK),
            Goal(distance: .fiveK, targetSeconds: 1500),
            Goal(distance: .tenK),
            Goal(distance: .tenK, targetSeconds: 3300),
        ]
        let fitnesses: [Fitness] = [.newRunner, .runsFiveMinutes, .runsTwentyMinutes, .recentRace(distance: .fiveK, seconds: 1800)]
        let daySets: [[Weekday]] = [
            [.tuesday, .saturday],
            [.tuesday, .thursday, .saturday],
            [.monday, .wednesday, .friday, .sunday],
            [.monday, .tuesday, .thursday, .saturday, .sunday],
        ]

        for goal in goals {
            for fitness in fitnesses {
                for days in daySets {
                    for weeks in Profile.planWeeksRange {
                        let profile = makeProfile(goal: goal, fitness: fitness, runDays: days, weeks: weeks)
                        checkValid(generate(profile), profile: profile, label: "\(goal) \(fitness) \(days.count)d \(weeks)w")
                    }
                }
            }
        }
    }

    func testSameProfileGivesSamePlan() {
        let profile = makeProfile(goal: Goal(distance: .tenK, targetSeconds: 3300), fitness: .recentRace(distance: .tenK, seconds: 3500), weeks: 12)
        let first = generate(profile).weeks.flatMap(\.workouts)
        let second = generate(profile).weeks.flatMap(\.workouts)
        XCTAssertEqual(first.map(\.date), second.map(\.date))
        XCTAssertEqual(first.map(\.title), second.map(\.title))
        XCTAssertEqual(first.map(shapes), second.map(shapes))
    }

    func testStartDateMidWeekKeepsRolesByWeekday() {
        var profile = makeProfile()
        profile.startDate = TestCalendar.date(2026, 11, 4) // a Wednesday
        let week1 = generate(profile).weeks[0].workouts
        XCTAssertEqual(week1.map(\.date), [TestCalendar.date(2026, 11, 5), TestCalendar.date(2026, 11, 7), TestCalendar.date(2026, 11, 10)])
        XCTAssertEqual(week1.map(\.kind), [.easy, .longRun, .intervals])
    }

    func testDatesStayAtMidnightAcrossDaylightSavingChange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        var profile = makeProfile()
        profile.startDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26))!
        let workouts = PlanGenerator.generate(profile, calendar: calendar).weeks.flatMap(\.workouts)
        XCTAssertEqual(workouts.count, 24)
        for workout in workouts {
            XCTAssertEqual(workout.date, calendar.startOfDay(for: workout.date))
            XCTAssertTrue(profile.runDays.contains(Weekday(of: workout.date, calendar: calendar)))
        }
    }

    // MARK: - Invariants

    private func checkValid(_ plan: Plan, profile: Profile, label: String) {
        let calendar = TestCalendar.utc
        let start = calendar.startOfDay(for: profile.startDate)
        XCTAssertEqual(plan.weeks.map(\.number), Array(1...profile.planWeeks), label)

        var previousBuildSeconds: Int?
        for week in plan.weeks {
            let context = "\(label) week \(week.number)"
            let expectedKind: WeekKind = week.number == profile.planWeeks ? .taper
                : week.number.isMultiple(of: 4) ? .cutback : .build
            XCTAssertEqual(week.kind, expectedKind, context)

            let windowStart = calendar.date(byAdding: .day, value: (week.number - 1) * 7, to: start)!
            let windowEnd = calendar.date(byAdding: .day, value: 7, to: windowStart)!
            XCTAssertEqual(week.workouts.count, profile.daysPerWeek, context)
            XCTAssertEqual(week.workouts.map(\.date), week.workouts.map(\.date).sorted(), context)
            for workout in week.workouts {
                XCTAssertTrue(workout.date >= windowStart && workout.date < windowEnd, context)
                XCTAssertTrue(profile.runDays.contains(Weekday(of: workout.date, calendar: calendar)), context)
                for step in workout.steps {
                    switch step.measure {
                    case .time(let seconds): XCTAssertGreaterThan(seconds, 0, context)
                    case .distance(let meters): XCTAssertGreaterThan(meters, 0, context)
                    }
                    if workout.kind == .walkRun {
                        XCTAssertNil(step.targetPaceSecondsPerMile, context)
                    }
                }
            }

            let kinds = week.workouts.map(\.kind)
            let running = !kinds.contains(.walkRun)
            if week.kind != .taper {
                XCTAssertFalse(kinds.contains(.timeTrial), context)
                if running {
                    XCTAssertEqual(kinds.filter { $0 == .longRun }.count, 1, context)
                    XCTAssertLessThanOrEqual(kinds.filter { $0 == .intervals || $0 == .tempo }.count, 1, context)
                }
            }

            guard running, week.kind != .taper else { continue }
            let seconds = week.workouts.map(plannedSeconds).reduce(0, +)
            let slack = 60 * profile.daysPerWeek
            if week.kind == .build {
                if let previous = previousBuildSeconds {
                    XCTAssertLessThanOrEqual(Double(seconds), Double(previous) * 1.1 + Double(slack), "\(context) grew from \(previous) to \(seconds)")
                }
                previousBuildSeconds = seconds
            } else if let previous = previousBuildSeconds {
                XCTAssertLessThanOrEqual(Double(seconds), Double(previous) * 0.8 + Double(slack), "\(context) cutback \(seconds) after \(previous)")
            }
        }

        let all = plan.weeks.flatMap(\.workouts)
        XCTAssertEqual(all.filter { $0.kind == .timeTrial }.count, 1, label)
        let last = plan.weeks.last?.workouts.last
        XCTAssertEqual(last?.kind, .timeTrial, label)
        XCTAssertEqual(last?.steps.map(\.measure).contains(.distance(meters: profile.goal.distance.meters)), true, label)
    }
}
```

The mid-week test covers a start on Wednesday 4 November with Tuesday, Thursday and Saturday runs. The 7-day window runs Wednesday to Tuesday, so the dates are Thursday 5, Saturday 7 and Tuesday 10. Roles still follow the weekday: Tuesday is the quality day and Saturday the long run.

- [ ] **Step 2: Run the tests to verify they fail**

Run: TEST with `--filter PlanGeneratorTests`
Expected: build error `cannot find 'PlanGenerator' in scope`.

- [ ] **Step 3: Write the implementation**

`RunCore/Sources/RunCore/Planning/PlanGenerator.swift`:

```swift
import Foundation

/// Builds a training plan from onboarding answers. Deterministic: the same profile and
/// calendar always give the same weeks, dates and steps; only the generated IDs differ.
///
/// - Weeks: the last week is a taper ending in a time trial at the goal distance, every fourth
///   other week is a cutback at 75 percent, and the rest are build weeks.
/// - Walk-run: a runner who cannot yet run 20 minutes climbs `WalkRunLevel.ladder` one rung
///   per build week, then switches to running.
/// - Running: the week's easy-run length starts at 20 minutes (30 with a race result) and
///   grows 10 percent per build week, capped by goal distance. Run days in Monday-first order
///   take roles: the first is the quality session (intervals and tempo alternating), the last
///   is the long run at 1.5 times easy length, and any others are easy runs.
public enum PlanGenerator {

    enum DayRole {
        case quality
        case easy
        case long
    }

    struct RunDay {
        let date: Date
        let role: DayRole
    }

    public static func generate(_ profile: Profile, calendar: Calendar = .current) -> Plan {
        guard profile.planWeeks > 0 else { return Plan(profile: profile, weeks: []) }

        let paces = PaceCalculator.paces(goal: profile.goal, fitness: profile.fitness)
        let builder = WorkoutBuilder(paces: paces, goal: profile.goal)
        let start = calendar.startOfDay(for: profile.startDate)

        var walkRunIndex = WalkRunLevel.startIndex(for: profile.fitness)
        var easyMinutes: Int?
        var qualityCount = 0
        var weeks: [Week] = []

        for number in 1...profile.planWeeks {
            let kind = weekKind(number, of: profile.planWeeks)
            let days = runDays(inWeek: number, from: start, profile: profile, calendar: calendar)
            let workouts: [Workout]

            if let index = walkRunIndex {
                let level = WalkRunLevel.ladder[kind == .build ? index : max(index - 1, 0)]
                workouts = days.map { day in
                    guard day.role == .long else {
                        return builder.walkRun(level, extraRep: false, on: day.date)
                    }
                    return kind == .taper
                        ? builder.timeTrial(afterWalkRun: true, on: day.date)
                        : builder.walkRun(level, extraRep: true, on: day.date)
                }
                if kind == .build {
                    walkRunIndex = index + 1 < WalkRunLevel.ladder.count ? index + 1 : nil
                }
            } else {
                let minutes = nextEasyMinutes(after: easyMinutes, kind: kind, profile: profile)
                easyMinutes = minutes

                if kind == .taper {
                    let easy = Scaling.round(minutes, times: 3, over: 5)
                    workouts = days.map { day in
                        day.role == .long
                            ? builder.timeTrial(afterWalkRun: false, on: day.date)
                            : builder.easy(minutes: easy, on: day.date)
                    }
                } else {
                    let level = kind == .build ? minutes : Scaling.round(minutes, times: 3, over: 4)
                    let longMinutes = min(Scaling.round(level, times: 3, over: 2), longRunCap(profile.goal.distance))
                    let intervalsWeek = qualityCount.isMultiple(of: 2)
                    qualityCount += 1
                    workouts = days.map { day in
                        switch day.role {
                        case .quality:
                            return intervalsWeek
                                ? builder.intervals(level: level, on: day.date)
                                : builder.tempo(level: level, on: day.date)
                        case .long:
                            return builder.longRun(minutes: longMinutes, on: day.date)
                        case .easy:
                            return builder.easy(minutes: level, on: day.date)
                        }
                    }
                }
            }

            weeks.append(Week(number: number, kind: kind, workouts: workouts))
        }

        return Plan(profile: profile, weeks: weeks)
    }

    static func weekKind(_ number: Int, of total: Int) -> WeekKind {
        if number == total { return .taper }
        return number.isMultiple(of: 4) ? .cutback : .build
    }

    /// The first running week starts the easy run at 20 minutes, or 30 with a race result.
    /// Build weeks then add 10 percent up to the cap; cutback and taper weeks hold it.
    static func nextEasyMinutes(after current: Int?, kind: WeekKind, profile: Profile) -> Int {
        guard let current else {
            if case .recentRace = profile.fitness { return 30 }
            return 20
        }
        guard kind == .build else { return current }
        return min(current * 11 / 10, easyRunCap(profile.goal.distance))
    }

    static func easyRunCap(_ distance: RaceDistance) -> Int {
        switch distance {
        case .fiveK: return 40
        case .tenK: return 50
        }
    }

    /// A safety bound: with today's easy-run caps (40 and 50 minutes) the long run tops out at 60 and 75 minutes, so this never binds.
    static func longRunCap(_ distance: RaceDistance) -> Int {
        switch distance {
        case .fiveK: return 60
        case .tenK: return 90
        }
    }

    /// The run days inside week `number`'s 7-day window from `start`, in date order.
    static func runDays(inWeek number: Int, from start: Date, profile: Profile, calendar: Calendar) -> [RunDay] {
        let ordered = profile.runDays.sorted()
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: (number - 1) * 7 + offset, to: start) else {
                return nil
            }
            guard let position = ordered.firstIndex(of: Weekday(of: date, calendar: calendar)) else {
                return nil
            }
            return RunDay(date: date, role: role(at: position, of: ordered.count))
        }
    }

    static func role(at position: Int, of count: Int) -> DayRole {
        if position == count - 1 { return .long }
        if position == 0 { return .quality }
        return .easy
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass. `testEveryProfileGivesAValidPlan` checks 704 plans and should take a few seconds.

- [ ] **Step 5: Commit**

```bash
git add RunCore/Sources/RunCore/Planning/PlanGenerator.swift RunCore/Tests/RunCoreTests/PlanGeneratorTests.swift
git commit -m "Add plan generator" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Plan queries, completion, edits and storage

**Goal:** `Plan` can find the next workout, mark one completed and replace an edited one; `PlanStore` saves and loads it as `plan.json`.

**Files:**
- Modify: `RunCore/Sources/RunCore/Models/Plan.swift`
- Create: `RunCore/Sources/RunCore/Storage/PlanStore.swift`
- Create: `RunCore/Tests/RunCoreTests/PlanTests.swift`, `RunCore/Tests/RunCoreTests/PlanStoreTests.swift`

**Acceptance Criteria:**
- [ ] `nextWorkout(onOrAfter:)` returns the first uncompleted workout on or after that day, skips missed and completed ones, and is nil after the plan ends
- [ ] `markCompleted` sets `recordID`; an unknown ID changes nothing
- [ ] `update` replaces a workout by ID and keeps its week in date order
- [ ] A saved plan loads back equal; a missing file loads as nil

**Verify:** TEST with `--filter Plan` → `PlanTests`, `PlanStoreTests` and the earlier plan tests pass

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/PlanTests.swift`:

```swift
import XCTest
@testable import RunCore

final class PlanTests: XCTestCase {

    private var plan = PlanGenerator.generate(makeProfile(), calendar: TestCalendar.utc)

    private func next(on date: Date) -> Workout? {
        plan.nextWorkout(onOrAfter: date, calendar: TestCalendar.utc)
    }

    func testNextWorkoutIsFirstOnOrAfterTheDay() {
        XCTAssertEqual(next(on: TestCalendar.date(2026, 11, 2))?.date, TestCalendar.date(2026, 11, 3))
        let eveningOfTheThird = TestCalendar.date(2026, 11, 3).addingTimeInterval(18 * 3600)
        XCTAssertEqual(next(on: eveningOfTheThird)?.date, TestCalendar.date(2026, 11, 3))
    }

    func testNextWorkoutSkipsMissedAndCompleted() {
        XCTAssertEqual(next(on: TestCalendar.date(2026, 11, 4))?.date, TestCalendar.date(2026, 11, 5))

        let first = plan.weeks[0].workouts[0]
        plan.markCompleted(workoutID: first.id, recordID: UUID())
        XCTAssertEqual(next(on: TestCalendar.date(2026, 11, 3))?.date, TestCalendar.date(2026, 11, 5))
    }

    func testNoNextWorkoutAfterThePlanEnds() {
        XCTAssertNil(next(on: TestCalendar.date(2027, 1, 1)))
    }

    func testMarkCompletedSetsRecordID() {
        let workout = plan.weeks[2].workouts[1]
        let recordID = UUID()
        plan.markCompleted(workoutID: workout.id, recordID: recordID)
        XCTAssertEqual(plan.workout(id: workout.id)?.recordID, recordID)
    }

    func testUnknownWorkoutChangesNothing() {
        let before = plan
        plan.markCompleted(workoutID: UUID(), recordID: UUID())
        plan.update(Workout(date: Date(), kind: .easy, title: "Stray", steps: []))
        XCTAssertEqual(plan, before)
    }

    func testUpdateReplacesAndKeepsWeekInDateOrder() {
        var workout = plan.weeks[0].workouts[0]
        workout.date = TestCalendar.date(2026, 11, 6)
        workout.title = "Moved intervals"
        plan.update(workout)

        XCTAssertEqual(plan.weeks[0].workouts.map(\.date), [
            TestCalendar.date(2026, 11, 5), TestCalendar.date(2026, 11, 6), TestCalendar.date(2026, 11, 7),
        ])
        XCTAssertEqual(plan.workout(id: workout.id)?.title, "Moved intervals")
        XCTAssertEqual(plan.workouts.count, 24)
    }
}
```

`RunCore/Tests/RunCoreTests/PlanStoreTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: TEST with `--filter Plan`
Expected: build errors such as `value of type 'Plan' has no member 'nextWorkout'` and `cannot find 'PlanStore' in scope`.

- [ ] **Step 3: Write the implementation**

Replace `RunCore/Sources/RunCore/Models/Plan.swift` with:

```swift
import Foundation

/// A generated training plan and the profile it was generated from.
public struct Plan: Codable, Equatable, Sendable {
    public var profile: Profile
    public var weeks: [Week]

    public init(profile: Profile, weeks: [Week]) {
        self.profile = profile
        self.weeks = weeks
    }

    /// Every workout, week by week.
    public var workouts: [Workout] {
        weeks.flatMap(\.workouts)
    }

    public func workout(id: UUID) -> Workout? {
        workouts.first { $0.id == id }
    }

    /// The earliest workout not yet completed that falls on or after the day containing
    /// `date`. Missed workouts on earlier days are skipped.
    public func nextWorkout(onOrAfter date: Date, calendar: Calendar = .current) -> Workout? {
        let day = calendar.startOfDay(for: date)
        return workouts
            .filter { $0.recordID == nil && $0.date >= day }
            .min { $0.date < $1.date }
    }

    public mutating func markCompleted(workoutID: UUID, recordID: UUID) {
        modifyWorkout(id: workoutID) { $0.recordID = recordID }
    }

    /// Replaces the workout with the same ID and keeps its week in date order.
    public mutating func update(_ workout: Workout) {
        modifyWorkout(id: workout.id) { $0 = workout }
    }

    private mutating func modifyWorkout(id: UUID, _ change: (inout Workout) -> Void) {
        for weekIndex in weeks.indices {
            guard let index = weeks[weekIndex].workouts.firstIndex(where: { $0.id == id }) else { continue }
            change(&weeks[weekIndex].workouts[index])
            weeks[weekIndex].workouts.sort { $0.date < $1.date }
            return
        }
    }
}
```

`RunCore/Sources/RunCore/Storage/PlanStore.swift`:

```swift
import Foundation

/// The training plan, stored as one file. The profile it was generated from is inside it.
public struct PlanStore: Sendable {
    private static let file = "plan.json"
    private let store: JSONStore

    public init(store: JSONStore) {
        self.store = store
    }

    public func load() -> Plan? {
        store.load(Plan.self, from: Self.file)
    }

    public func save(_ plan: Plan) throws {
        try store.save(plan, as: Self.file)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add RunCore/Sources/RunCore/Models/Plan.swift RunCore/Sources/RunCore/Storage/PlanStore.swift RunCore/Tests/RunCoreTests/PlanTests.swift RunCore/Tests/RunCoreTests/PlanStoreTests.swift
git commit -m "Add plan queries, completion, edits and storage" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Plan state in the app model

**Goal:** `AppModel` loads and saves the plan, creates one from a profile, saves edited workouts, and marks a workout completed when its run is saved. This change only adds; the home screen is untouched until Task 8.

**Files:**
- Modify: `Sources/RunPlan/App/AppModel.swift`

**Acceptance Criteria:**
- [ ] `AppModel.plan` is loaded from `plan.json` at launch
- [ ] `createPlan(from:)` generates and saves a plan
- [ ] `update(_:)` saves an edited workout
- [ ] `save(_:)` marks the run's workout completed and saves the plan
- [ ] BUILD succeeds

**Verify:** BUILD → ends with `Build complete!` (or the `.app` path), no errors

**Steps:**

- [ ] **Step 1: Replace `Sources/RunPlan/App/AppModel.swift`**

```swift
import Foundation
import Observation
import RunCore

/// App-wide state: the training plan, run history, and the session in progress.
@MainActor
@Observable
final class AppModel {

    let store: JSONStore
    private let runs: RunStore
    private let plans: PlanStore

    private(set) var records: [RunRecord] = []
    /// nil until onboarding has created one.
    private(set) var plan: Plan?
    let todaysWorkout: Workout = SampleWorkouts.runWalk()

    /// Non-nil while a workout is on screen.
    var session: WorkoutSessionModel?
    /// A workout found on disk from a previous launch, waiting for the user to decide.
    var pendingResume: ActiveWorkout?

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        store = JSONStore(directory: documents)
        runs = RunStore(store: store)
        plans = PlanStore(store: store)
        records = runs.all()
        plan = plans.load()
        pendingResume = store.load(ActiveWorkout.self, from: WorkoutSessionModel.checkpointFile)
    }

    /// Generates a plan from onboarding answers and saves it.
    func createPlan(from profile: Profile) {
        plan = PlanGenerator.generate(profile)
        persistPlan()
    }

    /// Saves an edited planned workout.
    func update(_ workout: Workout) {
        plan?.update(workout)
        persistPlan()
    }

    func start(_ workout: Workout, mode: RunMode) {
        let session = WorkoutSessionModel(workout: workout, mode: mode, store: store)
        self.session = session
        session.begin()
    }

    func resumePending() {
        guard let active = pendingResume else { return }
        pendingResume = nil
        let session = WorkoutSessionModel(resuming: active, store: store)
        self.session = session
        session.begin()
    }

    func discardPending() {
        pendingResume = nil
        store.delete(WorkoutSessionModel.checkpointFile)
    }

    /// Saves the finished session as a run, marks its planned workout done, and closes it.
    func save(_ record: RunRecord) {
        try? runs.save(record)
        records = runs.all()
        if let workoutID = record.workoutID {
            plan?.markCompleted(workoutID: workoutID, recordID: record.id)
            persistPlan()
        }
        closeSession()
    }

    func closeSession() {
        session?.releaseAudio()
        session = nil
    }

    private func persistPlan() {
        guard let plan else { return }
        try? plans.save(plan)
    }
}
```

- [ ] **Step 2: Build**

Run: BUILD
Expected: success.

- [ ] **Step 3: Commit**

```bash
git add Sources/RunPlan/App/AppModel.swift
git commit -m "Keep the training plan in the app model" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Onboarding

**Goal:** On first launch (no plan saved) the app asks for the goal, current fitness, run days, plan length and start date, previews the generated plan with its paces and any goal warning, and saves it.

**Files:**
- Create: `Sources/RunPlan/Onboarding/OnboardingModel.swift`, `OnboardingView.swift`, `DurationPicker.swift`, `PlanPreviewView.swift`
- Modify: `Sources/RunPlan/App/RootView.swift`

**Acceptance Criteria:**
- [ ] With no plan saved, the root shows onboarding; once a plan is saved it shows the existing home screen
- [ ] Next is disabled on the schedule page unless 2 to 5 run days are picked
- [ ] An ambitious goal shows a warning offering the suggested plan length (when there is one) and "Train to finish instead"
- [ ] BUILD succeeds

**Verify:** BUILD → success

**Steps:**

- [ ] **Step 1: Create `Sources/RunPlan/Onboarding/OnboardingModel.swift`**

```swift
import Foundation
import Observation
import RunCore

/// Draft onboarding answers, turned into a `Profile` for the preview and the saved plan.
@MainActor
@Observable
final class OnboardingModel {

    enum Page: Int, CaseIterable {
        case goal
        case fitness
        case schedule
        case preview

        var title: String {
            switch self {
            case .goal: return "Your goal"
            case .fitness: return "Your running now"
            case .schedule: return "Your schedule"
            case .preview: return "Your plan"
            }
        }
    }

    enum FitnessChoice: String, CaseIterable, Identifiable {
        case newRunner
        case runsFiveMinutes
        case runsTwentyMinutes
        case recentRace

        var id: String { rawValue }

        var title: String {
            switch self {
            case .newRunner: return "New to running"
            case .runsFiveMinutes: return "Can run 5 minutes"
            case .runsTwentyMinutes: return "Can run 20 minutes"
            case .recentRace: return "I have a recent race time"
            }
        }
    }

    var page: Page = .goal

    var distance: RaceDistance = .fiveK
    var hasGoalTime = false
    /// Starts at 30:00; the view resets it when the distance changes.
    var goalSeconds = 1800

    var fitnessChoice: FitnessChoice = .runsTwentyMinutes
    var raceDistance: RaceDistance = .fiveK
    var raceSeconds = 1800

    var runDays: Set<Weekday> = [.tuesday, .thursday, .saturday]
    var planWeeks = 8
    var startDate = Calendar.current.startOfDay(for: Date())

    var profile: Profile {
        Profile(
            goal: Goal(distance: distance, targetSeconds: hasGoalTime ? goalSeconds : nil),
            fitness: fitness,
            runDays: Array(runDays),
            planWeeks: planWeeks,
            startDate: startDate
        )
    }

    var canContinue: Bool {
        page != .schedule || Profile.daysPerWeekRange.contains(runDays.count)
    }

    func next() {
        if let nextPage = Page(rawValue: page.rawValue + 1) { page = nextPage }
    }

    func back() {
        if let previousPage = Page(rawValue: page.rawValue - 1) { page = previousPage }
    }

    func toggle(_ day: Weekday) {
        if runDays.contains(day) {
            runDays.remove(day)
        } else {
            runDays.insert(day)
        }
    }

    private var fitness: Fitness {
        switch fitnessChoice {
        case .newRunner: return .newRunner
        case .runsFiveMinutes: return .runsFiveMinutes
        case .runsTwentyMinutes: return .runsTwentyMinutes
        case .recentRace: return .recentRace(distance: raceDistance, seconds: raceSeconds)
        }
    }

    /// A typical time to start the wheels on: 30:00 for 5K, 60:00 for 10K.
    nonisolated static func defaultSeconds(for distance: RaceDistance) -> Int {
        switch distance {
        case .fiveK: return 1800
        case .tenK: return 3600
        }
    }

    /// Minutes offered on the wheel for a time at `distance`.
    nonisolated static func minuteRange(for distance: RaceDistance) -> ClosedRange<Int> {
        switch distance {
        case .fiveK: return 12...60
        case .tenK: return 25...120
        }
    }
}
```

- [ ] **Step 2: Create `Sources/RunPlan/Onboarding/DurationPicker.swift`**

```swift
import SwiftUI

/// Minute and second wheels bound to a total number of seconds.
struct DurationPicker: View {
    @Binding var seconds: Int
    let minuteRange: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 0) {
            Picker("Minutes", selection: minutes) {
                ForEach(minuteRange, id: \.self) { Text("\($0) min").tag($0) }
            }
            Picker("Seconds", selection: secondsPart) {
                ForEach(0..<60, id: \.self) { Text(String(format: "%02d s", $0)).tag($0) }
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 150)
    }

    private var minutes: Binding<Int> {
        Binding(
            get: { min(max(seconds / 60, minuteRange.lowerBound), minuteRange.upperBound) },
            set: { seconds = $0 * 60 + seconds % 60 }
        )
    }

    private var secondsPart: Binding<Int> {
        Binding(
            get: { seconds % 60 },
            set: { seconds = (seconds / 60) * 60 + $0 }
        )
    }
}
```

- [ ] **Step 3: Create `Sources/RunPlan/Onboarding/PlanPreviewView.swift`**

```swift
import SwiftUI
import RunCore

/// The generated plan before it is saved, with its paces and a warning when the goal time
/// looks out of reach.
struct PlanPreviewView: View {
    @Environment(AppModel.self) private var app
    let model: OnboardingModel

    var body: some View {
        let profile = model.profile
        let plan = PlanGenerator.generate(profile)
        let paces = PaceCalculator.paces(goal: profile.goal, fitness: profile.fitness)

        List {
            switch PaceCalculator.assess(profile) {
            case .reachable:
                EmptyView()
            case .ambitious(let suggestedWeeks):
                Section {
                    Text("This goal time needs more improvement than \(model.planWeeks) weeks usually allow.")
                    if let weeks = suggestedWeeks {
                        Button("Use a \(weeks)-week plan") { model.planWeeks = weeks }
                    }
                    Button("Train to finish instead") { model.hasGoalTime = false }
                } header: {
                    Label("Ambitious goal", systemImage: "exclamationmark.triangle")
                }
            }

            Section("Paces") {
                PaceRow(label: "Easy", seconds: paces.easy)
                PaceRow(label: "Tempo", seconds: paces.tempo)
                PaceRow(label: "Intervals", seconds: paces.interval)
                if let goal = paces.goal {
                    PaceRow(label: "Goal", seconds: goal)
                }
            }

            ForEach(plan.weeks) { week in
                Section("Week \(week.number) · \(week.kind.displayName)") {
                    ForEach(week.workouts) { workout in
                        HStack {
                            Text(workout.title)
                            Spacer()
                            Text(workout.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                app.createPlan(from: model.profile)
            } label: {
                Text("Save plan").font(.title3.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
    }
}

private struct PaceRow: View {
    let label: String
    let seconds: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(Pace.clock(seconds)) /mi · \(String(format: "%.1f", Pace.mph(fromSecondsPerMile: seconds))) mph")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
```

- [ ] **Step 4: Create `Sources/RunPlan/Onboarding/OnboardingView.swift`**

```swift
import SwiftUI
import RunCore

/// First launch: goal, current fitness and schedule, then a preview of the plan before it is
/// saved.
struct OnboardingView: View {
    @State private var model = OnboardingModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(model.page.title)
                .toolbar {
                    if model.page != .goal {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") { model.back() }
                        }
                    }
                    if model.page != .preview {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Next") { model.next() }.disabled(!model.canContinue)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.page {
        case .goal: goalForm
        case .fitness: fitnessForm
        case .schedule: scheduleForm
        case .preview: PlanPreviewView(model: model)
        }
    }

    private var goalForm: some View {
        Form {
            Section("Distance") {
                Picker("Distance", selection: $model.distance) {
                    ForEach(RaceDistance.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section {
                Toggle("I have a goal time", isOn: $model.hasGoalTime)
                if model.hasGoalTime {
                    DurationPicker(seconds: $model.goalSeconds, minuteRange: OnboardingModel.minuteRange(for: model.distance))
                }
            } footer: {
                Text("Leave this off to train to finish.")
            }
        }
        .onChange(of: model.distance) { _, distance in
            model.goalSeconds = OnboardingModel.defaultSeconds(for: distance)
        }
    }

    private var fitnessForm: some View {
        Form {
            Section {
                Picker("Fitness", selection: $model.fitnessChoice) {
                    ForEach(OnboardingModel.FitnessChoice.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            if model.fitnessChoice == .recentRace {
                Section("Race result") {
                    Picker("Distance", selection: $model.raceDistance) {
                        ForEach(RaceDistance.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    DurationPicker(seconds: $model.raceSeconds, minuteRange: OnboardingModel.minuteRange(for: model.raceDistance))
                }
            }
        }
        .onChange(of: model.raceDistance) { _, distance in
            model.raceSeconds = OnboardingModel.defaultSeconds(for: distance)
        }
    }

    private var scheduleForm: some View {
        Form {
            Section {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Button {
                        model.toggle(day)
                    } label: {
                        HStack {
                            Text(day.name).foregroundStyle(.primary)
                            Spacer()
                            if model.runDays.contains(day) {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                }
            } header: {
                Text("Run days")
            } footer: {
                Text("Pick 2 to 5 days. The last one each week is the long run.")
            }
            Section("Plan length") {
                Stepper("\(model.planWeeks) weeks", value: $model.planWeeks, in: Profile.planWeeksRange)
            }
            Section("Start") {
                DatePicker("Start date", selection: $model.startDate, displayedComponents: .date)
            }
        }
    }
}
```

- [ ] **Step 5: Show onboarding when there is no plan**

In `Sources/RunPlan/App/RootView.swift`, replace the line `        HomeView()` with:

```swift
        Group {
            if app.plan == nil {
                OnboardingView()
            } else {
                HomeView()
            }
        }
```

The `.fullScreenCover`, `.alert` and `.onChange` modifiers that followed `HomeView()` now follow the `Group`. Leave them unchanged.

- [ ] **Step 6: Build**

Run: BUILD
Expected: success.

- [ ] **Step 7: Commit**

```bash
git add Sources/RunPlan/Onboarding Sources/RunPlan/App/RootView.swift
git commit -m "Add onboarding with plan preview and goal check" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Plan and Runs tabs

**Goal:** Replace the home screen with two tabs. Plan shows the next workout and every week with done marks, opening a workout's detail and Start. Runs is the existing run history.

**Files:**
- Create: `Sources/RunPlan/Plan/PlanView.swift`, `Sources/RunPlan/Plan/WorkoutRow.swift`, `Sources/RunPlan/Runs/RunsView.swift`
- Modify: `Sources/RunPlan/Workout/WorkoutDetailView.swift`, `Sources/RunPlan/App/RootView.swift`, `Sources/RunPlan/App/AppModel.swift`
- Delete: `Sources/RunPlan/Home/HomeView.swift`

**Acceptance Criteria:**
- [ ] The Plan tab heads the list with "Today" (or "Next") and that workout, or "Plan complete"
- [ ] Each week section shows its kind and "n of m done", and each workout a done mark and date
- [ ] Tapping a workout opens its detail, looked up by ID so later edits show
- [ ] The Runs tab lists saved runs, newest first
- [ ] The sample workout and `HomeView` are gone; BUILD succeeds

**Verify:** BUILD → success

**Steps:**

- [ ] **Step 1: Create `Sources/RunPlan/Plan/WorkoutRow.swift`**

```swift
import SwiftUI
import RunCore

/// A planned workout in a list: done mark, title and date.
struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDone ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.title).font(.headline)
                Text(workout.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isDone: Bool { workout.recordID != nil }
}
```

- [ ] **Step 2: Create `Sources/RunPlan/Plan/PlanView.swift`**

```swift
import SwiftUI
import RunCore

/// The training plan: the next workout, then every week with its workouts.
struct PlanView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            List {
                if let plan = app.plan {
                    let next = plan.nextWorkout(onOrAfter: Date())
                    Section(nextHeader(next)) {
                        if let next {
                            NavigationLink(value: next.id) { WorkoutRow(workout: next) }
                        } else {
                            Text("Plan complete").foregroundStyle(.secondary)
                        }
                    }
                    ForEach(plan.weeks) { week in
                        Section(weekHeader(week)) {
                            ForEach(week.workouts) { workout in
                                NavigationLink(value: workout.id) { WorkoutRow(workout: workout) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Plan")
            .navigationDestination(for: UUID.self) { id in
                WorkoutDetailView(workoutID: id)
            }
        }
    }

    private func nextHeader(_ next: Workout?) -> String {
        guard let next, Calendar.current.isDateInToday(next.date) else { return "Next" }
        return "Today"
    }

    private func weekHeader(_ week: Week) -> String {
        let done = week.workouts.filter { $0.recordID != nil }.count
        return "Week \(week.number) · \(week.kind.displayName) · \(done) of \(week.workouts.count) done"
    }
}
```

- [ ] **Step 3: Create `Sources/RunPlan/Runs/RunsView.swift`**

This moves the run list and `RunRow` out of `HomeView`, unchanged:

```swift
import SwiftUI
import RunCore

/// Saved runs, newest first.
struct RunsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            List {
                if app.records.isEmpty {
                    Text("No runs yet").foregroundStyle(.secondary)
                } else {
                    ForEach(app.records) { record in
                        RunRow(record: record)
                    }
                }
            }
            .navigationTitle("Runs")
        }
    }
}

private struct RunRow: View {
    let record: RunRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var detail: String {
        var parts = [record.startedAt.formatted(date: .abbreviated, time: .shortened), Pace.clock(record.durationSeconds)]
        if record.distanceMeters > 0 {
            parts.append(String(format: "%.2f mi", Pace.miles(fromMeters: record.distanceMeters)))
        }
        return parts.joined(separator: " · ")
    }
}
```

- [ ] **Step 4: Replace `Sources/RunPlan/Workout/WorkoutDetailView.swift`**

```swift
import SwiftUI
import RunCore

/// A planned workout's date and steps, with Start.
struct WorkoutDetailView: View {
    @Environment(AppModel.self) private var app
    let workoutID: UUID

    @State private var choosingMode = false

    var body: some View {
        if let workout = app.plan?.workout(id: workoutID) {
            detail(workout)
        } else {
            ContentUnavailableView("Workout not found", systemImage: "questionmark.circle")
        }
    }

    private func detail(_ workout: Workout) -> some View {
        List {
            Section {
                LabeledContent("Date", value: workout.date.formatted(date: .complete, time: .omitted))
                if workout.recordID != nil {
                    Label("Completed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            Section("Steps") {
                ForEach(workout.steps) { step in
                    HStack {
                        Text(label(for: step))
                        Spacer()
                        Text(measure(for: step)).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle(workout.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                choosingMode = true
            } label: {
                Text("Start").font(.title3.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .confirmationDialog("Where are you running?", isPresented: $choosingMode, titleVisibility: .visible) {
            Button("Treadmill") { app.start(workout, mode: .treadmill) }
            Button("Outdoor (coming with GPS tracking)") {}.disabled(true)
        }
    }

    private func label(for step: Step) -> String {
        let kind = CueText.displayKind(step.kind)
        if let count = step.repeatCount, step.repeatGroup != nil {
            return "\(count) × \(kind)"
        }
        return kind
    }

    private func measure(for step: Step) -> String {
        let amount: String
        switch step.measure {
        case .time(let seconds): amount = Pace.clock(seconds)
        case .distance(let meters): amount = String(format: "%.2f mi", Pace.miles(fromMeters: meters))
        }
        guard let pace = step.targetPaceSecondsPerMile else { return amount }
        return "\(amount) @ \(String(format: "%.1f", Pace.mph(fromSecondsPerMile: pace))) mph"
    }
}
```

- [ ] **Step 5: Use the tabs in `Sources/RunPlan/App/RootView.swift`**

Replace the `HomeView()` line inside the `Group` from Task 7 with:

```swift
                TabView {
                    PlanView()
                        .tabItem { Label("Plan", systemImage: "calendar") }
                    RunsView()
                        .tabItem { Label("Runs", systemImage: "figure.run") }
                }
```

- [ ] **Step 6: Remove the sample workout and the old home screen**

In `Sources/RunPlan/App/AppModel.swift`, delete the line:

```swift
    let todaysWorkout: Workout = SampleWorkouts.runWalk()
```

Then delete the file:

```bash
git rm Sources/RunPlan/Home/HomeView.swift
```

`SampleWorkouts` stays in `RunCore`: the tests still use it.

- [ ] **Step 7: Build**

Run: BUILD
Expected: success. If it reports `cannot find 'HomeView'` or `todaysWorkout`, a reference was missed: search with `grep -rn "HomeView\|todaysWorkout" Sources`.

- [ ] **Step 8: Commit**

```bash
git add Sources/RunPlan
git commit -m "Add Plan and Runs tabs" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Workout editing

**Goal:** Edit a planned workout's title, date and steps (kind, length, speed target, repeat count; add and delete), saved to the plan.

**Files:**
- Create: `RunCore/Sources/RunCore/Models/Workout+RepeatGroups.swift`, `RunCore/Tests/RunCoreTests/WorkoutRepeatGroupTests.swift`
- Create: `Sources/RunPlan/Plan/WorkoutEditView.swift`, `Sources/RunPlan/Plan/StepEditor.swift`
- Modify: `Sources/RunPlan/Workout/WorkoutDetailView.swift`

**Acceptance Criteria:**
- [ ] `Workout` can tell which step starts a repeat group, read its repeat count the way `StepExpander` does, and set the count on every step of the group
- [ ] The detail screen has Edit, opening a form whose changes apply only on Save
- [ ] The repeat count is edited once per group, on its first step
- [ ] Save is disabled when no steps remain
- [ ] TEST and BUILD succeed

**Verify:** TEST with `--filter WorkoutRepeatGroupTests` → `Executed 3 tests, with 0 failures`; then BUILD → success

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/WorkoutRepeatGroupTests.swift`:

```swift
import XCTest
@testable import RunCore

final class WorkoutRepeatGroupTests: XCTestCase {

    // warm-up, 6 × (run, walk), cool-down
    private var workout = SampleWorkouts.runWalk(on: TestCalendar.date(2026, 11, 3))

    func testGroupStart() {
        XCTAssertFalse(workout.startsRepeatGroup(at: 0))
        XCTAssertTrue(workout.startsRepeatGroup(at: 1))
        XCTAssertFalse(workout.startsRepeatGroup(at: 2))
        XCTAssertFalse(workout.startsRepeatGroup(at: 9))
    }

    func testRepeatCountReadsTheGroup() {
        XCTAssertEqual(workout.repeatCount(ofGroupAt: 2), 6)
        XCTAssertEqual(workout.repeatCount(ofGroupAt: 0), 1)
        XCTAssertEqual(workout.repeatCount(ofGroupAt: 9), 1)
    }

    func testSetRepeatCountChangesEveryStepInTheGroup() {
        workout.setRepeatCount(8, ofGroupAt: 2)
        XCTAssertEqual(workout.steps.map(\.repeatCount), [nil, 8, 8, nil])
        XCTAssertEqual(StepExpander.expand(workout.steps).count, 18)

        workout.setRepeatCount(3, ofGroupAt: 0)
        XCTAssertNil(workout.steps[0].repeatCount)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: TEST with `--filter WorkoutRepeatGroupTests`
Expected: build error `value of type 'Workout' has no member 'startsRepeatGroup'`.

- [ ] **Step 3: Write `RunCore/Sources/RunCore/Models/Workout+RepeatGroups.swift`**

```swift
import Foundation

/// Repeat groups as an editor sees them: one repeat count per group, edited on its first step.
extension Workout {

    /// True when the step at `index` is the first of a repeat group.
    public func startsRepeatGroup(at index: Int) -> Bool {
        guard steps.indices.contains(index), let group = steps[index].repeatGroup else { return false }
        return index == 0 || steps[index - 1].repeatGroup != group
    }

    /// The repeat count of the group containing `index`, read the way `StepExpander` reads it.
    /// 1 for a step outside any group.
    public func repeatCount(ofGroupAt index: Int) -> Int {
        groupIndices(at: index).compactMap { steps[$0].repeatCount }.first ?? 1
    }

    /// Sets the repeat count on every step of the group containing `index`.
    public mutating func setRepeatCount(_ count: Int, ofGroupAt index: Int) {
        for stepIndex in groupIndices(at: index) {
            steps[stepIndex].repeatCount = count
        }
    }

    /// Indices of the contiguous steps sharing the repeat group at `index`; empty when the step
    /// is not in a group.
    private func groupIndices(at index: Int) -> [Int] {
        guard steps.indices.contains(index), let group = steps[index].repeatGroup else { return [] }
        var lower = index
        while lower > 0, steps[lower - 1].repeatGroup == group { lower -= 1 }
        var upper = index
        while upper + 1 < steps.count, steps[upper + 1].repeatGroup == group { upper += 1 }
        return Array(lower...upper)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass.

- [ ] **Step 5: Create `Sources/RunPlan/Plan/StepEditor.swift`**

```swift
import SwiftUI
import RunCore

/// One step's controls: kind, length, an optional treadmill speed target, and, on the first
/// step of a repeat group, the group's repeat count.
struct StepEditor: View {
    @Binding var step: Step
    /// Non-nil only on the first step of a repeat group.
    let repeatCount: Binding<Int>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Kind", selection: $step.kind) {
                ForEach(StepKind.allCases, id: \.self) { Text(CueText.displayKind($0)).tag($0) }
            }

            switch step.measure {
            case .time(let seconds):
                Stepper(Pace.clock(seconds), value: timeSeconds, in: 15...7200, step: 15)
            case .distance(let meters):
                Stepper(String(format: "%.2f mi", Pace.miles(fromMeters: meters)), value: distanceMiles, in: 0.05...26.2, step: 0.05)
            }

            Toggle("Speed target", isOn: hasTarget)
            if let pace = step.targetPaceSecondsPerMile {
                Stepper(
                    "\(String(format: "%.1f", Pace.mph(fromSecondsPerMile: pace))) mph · \(Pace.clock(pace)) /mi",
                    value: targetMph,
                    in: 1.0...15.0,
                    step: 0.1
                )
            }

            if let repeatCount {
                Stepper("Repeat \(repeatCount.wrappedValue) ×", value: repeatCount, in: 1...20)
            }
        }
        .padding(.vertical, 4)
    }

    private var timeSeconds: Binding<Int> {
        Binding(
            get: {
                if case .time(let seconds) = step.measure { return seconds }
                return 0
            },
            set: { step.measure = .time(seconds: $0) }
        )
    }

    private var distanceMiles: Binding<Double> {
        Binding(
            get: {
                if case .distance(let meters) = step.measure { return Pace.miles(fromMeters: meters) }
                return 0
            },
            set: { step.measure = .distance(meters: Pace.meters(fromMiles: $0)) }
        )
    }

    /// Turning the target on starts it at 5.0 mph.
    private var hasTarget: Binding<Bool> {
        Binding(
            get: { step.targetPaceSecondsPerMile != nil },
            set: { step.targetPaceSecondsPerMile = $0 ? Pace.secondsPerMile(fromMph: 5.0) : nil }
        )
    }

    /// Read rounded to 0.1 mph, so each press moves one treadmill increment.
    private var targetMph: Binding<Double> {
        Binding(
            get: { Pace.mph(fromSecondsPerMile: step.targetPaceSecondsPerMile ?? 0) },
            set: { step.targetPaceSecondsPerMile = Pace.secondsPerMile(fromMph: $0) }
        )
    }
}
```

- [ ] **Step 6: Create `Sources/RunPlan/Plan/WorkoutEditView.swift`**

```swift
import SwiftUI
import RunCore

/// Edits a copy of a planned workout: title, date and steps. Nothing changes until Save.
struct WorkoutEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Workout
    let onSave: (Workout) -> Void

    init(workout: Workout, onSave: @escaping (Workout) -> Void) {
        _draft = State(initialValue: workout)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $draft.title)
                    DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                }
                Section {
                    ForEach($draft.steps) { $step in
                        let index = draft.steps.firstIndex { $0.id == step.id } ?? 0
                        StepEditor(
                            step: $step,
                            repeatCount: draft.startsRepeatGroup(at: index) ? repeatCount(forStep: step.id) : nil
                        )
                    }
                    .onDelete { draft.steps.remove(atOffsets: $0) }
                    Button("Add step") {
                        draft.steps.append(Step(kind: .run, measure: .time(seconds: 300)))
                    }
                } header: {
                    Text("Steps")
                } footer: {
                    Text("Swipe a step to delete it.")
                }
            }
            .navigationTitle("Edit workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.steps.isEmpty)
                }
            }
        }
    }

    /// The repeat count of the group starting at the step with `id`, looked up on every access
    /// because deleting steps shifts indices.
    private func repeatCount(forStep id: UUID) -> Binding<Int> {
        Binding(
            get: {
                guard let index = draft.steps.firstIndex(where: { $0.id == id }) else { return 1 }
                return draft.repeatCount(ofGroupAt: index)
            },
            set: { count in
                guard let index = draft.steps.firstIndex(where: { $0.id == id }) else { return }
                draft.setRepeatCount(count, ofGroupAt: index)
            }
        )
    }
}
```

- [ ] **Step 7: Add Edit to the detail screen**

In `Sources/RunPlan/Workout/WorkoutDetailView.swift`, add a state property under `choosingMode`:

```swift
    @State private var editing = false
```

and, in `detail(_:)`, add these modifiers after `.navigationBarTitleDisplayMode(.inline)`:

```swift
        .toolbar {
            Button("Edit") { editing = true }
        }
        .sheet(isPresented: $editing) {
            WorkoutEditView(workout: workout) { app.update($0) }
        }
```

- [ ] **Step 8: Build**

Run: BUILD
Expected: success.

- [ ] **Step 9: Commit**

```bash
git add RunCore/Sources/RunCore/Models/Workout+RepeatGroups.swift RunCore/Tests/RunCoreTests/WorkoutRepeatGroupTests.swift Sources/RunPlan/Plan Sources/RunPlan/Workout/WorkoutDetailView.swift
git commit -m "Add workout editing" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Docs, final verification and on-device check

**Goal:** Record the stage 3 deviations in the spec, add the stage 3 on-device checklist to the README, and verify everything end to end.

**Files:**
- Modify: `README.md`, `docs/superpowers/specs/2026-10-12-runplan-design.md`

**Acceptance Criteria:**
- [ ] The spec notes that the profile lives inside `plan.json`, that `daysPerWeek` is derived, and that `units` is omitted
- [ ] The README has a stage 3 on-device checklist
- [ ] TEST passes in full and BUILD succeeds
- [ ] The app is installed on the phone, and the checklist has been handed to the user

**Verify:** TEST → `Executed N tests, with 0 failures`; BUILD → success

**Steps:**

- [ ] **Step 1: Add an implementation note to the spec**

In `docs/superpowers/specs/2026-10-12-runplan-design.md`, add this paragraph directly after the line `history never rewrites one large file.`:

```markdown
Implementation note (stage 3, 2026-10-18): the profile is stored inside `plan.json` rather than
in its own `profile.json`, since a plan is always generated from exactly one profile.
`Profile.daysPerWeek` is derived from `runDays`, and the fixed `units` field is omitted until
kilometres are supported. The generator's exact numbers (walk-run ladder, session lengths, caps)
are in `docs/superpowers/plans/2026-10-18-plan-generation.md`.
```

- [ ] **Step 2: Add the stage 3 checklist to the README**

Append to `README.md`:

```markdown

## On-device checklist (plan generation)

- Delete and reinstall the app (or start without a plan): onboarding appears.
- A 5K goal of 20:00 for a new runner shows the ambitious-goal warning, and "Train to finish
  instead" clears it.
- Save a plan: the Plan tab shows Today or Next on top and every week below.
- Open a workout, tap Edit, change its date and one step's speed, Save: the change shows, and
  survives a relaunch.
- Run a planned workout and save it: it gets a done mark and the week's count goes up.
```

- [ ] **Step 3: Run the full verification**

Run: TEST
Expected: every test passes, with no failures.

Run: BUILD
Expected: success.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/superpowers/specs/2026-10-12-runplan-design.md
git commit -m "Document plan generation and its on-device checks" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Install on the phone**

Follow README "Commands": start `tools/muxshim.py` in a second WSL terminal, then run `xtool dev` from the repo root. The existing install has no `plan.json`, so onboarding appears on first launch. Hand the checklist from Step 2 to the user; only they can run it.
