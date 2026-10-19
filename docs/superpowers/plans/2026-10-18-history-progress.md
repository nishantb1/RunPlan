# History, Progress and Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** RunPlan gets History (every run with its summary and route), Progress (weekly distance, pace trend, plan completion, longest run) and Settings (keep screen awake, voice cues, auto-pause outdoors, change plan, reset), completing the spec's five build stages.

**Architecture:** The logic lives in `RunCore`, unit-tested on Linux: settings with forward-compatible decoding, run statistics and plan progress, an auto-pause detector fed by GPS fixes, and run routes stored in their own files so the run list loads without them. The app adds three tabs, a run detail screen, Swift Charts, and settings that the workout session reads when it starts.

**Tech Stack:** Swift 6.4 in WSL (Ubuntu 24.04), xtool 1.22.2, SwiftUI, Swift Charts and MapKit (iOS 17), XCTest. No third-party packages.

**Spec:** `docs/superpowers/specs/2026-10-12-runplan-design.md`, build stage 5 ("Screens" 6-8, "Workout engine" auto-pause, the `Stats/` layout entry), and the stage 5 notes in its stage 4 implementation note.

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

These are called **TEST** and **BUILD** below. To run one test class, add `--filter <ClassName>` after `swift test`. The suite has 124 passing tests before this plan. BUILD must end with no warnings in `Sources/RunPlan`.

