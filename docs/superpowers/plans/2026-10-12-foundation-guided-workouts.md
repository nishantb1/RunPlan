# Foundation and Guided Treadmill Workouts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A buildable RunPlan app that runs one sample workout in treadmill mode with spoken cues, survives screen lock and app kill, and saves the run to history.

**Architecture:** A UI-free Swift package `RunCore/` (models, pace maths, wall-clock workout engine, cue scheduling, JSON storage) unit-tested on Linux, and a root xtool package whose single `RunPlan` target is the SwiftUI app depending on `RunCore`. The app layer is thin glue: audio, haptics, a session model and views.

**Tech Stack:** Swift 6.4 in WSL (Ubuntu 24.04), xtool 1.21.0, iOS 27.1 SDK, SwiftUI, AVFoundation, XCTest. No third-party packages.

**Spec:** `docs/superpowers/specs/2026-10-12-runplan-design.md` (build stages 1 and 2). Stages 3 to 5 get their own plans.

---

## Conventions for every task

Verified on this machine on 2026-10-12: nested-package `swift test` and `xtool dev build` both work from `/mnt/c`.

Run from Git Bash on Windows:

```bash
# Unit tests (RunCore only, runs on Linux)
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 -u nishant -- bash -lc \
  "cd /mnt/c/Users/bobba/Documents/RunPlan/RunCore && swift test 2>&1 | tail -15"

# App build for iPhone (no Apple login needed)
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 -u nishant -- bash -lc \
  "cd /mnt/c/Users/bobba/Documents/RunPlan && xtool dev build 2>&1 | tr '\r' '\n' | tail -15"
```

These are called **TEST** and **BUILD** below. `xtool new` hangs without `--skip-setup </dev/null`; this plan never needs it.

Rules: one type per file, value types where possible, no force unwrapping outside tests, no SwiftUI/UIKit/AVFoundation imports in `RunCore`. Everything `RunCore` exposes to the app is `public`. Commit after each task with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

Installing to the phone is blocked by xtool issue 329 (Apple login error -80045). Each task is verified with TEST and BUILD only.

## File structure

```
.gitattributes, .gitignore
Package.swift                       root xtool package, one library product "RunPlan"
xtool.yml                           bundleID, infoPath
Info.plist                          extra keys: display name, background audio, iPhone only
RunCore/Package.swift               library "RunCore" + test target
RunCore/Sources/RunCore/
  Models/StepKind.swift StepMeasure.swift Step.swift WorkoutKind.swift Workout.swift
         RunMode.swift Split.swift RoutePoint.swift RunRecord.swift ActiveWorkout.swift
         SampleWorkouts.swift
  Pace/Pace.swift
  Engine/FlatStep.swift StepExpander.swift StepResolution.swift StepResolver.swift
         WorkoutEngine.swift
  Cues/CueEvent.swift CueScheduler.swift CueText.swift
  Storage/JSONStore.swift RunStore.swift
RunCore/Tests/RunCoreTests/
  PaceTests.swift ModelCodingTests.swift StepExpanderTests.swift StepResolverTests.swift
  WorkoutEngineTests.swift CueSchedulerTests.swift CueTextTests.swift JSONStoreTests.swift
Sources/RunPlan/
  App/RunPlanApp.swift AppModel.swift RootView.swift
  Services/AudioCueService.swift HapticsService.swift
  Workout/WorkoutSessionModel.swift SessionContainerView.swift LiveWorkoutView.swift
          SummaryView.swift WorkoutDetailView.swift
  Home/HomeView.swift
  Resources/beep.wav
README.md
```

Deviation from the spec's layout: `RunCore` is a nested package rather than a second target of the root package, because `swift test` on Linux would otherwise try to compile the SwiftUI target. The app icon is deferred to the stage 5 plan.

---

### Task 1: Project scaffold

**Goal:** Root xtool package and nested `RunCore` package that both build, with a placeholder screen.

**Files:**
- Create: `.gitattributes`, `.gitignore`, `Package.swift`, `xtool.yml`, `Info.plist`
- Create: `RunCore/Package.swift`, `RunCore/Sources/RunCore/Pace/Pace.swift`, `RunCore/Tests/RunCoreTests/PaceTests.swift`
- Create: `Sources/RunPlan/App/RunPlanApp.swift`, `Sources/RunPlan/App/RootView.swift`
- Create: `Sources/RunPlan/Resources/beep.wav` (copied from PaceKeeper)

**Acceptance Criteria:**
- [ ] TEST passes with the pace tests
- [ ] BUILD ends with `Wrote to .../xtool/RunPlan.app`
- [ ] Built `Info.plist` contains `UIBackgroundModes` with `audio`

**Verify:** TEST → `Executed 6 tests, with 0 failures`; BUILD → `Wrote to /mnt/c/Users/bobba/Documents/RunPlan/xtool/RunPlan.app`

**Steps:**

- [ ] **Step 1: Repo files**

`.gitattributes`:
```
* text=auto eol=lf
*.wav binary
*.png binary
```

`.gitignore`:
```
.DS_Store
.build/
/Packages
/xtool
xcuserdata/
DerivedData/
.swiftpm/
.netrc
```

- [ ] **Step 2: Write the failing pace tests**

`RunCore/Package.swift`:
```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RunCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "RunCore", targets: ["RunCore"]),
    ],
    targets: [
        .target(name: "RunCore"),
        .testTarget(name: "RunCoreTests", dependencies: ["RunCore"]),
    ]
)
```

`RunCore/Tests/RunCoreTests/PaceTests.swift`:
```swift
import XCTest
@testable import RunCore

final class PaceTests: XCTestCase {

    func testMphFromPaceRoundsToOneDecimal() {
        XCTAssertEqual(Pace.mph(fromSecondsPerMile: 766), 4.7)
        XCTAssertEqual(Pace.mph(fromSecondsPerMile: 1440), 2.5)
        XCTAssertEqual(Pace.mph(fromSecondsPerMile: 600), 6.0)
    }

    func testPaceFromMph() {
        XCTAssertEqual(Pace.secondsPerMile(fromMph: 4.7), 766)
        XCTAssertEqual(Pace.secondsPerMile(fromMph: 6.0), 600)
    }

    func testClockFormatting() {
        XCTAssertEqual(Pace.clock(0), "0:00")
        XCTAssertEqual(Pace.clock(65), "1:05")
        XCTAssertEqual(Pace.clock(766), "12:46")
        XCTAssertEqual(Pace.clock(3725), "1:02:05")
    }

    func testNegativeClockClampsToZero() {
        XCTAssertEqual(Pace.clock(-4), "0:00")
    }

    func testAveragePace() {
        XCTAssertEqual(Pace.secondsPerMile(distanceMeters: 1609.344, durationSeconds: 600), 600)
        XCTAssertNil(Pace.secondsPerMile(distanceMeters: 0, durationSeconds: 600))
    }

    func testMileConversions() {
        XCTAssertEqual(Pace.miles(fromMeters: 5000), 3.107, accuracy: 0.001)
        XCTAssertEqual(Pace.meters(fromMiles: 3.1), 4988.97, accuracy: 0.01)
    }
}
```

- [ ] **Step 3: Run TEST, expect a compile failure** (`cannot find 'Pace' in scope`)

- [ ] **Step 4: Implement Pace**

`RunCore/Sources/RunCore/Pace/Pace.swift`:
```swift
import Foundation

/// Pace, speed and distance conversions. Targets are stored as seconds per mile; treadmill
/// mode shows the same target as mph.
public enum Pace {
    public static let metersPerMile = 1609.344

    /// Treadmill speed for a pace, rounded to the 0.1 mph a treadmill can be set to.
    public static func mph(fromSecondsPerMile seconds: Int) -> Double {
        guard seconds > 0 else { return 0 }
        return (36000.0 / Double(seconds)).rounded() / 10
    }

    public static func secondsPerMile(fromMph mph: Double) -> Int {
        guard mph > 0 else { return 0 }
        return Int((3600.0 / mph).rounded())
    }

    /// Average pace for a finished run, or nil when there is no distance to divide by.
    public static func secondsPerMile(distanceMeters: Double, durationSeconds: Int) -> Int? {
        guard distanceMeters > 0 else { return nil }
        return Int((Double(durationSeconds) / miles(fromMeters: distanceMeters)).rounded())
    }

    public static func miles(fromMeters meters: Double) -> Double {
        meters / metersPerMile
    }

    public static func meters(fromMiles miles: Double) -> Double {
        miles * metersPerMile
    }

    /// "m:ss", or "h:mm:ss" from one hour up. Used for both durations and paces.
    public static func clock(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
```

- [ ] **Step 5: Run TEST** → `Executed 6 tests, with 0 failures`

- [ ] **Step 6: Root package and app shell**

`Package.swift`:
```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RunPlan",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "RunPlan",
            targets: ["RunPlan"]
        ),
    ],
    dependencies: [
        .package(path: "RunCore"),
    ],
    targets: [
        .target(
            name: "RunPlan",
            dependencies: [
                .product(name: "RunCore", package: "RunCore"),
            ],
            resources: [
                .copy("Resources/beep.wav"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
```

`xtool.yml`:
```yaml
version: 1
bundleID: com.nishant.runplan
infoPath: Info.plist
```

`Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>RunPlan</string>
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
    </array>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
    </array>
    <key>UIRequiresFullScreen</key>
    <true/>
</dict>
</plist>
```

`Sources/RunPlan/App/RunPlanApp.swift`:
```swift
import SwiftUI

@main
struct RunPlanApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

`Sources/RunPlan/App/RootView.swift`:
```swift
import SwiftUI
import RunCore

struct RootView: View {
    var body: some View {
        Text("RunPlan \(Pace.clock(766))")
    }
}
```

Copy the beep:
```bash
mkdir -p "/c/Users/bobba/Documents/RunPlan/Sources/RunPlan/Resources"
cp "/c/Users/bobba/Documents/Running App/PaceKeeper/Resources/beep.wav" \
   "/c/Users/bobba/Documents/RunPlan/Sources/RunPlan/Resources/beep.wav"
```

- [ ] **Step 7: Run BUILD** → `Wrote to .../xtool/RunPlan.app`, then check the plist:

```bash
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 -u nishant -- bash -lc \
  "grep -A3 UIBackgroundModes /mnt/c/Users/bobba/Documents/RunPlan/xtool/RunPlan.app/Info.plist"
```
Expected: an `<array>` containing `<string>audio</string>`.

- [ ] **Step 8: Commit** — `git add -A && git commit -m "Scaffold RunPlan xtool package and RunCore"`

---

### Task 2: Models

**Goal:** Codable value types for workouts, steps, run records and the in-progress workout, plus one sample workout.

**Files:**
- Create: the eleven files under `RunCore/Sources/RunCore/Models/`
- Test: `RunCore/Tests/RunCoreTests/ModelCodingTests.swift`

**Acceptance Criteria:**
- [ ] Every model round-trips through JSON unchanged
- [ ] The sample workout has warm-up, 6 x (run, walk) as a repeat group, and cool-down

**Verify:** TEST → `Executed 10 tests, with 0 failures`

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/ModelCodingTests.swift`:
```swift
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
```

- [ ] **Step 2: Run TEST, expect compile failure** (`cannot find 'Step' in scope`)

- [ ] **Step 3: Implement the models**

`Models/StepKind.swift`:
```swift
import Foundation

/// `.warmup` and `.cooldown` bookend a workout; `.walk` and `.recovery` separate efforts.
public enum StepKind: String, Codable, CaseIterable, Sendable {
    case warmup
    case run
    case walk
    case recovery
    case cooldown
}
```

`Models/StepMeasure.swift`:
```swift
import Foundation

/// What ends a step: a duration, or a distance.
public enum StepMeasure: Codable, Equatable, Sendable {
    case time(seconds: Int)
    case distance(meters: Double)
}
```

`Models/Step.swift`:
```swift
import Foundation

/// One step of a workout as authored. Contiguous steps sharing a `repeatGroup` repeat
/// together `repeatCount` times, e.g. 6 x (run, walk). See `StepExpander`.
public struct Step: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var kind: StepKind
    public var measure: StepMeasure
    /// nil means no target, e.g. an open effort.
    public var targetPaceSecondsPerMile: Int?
    public var repeatGroup: Int?
    public var repeatCount: Int?

    public init(
        id: UUID = UUID(),
        kind: StepKind,
        measure: StepMeasure,
        targetPaceSecondsPerMile: Int? = nil,
        repeatGroup: Int? = nil,
        repeatCount: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.measure = measure
        self.targetPaceSecondsPerMile = targetPaceSecondsPerMile
        self.repeatGroup = repeatGroup
        self.repeatCount = repeatCount
    }
}
```

`Models/WorkoutKind.swift`:
```swift
import Foundation

public enum WorkoutKind: String, Codable, CaseIterable, Sendable {
    case walkRun
    case easy
    case intervals
    case tempo
    case longRun
    case timeTrial
}
```

`Models/Workout.swift`:
```swift
import Foundation

public struct Workout: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var date: Date
    public var kind: WorkoutKind
    public var title: String
    public var steps: [Step]
    /// Set once the workout has been completed and saved.
    public var recordID: UUID?

    public init(
        id: UUID = UUID(),
        date: Date,
        kind: WorkoutKind,
        title: String,
        steps: [Step],
        recordID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.title = title
        self.steps = steps
        self.recordID = recordID
    }
}
```

`Models/RunMode.swift`:
```swift
import Foundation

public enum RunMode: String, Codable, CaseIterable, Sendable {
    case treadmill
    case outdoor
}
```

`Models/Split.swift`:
```swift
import Foundation

/// One mile split of a recorded run. `index` starts at 1.
public struct Split: Codable, Equatable, Sendable {
    public var index: Int
    public var distanceMeters: Double
    public var durationSeconds: Int

    public init(index: Int, distanceMeters: Double, durationSeconds: Int) {
        self.index = index
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
    }
}
```

`Models/RoutePoint.swift`:
```swift
import Foundation

public struct RoutePoint: Codable, Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var timestamp: Date

    public init(latitude: Double, longitude: Double, timestamp: Date) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }
}
```

`Models/RunRecord.swift`:
```swift
import Foundation

/// A completed run. `workoutID` is nil for a free run with no planned workout.
public struct RunRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var workoutID: UUID?
    public var title: String
    public var mode: RunMode
    public var startedAt: Date
    public var durationSeconds: Int
    public var distanceMeters: Double
    public var perceivedEffort: Int?
    public var notes: String
    public var splits: [Split]
    public var route: [RoutePoint]

    public init(
        id: UUID = UUID(),
        workoutID: UUID? = nil,
        title: String = "Run",
        mode: RunMode,
        startedAt: Date,
        durationSeconds: Int,
        distanceMeters: Double,
        perceivedEffort: Int? = nil,
        notes: String = "",
        splits: [Split] = [],
        route: [RoutePoint] = []
    ) {
        self.id = id
        self.workoutID = workoutID
        self.title = title
        self.mode = mode
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.perceivedEffort = perceivedEffort
        self.notes = notes
        self.splits = splits
        self.route = route
    }
}
```

`Models/ActiveWorkout.swift` (uses `WorkoutEngine.Checkpoint` from Task 3; create this file in Task 3 Step 3, listed here for the file map):
```swift
import Foundation

/// A workout in progress, written to disk every few seconds so it can be resumed if the
/// app is killed.
public struct ActiveWorkout: Codable, Equatable, Sendable {
    public var workout: Workout
    public var mode: RunMode
    public var startedAt: Date
    public var checkpoint: WorkoutEngine.Checkpoint

    public init(workout: Workout, mode: RunMode, startedAt: Date, checkpoint: WorkoutEngine.Checkpoint) {
        self.workout = workout
        self.mode = mode
        self.startedAt = startedAt
        self.checkpoint = checkpoint
    }
}
```

`Models/SampleWorkouts.swift`:
```swift
import Foundation

/// Hand-written workouts used until the plan generator exists.
public enum SampleWorkouts {
    /// 5 min walk, 6 x (1:30 run at 4.7 mph, 2:00 walk at 2.5 mph), 3 min walk.
    public static func runWalk(on date: Date = Date()) -> Workout {
        let walkPace = Pace.secondsPerMile(fromMph: 2.5)
        let runPace = Pace.secondsPerMile(fromMph: 4.7)
        return Workout(
            date: date,
            kind: .walkRun,
            title: "Run-walk intervals",
            steps: [
                Step(kind: .warmup, measure: .time(seconds: 300), targetPaceSecondsPerMile: walkPace),
                Step(kind: .run, measure: .time(seconds: 90), targetPaceSecondsPerMile: runPace, repeatGroup: 1, repeatCount: 6),
                Step(kind: .walk, measure: .time(seconds: 120), targetPaceSecondsPerMile: walkPace, repeatGroup: 1, repeatCount: 6),
                Step(kind: .cooldown, measure: .time(seconds: 180), targetPaceSecondsPerMile: walkPace),
            ]
        )
    }
}
```