Rules: one type per file (small private helper views may share their screen's file), value types where possible, no force unwrapping outside tests, no SwiftUI/UIKit/AVFoundation/CoreLocation imports in `RunCore`. Everything `RunCore` exposes to the app is `public`. Commit after each task with a plain message: no Co-Authored-By or other Claude attribution line.

`RunCore` tasks (1 to 4) are test-first. App tasks (5 to 8) are verified with BUILD, then on the phone in Task 9.

## Design decisions fixed by this plan

- **Settings** (`settings.json`): keep screen awake (default on), voice cues (default on), auto-pause (default off). Missing keys decode to their defaults, so settings saved by an older build still load. The session reads the settings once, when the workout starts.
- **Voice cues off** silences step announcements, mile splits, pace cues and "Workout complete". Countdown beeps and haptics still play, and the app no longer ducks other audio, so music plays at full volume.
- **Auto-pause** applies outdoors only. Over the last 6 s of used fixes, with at least 4 s of data:
  - while running, a speed below 0.5 m/s pauses the workout
  - after an automatic pause, a speed above 1.2 m/s resumes it, as long as the distance moved is also more than the
    two readings' combined accuracy (capped at 15 m), so GPS wander while standing does not resume it
  - a pause or resume by hand cancels any automatic state and clears the window, so a manual pause is never resumed
    automatically and a manual resume after standing is not paused again straight away

  Both changes are spoken ("Auto-paused." / "Resumed.") and the live screen shows "Auto-paused". With a 4 m/s runner stopping at 30 s, it pauses at 36 s; setting off again at 3 m/s from 60 s resumes at 64 s (checked by hand).
- **Routes** are stored in `routes/<id>.json`, separately from `records/<id>.json`. `RunStore.all()` returns records with empty routes, and the run detail screen loads the route on demand. Records saved before this change keep their embedded route, which `route(for:)` still reads.
- **Statistics:**
  - Weeks start on Monday.
  - Weekly distance covers the last 8 weeks, empty weeks included.
  - The pace trend is each run's average pace, for the last 12 runs of at least 100 m, oldest first.
  - The longest run is the greatest distance.
  - Plan completion counts the plan's workouts that have a record.
- **Charts** (per the data-visualisation guidance):
  - Both charts are single series in one colour, with no legend.
  - Weekly distance is a bar chart with 4 pt rounded bars. Tapping a bar shows its miles and number of runs.
  - Pace is a 2 pt line with 8 pt points, faster plotted higher, and tapping shows the nearest run.
  - Plan completion and the longest run are stat tiles, not charts.
  - The colour is `#C85A12` in light mode and `#D86A24` in dark mode, both validated with the guidance's palette validator (lightness band, chroma and contrast pass in each mode). iOS's system orange failed: too low contrast in light mode, too light in dark mode.
- **Reset** deletes the plan, every run and route, the settings and any unfinished workout, after a confirmation, and returns to onboarding.
- **Change plan** stays on the Plan tab and is also offered in Settings, which the spec lists as "regenerate plan".
- **Deferred, not in this plan:**
  - The pace-cue grace period, which waits on the user's outdoor run.
  - Writing the route to the crash checkpoint less often.
  - Drawing the route across a pause.

## File structure

```
RunCore/Sources/RunCore/
  Models/   AppSettings.swift                                                  (new)
  Storage/  SettingsStore.swift                                                (new)
            RunStore.swift PlanStore.swift                                     (modify)
  Stats/    WeeklyTotal.swift PacePoint.swift RunStats.swift PlanProgress.swift (new)
  Tracking/ AutoPauseDetector.swift                                            (new)
RunCore/Tests/RunCoreTests/
  SettingsStoreTests.swift RunStatsTests.swift AutoPauseDetectorTests.swift
  RunStoreTests.swift                                                          (new)
Sources/RunPlan/
  App/AppModel.swift RootView.swift                                            (modify)
  Workout/WorkoutSessionModel.swift LiveWorkoutView.swift SummaryView.swift    (modify)
  Workout/RouteMap.swift SplitLabel.swift                                      (new)
  History/HistoryView.swift RunDetailView.swift                                (new; replaces Runs/RunsView.swift)
  Progress/StatsView.swift ChartColor.swift                                    (new)
  Settings/SettingsView.swift                                                  (new)
README.md, docs/superpowers/specs/2026-10-12-runplan-design.md                 (modify)
```

---

### Task 1: Settings

**Goal:** An `AppSettings` value with forward-compatible decoding, and a `SettingsStore` that loads, saves and deletes `settings.json`.

**Files:**
- Create: `RunCore/Sources/RunCore/Models/AppSettings.swift`, `RunCore/Sources/RunCore/Storage/SettingsStore.swift`
- Create: `RunCore/Tests/RunCoreTests/SettingsStoreTests.swift`

**Acceptance Criteria:**
- [ ] With no file, `load()` returns the defaults (screen awake on, voice cues on, auto-pause off)
- [ ] Saved settings load back equal; a file with only some keys loads with defaults for the rest
- [ ] `delete()` removes the file, so `load()` returns the defaults again

**Verify:** TEST with `--filter SettingsStoreTests` → `Executed 4 tests, with 0 failures`

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/SettingsStoreTests.swift`:

```swift
import XCTest
@testable import RunCore

final class SettingsStoreTests: XCTestCase {

    private var directory: URL!
    private var settings: SettingsStore!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("runcore-\(UUID().uuidString)")
        settings = SettingsStore(store: JSONStore(directory: directory))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testDefaultsWhenNothingIsSaved() {
        XCTAssertEqual(settings.load(), AppSettings(keepScreenAwake: true, voiceCues: true, autoPause: false))
    }

    func testSaveThenLoad() throws {
        let changed = AppSettings(keepScreenAwake: false, voiceCues: false, autoPause: true)
        try settings.save(changed)
        XCTAssertEqual(settings.load(), changed)
    }

    func testMissingKeysTakeTheirDefaults() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"voiceCues":false}"#.utf8).write(to: directory.appendingPathComponent("settings.json"))
        XCTAssertEqual(settings.load(), AppSettings(keepScreenAwake: true, voiceCues: false, autoPause: false))
    }

    func testDeleteReturnsToDefaults() throws {
        try settings.save(AppSettings(keepScreenAwake: false, voiceCues: false, autoPause: true))
        settings.delete()
        XCTAssertEqual(settings.load(), AppSettings())
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: TEST with `--filter SettingsStoreTests`
Expected: build errors such as `cannot find 'SettingsStore' in scope`.

- [ ] **Step 3: Write the implementation**

`RunCore/Sources/RunCore/Models/AppSettings.swift`:

```swift
import Foundation

/// The runner's preferences. A workout reads them once, when it starts.
public struct AppSettings: Codable, Equatable, Sendable {
    /// Keep the screen on during a workout.
    public var keepScreenAwake: Bool
    /// Speak step announcements, mile splits and pace cues. Countdown beeps and haptics play
    /// either way.
    public var voiceCues: Bool
    /// Outdoors, pause when the runner stops and resume when they set off again.
    public var autoPause: Bool

    public init(keepScreenAwake: Bool = true, voiceCues: Bool = true, autoPause: Bool = false) {
        self.keepScreenAwake = keepScreenAwake
        self.voiceCues = voiceCues
        self.autoPause = autoPause
    }

    /// Missing keys take their defaults, so settings saved by an older build still load.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        keepScreenAwake = try container.decodeIfPresent(Bool.self, forKey: .keepScreenAwake) ?? defaults.keepScreenAwake
        voiceCues = try container.decodeIfPresent(Bool.self, forKey: .voiceCues) ?? defaults.voiceCues
        autoPause = try container.decodeIfPresent(Bool.self, forKey: .autoPause) ?? defaults.autoPause
    }
}
```

`RunCore/Sources/RunCore/Storage/SettingsStore.swift`:

```swift
import Foundation

/// The runner's settings, stored as one small file.
public struct SettingsStore: Sendable {
    private static let file = "settings.json"
    private let store: JSONStore

    public init(store: JSONStore) {
        self.store = store
    }

    /// The saved settings, or the defaults when none are saved.
    public func load() -> AppSettings {
        store.load(AppSettings.self, from: Self.file) ?? AppSettings()
    }

    public func save(_ settings: AppSettings) throws {
        try store.save(settings, as: Self.file)
    }

    public func delete() {
        store.delete(Self.file)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add RunCore/Sources/RunCore/Models/AppSettings.swift RunCore/Sources/RunCore/Storage/SettingsStore.swift RunCore/Tests/RunCoreTests/SettingsStoreTests.swift
git commit -m "Add settings and their store"
```

---

### Task 2: Run statistics and plan progress

**Goal:** Weekly distance totals, a pace trend, the longest run and plan completion, computed from run records and the plan.

**Files:**
- Create: `RunCore/Sources/RunCore/Stats/WeeklyTotal.swift`, `PacePoint.swift`, `RunStats.swift`, `PlanProgress.swift`
- Create: `RunCore/Tests/RunCoreTests/RunStatsTests.swift`

**Acceptance Criteria:**
- [ ] Three Monday-start weeks ending Wednesday 18 Nov 2026 give 5, 0 and 1 miles with 2, 0 and 2 runs; a run the week before is left out
- [ ] The pace trend skips runs without distance, runs oldest first, and keeps the last `limit` (paces 660 then 540 for a limit of 2)
- [ ] The longest run is the 4-mile one; with no distances there is none
- [ ] Plan progress counts completed workouts (2 of 24, fraction 1/12)

**Verify:** TEST with `--filter RunStatsTests` → `Executed 6 tests, with 0 failures`

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/RunStatsTests.swift`:

```swift
import XCTest
@testable import RunCore

final class RunStatsTests: XCTestCase {

    private func run(_ month: Int, _ day: Int, miles: Double, minutes: Int) -> RunRecord {
        var start = TestCalendar.date(2026, month, day)
        start.addTimeInterval(8 * 3600)
        return RunRecord(
            mode: .outdoor,
            startedAt: start,
            durationSeconds: minutes * 60,
            distanceMeters: Pace.meters(fromMiles: miles)
        )
    }

    private lazy var runs = [
        run(10, 30, miles: 4, minutes: 40),
        run(11, 3, miles: 2, minutes: 20),
        run(11, 5, miles: 3, minutes: 33),
        run(11, 16, miles: 1, minutes: 9),
        run(11, 17, miles: 0, minutes: 25),
    ]

    func testWeeklyTotalsIncludeEmptyWeeks() {
        let weeks = RunStats.weeklyTotals(runs, weeks: 3, endingOn: TestCalendar.date(2026, 11, 18), calendar: TestCalendar.utc)
        XCTAssertEqual(weeks.map(\.weekStart), [
            TestCalendar.date(2026, 11, 2), TestCalendar.date(2026, 11, 9), TestCalendar.date(2026, 11, 16),
        ])
        XCTAssertEqual(weeks.map { (Pace.miles(fromMeters: $0.meters) * 1000).rounded() / 1000 }, [5, 0, 1])
        XCTAssertEqual(weeks.map(\.runs), [2, 0, 2])
    }

    func testPaceTrendSkipsRunsWithoutDistance() {
        XCTAssertEqual(RunStats.paceTrend(runs, limit: 2).map(\.secondsPerMile), [660, 540])
        XCTAssertEqual(RunStats.paceTrend(runs, limit: 10).map(\.secondsPerMile), [600, 600, 660, 540])
    }

    func testWeeksStartOnMondayWhateverTheCalendarSays() {
        var sundayFirst = TestCalendar.utc
        sundayFirst.firstWeekday = 1
        let mondayMidnight = TestCalendar.date(2026, 11, 9)
        let boundaryRuns = [
            RunRecord(mode: .treadmill, startedAt: mondayMidnight.addingTimeInterval(-1), durationSeconds: 600, distanceMeters: 1000),
            RunRecord(mode: .treadmill, startedAt: mondayMidnight, durationSeconds: 600, distanceMeters: 2000),
        ]
        let weeks = RunStats.weeklyTotals(boundaryRuns, weeks: 2, endingOn: TestCalendar.date(2026, 11, 10), calendar: sundayFirst)
        XCTAssertEqual(weeks.map(\.weekStart), [TestCalendar.date(2026, 11, 2), mondayMidnight])
        XCTAssertEqual(weeks.map(\.meters), [1000, 2000])
    }

    func testPaceTrendIgnoresRunsTooShortToTime() {
        let short = RunRecord(mode: .outdoor, startedAt: TestCalendar.date(2026, 11, 20), durationSeconds: 5, distanceMeters: 50)
        XCTAssertEqual(RunStats.paceTrend(runs + [short], limit: 10).map(\.secondsPerMile), [600, 600, 660, 540])
    }

    func testLongestRun() {
        XCTAssertEqual(RunStats.longestRun(runs)?.distanceMeters, Pace.meters(fromMiles: 4))
        XCTAssertNil(RunStats.longestRun([run(11, 17, miles: 0, minutes: 25)]))
    }

    func testPlanProgressCountsCompletedWorkouts() {
        var plan = PlanGenerator.generate(makeProfile(), calendar: TestCalendar.utc)
        plan.markCompleted(workoutID: plan.weeks[0].workouts[0].id, recordID: UUID())
        plan.markCompleted(workoutID: plan.weeks[0].workouts[1].id, recordID: UUID())
        let progress = PlanProgress(plan: plan)
        XCTAssertEqual(progress.completed, 2)
        XCTAssertEqual(progress.total, 24)
        XCTAssertEqual(progress.fraction, 2.0 / 24.0, accuracy: 1e-9)
    }
}
```

The 0-mile run on 17 Nov counts as a run in its week but adds no distance and has no pace, so week 3 has 2 runs and 1 mile. The 30 Oct run falls in the week before the first one shown.

- [ ] **Step 2: Run the tests to verify they fail**

Run: TEST with `--filter RunStatsTests`
Expected: build errors such as `cannot find 'RunStats' in scope`.

- [ ] **Step 3: Write the implementation**

`RunCore/Sources/RunCore/Stats/WeeklyTotal.swift`:

```swift
import Foundation

/// Distance and number of runs in one Monday-start week.
public struct WeeklyTotal: Equatable, Sendable {
    public let weekStart: Date
    public let meters: Double
    public let runs: Int

    public init(weekStart: Date, meters: Double, runs: Int) {
        self.weekStart = weekStart
        self.meters = meters
        self.runs = runs
    }
}
```

`RunCore/Sources/RunCore/Stats/PacePoint.swift`:

```swift
import Foundation

/// One run's average pace, for the pace trend.
public struct PacePoint: Equatable, Sendable {
    public let date: Date
    public let secondsPerMile: Int

    public init(date: Date, secondsPerMile: Int) {
        self.date = date
        self.secondsPerMile = secondsPerMile
    }
}
```

`RunCore/Sources/RunCore/Stats/RunStats.swift`:

```swift
import Foundation

/// Figures for the Progress screen, computed from saved runs.
public enum RunStats {

    /// Runs shorter than this (ended straight away, say, with a little GPS drift) give a
    /// meaningless pace, so the pace trend leaves them out.
    static let minimumPaceMeters = 100.0

    /// Distance and run count for each of the last `weeks` Monday-start weeks up to the week
    /// containing `now`, oldest first. Weeks without runs are included.
    public static func weeklyTotals(_ records: [RunRecord], weeks: Int, endingOn now: Date, calendar: Calendar) -> [WeeklyTotal] {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        guard weeks > 0, let current = mondayFirst.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return (0..<weeks).reversed().compactMap { weeksBack in
            guard let start = mondayFirst.date(byAdding: .day, value: -7 * weeksBack, to: current.start),
                  let end = mondayFirst.date(byAdding: .day, value: 7, to: start) else { return nil }
            let inWeek = records.filter { $0.startedAt >= start && $0.startedAt < end }
            return WeeklyTotal(weekStart: start, meters: inWeek.reduce(0) { $0 + $1.distanceMeters }, runs: inWeek.count)
        }
    }

    /// Average pace of each run of at least 100 m, oldest first, keeping the last `limit`.
    public static func paceTrend(_ records: [RunRecord], limit: Int) -> [PacePoint] {
        let points = records
            .filter { $0.distanceMeters >= minimumPaceMeters }
            .sorted { $0.startedAt < $1.startedAt }
            .compactMap { record in
                Pace.secondsPerMile(distanceMeters: record.distanceMeters, durationSeconds: record.durationSeconds)
                    .map { PacePoint(date: record.startedAt, secondsPerMile: $0) }
            }
        return Array(points.suffix(max(limit, 0)))
    }

    /// The run with the greatest distance, or nil when no run has a distance.
    public static func longestRun(_ records: [RunRecord]) -> RunRecord? {
        records.filter { $0.distanceMeters > 0 }.max { $0.distanceMeters < $1.distanceMeters }
    }
}
```

`RunCore/Sources/RunCore/Stats/PlanProgress.swift`:

```swift
import Foundation

/// How much of the plan is done: workouts with a saved run, out of all workouts.
public struct PlanProgress: Equatable, Sendable {
    public let completed: Int
    public let total: Int

    public init(plan: Plan) {
        let workouts = plan.workouts
        total = workouts.count
        completed = workouts.filter { $0.recordID != nil }.count
    }

    public var fraction: Double {
        total == 0 ? 0 : Double(completed) / Double(total)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add RunCore/Sources/RunCore/Stats RunCore/Tests/RunCoreTests/RunStatsTests.swift
git commit -m "Add run statistics and plan progress"
```

---

### Task 3: Auto-pause detector

**Goal:** `AutoPauseDetector` turns GPS fixes into pause and resume decisions, and never resumes a manual pause.

**Files:**
- Create: `RunCore/Sources/RunCore/Tracking/AutoPauseDetector.swift`
- Create: `RunCore/Tests/RunCoreTests/AutoPauseDetectorTests.swift`

**Acceptance Criteria:**
- [ ] A runner at 4 m/s who stops at 30 s is paused once, at 36 s; setting off at 3 m/s from 60 s resumes once, at 64 s
- [ ] GPS readings wandering 4 m while stopped do not resume; a manual resume needs 4 s of fresh data before it can pause again
- [ ] With under 4 s of fixes nothing happens
- [ ] A manual pause (not running) is never resumed automatically, and `manualOverride()` cancels an automatic pause

**Verify:** TEST with `--filter AutoPauseDetectorTests` → `Executed 5 tests, with 0 failures`

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/AutoPauseDetectorTests.swift`:

```swift
import XCTest
@testable import RunCore

final class AutoPauseDetectorTests: XCTestCase {

    /// 4 m/s until 30 s, standing at 120 m until 60 s, then 3 m/s.
    private func position(at second: Int) -> Double {
        if second <= 30 { return Double(4 * second) }
        if second <= 60 { return 120 }
        return 120 + Double(3 * (second - 60))
    }

    func testPausesWhenStoppedAndResumesWhenMovingAgain() {
        var detector = AutoPauseDetector()
        var running = true
        var actions: [(Int, AutoPauseDetector.Action)] = []

        for second in 0...80 {
            if let action = detector.update(fix(at: Double(second), north: position(at: second)), isRunning: running) {
                actions.append((second, action))
                running = action == .resume
            }
        }

        XCTAssertEqual(actions.map { $0.0 }, [36, 64])
        XCTAssertEqual(actions.map { $0.1 }, [.pause, .resume])
    }

    func testGPSJitterWhileStoppedDoesNotResume() {
        var detector = AutoPauseDetector()
        var running = true
        var actions: [AutoPauseDetector.Action] = []
        // Standing at 120 m from 30 s, with readings wandering 4 m either side.
        let jitter: [Double] = [0, 4, 0, -4]

        for second in 0...90 {
            let north = second <= 30 ? Double(4 * second) : 120 + jitter[second % 4]
            if let action = detector.update(fix(at: Double(second), north: north), isRunning: running) {
                actions.append(action)
                running = action == .resume
            }
        }

        XCTAssertEqual(actions, [.pause])
    }

    func testManualResumeAfterStandingWaitsForFreshData() {
        var detector = AutoPauseDetector()
        for second in 0...20 {
            _ = detector.update(fix(at: Double(second), north: 0), isRunning: false)
        }

        // The runner taps Resume and sets off at 2 m/s.
        detector.manualOverride()
        for second in 21...25 {
            XCTAssertNil(detector.update(fix(at: Double(second), north: Double(2 * (second - 20))), isRunning: true))
        }
    }

    func testNothingHappensWithTooLittleData() {
        var detector = AutoPauseDetector()
        for second in 0...3 {
            XCTAssertNil(detector.update(fix(at: Double(second), north: 0), isRunning: true))
        }
    }

    func testManualPausesAreNeverResumedAutomatically() {
        var paused = AutoPauseDetector()
        for second in 0...80 {
            XCTAssertNil(paused.update(fix(at: Double(second), north: position(at: second)), isRunning: false))
        }

        var overridden = AutoPauseDetector()
        var actions: [AutoPauseDetector.Action] = []
        for second in 0...80 {
            if second == 40 { overridden.manualOverride() }
            if let action = overridden.update(fix(at: Double(second), north: position(at: second)), isRunning: second <= 36) {
                actions.append(action)
            }
        }
        XCTAssertEqual(actions, [.pause])
        XCTAssertFalse(overridden.isAutoPaused)
    }
}
```

In the second case of the last test, the detector pauses at 36 s. At 40 s the runner presses pause or resume by hand (`manualOverride()`), so setting off at 60 s no longer resumes automatically.

- [ ] **Step 2: Run the tests to verify they fail**

Run: TEST with `--filter AutoPauseDetectorTests`
Expected: build errors such as `cannot find 'AutoPauseDetector' in scope`.

- [ ] **Step 3: Write the implementation**

`RunCore/Sources/RunCore/Tracking/AutoPauseDetector.swift`:

```swift
import Foundation

/// Decides when an outdoor run should pause because the runner has stopped, and resume when
/// they set off again, from straight-line speed over the last 6 seconds of fixes. Straight line
/// is used because jitter adds to a path length; the cost is that a very sharp turnaround can
/// pause briefly, which corrects itself a few seconds later.
public struct AutoPauseDetector: Codable, Equatable, Sendable {
    public enum Action: String, Codable, Sendable {
        case pause
        case resume
    }

    static let windowSeconds: TimeInterval = 6
    static let minimumSpanSeconds: TimeInterval = 4
    /// Slower than this while running means the runner has stopped.
    static let stoppedMetersPerSecond = 0.5
    /// Faster than this after an automatic pause means they have set off again. The gap between
    /// the two thresholds stops GPS jitter flipping between paused and running.
    static let movingMetersPerSecond = 1.2
    /// Most of a reading's accuracy radius that a resume must clear, so GPS wander while
    /// standing still never resumes the run.
    static let maxNoiseFloorMeters = 15.0

    private var fixes: [LocationSample] = []
    public private(set) var isAutoPaused = false

    public init() {}

    /// Feed every fix that passed `SampleFilter`. `isRunning` is whether the workout is running
    /// (not paused). Returns the change to make, if any.
    public mutating func update(_ sample: LocationSample, isRunning: Bool) -> Action? {
        fixes.append(sample)
        fixes.removeAll { sample.timestamp.timeIntervalSince($0.timestamp) > Self.windowSeconds }
        guard let first = fixes.first else { return nil }
        let span = sample.timestamp.timeIntervalSince(first.timestamp)
        guard span >= Self.minimumSpanSeconds else { return nil }
        let distance = Geo.distance(first, sample)
        let speed = distance / span
        let noiseFloor = min(first.horizontalAccuracy + sample.horizontalAccuracy, Self.maxNoiseFloorMeters)

        if isRunning, !isAutoPaused, speed < Self.stoppedMetersPerSecond {
            isAutoPaused = true
            return .pause
        }
        if isAutoPaused, speed > Self.movingMetersPerSecond, distance > noiseFloor {
            isAutoPaused = false
            return .resume
        }
        return nil
    }

    /// Call when the runner pauses or resumes by hand. A manual pause is then never resumed
    /// automatically, and after a manual resume the detector waits for fresh fixes rather than
    /// judging the runner by the seconds they spent standing still.
    public mutating func manualOverride() {
        isAutoPaused = false
        fixes.removeAll()
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add RunCore/Sources/RunCore/Tracking/AutoPauseDetector.swift RunCore/Tests/RunCoreTests/AutoPauseDetectorTests.swift
git commit -m "Add the auto-pause detector"
```

---

### Task 4: Routes in their own files, and deleting stored data

**Goal:** `RunStore` keeps each run's route in `routes/<id>.json`, so the run list loads without routes; `RunStore` and `PlanStore` can delete everything they store.

**Files:**
- Modify: `RunCore/Sources/RunCore/Storage/RunStore.swift`, `RunCore/Sources/RunCore/Storage/PlanStore.swift`
- Create: `RunCore/Tests/RunCoreTests/RunStoreTests.swift`

**Acceptance Criteria:**
- [ ] A saved outdoor run lists with an empty route; `route(for:)` returns its route from `routes/<id>.json`
- [ ] A record saved before this change, with its route inside, still lists without it and `route(for:)` still returns it
- [ ] A run with no route writes no route file
- [ ] `RunStore.deleteAll()` and `PlanStore.delete()` remove their files

**Verify:** TEST with `--filter RunStoreTests` → `Executed 4 tests, with 0 failures`

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/RunStoreTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: TEST with `--filter RunStoreTests`
Expected: build errors such as `value of type 'RunStore' has no member 'route'`.

- [ ] **Step 3: Write the implementation**

Replace `RunCore/Sources/RunCore/Storage/RunStore.swift` with:

```swift
import Foundation

/// Run history: one file per run, so a long history never rewrites one large file. Each run's
/// route has its own file too, so listing runs never loads routes.
public struct RunStore: Sendable {
    private static let folder = "records"
    private static let routeFolder = "routes"
    private let store: JSONStore

    public init(store: JSONStore) {
        self.store = store
    }

    /// Saves a finished run with its route. The route is written first, so the record is the
    /// commit point: an interrupted save leaves at most an unlisted route file, never a listed
    /// run that has lost its route. Records from `all()` carry no route, so do not save one
    /// back as it is.
    public func save(_ record: RunRecord) throws {
        if !record.route.isEmpty {
            try store.save(record.route, as: routeName(record.id))
        }
        var listed = record
        listed.route = []
        try store.save(listed, as: recordName(record.id))
    }

    /// Every readable record, newest first, without routes (see `route(for:)`).
    public func all() -> [RunRecord] {
        store.names(in: Self.folder)
            .filter { $0.hasSuffix(".json") }
            .compactMap { name -> RunRecord? in
                // Older records carry their route inside; drop it straight away.
                guard var record = store.load(RunRecord.self, from: "\(Self.folder)/\(name)") else { return nil }
                record.route = []
                return record
            }
            .sorted { $0.startedAt > $1.startedAt }
    }

    /// The run's route. Records saved before routes had their own files keep it inside.
    public func route(for record: RunRecord) -> [RoutePoint] {
        store.load([RoutePoint].self, from: routeName(record.id))
            ?? store.load(RunRecord.self, from: recordName(record.id))?.route
            ?? []
    }

    /// Deletes every run and route.
    public func deleteAll() {
        store.delete(Self.folder)
        store.delete(Self.routeFolder)
    }

    private func recordName(_ id: UUID) -> String {
        "\(Self.folder)/\(id.uuidString).json"
    }

    private func routeName(_ id: UUID) -> String {
        "\(Self.routeFolder)/\(id.uuidString).json"
    }
}
```

In `RunCore/Sources/RunCore/Storage/PlanStore.swift`, add after the `save(_:)` function:

```swift

    public func delete() {
        store.delete(Self.file)
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass, including the existing `JSONStoreTests.testRunStoreReturnsNewestFirst`.

- [ ] **Step 5: Commit**

```bash
git add RunCore/Sources/RunCore/Storage RunCore/Tests/RunCoreTests/RunStoreTests.swift
git commit -m "Store routes separately and let stores delete their data"
```

---

### Task 5: Settings in the app and the workout session

**Goal:** `AppModel` holds the settings, reads routes on demand and can reset everything; the workout session applies keep-screen-awake, voice cues and outdoor auto-pause.

**Files:**
- Modify: `Sources/RunPlan/App/AppModel.swift`, `Sources/RunPlan/Workout/WorkoutSessionModel.swift`, `Sources/RunPlan/Workout/LiveWorkoutView.swift`

**Acceptance Criteria:**
- [ ] `AppModel.settings` loads at launch and `updateSettings(_:)` saves changes; `route(for:)` reads a run's route; `reset()` deletes the plan, runs, routes, settings and checkpoint and clears the in-memory state
- [ ] A session keeps the screen awake only when the setting is on, and speaks only when voice cues are on (beeps and haptics either way)
- [ ] Outdoors with auto-pause on, the detector pauses and resumes the engine, speaks the change, and a manual pause or resume cancels any automatic pause
- [ ] The live screen shows "Auto-paused" while auto-paused; BUILD succeeds

**Verify:** BUILD → success, no warnings in `Sources/RunPlan`

**Steps:**

- [ ] **Step 1: Settings, routes and reset in `AppModel`**

In `Sources/RunPlan/App/AppModel.swift`:

1. After `    private let plans: PlanStore`, add:

```swift
    private let settingsStore: SettingsStore
```

2. After `    private(set) var plan: Plan?`, add:

```swift
    /// Read by each workout when it starts.
    private(set) var settings: AppSettings
```

3. In `init()`, after `        plans = PlanStore(store: store)`, add:

```swift
        settingsStore = SettingsStore(store: store)
        settings = settingsStore.load()
```

4. Change `WorkoutSessionModel(workout: workout, mode: mode, store: store, location: location)` to `WorkoutSessionModel(workout: workout, mode: mode, store: store, location: location, settings: settings)`, and `WorkoutSessionModel(resuming: active, store: store, location: location)` to `WorkoutSessionModel(resuming: active, store: store, location: location, settings: settings)`.

5. After the `update(_:)` function, add:

```swift

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        change(&settings)
        try? settingsStore.save(settings)
    }

    /// A saved run's route, loaded from its own file when the run is opened. A long run holds
    /// thousands of points, so the file is read and decoded off the main thread.
    func route(for record: RunRecord) async -> [RoutePoint] {
        let runs = runs
        return await Task.detached(priority: .userInitiated) { runs.route(for: record) }.value
    }

    /// Deletes the plan, every run, the settings and any unfinished workout, which returns the
    /// app to onboarding. Only call it with no workout in progress (Settings is not reachable
    /// during one), since it deletes the checkpoint directly.
    func reset() {
        plans.delete()
        runs.deleteAll()
        settingsStore.delete()
        store.delete(WorkoutSessionModel.checkpointFile)
        plan = nil
        records = []
        settings = AppSettings()
        pendingResume = nil
    }
```

- [ ] **Step 2: Apply the settings in `WorkoutSessionModel`**

In `Sources/RunPlan/Workout/WorkoutSessionModel.swift`:

1. After `    private let location: LocationService?`, add:

```swift
    private let settings: AppSettings
    /// Outdoors with auto-pause on only.
    private var autoPause: AutoPauseDetector?
```

2. Change the first initializer's signature to `    init(workout: Workout, mode: RunMode, store: JSONStore, location: LocationService, settings: AppSettings) {` and add at its end, after `        self.tracker = mode == .outdoor ? OutdoorTracker() : nil`:

```swift
        self.settings = settings
        self.autoPause = mode == .outdoor && settings.autoPause ? AutoPauseDetector() : nil
```

3. Change the resuming initializer's signature to `    init(resuming active: ActiveWorkout, store: JSONStore, location: LocationService, settings: AppSettings) {` and add at its end, after `        self.tracker = active.mode == .outdoor ? (active.outdoor ?? OutdoorTracker()) : nil`:

```swift
        self.settings = settings
        self.autoPause = active.mode == .outdoor && settings.autoPause ? AutoPauseDetector() : nil
```

4. After `    var isPaused: Bool { snapshot?.state == .paused }`, add:

```swift
    var isAutoPaused: Bool { autoPause?.isAutoPaused ?? false }
```

5. In `begin()`, change `        UIApplication.shared.isIdleTimerDisabled = true` to `        UIApplication.shared.isIdleTimerDisabled = settings.keepScreenAwake`.

6. Replace `pause()` and `resume()`:

```swift
    func pause() {
        engine.pause()
        refresh(forceCheckpoint: true)
    }

    func resume() {
        engine.resume()
        refresh(forceCheckpoint: true)
    }
```

with:

```swift
    func pause() {
        autoPause?.manualOverride()
        engine.pause()
        refresh(forceCheckpoint: true)
    }

    func resume() {
        autoPause?.manualOverride()
        engine.resume()
        refresh(forceCheckpoint: true)
    }
```

7. Replace `record(_:)`, including its doc comment:

```swift
    /// Records a fix and refreshes straight away, so splits and distance steps are handled
    /// promptly even if the screen refresh timer is slowed while the phone is locked.
    private func record(_ sample: LocationSample) {
        tracker?.record(sample, now: Date(), counting: engine.state == .running)
        refresh()
    }
```

with:

```swift
    /// Records a fix and refreshes straight away, so splits and distance steps are handled
    /// promptly even if the screen refresh timer is slowed while the phone is locked. With
    /// auto-pause on, the fix may also pause or resume the workout.
    private func record(_ sample: LocationSample) {
        let now = Date()
        // The snapshot settles a timed workout that has just run out, so a stop right at the
        // end cannot pause a workout that is already finished.
        let isRunning = engine.snapshot(now: now)?.state == .running
        // Fixes while paused only move the reference point, so the few metres covered before
        // an automatic resume is detected are not counted.
        tracker?.record(sample, now: now, counting: isRunning)
        if SampleFilter.accepts(sample, now: now),
           let action = autoPause?.update(sample, isRunning: isRunning) {
            applyAutoPause(action)
            return
        }
        refresh()
    }

    private func applyAutoPause(_ action: AutoPauseDetector.Action) {
        switch action {
        case .pause:
            engine.pause()
            speak("Auto-paused.")
        case .resume:
            engine.resume()
            speak("Resumed.")
        }
        haptics.stepTransition()
        refresh(forceCheckpoint: true)
    }

    /// Speaks only when voice cues are on. Beeps and haptics are not affected.
    private func speak(_ text: String) {
        if settings.voiceCues {
            audio.speak(text)
        }
    }
```

8. Replace each remaining `audio.speak(` call with `speak(` (four places: the step announcement, "Workout complete.", the split announcement and the pace cue). After this, `grep -n "audio.speak" Sources/RunPlan/Workout/WorkoutSessionModel.swift` shows only the one inside `speak(_:)`.

- [ ] **Step 3: Show auto-pause on the live screen**

In `Sources/RunPlan/Workout/LiveWorkoutView.swift`, directly before the line `                            Text(CueText.displayKind(snapshot.step.kind).uppercased())`, add:

```swift
                            if session.isAutoPaused {
                                Text("Auto-paused. Set off to resume.")
                                    .font(.headline)
                                    .foregroundStyle(.yellow)
                            }

```

- [ ] **Step 4: Build**

Run: BUILD
Expected: success, with no warnings in `Sources/RunPlan`.

- [ ] **Step 5: Commit**

```bash
git add Sources/RunPlan/App/AppModel.swift Sources/RunPlan/Workout/WorkoutSessionModel.swift Sources/RunPlan/Workout/LiveWorkoutView.swift
git commit -m "Apply settings and auto-pause in workouts"
```

---

### Task 6: History

**Goal:** A History tab lists runs newest first, each opening a detail screen with its summary, splits, notes and route map; the map is shared with the workout summary.

**Files:**
- Create: `Sources/RunPlan/Workout/RouteMap.swift`, `Sources/RunPlan/Workout/SplitLabel.swift`, `Sources/RunPlan/History/HistoryView.swift`, `Sources/RunPlan/History/RunDetailView.swift`
- Modify: `Sources/RunPlan/Workout/SummaryView.swift`, `Sources/RunPlan/App/RootView.swift`
- Delete: `Sources/RunPlan/Runs/RunsView.swift`

**Acceptance Criteria:**
- [ ] The second tab is History, listing runs newest first; tapping one opens its detail
- [ ] The detail shows date, treadmill or outdoor, time, distance and average pace when known, effort and notes when given, splits, and the route map (loaded when opened) for two or more points
- [ ] The workout summary uses the shared `RouteMap` and `SplitLabel`, and only `RouteMap.swift` imports MapKit
- [ ] BUILD succeeds

**Verify:** BUILD → success, no warnings in `Sources/RunPlan`

**Steps:**

- [ ] **Step 1: Create `Sources/RunPlan/Workout/RouteMap.swift`**

```swift
import SwiftUI
import MapKit
// SwiftUI's Map lives in this cross-import overlay; xtool's build does not pull it in on its own.
import _MapKit_SwiftUI
import RunCore

/// A run's route as an orange line on a zoom-only map, so a drag scrolls the surrounding list
/// instead of panning. Coordinates are converted in `init`, not on every redraw of the map.
struct RouteMap: View {
    private let coordinates: [CLLocationCoordinate2D]

    init(route: [RoutePoint]) {
        coordinates = route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: [.zoom]) {
            MapPolyline(coordinates: coordinates)
                .stroke(.orange, lineWidth: 4)
        }
        .accessibilityLabel("Route map")
    }
}
```

- [ ] **Step 2: Create `Sources/RunPlan/Workout/SplitLabel.swift`**

```swift
import Foundation
import RunCore

/// "Mile 3" for a whole mile, "Last 0.42 mi" for the partial split at the end.
enum SplitLabel {
    static func text(for split: Split) -> String {
        guard split.distanceMeters < Pace.metersPerMile - 1 else { return "Mile \(split.index)" }
        return String(format: "Last %.2f mi", Pace.miles(fromMeters: split.distanceMeters))
    }
}
```

- [ ] **Step 3: Use them in `SummaryView`**

In `Sources/RunPlan/Workout/SummaryView.swift`:

1. Replace the imports:

```swift
import SwiftUI
import MapKit
// SwiftUI's Map lives in this cross-import overlay; xtool's build does not pull it in on its own.
import _MapKit_SwiftUI
import RunCore
```

with:

```swift
import SwiftUI
import RunCore
```

2. Replace the route section's map:

```swift
                            // Zoom only, so a drag on the map scrolls the form instead of panning.
                            Map(initialPosition: .automatic, interactionModes: [.zoom]) {
                                MapPolyline(coordinates: session.route.map {
                                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                                })
                                .stroke(.orange, lineWidth: 4)
                            }
                            .frame(height: 240)
```

with:

```swift
                            RouteMap(route: session.route)
                                .frame(height: 240)
```

3. Replace `LabeledContent(splitLabel(split), value: Pace.clock(split.durationSeconds))` with `LabeledContent(SplitLabel.text(for: split), value: Pace.clock(split.durationSeconds))`, and delete the `private func splitLabel(_ split: Split) -> String { ... }` function.

- [ ] **Step 4: Create `Sources/RunPlan/History/RunDetailView.swift`**

```swift
import SwiftUI
import RunCore

/// One saved run: its summary, splits and notes, and the route map, loaded when opened.
struct RunDetailView: View {
    @Environment(AppModel.self) private var app
    let record: RunRecord

    @State private var route: [RoutePoint] = []

    var body: some View {
        Form {
            Section {
                LabeledContent("Date", value: record.startedAt.formatted(date: .complete, time: .shortened))
                LabeledContent("Where", value: record.mode == .outdoor ? "Outdoor" : "Treadmill")
                LabeledContent("Time", value: Pace.clock(record.durationSeconds))
                if record.distanceMeters > 0 {
                    LabeledContent("Distance", value: String(format: "%.2f mi", Pace.miles(fromMeters: record.distanceMeters)))
                }
                if let pace = Pace.secondsPerMile(distanceMeters: record.distanceMeters, durationSeconds: record.durationSeconds) {
                    LabeledContent("Average pace", value: "\(Pace.clock(pace)) /mi")
                }
                if let effort = record.perceivedEffort {
                    LabeledContent("Effort", value: "\(effort) of 5")
                }
            }

            if !record.splits.isEmpty {
                Section("Splits") {
                    ForEach(record.splits, id: \.index) { split in
                        LabeledContent(SplitLabel.text(for: split), value: Pace.clock(split.durationSeconds))
                    }
                }
            }

            if route.count > 1 {
                Section("Route") {
                    RouteMap(route: route)
                        .frame(height: 240)
                        .listRowInsets(EdgeInsets())
                }
            }

            if !record.notes.isEmpty {
                Section("Notes") {
                    Text(record.notes)
                }
            }
        }
        .navigationTitle(record.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: record.id) {
            route = await app.route(for: record)
        }
    }
}
```

- [ ] **Step 5: Create `Sources/RunPlan/History/HistoryView.swift` and remove `RunsView`**

```swift
import SwiftUI
import RunCore

/// Saved runs, newest first, each opening its summary.
struct HistoryView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            List {
                if app.records.isEmpty {
                    Text("No runs yet").foregroundStyle(.secondary)
                } else {
                    ForEach(app.records) { record in
                        NavigationLink(value: record.id) {
                            RunRow(record: record)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: UUID.self) { id in
                if let record = app.records.first(where: { $0.id == id }) {
                    RunDetailView(record: record)
                } else {
                    ContentUnavailableView("Run not found", systemImage: "questionmark.circle")
                }
            }
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

Then:

```bash
git rm Sources/RunPlan/Runs/RunsView.swift
```

- [ ] **Step 6: Point the tab at History**

In `Sources/RunPlan/App/RootView.swift`, replace:

```swift
                    RunsView()
                        .tabItem { Label("Runs", systemImage: "figure.run") }
```

with:

```swift
                    HistoryView()
                        .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
```

- [ ] **Step 7: Build**

Run: BUILD
Expected: success. `grep -rln "import MapKit" Sources` lists only `Sources/RunPlan/Workout/RouteMap.swift`, and `grep -rn "RunsView" Sources` finds nothing.

- [ ] **Step 8: Commit**

```bash
git add Sources/RunPlan
git commit -m "Add History with run details and a shared route map"
```

---

### Task 7: Progress

**Goal:** A Progress screen with plan-completion and longest-run tiles, a weekly distance bar chart and an average pace line chart, each tappable to read values.

**Files:**
- Create: `Sources/RunPlan/Progress/ChartColor.swift`, `Sources/RunPlan/Progress/StatsView.swift`

**Acceptance Criteria:**
- [ ] Tiles show plan completion ("n of m", workouts done) and the longest run (miles, date) when there is one
- [ ] Weekly distance shows the last 8 weeks as bars in the chart colour; tapping a bar shows its miles and runs
- [ ] Average pace shows a line with points, faster plotted higher, labelled as m:ss; tapping shows the nearest run's pace and date; with fewer than two runs with a distance, a short message instead
- [ ] The chart colour is `#C85A12` in light mode and `#D86A24` in dark mode; BUILD succeeds

**Verify:** BUILD → success, no warnings in `Sources/RunPlan`

**Steps:**

- [ ] **Step 1: Create `Sources/RunPlan/Progress/ChartColor.swift`**

```swift
import SwiftUI
import UIKit

extension Color {
    /// The one chart colour: an orange checked for lightness, chroma and contrast against the
    /// light and dark backgrounds with the data-visualisation palette validator (#C85A12 light,
    /// #D86A24 dark). The system orange fails both: too faint on white, too light on black.
    static let chartAccent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xD8 / 255, green: 0x6A / 255, blue: 0x24 / 255, alpha: 1)
            : UIColor(red: 0xC8 / 255, green: 0x5A / 255, blue: 0x12 / 255, alpha: 1)
    })
}
```

- [ ] **Step 2: Create `Sources/RunPlan/Progress/StatsView.swift`**

```swift
import SwiftUI
import Charts
import RunCore

/// Plan completion, longest run, weekly distance and average pace.
struct StatsView: View {
    @Environment(AppModel.self) private var app

    @State private var selectedWeek: Date?
    @State private var selectedPaceDate: Date?

    var body: some View {
        let weeks = RunStats.weeklyTotals(app.records, weeks: 8, endingOn: Date(), calendar: .current)
        let paces = RunStats.paceTrend(app.records, limit: 12)

        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        if let plan = app.plan {
                            let progress = PlanProgress(plan: plan)
                            StatTile(title: "Plan", value: "\(progress.completed) of \(progress.total)", detail: "workouts done")
                        }
                        if let longest = RunStats.longestRun(app.records) {
                            StatTile(
                                title: "Longest run",
                                value: String(format: "%.2f mi", Pace.miles(fromMeters: longest.distanceMeters)),
                                detail: longest.startedAt.formatted(date: .abbreviated, time: .omitted)
                            )
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Weekly distance") {
                    weeklyChart(weeks)
                }

                Section("Average pace") {
                    if paces.count < 2 {
                        Text("Pace appears after two runs with a distance.")
                            .foregroundStyle(.secondary)
                    } else {
                        paceChart(paces)
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }

    private func weeklyChart(_ weeks: [WeeklyTotal]) -> some View {
        Chart(weeks, id: \.weekStart) { week in
            BarMark(
                x: .value("Week", week.weekStart, unit: .weekOfYear),
                y: .value("Miles", Pace.miles(fromMeters: week.meters)),
                width: .ratio(0.6)
            )
            .foregroundStyle(Color.chartAccent)
            .cornerRadius(4)

            if let selectedWeek, Calendar.current.isDate(selectedWeek, equalTo: week.weekStart, toGranularity: .weekOfYear) {
                RuleMark(x: .value("Week", week.weekStart, unit: .weekOfYear))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        Text("\(String(format: "%.1f", Pace.miles(fromMeters: week.meters))) mi · \(week.runs) \(week.runs == 1 ? "run" : "runs")")
                            .font(.caption)
                            .padding(4)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    }
            }
        }
        .chartXSelection(value: $selectedWeek)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxisLabel("miles")
        .frame(height: 200)
        .padding(.vertical, 8)
    }

    private func paceChart(_ points: [PacePoint]) -> some View {
        let selected = selectedPaceDate.flatMap { date in
            points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
        }
        return Chart {
            ForEach(points, id: \.date) { point in
                LineMark(x: .value("Date", point.date), y: .value("Pace", point.secondsPerMile))
                    .foregroundStyle(Color.chartAccent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("Date", point.date), y: .value("Pace", point.secondsPerMile))
                    .foregroundStyle(Color.chartAccent)
                    .symbolSize(64)
            }
            if let selected {
                RuleMark(x: .value("Date", selected.date))
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        Text("\(Pace.clock(selected.secondsPerMile)) /mi · \(selected.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .padding(4)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    }
            }
        }
        .chartXSelection(value: $selectedPaceDate)
        // Faster (fewer seconds per mile) is plotted higher.
        .chartYScale(domain: .automatic(includesZero: false, reversed: true))
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let seconds = value.as(Int.self) {
                        Text(Pace.clock(seconds))
                    }
                }
            }
        }
        .chartYAxisLabel("min/mi, faster is higher")
        .frame(height: 200)
        .padding(.vertical, 8)
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 3: Build**

Run: BUILD
Expected: success, with no warnings in `Sources/RunPlan`. Nothing shows the screen yet; Task 8 adds its tab.

- [ ] **Step 4: Commit**

```bash
git add Sources/RunPlan/Progress
git commit -m "Add the Progress screen with weekly distance and pace charts"
```

---

### Task 8: Settings screen and tabs

**Goal:** A Settings tab with the three toggles, Change plan and a confirmed Reset, and the four tabs Plan, History, Progress and Settings.

**Files:**
- Create: `Sources/RunPlan/Settings/SettingsView.swift`
- Modify: `Sources/RunPlan/App/RootView.swift`

**Acceptance Criteria:**
- [ ] Toggles for keep screen awake, voice cues and auto-pause outdoors read and save `AppModel.settings`
- [ ] Change plan opens onboarding filled in with the current plan
- [ ] Reset everything asks first, then returns to onboarding with no runs
- [ ] The tab bar shows Plan, History, Progress and Settings; BUILD succeeds

**Verify:** BUILD → success, no warnings in `Sources/RunPlan`

**Steps:**

- [ ] **Step 1: Create `Sources/RunPlan/Settings/SettingsView.swift`**

```swift
import SwiftUI
import RunCore

/// Workout preferences, changing the plan, and resetting everything.
struct SettingsView: View {
    @Environment(AppModel.self) private var app

    @State private var changingPlan = false
    @State private var confirmingReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Keep screen awake", isOn: binding(\.keepScreenAwake))
                    Toggle("Voice cues", isOn: binding(\.voiceCues))
                    Toggle("Auto-pause outdoors", isOn: binding(\.autoPause))
                } header: {
                    Text("During a workout")
                } footer: {
                    Text("Voice cues covers step announcements, mile splits and pace cues; the countdown beeps always play. Auto-pause stops the clock when you stop moving outdoors and starts it again when you set off.")
                }

                Section {
                    Button("Change plan") { changingPlan = true }
                } footer: {
                    Text("Opens your answers so you can change them. The new plan starts fresh, and your runs stay in History.")
                }

                Section {
                    Button("Reset everything", role: .destructive) { confirmingReset = true }
                } footer: {
                    Text("Deletes your plan, every run and these settings.")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $changingPlan) {
                OnboardingView(changing: app.plan?.profile)
            }
            .confirmationDialog("Reset everything?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Delete plan, runs and settings", role: .destructive) { app.reset() }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { app.settings[keyPath: keyPath] },
            set: { value in app.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }
}
```

- [ ] **Step 2: Add the tabs**

In `Sources/RunPlan/App/RootView.swift`, replace:

```swift
                    HistoryView()
                        .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
```

with:

```swift
                    HistoryView()
                        .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                    StatsView()
                        .tabItem { Label("Progress", systemImage: "chart.bar") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
```

- [ ] **Step 3: Build**

Run: BUILD
Expected: success, with no warnings in `Sources/RunPlan`.

- [ ] **Step 4: Commit**

```bash
git add Sources/RunPlan/Settings Sources/RunPlan/App/RootView.swift
git commit -m "Add the Settings screen and the Progress and Settings tabs"
```

---

### Task 9: Docs, final verification and on-device check

**Goal:** Record the stage 5 decisions in the spec, add the stage 5 checklist to the README, verify end to end, and install.

**Files:**
- Modify: `README.md`, `docs/superpowers/specs/2026-10-12-runplan-design.md`

**Acceptance Criteria:**
- [ ] The spec notes how settings, auto-pause, separate route files and the chart colour work, and what stays deferred
- [ ] The README has a history, progress and settings checklist
- [ ] TEST passes in full and BUILD succeeds
- [ ] The app is installed on the phone and the checklist is handed to the user

**Verify:** TEST → `Executed N tests, with 0 failures`; BUILD → success

**Steps:**

- [ ] **Step 1: Add an implementation note to the spec**

In `docs/superpowers/specs/2026-10-12-runplan-design.md`, add this paragraph directly after the line `should load routes only when a run is opened.`:

```markdown

Implementation note (stage 5, 2026-10-18): settings live in `settings.json` and a workout reads
them when it starts; voice cues off keeps the countdown beeps. Auto-pause (outdoors, off by
default) pauses after speed over the last 6 s falls below 0.5 m/s and resumes above 1.2 m/s; a
manual pause is never resumed automatically. Routes are stored in `routes/<id>.json`, so History
lists runs without loading them; older records keep their route inside and still show it. The
chart colour is #C85A12 (light) and #D86A24 (dark), validated for lightness, chroma and contrast.
Still deferred: a grace period for the pace cue (waiting on an outdoor run), writing the route to
the crash checkpoint less often, and drawing the route across a pause.
```

- [ ] **Step 2: Add the stage 5 checklist to the README**

Append to `README.md`:

```markdown

## On-device checklist (history, progress and settings)

- History lists runs newest first; opening an outdoor run shows its splits and route map.
- Progress shows plan completion, the longest run, weekly distance bars (tap one for its miles)
  and, after two runs with a distance, the pace trend (tap for a run's pace).
- Settings > Voice cues off: a workout keeps its beeps but says nothing.
- Settings > Keep screen awake off: the screen dims and locks as usual during a workout.
- Settings > Auto-pause outdoors on: stand still for several seconds and "Auto-paused" shows and
  is spoken; set off again and it resumes. A pause by hand stays paused.
- Settings > Change plan opens your answers; Reset everything asks first, then returns to
  onboarding with no runs.
```

- [ ] **Step 3: Run the full verification**

Run: TEST
Expected: every test passes.

Run: BUILD
Expected: success, with no warnings in `Sources/RunPlan`.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/superpowers/specs/2026-10-12-runplan-design.md
git commit -m "Document history, progress and settings and their on-device checks"
```

- [ ] **Step 5: Install on the phone**

Follow README "Commands": make sure `tools/muxshim.py` is running in WSL, then run `xtool dev` from the repo root. Hand the stage 5 checklist to the user.