- [ ] **Step 4: Run TEST** → `Executed 10 tests, with 0 failures` (6 pace + 4 model). `ActiveWorkout.swift` is not yet created, so nothing references the engine.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "Add RunCore models and sample workout"`

---

### Task 3: Workout engine

**Goal:** Wall-clock workout engine ported from PaceKeeper's `TimerEngine`, with distance steps, and a checkpoint that restores a killed workout as paused.

**Files:**
- Create: `RunCore/Sources/RunCore/Engine/FlatStep.swift`, `StepExpander.swift`, `StepResolution.swift`, `StepResolver.swift`, `WorkoutEngine.swift`
- Create: `RunCore/Sources/RunCore/Models/ActiveWorkout.swift` (code in Task 2)
- Test: `RunCore/Tests/RunCoreTests/StepExpanderTests.swift`, `StepResolverTests.swift`, `WorkoutEngineTests.swift`

**Acceptance Criteria:**
- [ ] Repeat groups expand to the right flat sequence
- [ ] Step resolution is correct at exact boundaries and after a long gap
- [ ] Skip forward and back are safe at the first and last step
- [ ] Distance steps wait for a manual advance
- [ ] Paused time is excluded; a restored running checkpoint comes back paused at its save time

**Verify:** TEST → `Executed 30 tests, with 0 failures`

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/StepExpanderTests.swift`:
```swift
import XCTest
@testable import RunCore

final class StepExpanderTests: XCTestCase {

    func testRepeatGroupExpandsToFlatSequence() {
        let steps = [
            Step(kind: .warmup, measure: .time(seconds: 300)),
            Step(kind: .run, measure: .time(seconds: 90), targetPaceSecondsPerMile: 766, repeatGroup: 1, repeatCount: 3),
            Step(kind: .walk, measure: .time(seconds: 120), repeatGroup: 1, repeatCount: 3),
            Step(kind: .cooldown, measure: .time(seconds: 180)),
        ]

        let flat = StepExpander.expand(steps)

        XCTAssertEqual(flat.map(\.kind), [.warmup, .run, .walk, .run, .walk, .run, .walk, .cooldown])
        XCTAssertEqual(flat[1].durationSeconds, 90)
        XCTAssertEqual(flat[1].targetPaceSecondsPerMile, 766)
        XCTAssertEqual(flat[1].sourceStepID, steps[1].id)
    }

    func testTwoGroupsAndUngroupedSteps() {
        let steps = [
            Step(kind: .run, measure: .time(seconds: 60), repeatGroup: 1, repeatCount: 2),
            Step(kind: .walk, measure: .time(seconds: 30), repeatGroup: 1, repeatCount: 2),
            Step(kind: .run, measure: .time(seconds: 600)),
            Step(kind: .run, measure: .time(seconds: 20), repeatGroup: 2, repeatCount: 2),
            Step(kind: .recovery, measure: .time(seconds: 40), repeatGroup: 2, repeatCount: 2),
        ]

        let flat = StepExpander.expand(steps)

        XCTAssertEqual(flat.map(\.durationSeconds), [60, 30, 60, 30, 600, 20, 40, 20, 40])
    }

    func testDistanceStepHasNoDuration() {
        let flat = StepExpander.expand([Step(kind: .run, measure: .distance(meters: 5000))])

        XCTAssertNil(flat[0].durationSeconds)
        XCTAssertEqual(flat[0].distanceMeters, 5000)
        XCTAssertTrue(flat[0].isOpenEnded)
    }

    func testMissingRepeatCountMeansOnce() {
        let flat = StepExpander.expand([Step(kind: .run, measure: .time(seconds: 60), repeatGroup: 1)])
        XCTAssertEqual(flat.count, 1)
    }
}
```

`RunCore/Tests/RunCoreTests/StepResolverTests.swift`:
```swift
import XCTest
@testable import RunCore

final class StepResolverTests: XCTestCase {

    private let steps = StepExpander.expand([
        Step(kind: .warmup, measure: .time(seconds: 300)),
        Step(kind: .run, measure: .time(seconds: 90)),
        Step(kind: .walk, measure: .time(seconds: 120)),
    ])

    func testEmptyStepsResolveToNil() {
        XCTAssertNil(StepResolver.resolve(steps: [], elapsed: 10))
    }

    func testMidStep() throws {
        let r = try XCTUnwrap(StepResolver.resolve(steps: steps, elapsed: 310))
        XCTAssertEqual(r.index, 1)
        XCTAssertEqual(r.elapsedInStep, 10)
        XCTAssertEqual(r.remainingInStep, 80)
        XCTAssertFalse(r.isPastEnd)
    }

    func testExactBoundaryBelongsToNextStep() throws {
        let r = try XCTUnwrap(StepResolver.resolve(steps: steps, elapsed: 300))
        XCTAssertEqual(r.index, 1)
        XCTAssertEqual(r.elapsedInStep, 0)
    }

    func testPastEnd() throws {
        let r = try XCTUnwrap(StepResolver.resolve(steps: steps, elapsed: 9999))
        XCTAssertEqual(r.index, 2)
        XCTAssertTrue(r.isPastEnd)
        XCTAssertEqual(r.remainingInStep, 0)
    }

    func testStopsAtOpenEndedStep() throws {
        let withDistance = StepExpander.expand([
            Step(kind: .warmup, measure: .time(seconds: 300)),
            Step(kind: .run, measure: .distance(meters: 5000)),
            Step(kind: .cooldown, measure: .time(seconds: 300)),
        ])
        let r = try XCTUnwrap(StepResolver.resolve(steps: withDistance, elapsed: 5000))
        XCTAssertEqual(r.index, 1)
        XCTAssertTrue(r.isOpenEnded)
        XCTAssertNil(r.remainingInStep)
        XCTAssertEqual(r.elapsedInStep, 4700)
    }
}
```

`RunCore/Tests/RunCoreTests/WorkoutEngineTests.swift`:
```swift
import XCTest
@testable import RunCore

final class WorkoutEngineTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeEngine() -> WorkoutEngine {
        WorkoutEngine(planSteps: [
            Step(kind: .warmup, measure: .time(seconds: 300)),
            Step(kind: .run, measure: .time(seconds: 90), repeatGroup: 1, repeatCount: 2),
            Step(kind: .walk, measure: .time(seconds: 120), repeatGroup: 1, repeatCount: 2),
            Step(kind: .cooldown, measure: .time(seconds: 180)),
        ])
    }

    func testNoSnapshotBeforeStart() {
        XCTAssertNil(makeEngine().snapshot(now: t0))
    }

    func testAdvancesByWallClock() throws {
        let engine = makeEngine()
        engine.start(now: t0)

        let s = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(310)))
        XCTAssertEqual(s.stepIndex, 1)
        XCTAssertEqual(s.step.kind, .run)
        XCTAssertEqual(s.remainingInStep, 80)
        XCTAssertEqual(s.totalElapsed, 310)
        XCTAssertEqual(s.totalPlanned, 900)
        XCTAssertEqual(s.stepCount, 6)
        XCTAssertEqual(s.nextStep?.kind, .walk)
    }

    func testLongBackgroundGapLandsOnTheRightStep() throws {
        let engine = makeEngine()
        engine.start(now: t0)

        // 300 + 90 + 120 + 90 = 600, so 650 s is 50 s into the second walk.
        let s = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(650)))
        XCTAssertEqual(s.stepIndex, 4)
        XCTAssertEqual(s.elapsedInStep, 50)
    }

    func testFinishesAfterLastStep() throws {
        let engine = makeEngine()
        engine.start(now: t0)

        let s = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(901)))
        XCTAssertEqual(s.state, .finished)
        XCTAssertEqual(engine.state, .finished)
    }

    func testPauseExcludesPausedTime() throws {
        let engine = makeEngine()
        engine.start(now: t0)
        engine.pause(now: t0.addingTimeInterval(100))
        engine.resume(now: t0.addingTimeInterval(400))

        let s = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(450)))
        XCTAssertEqual(s.totalElapsed, 150)
        XCTAssertEqual(s.stepIndex, 0)
    }

    func testSkipForwardOnLastStepFinishes() {
        let engine = makeEngine()
        engine.start(now: t0)
        for _ in 0..<6 {
            engine.skipForward(now: t0.addingTimeInterval(1))
        }
        XCTAssertEqual(engine.state, .finished)
    }

    func testSkipBackOnFirstStepRestartsIt() throws {
        let engine = makeEngine()
        engine.start(now: t0)
        engine.skipBack(now: t0.addingTimeInterval(100))

        let s = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(110)))
        XCTAssertEqual(s.stepIndex, 0)
        XCTAssertEqual(s.elapsedInStep, 10)
    }

    func testSkipBackGoesToPreviousStep() throws {
        let engine = makeEngine()
        engine.start(now: t0)
        engine.skipBack(now: t0.addingTimeInterval(310))

        let s = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(310)))
        XCTAssertEqual(s.stepIndex, 0)
        XCTAssertEqual(s.elapsedInStep, 0)
    }

    func testDistanceStepWaitsForManualAdvance() throws {
        let engine = WorkoutEngine(planSteps: [
            Step(kind: .warmup, measure: .time(seconds: 60)),
            Step(kind: .run, measure: .distance(meters: 5000)),
            Step(kind: .cooldown, measure: .time(seconds: 60)),
        ])
        engine.start(now: t0)

        let waiting = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(2000)))
        XCTAssertEqual(waiting.stepIndex, 1)
        XCTAssertNil(waiting.remainingInStep)

        engine.advanceToNextStep(now: t0.addingTimeInterval(2000))
        let after = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(2010)))
        XCTAssertEqual(after.stepIndex, 2)
        XCTAssertEqual(after.remainingInStep, 50)
        XCTAssertEqual(after.totalElapsed, 2010)
    }

    func testRestoredRunningCheckpointComesBackPausedAtSaveTime() throws {
        let engine = makeEngine()
        engine.start(now: t0)
        let saved = engine.checkpoint(now: t0.addingTimeInterval(320))

        // The app was killed and relaunched an hour later.
        let restored = WorkoutEngine(steps: engine.steps, restoring: saved)
        XCTAssertEqual(restored.state, .paused)

        let relaunch = t0.addingTimeInterval(3920)
        let paused = try XCTUnwrap(restored.snapshot(now: relaunch))
        XCTAssertEqual(paused.stepIndex, 1)
        XCTAssertEqual(paused.elapsedInStep, 20)

        restored.resume(now: relaunch)
        let resumed = try XCTUnwrap(restored.snapshot(now: relaunch.addingTimeInterval(10)))
        XCTAssertEqual(resumed.stepIndex, 1)
        XCTAssertEqual(resumed.elapsedInStep, 30)
    }

    func testCheckpointRoundTripsThroughJSON() throws {
        let engine = makeEngine()
        engine.start(now: t0)
        let saved = engine.checkpoint(now: t0.addingTimeInterval(5))

        let data = try JSONEncoder().encode(saved)
        XCTAssertEqual(try JSONDecoder().decode(WorkoutEngine.Checkpoint.self, from: data), saved)
    }
}
```

- [ ] **Step 2: Run TEST, expect compile failure** (`cannot find 'StepExpander' in scope`)

- [ ] **Step 3: Implement the engine**

`Engine/FlatStep.swift`:
```swift
import Foundation

/// A single step after repeat groups have been expanded into a flat, ordered sequence.
public struct FlatStep: Equatable, Sendable {
    public let sourceStepID: UUID
    public let kind: StepKind
    /// nil for a distance step, which has no planned duration.
    public let durationSeconds: Int?
    public let distanceMeters: Double?
    public let targetPaceSecondsPerMile: Int?

    /// True for a distance step: it ends only when something advances it.
    public var isOpenEnded: Bool { durationSeconds == nil }

    public init(
        sourceStepID: UUID,
        kind: StepKind,
        durationSeconds: Int?,
        distanceMeters: Double?,
        targetPaceSecondsPerMile: Int?
    ) {
        self.sourceStepID = sourceStepID
        self.kind = kind
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.targetPaceSecondsPerMile = targetPaceSecondsPerMile
    }
}
```

`Engine/StepExpander.swift`:
```swift
import Foundation

public enum StepExpander {
    /// Expands repeat groups into a flat queue, preserving order. A contiguous run of steps
    /// sharing the same non-nil `repeatGroup` forms one group; its repeat count is taken
    /// from the first step in the group that specifies one.
    public static func expand(_ steps: [Step]) -> [FlatStep] {
        var result: [FlatStep] = []
        var index = 0

        while index < steps.count {
            let step = steps[index]

            guard let groupID = step.repeatGroup else {
                result.append(flatten(step))
                index += 1
                continue
            }

            var groupSteps: [Step] = []
            var lookahead = index
            while lookahead < steps.count, steps[lookahead].repeatGroup == groupID {
                groupSteps.append(steps[lookahead])
                lookahead += 1
            }

            let repeatCount = groupSteps.compactMap(\.repeatCount).first ?? 1
            for _ in 0..<max(repeatCount, 0) {
                for groupStep in groupSteps {
                    result.append(flatten(groupStep))
                }
            }

            index = lookahead
        }

        return result
    }

    private static func flatten(_ step: Step) -> FlatStep {
        switch step.measure {
        case .time(let seconds):
            return FlatStep(
                sourceStepID: step.id,
                kind: step.kind,
                durationSeconds: seconds,
                distanceMeters: nil,
                targetPaceSecondsPerMile: step.targetPaceSecondsPerMile
            )
        case .distance(let meters):
            return FlatStep(
                sourceStepID: step.id,
                kind: step.kind,
                durationSeconds: nil,
                distanceMeters: meters,
                targetPaceSecondsPerMile: step.targetPaceSecondsPerMile
            )
        }
    }
}
```

`Engine/StepResolution.swift`:
```swift
import Foundation

/// Where a given elapsed time lands within a run of steps.
public struct StepResolution: Equatable, Sendable {
    public let index: Int
    public let elapsedInStep: TimeInterval
    /// nil for an open-ended step.
    public let remainingInStep: TimeInterval?
    public let isOpenEnded: Bool
    /// True once elapsed time has run past the end of every timed step.
    public let isPastEnd: Bool
}
```

`Engine/StepResolver.swift`:
```swift
import Foundation

public enum StepResolver {
    /// Resolves the current step for an elapsed time, purely from arithmetic. This is what
    /// lets the engine recompute correctly after any length of backgrounding.
    ///
    /// At exactly `elapsed == stepEnd` the step has fully elapsed and the next one is current.
    public static func resolve(steps: [FlatStep], elapsed: TimeInterval) -> StepResolution? {
        guard !steps.isEmpty else { return nil }

        var cumulative: TimeInterval = 0
        for (index, step) in steps.enumerated() {
            guard let duration = step.durationSeconds else {
                return StepResolution(
                    index: index,
                    elapsedInStep: max(0, elapsed - cumulative),
                    remainingInStep: nil,
                    isOpenEnded: true,
                    isPastEnd: false
                )
            }

            let stepEnd = cumulative + TimeInterval(duration)
            if elapsed < stepEnd {
                return StepResolution(
                    index: index,
                    elapsedInStep: elapsed - cumulative,
                    remainingInStep: stepEnd - elapsed,
                    isOpenEnded: false,
                    isPastEnd: false
                )
            }
            cumulative = stepEnd
        }

        return StepResolution(
            index: steps.count - 1,
            elapsedInStep: elapsed - cumulative,
            remainingInStep: 0,
            isOpenEnded: false,
            isPastEnd: true
        )
    }
}
```

`Engine/WorkoutEngine.swift`:
```swift
import Foundation

/// Drives a workout purely from wall-clock time. The start of the current "phase" is stored;
/// the current step and remaining time are recomputed from the supplied `now` on every call
/// to `snapshot(now:)`. A UI timer only decides when to ask for a fresh snapshot.
///
/// A new phase starts at workout start and after every manual advance or skip, because an
/// open-ended step's real duration is not known ahead of time.
public final class WorkoutEngine {

    public enum State: String, Codable, Sendable {
        case notStarted
        case running
        case paused
        case finished
    }

    public struct Snapshot: Equatable, Sendable {
        public let state: State
        public let stepIndex: Int
        public let stepCount: Int
        public let step: FlatStep
        public let elapsedInStep: TimeInterval
        public let remainingInStep: TimeInterval?
        public let totalElapsed: TimeInterval
        /// Sum of timed step durations. Distance steps do not contribute.
        public let totalPlanned: TimeInterval
        public let nextStep: FlatStep?
    }

    /// Everything needed to rebuild the engine after the app is killed.
    public struct Checkpoint: Codable, Equatable, Sendable {
        public var state: State = .notStarted
        public var phaseStartIndex: Int = 0
        public var phaseStartTime: Date?
        public var pauseStartedAt: Date?
        public var accumulatedPause: TimeInterval = 0
        /// Elapsed time from steps before the current phase.
        public var bankedElapsed: TimeInterval = 0
        public var savedAt: Date?

        public init() {}
    }

    public let steps: [FlatStep]
    private var core: Checkpoint

    public var state: State { core.state }

    /// - Parameter restoring: a saved checkpoint. If it was running when saved, the engine
    ///   comes back paused at the save time, so time the app spent dead is not counted.
    public init(steps: [FlatStep], restoring checkpoint: Checkpoint? = nil) {
        self.steps = steps
        var restored = checkpoint ?? Checkpoint()
        if restored.state == .running, let savedAt = restored.savedAt {
            restored.pauseStartedAt = savedAt
            restored.state = .paused
        }
        if restored.phaseStartIndex >= steps.count {
            restored = Checkpoint()
        }
        self.core = restored
    }

    public convenience init(planSteps: [Step]) {
        self.init(steps: StepExpander.expand(planSteps))
    }

    public var totalPlanned: TimeInterval {
        steps.compactMap { $0.durationSeconds.map(TimeInterval.init) }.reduce(0, +)
    }

    public func checkpoint(now: Date = Date()) -> Checkpoint {
        var copy = core
        copy.savedAt = now
        return copy
    }

    public func start(now: Date = Date()) {
        guard core.state == .notStarted, !steps.isEmpty else { return }
        core = Checkpoint()
        core.phaseStartTime = now
        core.state = .running
    }

    public func pause(now: Date = Date()) {
        guard core.state == .running else { return }
        core.pauseStartedAt = now
        core.state = .paused
    }

    public func resume(now: Date = Date()) {
        guard core.state == .paused, let pausedAt = core.pauseStartedAt else { return }
        core.accumulatedPause += now.timeIntervalSince(pausedAt)
        core.pauseStartedAt = nil
        core.state = .running
    }

    public func end() {
        core.state = .finished
    }

    /// Ends the current step immediately. This is how a distance step is completed, and it
    /// doubles as skip forward for a timed step. Finishes the workout on the last step.
    public func advanceToNextStep(now: Date = Date()) {
        guard core.state == .running || core.state == .paused else { return }
        guard let resolution = currentResolution(now: now) else { return }

        let absoluteIndex = core.phaseStartIndex + resolution.index
        core.bankedElapsed += phaseElapsed(now: now)

        if absoluteIndex >= steps.count - 1 {
            // Keep the banked total readable after finishing.
            core.phaseStartTime = nil
            core.state = .finished
            return
        }

        startPhase(at: absoluteIndex + 1, now: now)
    }

    public func skipForward(now: Date = Date()) {
        advanceToNextStep(now: now)
    }

    /// Goes back to the start of the previous step, or restarts the first step.
    public func skipBack(now: Date = Date()) {
        guard core.state == .running || core.state == .paused else { return }
        guard let resolution = currentResolution(now: now) else { return }

        let absoluteIndex = core.phaseStartIndex + resolution.index
        let targetIndex = max(0, absoluteIndex - 1)

        core.bankedElapsed = plannedDuration(before: targetIndex)
        startPhase(at: targetIndex, now: now)
    }

    public func snapshot(now: Date = Date()) -> Snapshot? {
        guard core.state != .notStarted else { return nil }

        guard core.phaseStartTime != nil, let resolution = currentResolution(now: now) else {
            // Finished by a manual advance past the last step.
            guard let last = steps.last else { return nil }
            return Snapshot(
                state: core.state,
                stepIndex: steps.count - 1,
                stepCount: steps.count,
                step: last,
                elapsedInStep: 0,
                remainingInStep: 0,
                totalElapsed: core.bankedElapsed,
                totalPlanned: totalPlanned,
                nextStep: nil
            )
        }

        let absoluteIndex = core.phaseStartIndex + resolution.index
        if resolution.isPastEnd, core.state == .running {
            core.state = .finished
        }

        return Snapshot(
            state: core.state,
            stepIndex: absoluteIndex,
            stepCount: steps.count,
            step: steps[absoluteIndex],
            elapsedInStep: resolution.elapsedInStep,
            remainingInStep: resolution.remainingInStep,
            totalElapsed: core.bankedElapsed + phaseElapsed(now: now),
            totalPlanned: totalPlanned,
            nextStep: absoluteIndex + 1 < steps.count ? steps[absoluteIndex + 1] : nil
        )
    }

    // MARK: - Private helpers

    private func startPhase(at index: Int, now: Date) {
        let wasPaused = core.state == .paused
        core.phaseStartIndex = index
        core.phaseStartTime = now
        core.accumulatedPause = 0
        core.pauseStartedAt = wasPaused ? now : nil
    }

    private func phaseElapsed(now: Date) -> TimeInterval {
        guard let phaseStartTime = core.phaseStartTime else { return 0 }
        let pausedNow = core.pauseStartedAt.map { now.timeIntervalSince($0) } ?? 0
        return max(0, now.timeIntervalSince(phaseStartTime) - core.accumulatedPause - pausedNow)
    }

    private func currentResolution(now: Date) -> StepResolution? {
        guard core.phaseStartIndex < steps.count else { return nil }
        let phaseSteps = Array(steps[core.phaseStartIndex...])
        return StepResolver.resolve(steps: phaseSteps, elapsed: phaseElapsed(now: now))
    }

    private func plannedDuration(before index: Int) -> TimeInterval {
        steps.prefix(index).reduce(0) { $0 + ($1.durationSeconds.map(TimeInterval.init) ?? 0) }
    }
}
```

Two fixes over PaceKeeper's engine, both covered by tests: skipping while paused keeps the workout paused (PaceKeeper cleared the pause marker, which made `resume` a no-op), and the finished total stays readable after a manual advance past the last step.

Also create `Models/ActiveWorkout.swift` with the code from Task 2.

- [ ] **Step 4: Run TEST** → `Executed 30 tests, with 0 failures` (10 earlier + 4 expander + 5 resolver + 11 engine)

- [ ] **Step 5: Commit** — `git add -A && git commit -m "Add wall-clock workout engine with checkpoints"`

---

### Task 4: Cue scheduling and wording

**Goal:** Decide, from engine snapshots alone, when to announce a step, beep and finish, and what to say.

**Files:**
- Create: `RunCore/Sources/RunCore/Cues/CueEvent.swift`, `CueScheduler.swift`, `CueText.swift`
- Test: `RunCore/Tests/RunCoreTests/CueSchedulerTests.swift`, `CueTextTests.swift`

**Acceptance Criteria:**
- [ ] Each step is announced once on entry, and again after a skip back
- [ ] Beeps fire once each at 3, 2 and 1 seconds left, never while paused
- [ ] `finished` fires exactly once
- [ ] Treadmill wording uses mph, outdoor wording uses pace

**Verify:** TEST → zero failures, 9 new tests

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/CueSchedulerTests.swift`:
```swift
import XCTest
@testable import RunCore

final class CueSchedulerTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeEngine() -> WorkoutEngine {
        let engine = WorkoutEngine(planSteps: [
            Step(kind: .run, measure: .time(seconds: 10)),
            Step(kind: .walk, measure: .time(seconds: 10)),
        ])
        engine.start(now: t0)
        return engine
    }

    private func events(_ scheduler: inout CueScheduler, _ engine: WorkoutEngine, at offset: TimeInterval) throws -> [CueEvent] {
        let snapshot = try XCTUnwrap(engine.snapshot(now: t0.addingTimeInterval(offset)))
        return scheduler.events(for: snapshot)
    }

    func testAnnouncesEachStepOnce() throws {
        let engine = makeEngine()
        var scheduler = CueScheduler()

        XCTAssertEqual(try events(&scheduler, engine, at: 0), [.announce(engine.steps[0])])
        XCTAssertEqual(try events(&scheduler, engine, at: 1), [])
        XCTAssertEqual(try events(&scheduler, engine, at: 10), [.announce(engine.steps[1])])
    }

    func testBeepsOnceAtThreeTwoOne() throws {
        let engine = makeEngine()
        var scheduler = CueScheduler()
        _ = try events(&scheduler, engine, at: 0)

        XCTAssertEqual(try events(&scheduler, engine, at: 6.9), [])
        XCTAssertEqual(try events(&scheduler, engine, at: 7.1), [.countdownBeep])
        XCTAssertEqual(try events(&scheduler, engine, at: 7.4), [])
        XCTAssertEqual(try events(&scheduler, engine, at: 8.2), [.countdownBeep])
        XCTAssertEqual(try events(&scheduler, engine, at: 9.3), [.countdownBeep])
        XCTAssertEqual(try events(&scheduler, engine, at: 9.6), [])
    }

    func testNoBeepWhilePaused() throws {
        let engine = makeEngine()
        var scheduler = CueScheduler()
        _ = try events(&scheduler, engine, at: 0)

        engine.pause(now: t0.addingTimeInterval(7.5))
        XCTAssertEqual(try events(&scheduler, engine, at: 60), [])
    }

    func testReannouncesAfterSkipBack() throws {
        let engine = makeEngine()
        var scheduler = CueScheduler()
        _ = try events(&scheduler, engine, at: 0)
        _ = try events(&scheduler, engine, at: 12)

        engine.skipBack(now: t0.addingTimeInterval(13))
        XCTAssertEqual(try events(&scheduler, engine, at: 13), [.announce(engine.steps[0])])
    }

    func testFinishedFiresOnce() throws {
        let engine = makeEngine()
        var scheduler = CueScheduler()
        _ = try events(&scheduler, engine, at: 0)

        XCTAssertEqual(try events(&scheduler, engine, at: 25), [.finished])
        XCTAssertEqual(try events(&scheduler, engine, at: 26), [])
    }
}
```

`RunCore/Tests/RunCoreTests/CueTextTests.swift`:
```swift
import XCTest
@testable import RunCore

final class CueTextTests: XCTestCase {

    private func flat(_ kind: StepKind, seconds: Int? = nil, meters: Double? = nil, pace: Int? = nil) -> FlatStep {
        FlatStep(sourceStepID: UUID(), kind: kind, durationSeconds: seconds, distanceMeters: meters, targetPaceSecondsPerMile: pace)
    }

    func testTreadmillAnnouncementUsesMph() {
        XCTAssertEqual(
            CueText.announcement(for: flat(.run, seconds: 90, pace: 766), mode: .treadmill),
            "Run, 4.7 miles per hour, 1 minute 30 seconds."
        )
    }

    func testOutdoorAnnouncementUsesPace() {
        XCTAssertEqual(
            CueText.announcement(for: flat(.run, seconds: 120, pace: 600), mode: .outdoor),
            "Run, 10 minutes per mile, 2 minutes."
        )
        XCTAssertEqual(
            CueText.announcement(for: flat(.run, seconds: 45, pace: 766), mode: .outdoor),
            "Run, 12 minutes 46 seconds per mile, 45 seconds."
        )
    }

    func testDistanceStepWithoutTarget() {
        XCTAssertEqual(
            CueText.announcement(for: flat(.run, meters: 5000), mode: .treadmill),
            "Run, 3.1 miles."
        )
    }

    func testTargetLabel() {
        XCTAssertEqual(CueText.target(for: flat(.run, seconds: 90, pace: 766), mode: .treadmill), "4.7 mph")
        XCTAssertEqual(CueText.target(for: flat(.run, seconds: 90, pace: 766), mode: .outdoor), "12:46 /mi")
        XCTAssertNil(CueText.target(for: flat(.walk, seconds: 90), mode: .treadmill))
    }
}
```

- [ ] **Step 2: Run TEST, expect compile failure** (`cannot find 'CueScheduler' in scope`)

- [ ] **Step 3: Implement**

`Cues/CueEvent.swift`:
```swift
import Foundation

public enum CueEvent: Equatable, Sendable {
    case announce(FlatStep)
    case countdownBeep
    case finished
}
```

`Cues/CueScheduler.swift`:
```swift
import Foundation

/// Turns a stream of engine snapshots into cue events. Holds only what has already been
/// cued, so it gives the same answers however irregularly it is polled.
public struct CueScheduler: Sendable {
    private var lastStepIndex: Int?
    private var beepsPlayed: Set<Int> = []
    private var finishedSent = false

    public init() {}

    public mutating func events(for snapshot: WorkoutEngine.Snapshot) -> [CueEvent] {
        if snapshot.state == .finished {
            guard !finishedSent else { return [] }
            finishedSent = true
            return [.finished]
        }

        if snapshot.stepIndex != lastStepIndex {
            lastStepIndex = snapshot.stepIndex
            beepsPlayed = []
            return [.announce(snapshot.step)]
        }

        guard snapshot.state == .running, let remaining = snapshot.remainingInStep else { return [] }

        var events: [CueEvent] = []
        for mark in [3, 2, 1] where remaining <= Double(mark) && remaining > Double(mark - 1) && !beepsPlayed.contains(mark) {
            beepsPlayed.insert(mark)
            events.append(.countdownBeep)
        }
        return events
    }
}
```

`Cues/CueText.swift`:
```swift
import Foundation

/// Wording for spoken cues and on-screen targets.
public enum CueText {

    /// e.g. "Run, 4.7 miles per hour, 1 minute 30 seconds."
    public static func announcement(for step: FlatStep, mode: RunMode) -> String {
        var parts = [spokenKind(step.kind)]
        if let pace = step.targetPaceSecondsPerMile {
            parts.append(spokenTarget(pace: pace, mode: mode))
        }
        if let seconds = step.durationSeconds {
            parts.append(spokenDuration(seconds))
        } else if let meters = step.distanceMeters {
            parts.append("\(decimal(Pace.miles(fromMeters: meters))) miles")
        }
        return parts.joined(separator: ", ") + "."
    }

    /// Short on-screen target, e.g. "4.7 mph" or "12:46 /mi". nil when the step has no target.
    public static func target(for step: FlatStep, mode: RunMode) -> String? {
        guard let pace = step.targetPaceSecondsPerMile else { return nil }
        switch mode {
        case .treadmill: return "\(decimal(Pace.mph(fromSecondsPerMile: pace))) mph"
        case .outdoor: return "\(Pace.clock(pace)) /mi"
        }
    }

    public static func displayKind(_ kind: StepKind) -> String {
        switch kind {
        case .warmup: return "Warm up"
        case .run: return "Run"
        case .walk: return "Walk"
        case .recovery: return "Recover"
        case .cooldown: return "Cool down"
        }
    }

    private static func spokenKind(_ kind: StepKind) -> String {
        displayKind(kind)
    }

    private static func spokenTarget(pace: Int, mode: RunMode) -> String {
        switch mode {
        case .treadmill:
            return "\(decimal(Pace.mph(fromSecondsPerMile: pace))) miles per hour"
        case .outdoor:
            return "\(spokenDuration(pace)) per mile"
        }
    }

    private static func spokenDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        let minuteText = "\(minutes) minute\(minutes == 1 ? "" : "s")"
        let secondText = "\(remainder) second\(remainder == 1 ? "" : "s")"
        if minutes == 0 { return secondText }
        if remainder == 0 { return minuteText }
        return "\(minuteText) \(secondText)"
    }

    /// One decimal place, dropping a trailing ".0".
    private static func decimal(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
    }
}
```

- [ ] **Step 4: Run TEST** → zero failures, 9 more tests than Task 3

- [ ] **Step 5: Commit** — `git add -A && git commit -m "Add cue scheduling and wording"`

---

### Task 5: JSON storage

**Goal:** File storage that never crashes on a bad file, and a run history store on top of it.

**Files:**
- Create: `RunCore/Sources/RunCore/Storage/JSONStore.swift`, `RunStore.swift`
- Test: `RunCore/Tests/RunCoreTests/JSONStoreTests.swift`

**Acceptance Criteria:**
- [ ] Save then load returns the same value; a missing file loads as nil
- [ ] A corrupt file loads as nil and is renamed aside, not deleted
- [ ] `RunStore.all()` returns records newest first

**Verify:** TEST → zero failures, 5 new tests

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/JSONStoreTests.swift`:
```swift
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
```

- [ ] **Step 2: Run TEST, expect compile failure** (`cannot find 'JSONStore' in scope`)

- [ ] **Step 3: Implement**

`Storage/JSONStore.swift`:
```swift
import Foundation

/// Reads and writes Codable values as JSON files under one directory. Names may include a
/// subdirectory, e.g. "records/<id>.json".
public struct JSONStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func save<T: Encodable>(_ value: T, as name: String) throws {
        let url = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }

    /// nil when the file is missing. A file that fails to decode is renamed to
    /// "<name>.corrupt-<timestamp>" so the app starts clean without losing the bytes.
    public func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let value = try? JSONDecoder().decode(type, from: data) {
            return value
        }
        let stamp = Int(Date().timeIntervalSince1970)
        let aside = url.deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).corrupt-\(stamp)")
        try? FileManager.default.moveItem(at: url, to: aside)
        return nil
    }

    /// File names directly inside a subdirectory, in no particular order.
    public func names(in subdirectory: String) -> [String] {
        let url = directory.appendingPathComponent(subdirectory)
        return (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
    }

    public func delete(_ name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }
}
```

`Storage/RunStore.swift`:
```swift
import Foundation

/// Run history: one file per run, so a long history never rewrites one large file.
public struct RunStore: Sendable {
    private static let folder = "records"
    private let store: JSONStore

    public init(store: JSONStore) {
        self.store = store
    }

    public func save(_ record: RunRecord) throws {
        try store.save(record, as: "\(Self.folder)/\(record.id.uuidString).json")
    }

    /// Every readable record, newest first.
    public func all() -> [RunRecord] {
        store.names(in: Self.folder)
            .filter { $0.hasSuffix(".json") }
            .compactMap { store.load(RunRecord.self, from: "\(Self.folder)/\($0)") }
            .sorted { $0.startedAt > $1.startedAt }
    }
}
```

- [ ] **Step 4: Run TEST** → zero failures, 5 more tests than Task 4

- [ ] **Step 5: Commit** — `git add -A && git commit -m "Add JSON storage and run history store"`

---

### Task 6: App services and session model

**Goal:** The glue that runs a workout on the phone: audio cues, haptics, app-wide state, and the session model that polls the engine.

**Files:**
- Create: `Sources/RunPlan/Services/AudioCueService.swift`, `HapticsService.swift`
- Create: `Sources/RunPlan/App/AppModel.swift`
- Create: `Sources/RunPlan/Workout/WorkoutSessionModel.swift`

**Acceptance Criteria:**
- [ ] BUILD succeeds
- [ ] Session model saves a checkpoint at most every 5 seconds and on every control action
- [ ] Finishing clears the checkpoint file and re-enables the idle timer

**Verify:** BUILD → `Wrote to .../xtool/RunPlan.app`

**Steps:**

- [ ] **Step 1: Services**

`Sources/RunPlan/Services/AudioCueService.swift`:
```swift
import AVFoundation

/// Speaks cues and plays countdown beeps. The playback category with ducking lets cues play
/// over music and keeps the app's audio alive in the background.
final class AudioCueService {

    private let synthesizer = AVSpeechSynthesizer()
    private var beepPlayer: AVAudioPlayer?

    init() {
        beepPlayer = Self.makeBeepPlayer()
    }

    func activate() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true)
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    /// A bundled tone rather than a system sound, so it plays with the silent switch on.
    func playCountdownBeep() {
        beepPlayer?.currentTime = 0
        beepPlayer?.play()
    }

    private static func makeBeepPlayer() -> AVAudioPlayer? {
        guard let url = Bundle.module.url(forResource: "beep", withExtension: "wav") else { return nil }
        return try? AVAudioPlayer(contentsOf: url)
    }
}
```

`Sources/RunPlan/Services/HapticsService.swift`:
```swift
import UIKit

/// Fires haptic feedback on each step transition.
final class HapticsService {
    private let generator = UIImpactFeedbackGenerator(style: .medium)

    init() {
        generator.prepare()
    }

    func stepTransition() {
        generator.impactOccurred()
        generator.prepare()
    }
}
```

- [ ] **Step 2: Session model**

`Sources/RunPlan/Workout/WorkoutSessionModel.swift`:
```swift
import Foundation
import Observation
import UIKit
import RunCore

/// Owns a `WorkoutEngine` for one workout and wires it to cues, haptics, a UI refresh timer
/// and the on-disk checkpoint. The engine does the timing; this only polls it.
@MainActor
@Observable
final class WorkoutSessionModel: Identifiable {

    static let checkpointFile = "active.json"

    let id = UUID()
    let workout: Workout
    let mode: RunMode
    let startedAt: Date

    private(set) var snapshot: WorkoutEngine.Snapshot?
    private(set) var isFinished = false

    private let engine: WorkoutEngine
    private var scheduler = CueScheduler()
    private let audio = AudioCueService()
    private let haptics = HapticsService()
    private let store: JSONStore
    private var uiTimer: Timer?
    private var lastCheckpointSave = Date.distantPast

    init(workout: Workout, mode: RunMode, store: JSONStore) {
        self.workout = workout
        self.mode = mode
        self.startedAt = Date()
        self.store = store
        self.engine = WorkoutEngine(planSteps: workout.steps)
    }

    /// Resumes a workout that was in progress when the app was killed. It comes back paused.
    init(resuming active: ActiveWorkout, store: JSONStore) {
        self.workout = active.workout
        self.mode = active.mode
        self.startedAt = active.startedAt
        self.store = store
        self.engine = WorkoutEngine(steps: StepExpander.expand(active.workout.steps), restoring: active.checkpoint)
    }

    var isPaused: Bool { snapshot?.state == .paused }
    var durationSeconds: Int { Int((snapshot?.totalElapsed ?? 0).rounded()) }

    func begin() {
        audio.activate()
        engine.start()
        UIApplication.shared.isIdleTimerDisabled = true
        refresh()
        startUITimer()
    }

    func pause() {
        engine.pause()
        refresh(forceCheckpoint: true)
    }

    func resume() {
        engine.resume()
        refresh(forceCheckpoint: true)
    }

    func skipForward() {
        engine.skipForward()
        refresh(forceCheckpoint: true)
    }

    func skipBack() {
        engine.skipBack()
        refresh(forceCheckpoint: true)
    }

    func endEarly() {
        engine.end()
        refresh()
    }

    /// Call when the app returns to the foreground so the screen catches up at once.
    func handleForeground() {
        refresh()
    }

    private func startUITimer() {
        uiTimer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        uiTimer = timer
    }

    private func refresh(forceCheckpoint: Bool = false) {
        guard !isFinished, let snapshot = engine.snapshot() else { return }

        for event in scheduler.events(for: snapshot) {
            switch event {
            case .announce(let step):
                audio.speak(CueText.announcement(for: step, mode: mode))
                haptics.stepTransition()
            case .countdownBeep:
                audio.playCountdownBeep()
            case .finished:
                audio.speak("Workout complete.")
                haptics.stepTransition()
            }
        }

        self.snapshot = snapshot

        if snapshot.state == .finished {
            finish()
        } else {
            saveCheckpoint(force: forceCheckpoint)
        }
    }

    private func saveCheckpoint(force: Bool) {
        let now = Date()
        guard force || now.timeIntervalSince(lastCheckpointSave) >= 5 else { return }
        lastCheckpointSave = now
        let active = ActiveWorkout(workout: workout, mode: mode, startedAt: startedAt, checkpoint: engine.checkpoint(now: now))
        try? store.save(active, as: Self.checkpointFile)
    }

    private func finish() {
        isFinished = true
        uiTimer?.invalidate()
        uiTimer = nil
        UIApplication.shared.isIdleTimerDisabled = false
        store.delete(Self.checkpointFile)
    }

    /// Call once the summary has been saved or discarded.
    func releaseAudio() {
        audio.deactivate()
    }
}
```

- [ ] **Step 3: App model**

`Sources/RunPlan/App/AppModel.swift`:
```swift
import Foundation
import Observation
import RunCore

/// App-wide state: run history, the workout on offer, and the session in progress.
@MainActor
@Observable
final class AppModel {

    let store: JSONStore
    private let runs: RunStore

    private(set) var records: [RunRecord] = []
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
        records = runs.all()
        pendingResume = store.load(ActiveWorkout.self, from: WorkoutSessionModel.checkpointFile)
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

    /// Saves the finished session as a run and closes it.
    func save(_ record: RunRecord) {
        try? runs.save(record)
        records = runs.all()
        closeSession()
    }

    func closeSession() {
        session?.releaseAudio()
        session = nil
    }
}
```

`begin()` on a restored session calls `engine.start()`, which is a no-op because the restored state is `.paused`, so the workout stays paused until the user taps Resume.

- [ ] **Step 4: Run BUILD** → `Wrote to .../xtool/RunPlan.app`. Fix any compile errors in these four files before moving on.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "Add audio, haptics, session model and app model"`

---

### Task 7: Screens

**Goal:** Home, workout detail, live workout and summary screens wired to the app model, with the resume prompt.

**Files:**
- Modify: `Sources/RunPlan/App/RunPlanApp.swift`, `Sources/RunPlan/App/RootView.swift`
- Create: `Sources/RunPlan/Home/HomeView.swift`
- Create: `Sources/RunPlan/Workout/WorkoutDetailView.swift`, `SessionContainerView.swift`, `LiveWorkoutView.swift`, `SummaryView.swift`

**Acceptance Criteria:**
- [ ] BUILD succeeds
- [ ] Home lists today's workout and saved runs
- [ ] Start offers Treadmill; Outdoor is shown disabled until the GPS stage
- [ ] Live screen shows step kind, target, time left, progress and next step, with pause, skip, back and end
- [ ] Summary saves a run with optional distance, effort and note

**Verify:** BUILD → `Wrote to .../xtool/RunPlan.app`; TEST still zero failures

**Steps:**

- [ ] **Step 1: Entry point and root**

`Sources/RunPlan/App/RunPlanApp.swift`:
```swift
import SwiftUI

@main
struct RunPlanApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
        }
    }
}
```

`Sources/RunPlan/App/RootView.swift`:
```swift
import SwiftUI
import RunCore

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var app = app

        HomeView()
            .fullScreenCover(item: $app.session) { session in
                SessionContainerView(session: session)
            }
            .alert(
                "Resume your workout?",
                isPresented: Binding(
                    get: { app.pendingResume != nil && app.session == nil },
                    set: { if !$0 { app.pendingResume = nil } }
                )
            ) {
                Button("Resume") { app.resumePending() }
                Button("Discard", role: .destructive) { app.discardPending() }
            } message: {
                Text("A workout was in progress when the app closed. It will resume paused.")
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    app.session?.handleForeground()
                }
            }
    }
}
```

- [ ] **Step 2: Home**

`Sources/RunPlan/Home/HomeView.swift`:
```swift
import SwiftUI
import RunCore

struct HomeView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    NavigationLink {
                        WorkoutDetailView(workout: app.todaysWorkout)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.todaysWorkout.title).font(.headline)
                            Text(plannedText(app.todaysWorkout)).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Recent runs") {
                    if app.records.isEmpty {
                        Text("No runs yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(app.records) { record in
                            RunRow(record: record)
                        }
                    }
                }
            }
            .navigationTitle("RunPlan")
        }
    }

    private func plannedText(_ workout: Workout) -> String {
        let planned = WorkoutEngine(planSteps: workout.steps).totalPlanned
        return "\(Pace.clock(Int(planned))) planned"
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

- [ ] **Step 3: Workout detail**

`Sources/RunPlan/Workout/WorkoutDetailView.swift`:
```swift
import SwiftUI
import RunCore

struct WorkoutDetailView: View {
    @Environment(AppModel.self) private var app
    let workout: Workout

    @State private var choosingMode = false

    var body: some View {
        List {
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

- [ ] **Step 4: Live workout and container**

`Sources/RunPlan/Workout/SessionContainerView.swift`:
```swift
import SwiftUI

/// Shows the live screen while the workout runs, then the summary.
struct SessionContainerView: View {
    let session: WorkoutSessionModel

    var body: some View {
        if session.isFinished {
            SummaryView(session: session)
        } else {
            LiveWorkoutView(session: session)
        }
    }
}
```

`Sources/RunPlan/Workout/LiveWorkoutView.swift`:
```swift
import SwiftUI
import RunCore

/// Large, glanceable and high contrast: readable at arm's length on a treadmill console.
struct LiveWorkoutView: View {
    let session: WorkoutSessionModel

    @State private var confirmingEnd = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let snapshot = session.snapshot {
                VStack(spacing: 20) {
                    Text("Step \(snapshot.stepIndex + 1) of \(snapshot.stepCount)")
                        .font(.headline)
                        .foregroundStyle(.gray)

                    Text(CueText.displayKind(snapshot.step.kind).uppercased())
                        .font(.system(size: 64, weight: .heavy))
                        .foregroundStyle(color(for: snapshot.step.kind))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text(CueText.target(for: snapshot.step, mode: session.mode) ?? "No target")
                        .font(.system(size: 72, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text(clock(for: snapshot))
                        .font(.system(size: 88, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    ProgressView(value: min(snapshot.totalElapsed, max(snapshot.totalPlanned, 1)), total: max(snapshot.totalPlanned, 1))
                        .tint(.white)

                    Text("\(Pace.clock(Int(snapshot.totalElapsed))) of \(Pace.clock(Int(snapshot.totalPlanned)))")
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.gray)

                    Text(nextText(snapshot))
                        .font(.title3)
                        .foregroundStyle(.gray)

                    Spacer()

                    controls(snapshot)
                }
                .padding()
            }
        }
        .confirmationDialog("End this workout?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End workout", role: .destructive) { session.endEarly() }
        }
    }

    private func controls(_ snapshot: WorkoutEngine.Snapshot) -> some View {
        HStack(spacing: 24) {
            controlButton("backward.end.fill") { session.skipBack() }
            controlButton(session.isPaused ? "play.fill" : "pause.fill") {
                if session.isPaused { session.resume() } else { session.pause() }
            }
            controlButton("forward.end.fill") { session.skipForward() }
            controlButton("stop.fill") { confirmingEnd = true }
        }
    }

    private func controlButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 30))
                .frame(width: 72, height: 72)
                .background(Color.white.opacity(0.15), in: Circle())
                .foregroundStyle(.white)
        }
    }

    /// Countdown for a timed step, count-up for a distance step.
    private func clock(for snapshot: WorkoutEngine.Snapshot) -> String {
        if let remaining = snapshot.remainingInStep {
            return Pace.clock(Int(remaining.rounded(.up)))
        }
        return Pace.clock(Int(snapshot.elapsedInStep))
    }

    private func nextText(_ snapshot: WorkoutEngine.Snapshot) -> String {
        guard let next = snapshot.nextStep else { return "Last step" }
        let kind = CueText.displayKind(next.kind)
        guard let target = CueText.target(for: next, mode: session.mode) else { return "Next: \(kind)" }
        return "Next: \(kind) at \(target)"
    }

    private func color(for kind: StepKind) -> Color {
        switch kind {
        case .run: return .green
        case .walk, .recovery: return .yellow
        case .warmup, .cooldown: return .cyan
        }
    }
}
```

- [ ] **Step 5: Summary**

`Sources/RunPlan/Workout/SummaryView.swift`:
```swift
import SwiftUI
import RunCore

/// One screen, every field skippable.
struct SummaryView: View {
    @Environment(AppModel.self) private var app
    let session: WorkoutSessionModel

    @State private var distanceText = ""
    @State private var effort = 0
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    LabeledContent("Time", value: Pace.clock(session.durationSeconds))
                    if let pace = Pace.secondsPerMile(distanceMeters: distanceMeters, durationSeconds: session.durationSeconds) {
                        LabeledContent("Average pace", value: "\(Pace.clock(pace)) /mi")
                    }
                }

                Section("Distance (miles, from the treadmill)") {
                    TextField("Optional", text: $distanceText)
                        .keyboardType(.decimalPad)
                }

                Section("Effort") {
                    Picker("Effort", selection: $effort) {
                        Text("Skip").tag(0)
                        ForEach(1...5, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive) { app.closeSession() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { app.save(record) }
                }
            }
        }
    }

    private var distanceMeters: Double {
        let normalized = distanceText.replacingOccurrences(of: ",", with: ".")
        guard let miles = Double(normalized), miles > 0 else { return 0 }
        return Pace.meters(fromMiles: miles)
    }

    private var record: RunRecord {
        RunRecord(
            workoutID: session.workout.id,
            title: session.workout.title,
            mode: session.mode,
            startedAt: session.startedAt,
            durationSeconds: session.durationSeconds,
            distanceMeters: distanceMeters,
            perceivedEffort: effort == 0 ? nil : effort,
            notes: notes
        )
    }
}
```

- [ ] **Step 6: Run BUILD** → `Wrote to .../xtool/RunPlan.app`. Then TEST → zero failures.

- [ ] **Step 7: Commit** — `git add -A && git commit -m "Add home, workout, live and summary screens"`

---

### Task 8: README and final verification

**Goal:** Document how to test, build and install, and confirm the whole stage from a clean build.

**Files:**
- Create: `README.md`

**Acceptance Criteria:**
- [ ] README has the exact test, build and install commands and the on-device checklist
- [ ] Clean TEST and clean BUILD both succeed

**Verify:** after `rm -rf .build xtool RunCore/.build`, TEST → zero failures and BUILD → `Wrote to .../xtool/RunPlan.app`

**Steps:**

- [ ] **Step 1: Write `README.md`**

````markdown
# RunPlan

Personal running app for iPhone, built on Windows with [xtool](https://xtool.sh). Design:
`docs/superpowers/specs/2026-10-12-runplan-design.md`.

## Layout

- `RunCore/` is the logic: models, pace maths, workout engine, cues, storage. No UI code,
  unit-tested on Linux.
- `Sources/RunPlan/` is the SwiftUI app.

## Commands

Run inside WSL (Ubuntu app), from `/mnt/c/Users/bobba/Documents/RunPlan`:

```bash
cd RunCore && swift test      # unit tests
xtool dev build               # build xtool/RunPlan.app, no Apple login needed
xtool dev                     # build, sign and install to the connected iPhone
```

Installing needs `xtool auth login` and the iPhone attached to WSL. In an admin PowerShell:
`usbipd list`, then `usbipd bind --busid <id>` once and `usbipd attach --wsl --busid <id>`
each time the phone is plugged in. With a free Apple ID the app expires after 7 days;
run `xtool dev` again to renew it.

## On-device checklist (guided workouts)

- Start the sample workout in Treadmill mode: the step and speed are spoken.
- Beeps play at 3, 2 and 1 seconds before each change, over music.
- Lock the phone for two steps: cues keep playing and the screen is correct on unlock.
- Pause, skip forward, skip back and end all behave.
- Force-quit mid-workout and reopen: the app offers to resume, paused.
- Save the summary: the run appears under Recent runs after relaunch.
````

- [ ] **Step 2: Clean verification**

```bash
MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 -u nishant -- bash -lc \
  "cd /mnt/c/Users/bobba/Documents/RunPlan && rm -rf .build xtool RunCore/.build && (cd RunCore && swift test 2>&1 | tail -6) && xtool dev build 2>&1 | tr '\r' '\n' | tail -4"
```
Expected: `Executed N tests, with 0 failures` and `Wrote to .../xtool/RunPlan.app`.

- [ ] **Step 3: Commit** — `git add -A && git commit -m "Add README with build and device checklist"`
