# Outdoor GPS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** RunPlan records outdoor runs with GPS: distance and pace on the live screen, distance steps that end on measured distance, spoken mile splits and pace cues, a route map and splits in the summary, and a free run from the Plan screen.

**Architecture:** All tracking maths lives in `RunCore` as plain values, unit-tested on Linux: GPS sample filtering, distance accumulation, a 15 second pace window, mile splits, a pace-cue monitor, and an `OutdoorTracker` that combines them and is saved in the crash checkpoint. The app adds a thin `LocationService` over CoreLocation, feeds its fixes to the tracker from `WorkoutSessionModel`, and extends the start flow, live screen and summary.

**Tech Stack:** Swift 6.4 in WSL (Ubuntu 24.04), xtool 1.22.2, SwiftUI and MapKit (iOS 17), CoreLocation, XCTest. No third-party packages.

**Spec:** `docs/superpowers/specs/2026-10-12-runplan-design.md`, build stage 4 (sections "Workout engine", "GPS tracking", "Screens" 3-5, "Error handling").

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

These are called **TEST** and **BUILD** below. To run one test class, add `--filter <ClassName>` after `swift test`. The suite has 91 passing tests before this plan.

Rules: one type per file (small private helper views may share their screen's file), value types where possible, no force unwrapping outside tests, no SwiftUI/UIKit/AVFoundation/CoreLocation imports in `RunCore`. Everything `RunCore` exposes to the app is `public`. Commit after each task with a plain message: no Co-Authored-By or other Claude attribution line.

`RunCore` tasks (1 to 6) are test-first. App tasks (7 to 11) are verified with BUILD, then outdoors on the phone in Task 12.

## Design decisions fixed by this plan

The numbers below were checked in Python before writing the tests.

- **Sample filter:** a fix is used only if its horizontal accuracy is between 0 and 20 m, it is at most 5 s old, and it is dated no more than 1 s in the future.
- **Distance:** the great-circle (haversine) distance between consecutive used fixes, with an Earth radius of 6,371,000 m. A fix implying more than 10 m/s (about 2:41 per mile) since the last one is a GPS jump: it is ignored, and the previous fix stays the reference. While the workout is paused, fixes move the reference point but add no distance and no route points.
- **Pace:** distance and time between the oldest and newest fixes within the last 15 s. There is no pace until the window spans at least 5 s and 5 m. The window restarts after a pause.
- **Splits:** a split is recorded each mile of distance, timed in active (unpaused) workout time. A crossing between two fixes is timed by straight-line interpolation. A partial final split is kept if it is at least 16 m.
- **Pace cue (known tuning point):** when a step has a target pace and the smoothed pace is more than 15 s/mi off it for 30 s, the app says "Pick up the pace." or "Ease off the pace.". It repeats every further 30 s while still off. The timer restarts on a step change, a pause, a change of direction, or a return to within 15 s.
  One in-tolerance reading restarts it, so GPS noise may suppress cues for a runner only 16-25 s/mi
  off. Judge this on the outdoor run, and add a short grace period if needed.
- **Distance steps outdoors** end when the distance covered since the step started reaches the step's distance. Skip forward still ends them by hand, for example when GPS is lost.
- **GPS lost:** with no used fix for 10 s, the live screen shows a warning. Time keeps running and distance holds.
- **Free run:** one run step with a new `StepMeasure.open`, which lasts until the runner ends the workout. A free run is never in the plan, so its record's `workoutID` is nil. This is decided in the summary by checking whether the plan contains the workout.
- **Start outdoors:** the start sheet asks for when-in-use location permission and waits for a fix that passes the filter. If location is denied, it explains why and offers treadmill mode.
- **Clocks:** splits, the summary time and average pace use the engine's `activeElapsed`, which counts time actually run and never goes back on skip back; `totalElapsed` still drives plan progress. `FlatStep`'s comments describe open steps alongside distance steps.
- **Not in this stage:** auto-pause. The spec lists it under Settings, so it moves to stage 5 with the Settings screen. Task 12 records this in the spec.

## File structure

```
RunCore/Sources/RunCore/
  Tracking/ LocationSample.swift SampleFilter.swift Geo.swift DistanceAccumulator.swift  (new)
            PaceSmoother.swift SplitTracker.swift PaceCue.swift PaceCueMonitor.swift     (new)
            OutdoorEvent.swift OutdoorTracker.swift                                      (new)
  Models/   FreeRun.swift                                                                (new)
            StepMeasure.swift ActiveWorkout.swift                                        (modify)
  Engine/   StepExpander.swift                                                           (modify)
  Cues/     CueText.swift                                                                (modify)
RunCore/Tests/RunCoreTests/
  TrackingTestSupport.swift GeoTests.swift DistanceAccumulatorTests.swift                (new)
  PaceSmootherTests.swift SplitTrackerTests.swift PaceCueTests.swift                     (new)
  OutdoorTrackerTests.swift FreeRunTests.swift                                           (new)
  PlanGeneratorTests.swift                                                               (modify)
Info.plist                                                                               (modify)
Sources/RunPlan/
  Services/LocationService.swift                                                         (new)
  Workout/StartRunFlow.swift OutdoorStartView.swift                                      (new)
  Workout/WorkoutSessionModel.swift LiveWorkoutView.swift SummaryView.swift
          WorkoutDetailView.swift                                                        (modify)
  App/AppModel.swift  Plan/PlanView.swift StepEditor.swift                               (modify)
  Onboarding/OnboardingModel.swift OnboardingView.swift PlanPreviewView.swift           (modify, Task 5a)
README.md, docs/superpowers/specs/2026-10-12-runplan-design.md                           (modify)
```

---

### Task 1: GPS samples, filter and distance

**Goal:** A plain `LocationSample` value, the accuracy-and-age filter, and haversine distance, with no CoreLocation dependency.

**Files:**
- Create: `RunCore/Sources/RunCore/Tracking/LocationSample.swift`, `SampleFilter.swift`, `Geo.swift`
- Create: `RunCore/Tests/RunCoreTests/TrackingTestSupport.swift`, `RunCore/Tests/RunCoreTests/GeoTests.swift`

**Acceptance Criteria:**
- [ ] 0.001° of latitude measures 111.195 m; 0.001° of longitude at 51.5°N measures 69.220 m
- [ ] The filter accepts accuracy 0 to 20 m and age up to 5 s, and rejects worse, negative (invalid) or older fixes
- [ ] A sample converts to a `RoutePoint`

**Verify:** TEST with `--filter GeoTests` → `Executed 4 tests, with 0 failures`

**Steps:**

- [ ] **Step 1: Write the shared tracking test support**

`RunCore/Tests/RunCoreTests/TrackingTestSupport.swift`:

```swift
import Foundation
@testable import RunCore

/// Fixed start time for tracking tests.
let trackStart = Date(timeIntervalSince1970: 1_800_000_000)

/// Metres per degree of latitude on the haversine sphere, so `north` gives exact distances.
let metersPerDegreeLatitude = Double.pi * Geo.earthRadiusMeters / 180

/// A fix `seconds` after `trackStart`, `meters` north of (0, 0).
func fix(at seconds: Double, north meters: Double, accuracy: Double = 5) -> LocationSample {
    LocationSample(
        latitude: meters / metersPerDegreeLatitude,
        longitude: 0,
        timestamp: trackStart.addingTimeInterval(seconds),
        horizontalAccuracy: accuracy
    )
}
```

- [ ] **Step 2: Write the failing tests**

`RunCore/Tests/RunCoreTests/GeoTests.swift`:

```swift
import XCTest
@testable import RunCore

final class GeoTests: XCTestCase {

    private func sample(_ latitude: Double, _ longitude: Double) -> LocationSample {
        LocationSample(latitude: latitude, longitude: longitude, timestamp: trackStart, horizontalAccuracy: 5)
    }

    func testHaversineDistance() {
        XCTAssertEqual(Geo.distance(sample(0, 0), sample(0.001, 0)), 111.195, accuracy: 0.001)
        XCTAssertEqual(Geo.distance(sample(51.5, 0), sample(51.5, 0.001)), 69.220, accuracy: 0.001)
        XCTAssertEqual(Geo.distance(sample(51.5, -0.1), sample(51.5, -0.1)), 0)
        XCTAssertEqual(Geo.distance(fix(at: 0, north: 0), fix(at: 1, north: 3)), 3, accuracy: 1e-9)
    }

    func testFilterAcceptsAccurateRecentFixes() {
        let now = trackStart.addingTimeInterval(5)
        XCTAssertTrue(SampleFilter.accepts(fix(at: 0, north: 0, accuracy: 20), now: now))
        XCTAssertTrue(SampleFilter.accepts(fix(at: 5, north: 0, accuracy: 0), now: now))
        XCTAssertTrue(SampleFilter.accepts(fix(at: 5.5, north: 0), now: now))
    }

    func testFilterRejectsInaccurateInvalidStaleOrFutureFixes() {
        let now = trackStart.addingTimeInterval(5)
        XCTAssertFalse(SampleFilter.accepts(fix(at: 5, north: 0, accuracy: 20.5), now: now))
        XCTAssertFalse(SampleFilter.accepts(fix(at: 5, north: 0, accuracy: -1), now: now))
        XCTAssertFalse(SampleFilter.accepts(fix(at: -0.5, north: 0), now: now))
        XCTAssertFalse(SampleFilter.accepts(fix(at: 65, north: 0), now: now))
    }

    func testSampleMakesRoutePoint() {
        let point = fix(at: 3, north: 0).routePoint
        XCTAssertEqual(point, RoutePoint(latitude: 0, longitude: 0, timestamp: trackStart.addingTimeInterval(3)))
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: TEST with `--filter GeoTests`
Expected: build errors such as `cannot find 'LocationSample' in scope`.

- [ ] **Step 4: Write the implementation**

`RunCore/Sources/RunCore/Tracking/LocationSample.swift`:

```swift
import Foundation

/// One GPS fix as plain values, so tracking maths needs no CoreLocation.
public struct LocationSample: Codable, Equatable, Sendable {
    public var latitude: Double
    public var longitude: Double
    public var timestamp: Date
    /// Radius of uncertainty in metres. Negative means the fix is invalid.
    public var horizontalAccuracy: Double

    public init(latitude: Double, longitude: Double, timestamp: Date, horizontalAccuracy: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
    }

    public var routePoint: RoutePoint {
        RoutePoint(latitude: latitude, longitude: longitude, timestamp: timestamp)
    }
}
```

`RunCore/Sources/RunCore/Tracking/SampleFilter.swift`:

```swift
import Foundation

/// Decides whether a GPS fix is good enough to use: accurate to 20 m, at most 5 s old, and not
/// dated in the future. A future-dated fix would make every later fix look older than it and
/// freeze distance for the rest of the run.
public enum SampleFilter {
    public static let maxAccuracyMeters = 20.0
    public static let maxAgeSeconds: TimeInterval = 5
    /// Allowance for a fix stamped slightly after the `now` its caller captured.
    public static let maxClockSkewSeconds: TimeInterval = 1

    public static func accepts(_ sample: LocationSample, now: Date) -> Bool {
        let age = now.timeIntervalSince(sample.timestamp)
        return sample.horizontalAccuracy >= 0
            && sample.horizontalAccuracy <= maxAccuracyMeters
            && age >= -maxClockSkewSeconds
            && age <= maxAgeSeconds
    }
}
```

`RunCore/Sources/RunCore/Tracking/Geo.swift`:

```swift
import Foundation

/// Distance on the Earth's surface.
public enum Geo {
    static let earthRadiusMeters = 6_371_000.0

    /// Great-circle distance in metres between two fixes (haversine formula).
    public static func distance(_ a: LocationSample, _ b: LocationSample) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusMeters * asin(min(1, sqrt(h)))
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add RunCore/Sources/RunCore/Tracking RunCore/Tests/RunCoreTests/TrackingTestSupport.swift RunCore/Tests/RunCoreTests/GeoTests.swift
git commit -m "Add GPS samples, filter and distance"
```

---

### Task 2: Distance accumulator

**Goal:** `DistanceAccumulator` sums distance and builds the route from used fixes, ignoring GPS jumps and movement while paused.

**Files:**
- Create: `RunCore/Sources/RunCore/Tracking/DistanceAccumulator.swift`
- Create: `RunCore/Tests/RunCoreTests/DistanceAccumulatorTests.swift`

**Acceptance Criteria:**
- [ ] Eleven fixes 3 m apart sum to 30 m with 11 route points
- [ ] A fix implying more than 10 m/s is ignored and the previous fix stays the reference
- [ ] Fixes while paused move the reference point but add no distance or route points
- [ ] A fix with no time since the previous one is ignored

**Verify:** TEST with `--filter DistanceAccumulatorTests` → `Executed 5 tests, with 0 failures`

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/DistanceAccumulatorTests.swift`:

```swift
import XCTest
@testable import RunCore

final class DistanceAccumulatorTests: XCTestCase {

    func testSumsDistanceBetweenFixes() {
        var accumulator = DistanceAccumulator()
        for second in 0...10 {
            accumulator.add(fix(at: Double(second), north: Double(3 * second)))
        }
        XCTAssertEqual(accumulator.totalMeters, 30, accuracy: 1e-6)
        XCTAssertEqual(accumulator.route.count, 11)
    }

    func testIgnoresImpossibleJump() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0))
        accumulator.add(fix(at: 1, north: 3))
        XCTAssertEqual(accumulator.add(fix(at: 2, north: 503)), 0)
        accumulator.add(fix(at: 3, north: 6))
        XCTAssertEqual(accumulator.totalMeters, 6, accuracy: 1e-6)
        XCTAssertEqual(accumulator.route.count, 3)
    }

    func testPausedFixesMoveTheReferenceOnly() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0))
        accumulator.add(fix(at: 1, north: 3))
        accumulator.add(fix(at: 2, north: 6), counting: false)
        accumulator.add(fix(at: 3, north: 9), counting: false)
        accumulator.add(fix(at: 4, north: 12))
        XCTAssertEqual(accumulator.totalMeters, 6, accuracy: 1e-6)
        XCTAssertEqual(accumulator.route.count, 3)
    }

    func testRecoversFromABadReferenceFix() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 500))
        XCTAssertEqual(accumulator.add(fix(at: 1, north: 0)), 0)
        accumulator.add(fix(at: 60, north: 0))
        XCTAssertEqual(accumulator.totalMeters, 500, accuracy: 1e-6)
        XCTAssertEqual(accumulator.route.count, 2)
    }

    func testFixWithNoElapsedTimeIsIgnored() {
        var accumulator = DistanceAccumulator()
        accumulator.add(fix(at: 0, north: 0))
        XCTAssertEqual(accumulator.add(fix(at: 0, north: 3)), 0)
        XCTAssertEqual(accumulator.totalMeters, 0)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: TEST with `--filter DistanceAccumulatorTests`
Expected: build error `cannot find 'DistanceAccumulator' in scope`.

- [ ] **Step 3: Write the implementation**

`RunCore/Sources/RunCore/Tracking/DistanceAccumulator.swift`:

```swift
import Foundation

/// Sums distance between used GPS fixes and keeps the route, ignoring jumps that imply an
/// impossible speed.
public struct DistanceAccumulator: Codable, Equatable, Sendable {
    /// About 2:41 per mile. Anything faster is a GPS jump, not running.
    public static let maxSpeedMetersPerSecond = 10.0

    public private(set) var totalMeters: Double = 0
    public private(set) var route: [RoutePoint] = []
    /// The reference fix. It is not advanced on a rejected jump, so the implied speed falls as
    /// time passes and a bad reference ages out instead of blocking every later fix.
    private var last: LocationSample?

    public init() {}

    /// Adds the distance from the previous fix and returns it. With `counting` false (paused)
    /// the fix only becomes the new reference point, so movement while paused is not counted.
    @discardableResult
    public mutating func add(_ sample: LocationSample, counting: Bool = true) -> Double {
        guard let previous = last else {
            last = sample
            if counting { route.append(sample.routePoint) }
            return 0
        }
        let seconds = sample.timestamp.timeIntervalSince(previous.timestamp)
        guard seconds > 0 else { return 0 }
        let meters = Geo.distance(previous, sample)
        guard meters / seconds <= Self.maxSpeedMetersPerSecond else { return 0 }

        last = sample
        guard counting else { return 0 }
        totalMeters += meters
        route.append(sample.routePoint)
        return meters
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add RunCore/Sources/RunCore/Tracking/DistanceAccumulator.swift RunCore/Tests/RunCoreTests/DistanceAccumulatorTests.swift
git commit -m "Add GPS distance accumulator"
```

---

### Task 3: Pace window and mile splits

**Goal:** `PaceSmoother` reports pace over the last 15 s; `SplitTracker` times each mile with interpolation and keeps a partial final split.

**Files:**
- Create: `RunCore/Sources/RunCore/Tracking/PaceSmoother.swift`, `RunCore/Sources/RunCore/Tracking/SplitTracker.swift`
- Create: `RunCore/Tests/RunCoreTests/PaceSmootherTests.swift`, `RunCore/Tests/RunCoreTests/SplitTrackerTests.swift`

**Acceptance Criteria:**
- [ ] 3 m/s gives 536 s/mi; after switching from 2 to 4 m/s, the window shows only the new speed (402)
- [ ] No pace when standing still, with under 5 s of data, or after a reset
- [ ] Splits: crossing a mile between fixes at 500 s and 505 s gives 502 s; the next mile gives 474 s; the partial last 81.312 m gives 24 s
- [ ] Two miles in one update give two splits of 488 s; a partial under 16 m is dropped

**Verify:** TEST with `--filter PaceSmootherTests` and `--filter SplitTrackerTests` → 3 and 3 tests, 0 failures

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/PaceSmootherTests.swift`:

```swift
import XCTest
@testable import RunCore

final class PaceSmootherTests: XCTestCase {

    private func feed(_ smoother: inout PaceSmoother, seconds: ClosedRange<Int>, meters: (Int) -> Double) {
        for second in seconds {
            smoother.add(time: trackStart.addingTimeInterval(Double(second)), totalMeters: meters(second))
        }
    }

    func testPaceOverTheLastFifteenSeconds() {
        var smoother = PaceSmoother()
        feed(&smoother, seconds: 0...20) { Double(3 * $0) }
        XCTAssertEqual(smoother.secondsPerMile, 536)

        var changing = PaceSmoother()
        feed(&changing, seconds: 0...20) { Double(2 * $0) }
        feed(&changing, seconds: 21...40) { 40 + Double(4 * ($0 - 20)) }
        XCTAssertEqual(changing.secondsPerMile, 402)
    }

    func testNoPaceWithoutEnoughData() {
        var standing = PaceSmoother()
        feed(&standing, seconds: 0...20) { _ in 100 }
        XCTAssertNil(standing.secondsPerMile)

        var brief = PaceSmoother()
        feed(&brief, seconds: 0...3) { Double(3 * $0) }
        XCTAssertNil(brief.secondsPerMile)
    }

    func testResetClearsTheWindow() {
        var smoother = PaceSmoother()
        feed(&smoother, seconds: 0...20) { Double(3 * $0) }
        smoother.reset()
        XCTAssertNil(smoother.secondsPerMile)
    }
}
```

`RunCore/Tests/RunCoreTests/SplitTrackerTests.swift`:

```swift
import XCTest
@testable import RunCore

final class SplitTrackerTests: XCTestCase {

    func testInterpolatesEachMile() {
        var tracker = SplitTracker()
        XCTAssertEqual(tracker.update(totalMeters: 1600, elapsed: 500), [])
        XCTAssertEqual(tracker.update(totalMeters: 1620, elapsed: 505), [
            Split(index: 1, distanceMeters: Pace.metersPerMile, durationSeconds: 502),
        ])
        XCTAssertEqual(tracker.update(totalMeters: 3300, elapsed: 1000), [
            Split(index: 2, distanceMeters: Pace.metersPerMile, durationSeconds: 474),
        ])

        let all = tracker.allSplits(totalMeters: 3300, elapsed: 1000)
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[2].index, 3)
        XCTAssertEqual(all[2].distanceMeters, 81.312, accuracy: 0.001)
        XCTAssertEqual(all[2].durationSeconds, 24)
    }

    func testSeveralMilesInOneUpdate() {
        var tracker = SplitTracker()
        XCTAssertEqual(tracker.update(totalMeters: 3300, elapsed: 1000).map(\.durationSeconds), [488, 488])
    }

    func testShortPartialSplitIsDropped() {
        var tracker = SplitTracker()
        _ = tracker.update(totalMeters: 1620, elapsed: 500)
        XCTAssertEqual(tracker.allSplits(totalMeters: 1620, elapsed: 500).count, 1)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: TEST with `--filter PaceSmootherTests`
Expected: build errors such as `cannot find 'PaceSmoother' in scope`.

- [ ] **Step 3: Write the implementation**

`RunCore/Sources/RunCore/Tracking/PaceSmoother.swift`:

```swift
import Foundation

/// Pace over the last 15 seconds of used fixes.
public struct PaceSmoother: Codable, Equatable, Sendable {
    public static let windowSeconds: TimeInterval = 15
    static let minimumSpanSeconds: TimeInterval = 5
    static let minimumMeters = 5.0

    struct Entry: Codable, Equatable, Sendable {
        let time: Date
        let meters: Double
    }

    private var entries: [Entry] = []

    public init() {}

    public mutating func add(time: Date, totalMeters: Double) {
        entries.append(Entry(time: time, meters: totalMeters))
        entries.removeAll { time.timeIntervalSince($0.time) > Self.windowSeconds }
    }

    public mutating func reset() {
        entries.removeAll()
    }

    /// Seconds per mile, or nil until the window holds at least 5 s and 5 m. It does not age
    /// by itself, so callers must ignore it once GPS has been lost.
    public var secondsPerMile: Int? {
        guard let first = entries.first, let last = entries.last else { return nil }
        let seconds = last.time.timeIntervalSince(first.time)
        let meters = last.meters - first.meters
        guard seconds >= Self.minimumSpanSeconds, meters >= Self.minimumMeters else { return nil }
        return Int((seconds / Pace.miles(fromMeters: meters)).rounded())
    }
}
```

`RunCore/Sources/RunCore/Tracking/SplitTracker.swift`:

```swift
import Foundation

/// Mile splits from cumulative distance and active (unpaused) time. A mile crossed between two
/// updates is timed by straight-line interpolation.
public struct SplitTracker: Codable, Equatable, Sendable {
    /// A partial final split shorter than this (about 0.01 mi) is dropped.
    static let minimumFinalMeters = 16.0

    public private(set) var completed: [Split] = []
    private var lastMeters: Double = 0
    private var lastElapsed: TimeInterval = 0
    private var lastSplitElapsed: TimeInterval = 0

    public init() {}

    /// Returns the splits completed by this update, usually none.
    public mutating func update(totalMeters: Double, elapsed: TimeInterval) -> [Split] {
        var new: [Split] = []
        while totalMeters >= Double(completed.count + 1) * Pace.metersPerMile {
            let boundary = Double(completed.count + 1) * Pace.metersPerMile
            let fraction = totalMeters > lastMeters ? (boundary - lastMeters) / (totalMeters - lastMeters) : 1
            let crossing = lastElapsed + fraction * (elapsed - lastElapsed)
            let split = Split(
                index: completed.count + 1,
                distanceMeters: Pace.metersPerMile,
                durationSeconds: Int((crossing - lastSplitElapsed).rounded())
            )
            completed.append(split)
            new.append(split)
            lastSplitElapsed = crossing
        }
        lastMeters = totalMeters
        lastElapsed = elapsed
        return new
    }

    /// Completed splits plus the partial last one, when it covers at least 16 m. Call `update`
    /// with the same distance first.
    public func allSplits(totalMeters: Double, elapsed: TimeInterval) -> [Split] {
        let remaining = totalMeters - Double(completed.count) * Pace.metersPerMile
        guard remaining >= Self.minimumFinalMeters else { return completed }
        let partial = Split(
            index: completed.count + 1,
            distanceMeters: remaining,
            durationSeconds: Int((elapsed - lastSplitElapsed).rounded())
        )
        return completed + [partial]
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add RunCore/Sources/RunCore/Tracking/PaceSmoother.swift RunCore/Sources/RunCore/Tracking/SplitTracker.swift RunCore/Tests/RunCoreTests/PaceSmootherTests.swift RunCore/Tests/RunCoreTests/SplitTrackerTests.swift
git commit -m "Add pace window and mile splits"
```

---

### Task 4: Pace cues and outdoor cue wording

**Goal:** `PaceCueMonitor` decides when to say "Pick up the pace." or "Ease off the pace."; `CueText` words the cues and mile splits.

**Files:**
- Create: `RunCore/Sources/RunCore/Tracking/PaceCue.swift`, `RunCore/Sources/RunCore/Tracking/PaceCueMonitor.swift`
- Modify: `RunCore/Sources/RunCore/Cues/CueText.swift`
- Create: `RunCore/Tests/RunCoreTests/PaceCueTests.swift`

**Acceptance Criteria:**
- [ ] 20 s/mi slow against a 600 target: no cue at 29 s, "speed up" at 30 s, again at 60 s
- [ ] Back within 15 s/mi, a change of direction, a missing pace or target, or `reset()` restarts the 30 s
- [ ] "Mile 2, 9 minutes 32 seconds." and "Mile 1, 10 minutes." wording; cue wording as above

**Verify:** TEST with `--filter PaceCueTests` → `Executed 5 tests, with 0 failures`

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/PaceCueTests.swift`:

```swift
import XCTest
@testable import RunCore

final class PaceCueTests: XCTestCase {

    private func at(_ seconds: Double) -> Date { trackStart.addingTimeInterval(seconds) }

    func testCueAfterThirtySecondsOffAndEveryThirtyAfter() {
        var monitor = PaceCueMonitor()
        XCTAssertNil(monitor.update(pace: 620, target: 600, now: at(0)))
        XCTAssertNil(monitor.update(pace: 620, target: 600, now: at(29)))
        XCTAssertEqual(monitor.update(pace: 620, target: 600, now: at(30)), .speedUp)
        XCTAssertNil(monitor.update(pace: 620, target: 600, now: at(31)))
        XCTAssertEqual(monitor.update(pace: 620, target: 600, now: at(60)), .speedUp)
    }

    func testFifteenSecondsOffIsWithinTolerance() {
        var monitor = PaceCueMonitor()
        for second in [0.0, 30, 60] {
            XCTAssertNil(monitor.update(pace: 615, target: 600, now: at(second)))
        }
        var justOutside = PaceCueMonitor()
        _ = justOutside.update(pace: 616, target: 600, now: at(0))
        XCTAssertEqual(justOutside.update(pace: 616, target: 600, now: at(30)), .speedUp)
    }

    func testOnPaceOrDirectionChangeRestartsTheTimer() {
        var monitor = PaceCueMonitor()
        _ = monitor.update(pace: 620, target: 600, now: at(0))
        XCTAssertNil(monitor.update(pace: 610, target: 600, now: at(20)))
        XCTAssertNil(monitor.update(pace: 620, target: 600, now: at(40)))
        XCTAssertNil(monitor.update(pace: 580, target: 600, now: at(60)))
        XCTAssertNil(monitor.update(pace: 580, target: 600, now: at(89)))
        XCTAssertEqual(monitor.update(pace: 580, target: 600, now: at(90)), .slowDown)
    }

    func testNoCueWithoutPaceOrTargetOrAfterReset() {
        var monitor = PaceCueMonitor()
        _ = monitor.update(pace: 620, target: 600, now: at(0))
        XCTAssertNil(monitor.update(pace: nil, target: 600, now: at(30)))
        XCTAssertNil(monitor.update(pace: 620, target: nil, now: at(31)))
        _ = monitor.update(pace: 620, target: 600, now: at(32))
        monitor.reset()
        XCTAssertNil(monitor.update(pace: 620, target: 600, now: at(62)))
    }

    func testOutdoorCueWording() {
        XCTAssertEqual(CueText.splitAnnouncement(Split(index: 2, distanceMeters: Pace.metersPerMile, durationSeconds: 572)), "Mile 2, 9 minutes 32 seconds.")
        XCTAssertEqual(CueText.splitAnnouncement(Split(index: 1, distanceMeters: Pace.metersPerMile, durationSeconds: 600)), "Mile 1, 10 minutes.")
        XCTAssertEqual(CueText.paceCue(.speedUp), "Pick up the pace.")
        XCTAssertEqual(CueText.paceCue(.slowDown), "Ease off the pace.")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: TEST with `--filter PaceCueTests`
Expected: build errors such as `cannot find 'PaceCueMonitor' in scope`.

- [ ] **Step 3: Write the implementation**

`RunCore/Sources/RunCore/Tracking/PaceCue.swift`:

```swift
import Foundation

/// `.speedUp` when running slower than the target, `.slowDown` when faster.
public enum PaceCue: String, Codable, Sendable {
    case speedUp
    case slowDown
}
```

`RunCore/Sources/RunCore/Tracking/PaceCueMonitor.swift`:

```swift
import Foundation

/// Fires a pace cue once the smoothed pace has been more than 15 s/mi off the step's target
/// for 30 s, and again every 30 s while it stays off in the same direction.
public struct PaceCueMonitor: Codable, Equatable, Sendable {
    public static let toleranceSecondsPerMile = 15
    public static let holdSeconds: TimeInterval = 30

    private var offSince: Date?
    private var offCue: PaceCue?

    public init() {}

    public mutating func update(pace: Int?, target: Int?, now: Date) -> PaceCue? {
        guard let pace, let target, abs(pace - target) > Self.toleranceSecondsPerMile else {
            reset()
            return nil
        }
        let cue: PaceCue = pace > target ? .speedUp : .slowDown
        guard let since = offSince, offCue == cue else {
            offSince = now
            offCue = cue
            return nil
        }
        guard now.timeIntervalSince(since) >= Self.holdSeconds else { return nil }
        offSince = now
        return cue
    }

    /// Call on a step change or pause.
    public mutating func reset() {
        offSince = nil
        offCue = nil
    }
}
```

In `RunCore/Sources/RunCore/Cues/CueText.swift`, add these two functions directly after the `target(for:mode:)` function (they use the existing private `spokenDuration`):

```swift
    /// e.g. "Mile 2, 9 minutes 32 seconds."
    public static func splitAnnouncement(_ split: Split) -> String {
        "Mile \(split.index), \(spokenDuration(split.durationSeconds))."
    }

    public static func paceCue(_ cue: PaceCue) -> String {
        switch cue {
        case .speedUp: return "Pick up the pace."
        case .slowDown: return "Ease off the pace."
        }
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add RunCore/Sources/RunCore/Tracking/PaceCue.swift RunCore/Sources/RunCore/Tracking/PaceCueMonitor.swift RunCore/Sources/RunCore/Cues/CueText.swift RunCore/Tests/RunCoreTests/PaceCueTests.swift
git commit -m "Add pace cues and split wording"
```

---

### Task 5: Outdoor tracker

**Goal:** `OutdoorTracker` combines the tracking pieces into the events the session acts on, and is saved in the crash checkpoint.

**Files:**
- Create: `RunCore/Sources/RunCore/Tracking/OutdoorEvent.swift`, `RunCore/Sources/RunCore/Tracking/OutdoorTracker.swift`
- Modify: `RunCore/Sources/RunCore/Models/ActiveWorkout.swift`
- Create: `RunCore/Tests/RunCoreTests/OutdoorTrackerTests.swift`

**Acceptance Criteria:**
- [ ] A 400 m step at 3 m/s with a 600 s/mi target gives "ease off" at 35, 65, 95 and 125 s, then "step distance reached" once at 134 s; 100 m remain at 100 s
- [ ] A free run at 3 m/s announces mile 1 in 536 s; the final splits at 545 s are mile 1 and a 25.656 m partial of 9 s
- [ ] Paused fixes add nothing; signal is lost 10 s after the last used fix, and an inaccurate fix doesn't count
- [ ] A pace measured before GPS was lost gives no pace cue afterwards
- [ ] The tracker round-trips through JSON inside `ActiveWorkout`, and an `ActiveWorkout` saved without it still loads

**Verify:** TEST with `--filter OutdoorTrackerTests` → `Executed 8 tests, with 0 failures`

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/OutdoorTrackerTests.swift`:

```swift
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

    func testSplitsStayPositiveAfterSkipBack() throws {
        let engine = WorkoutEngine(planSteps: [
            Step(kind: .run, measure: .time(seconds: 600)),
            Step(kind: .run, measure: .time(seconds: 3000)),
        ])
        engine.start(now: trackStart)
        var tracker = OutdoorTracker()
        var splits: [Split] = []

        for second in 0...1100 {
            if second == 700 {
                // Skip back from the second step rewinds plan progress, not the run's clock.
                engine.skipBack(now: at(second))
                tracker.restartStep()
            }
            tracker.record(fix(at: Double(second), north: Double(3 * second)), now: at(second), counting: true)
            let snapshot = try XCTUnwrap(engine.snapshot(now: at(second)))
            for case .split(let split) in tracker.events(for: snapshot, now: at(second)) {
                splits.append(split)
            }
        }

        XCTAssertEqual(splits.map(\.durationSeconds), [536, 536])
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

/// A plain timed workout for checkpoint tests.
private enum FreeRunlessWorkout {
    static func make() -> Workout {
        Workout(date: trackStart, kind: .easy, title: "Easy", steps: [Step(kind: .run, measure: .time(seconds: 600))])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: TEST with `--filter OutdoorTrackerTests`
Expected: build errors such as `cannot find 'OutdoorTracker' in scope`.

- [ ] **Step 3: Write the implementation**

`RunCore/Sources/RunCore/Tracking/OutdoorEvent.swift`:

```swift
import Foundation

/// What an outdoor session should do after a snapshot.
public enum OutdoorEvent: Equatable, Sendable {
    /// Announce a completed mile.
    case split(Split)
    case paceCue(PaceCue)
    /// The current distance step's distance has been covered: advance the engine.
    case stepDistanceReached
}
```

`RunCore/Sources/RunCore/Tracking/OutdoorTracker.swift`:

```swift
import Foundation

/// Everything measured on an outdoor run: GPS distance and route, smoothed pace, mile splits,
/// and when a distance step is complete or a pace cue is due. It holds only values, so it is
/// unit tested and saved in the crash checkpoint alongside the engine.
public struct OutdoorTracker: Codable, Equatable, Sendable {
    /// With no used fix for this long, the live screen shows a signal warning.
    public static let signalTimeoutSeconds: TimeInterval = 10

    private var distance = DistanceAccumulator()
    private var smoother = PaceSmoother()
    private var splits = SplitTracker()
    private var paceMonitor = PaceCueMonitor()
    private var stepIndex: Int?
    private var stepStartMeters: Double = 0
    private var stepDistanceSent = false
    private var splitCheckedMeters: Double = 0
    public private(set) var lastFixAt: Date?

    public init() {}

    public var totalMeters: Double { distance.totalMeters }
    public var route: [RoutePoint] { distance.route }

    /// Seconds per mile over the last 15 seconds, or nil while there is too little data. It is
    /// not cleared when fixes stop, so check `hasSignal(now:)` before showing it.
    public var currentPace: Int? { smoother.secondsPerMile }

    /// True while a fix that passed the filter arrived within the last 10 s.
    public func hasSignal(now: Date) -> Bool {
        guard let lastFixAt else { return false }
        return now.timeIntervalSince(lastFixAt) <= Self.signalTimeoutSeconds
    }

    /// Feeds one GPS fix. Inaccurate or stale fixes are ignored. While paused (`counting` false)
    /// a fix moves the reference point but adds no distance, and the pace window restarts.
    public mutating func record(_ sample: LocationSample, now: Date, counting: Bool) {
        guard SampleFilter.accepts(sample, now: now) else { return }
        lastFixAt = sample.timestamp
        distance.add(sample, counting: counting)
        if counting {
            smoother.add(time: sample.timestamp, totalMeters: distance.totalMeters)
        } else {
            smoother.reset()
        }
    }

    /// Splits to announce, pace cues to speak, and whether the current distance step is done
    /// (reported once per step).
    public mutating func events(for snapshot: WorkoutEngine.Snapshot, now: Date) -> [OutdoorEvent] {
        if snapshot.stepIndex != stepIndex {
            stepIndex = snapshot.stepIndex
            stepStartMeters = distance.totalMeters
            stepDistanceSent = false
            paceMonitor.reset()
        }

        var events: [OutdoorEvent] = []
        // Only when distance has changed, so a mile crossed between two fixes is interpolated
        // over the fix interval rather than over the last 0.25 s screen refresh.
        if distance.totalMeters != splitCheckedMeters {
            splitCheckedMeters = distance.totalMeters
            events += splits
                .update(totalMeters: distance.totalMeters, elapsed: snapshot.activeElapsed)
                .map(OutdoorEvent.split)
        }

        guard snapshot.state == .running else {
            paceMonitor.reset()
            return events
        }

        if let target = snapshot.step.distanceMeters, !stepDistanceSent,
           distance.totalMeters - stepStartMeters >= target {
            stepDistanceSent = true
            events.append(.stepDistanceReached)
        }
        let pace = hasSignal(now: now) ? currentPace : nil
        if let cue = paceMonitor.update(pace: pace, target: snapshot.step.targetPaceSecondsPerMile, now: now) {
            events.append(.paceCue(cue))
        }
        return events
    }

    /// Call when the runner skips or restarts a step by hand. The next `events` call then measures
    /// the step's distance afresh; skip back on the first step keeps the same step index.
    public mutating func restartStep() {
        stepIndex = nil
    }

    /// Distance left in the current step, or nil when the step is not measured by distance.
    public func stepMetersRemaining(for snapshot: WorkoutEngine.Snapshot) -> Double? {
        guard let target = snapshot.step.distanceMeters else { return nil }
        guard snapshot.stepIndex == stepIndex else { return target }
        return max(0, target - (distance.totalMeters - stepStartMeters))
    }

    /// Completed mile splits plus the partial last one.
    public func finalSplits(elapsed: TimeInterval) -> [Split] {
        splits.allSplits(totalMeters: distance.totalMeters, elapsed: elapsed)
    }
}
```

Replace `RunCore/Sources/RunCore/Models/ActiveWorkout.swift` with:

```swift
import Foundation

/// A workout in progress, written to disk every few seconds so it can be resumed if the
/// app is killed.
public struct ActiveWorkout: Codable, Equatable, Sendable {
    public var workout: Workout
    public var mode: RunMode
    public var startedAt: Date
    public var checkpoint: WorkoutEngine.Checkpoint
    /// Outdoor runs only: distance, route, pace window and splits so far.
    public var outdoor: OutdoorTracker?

    public init(
        workout: Workout,
        mode: RunMode,
        startedAt: Date,
        checkpoint: WorkoutEngine.Checkpoint,
        outdoor: OutdoorTracker? = nil
    ) {
        self.workout = workout
        self.mode = mode
        self.startedAt = startedAt
        self.checkpoint = checkpoint
        self.outdoor = outdoor
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: TEST
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add RunCore/Sources/RunCore/Tracking/OutdoorEvent.swift RunCore/Sources/RunCore/Tracking/OutdoorTracker.swift RunCore/Sources/RunCore/Models/ActiveWorkout.swift RunCore/Tests/RunCoreTests/OutdoorTrackerTests.swift
git commit -m "Add outdoor tracker and save it in the checkpoint"
```

---

### Task 5a: Change plan

**Goal:** From the Plan tab, reopen onboarding filled in with the current answers, change them, and replace the plan after a confirmation. Requested by the user after testing stage 3; it is independent of GPS, so it runs before Task 6.

**Files:**
- Modify: `Sources/RunPlan/Onboarding/OnboardingModel.swift`, `Sources/RunPlan/Onboarding/OnboardingView.swift`, `Sources/RunPlan/Onboarding/PlanPreviewView.swift`, `Sources/RunPlan/Plan/PlanView.swift`

**Acceptance Criteria:**
- [ ] The Plan tab has Change plan, which opens onboarding in a sheet with every answer filled in from the current plan
- [ ] A start date in the past is moved to today
- [ ] Cancel on the first page closes the sheet without changing anything
- [ ] Save asks "Replace your plan?"; confirming generates and saves the new plan and closes the sheet; runs already done stay in Runs
- [ ] First-launch onboarding is unchanged; BUILD succeeds

**Verify:** BUILD → success

**Steps:**

- [ ] **Step 1: Fill the draft from a profile**

In `Sources/RunPlan/Onboarding/OnboardingModel.swift`, add this initializer directly after the line `    var startDate = Calendar.current.startOfDay(for: Date())`:

```swift

    /// A blank draft for first launch, or one filled in from the current plan's answers so they
    /// can be changed. A start date in the past moves to today.
    init(profile: Profile? = nil) {
        guard let profile else { return }
        distance = profile.goal.distance
        hasGoalTime = profile.goal.targetSeconds != nil
        goalSeconds = profile.goal.targetSeconds ?? Self.defaultSeconds(for: profile.goal.distance)
        switch profile.fitness {
        case .newRunner:
            fitnessChoice = .newRunner
        case .runsFiveMinutes:
            fitnessChoice = .runsFiveMinutes
        case .runsTwentyMinutes:
            fitnessChoice = .runsTwentyMinutes
        case .recentRace(let distance, let seconds):
            fitnessChoice = .recentRace
            raceDistance = distance
            raceSeconds = seconds
        }
        runDays = Set(profile.runDays)
        planWeeks = profile.planWeeks
        let today = Calendar.current.startOfDay(for: Date())
        startDate = max(Calendar.current.startOfDay(for: profile.startDate), today)
    }
```

- [ ] **Step 2: Let onboarding edit an existing plan**

In `Sources/RunPlan/Onboarding/OnboardingView.swift`:

1. Replace the doc comment and the first lines of the struct:

```swift
/// First launch: goal, current fitness and schedule, then a preview of the plan before it is
/// saved.
struct OnboardingView: View {
    @State private var model = OnboardingModel()
```

with:

```swift
/// Goal, current fitness and schedule, then a preview of the plan before it is saved. Shown on
/// first launch, and from the Plan tab to change the current plan.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: OnboardingModel
    /// True when changing an existing plan, rather than on first launch.
    private let isChangingPlan: Bool

    init(changing profile: Profile? = nil) {
        _model = State(initialValue: OnboardingModel(profile: profile))
        isChangingPlan = profile != nil
    }
```

2. In the toolbar, replace:

```swift
                    if model.page != .goal {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") { model.back() }
                        }
                    }
```

with:

```swift
                    if model.page != .goal {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back") { model.back() }
                        }
                    } else if isChangingPlan {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                    }
```

3. Replace `        case .preview: PlanPreviewView(model: model)` with:

```swift
        case .preview: PlanPreviewView(model: model, isReplacing: isChangingPlan)
```

- [ ] **Step 3: Confirm before replacing**

In `Sources/RunPlan/Onboarding/PlanPreviewView.swift`:

1. Replace:

```swift
    @Environment(AppModel.self) private var app
    let model: OnboardingModel
```

with:

```swift
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let model: OnboardingModel
    /// True when this plan replaces an existing one, which needs a confirmation.
    let isReplacing: Bool

    @State private var confirmingReplace = false
```

2. Replace the Save button's action and label:

```swift
            Button {
                app.createPlan(from: model.profile)
            } label: {
                Text("Save plan").font(.title3.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
```

with:

```swift
            Button {
                if isReplacing {
                    confirmingReplace = true
                } else {
                    app.createPlan(from: model.profile)
                }
            } label: {
                Text(isReplacing ? "Replace plan" : "Save plan")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
```

3. Directly after the `.safeAreaInset(edge: .bottom) { ... }` modifier's closing brace, add:

```swift
        .confirmationDialog("Replace your plan?", isPresented: $confirmingReplace, titleVisibility: .visible) {
            Button("Replace plan", role: .destructive) {
                app.createPlan(from: model.profile)
                dismiss()
            }
        } message: {
            Text("The new plan starts fresh. Runs you have already done stay in Runs.")
        }
```

- [ ] **Step 4: Add Change plan to the Plan tab**

In `Sources/RunPlan/Plan/PlanView.swift`:

1. Add under `    @Environment(AppModel.self) private var app`:

```swift
    @State private var changingPlan = false
```

2. Directly after the `.navigationDestination(for: UUID.self) { id in ... }` modifier's closing brace, add:

```swift
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Change plan") { changingPlan = true }
                }
            }
            .sheet(isPresented: $changingPlan) {
                OnboardingView(changing: app.plan?.profile)
            }
```

- [ ] **Step 5: Build**

Run: BUILD
Expected: success.

- [ ] **Step 6: Commit**

```bash
git add Sources/RunPlan/Onboarding Sources/RunPlan/Plan/PlanView.swift
git commit -m "Let the plan be changed from the Plan tab"
```

---

### Task 6: Open steps and free runs

**Goal:** A `StepMeasure.open` step that lasts until the runner ends it, and `FreeRun.workout(on:)` built from one.

**Files:**
- Modify: `RunCore/Sources/RunCore/Models/StepMeasure.swift`, `RunCore/Sources/RunCore/Engine/StepExpander.swift`, `RunCore/Tests/RunCoreTests/PlanGeneratorTests.swift`
- Modify: `Sources/RunPlan/Workout/WorkoutDetailView.swift`, `Sources/RunPlan/Plan/StepEditor.swift`
- Create: `RunCore/Sources/RunCore/Models/FreeRun.swift`, `RunCore/Tests/RunCoreTests/FreeRunTests.swift`

**Acceptance Criteria:**
- [ ] A free run is one open run step titled "Free run", which expands to an open-ended step with no distance
- [ ] An open step is still running after 2 hours, with no remaining time and nothing planned, and finishes when advanced
- [ ] `.open` round-trips through JSON, and is announced as "Run."
- [ ] Every `switch` over `StepMeasure` handles `.open`; TEST and BUILD succeed

**Verify:** TEST with `--filter FreeRunTests` → `Executed 3 tests, with 0 failures`; then TEST and BUILD

**Steps:**

- [ ] **Step 1: Write the failing tests**

`RunCore/Tests/RunCoreTests/FreeRunTests.swift`:

```swift
import XCTest
@testable import RunCore

final class FreeRunTests: XCTestCase {

    func testFreeRunIsOneOpenRunStep() {
        let workout = FreeRun.workout(on: trackStart)
        XCTAssertEqual(workout.title, "Free run")
        XCTAssertEqual(workout.steps.map(\.measure), [.open])
        let flat = StepExpander.expand(workout.steps)
        XCTAssertEqual(flat.count, 1)
        XCTAssertTrue(flat[0].isOpenEnded)
        XCTAssertNil(flat[0].distanceMeters)
        XCTAssertEqual(CueText.announcement(for: flat[0], mode: .outdoor), "Run.")
    }

    func testOpenStepRunsUntilEnded() throws {
        let engine = WorkoutEngine(planSteps: FreeRun.workout(on: trackStart).steps)
        engine.start(now: trackStart)
        let snapshot = try XCTUnwrap(engine.snapshot(now: trackStart.addingTimeInterval(7200)))
        XCTAssertEqual(snapshot.state, .running)
        XCTAssertNil(snapshot.remainingInStep)
        XCTAssertEqual(snapshot.totalElapsed, 7200)
        XCTAssertEqual(snapshot.totalPlanned, 0)

        engine.advanceToNextStep(now: trackStart.addingTimeInterval(7201))
        XCTAssertEqual(engine.state, .finished)
    }

    func testOpenMeasureRoundTrips() throws {
        let step = Step(kind: .run, measure: .open)
        XCTAssertEqual(try JSONDecoder().decode(Step.self, from: JSONEncoder().encode(step)), step)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: TEST with `--filter FreeRunTests`
Expected: build errors such as `cannot find 'FreeRun' in scope` and `type 'StepMeasure' has no member 'open'`.

- [ ] **Step 3: Add the open measure and free run**

Replace `RunCore/Sources/RunCore/Models/StepMeasure.swift` with:

```swift
import Foundation

/// What ends a step: a duration, a distance, or the runner ending the workout (`open`, used
/// by free runs).
public enum StepMeasure: Codable, Equatable, Sendable {
    case time(seconds: Int)
    case distance(meters: Double)
    case open
}
```

`RunCore/Sources/RunCore/Models/FreeRun.swift`:

```swift
import Foundation

/// A run with no plan: one open run step that lasts until the runner ends it. A free run is
/// never part of the plan, so its record has no workout ID.
public enum FreeRun {
    public static let title = "Free run"

    public static func workout(on date: Date = Date()) -> Workout {
        Workout(date: date, kind: .easy, title: title, steps: [Step(kind: .run, measure: .open)])
    }
}
```

In `RunCore/Sources/RunCore/Engine/StepExpander.swift`, add this case at the end of the `switch step.measure` in `flatten(_:)`, after the `.distance` case:

```swift
        case .open:
            return FlatStep(
                sourceStepID: step.id,
                kind: step.kind,
                durationSeconds: nil,
                distanceMeters: nil,
                targetPaceSecondsPerMile: step.targetPaceSecondsPerMile
            )
```

- [ ] **Step 4: Handle `.open` everywhere else**

In `RunCore/Tests/RunCoreTests/PlanGeneratorTests.swift`, in `checkValid`, the `switch step.measure` gets a third case after the `.distance` line:

```swift
                    case .open: XCTFail("open step in a generated plan: \(context)")
```

In `Sources/RunPlan/Workout/WorkoutDetailView.swift`, in `measure(for:)`, add after the `.distance` case:

```swift
        case .open: amount = "Until you end it"
```

In `Sources/RunPlan/Plan/StepEditor.swift`, in the `switch step.measure` in `body`, add after the `.distance` case:

```swift
            case .open:
                Text("Until you end it").foregroundStyle(.secondary)
```

- [ ] **Step 5: Run the tests and build**

Run: TEST
Expected: all tests pass.

Run: BUILD
Expected: success.

- [ ] **Step 6: Commit**

```bash
git add RunCore/Sources/RunCore/Models/StepMeasure.swift RunCore/Sources/RunCore/Models/FreeRun.swift RunCore/Sources/RunCore/Engine/StepExpander.swift RunCore/Tests/RunCoreTests/FreeRunTests.swift RunCore/Tests/RunCoreTests/PlanGeneratorTests.swift Sources/RunPlan/Workout/WorkoutDetailView.swift Sources/RunPlan/Plan/StepEditor.swift
git commit -m "Add open steps and free runs"
```

---

### Task 7: Location service and permissions

**Goal:** `LocationService` wraps CoreLocation for outdoor runs, and `Info.plist` declares background location and the permission text.

**Files:**
- Create: `Sources/RunPlan/Services/LocationService.swift`
- Modify: `Info.plist`

**Acceptance Criteria:**
- [ ] `Info.plist` has `location` in `UIBackgroundModes` and both location usage descriptions
- [ ] `LocationService` publishes its authorization and newest fix, requests when-in-use permission, and starts and stops updates (fitness activity, best accuracy, background allowed)
- [ ] BUILD succeeds

**Verify:** BUILD → success; `grep -c location Info.plist` → at least 3

**Steps:**

- [ ] **Step 1: Update `Info.plist`**

In `Info.plist`, add `<string>location</string>` under `<string>audio</string>` in the `UIBackgroundModes` array, and add these keys after the array:

```xml
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>RunPlan uses your location during outdoor runs, including with the screen locked, to measure distance, pace and your route.</string>
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>RunPlan uses your location during outdoor runs, including with the screen locked, to measure distance, pace and your route.</string>
```

- [ ] **Step 2: Create `Sources/RunPlan/Services/LocationService.swift`**

```swift
import CoreLocation
import Observation
import RunCore

/// Wraps CoreLocation for outdoor runs: fitness activity type, best accuracy, and updates that
/// keep coming with the screen locked. Each fix is handed on as a plain `LocationSample`.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {

    private(set) var authorization: CLAuthorizationStatus
    /// True when Precise Location is off, so fixes are too coarse to measure a run.
    private(set) var isReducedAccuracy: Bool
    /// The newest fix, good or bad. The outdoor start sheet watches it to know when GPS is ready.
    private(set) var latest: LocationSample?
    /// Receives every fix while updates are running.
    @ObservationIgnored var onSample: ((LocationSample) -> Void)?

    private let manager: CLLocationManager
    @ObservationIgnored private var isUpdating = false

    override init() {
        let manager = CLLocationManager()
        self.manager = manager
        self.authorization = manager.authorizationStatus
        self.isReducedAccuracy = manager.accuracyAuthorization == .reducedAccuracy
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
    }

    var needsPermission: Bool { authorization == .notDetermined }
    var isAuthorized: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Starts updates. The start sheet only needs them in the foreground; a running workout asks
    /// for background updates too, so recording continues with the screen locked. Does nothing
    /// without permission, and is safe to call again (for example to add background updates).
    func start(inBackground: Bool) {
        guard isAuthorized else { return }
        if inBackground, !manager.allowsBackgroundLocationUpdates {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        guard !isUpdating else { return }
        manager.startUpdatingLocation()
        isUpdating = true
    }

    func stop() {
        // Always switch background updates off, even if updates already stopped because
        // permission was withdrawn mid-run.
        manager.allowsBackgroundLocationUpdates = false
        guard isUpdating else { return }
        manager.stopUpdatingLocation()
        isUpdating = false
        latest = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let reduced = manager.accuracyAuthorization == .reducedAccuracy
        Task { @MainActor in
            self.authorization = status
            self.isReducedAccuracy = reduced
            // CoreLocation stops delivering when permission is withdrawn, so a later start()
            // must not think updates are still running.
            if !self.isAuthorized {
                self.isUpdating = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let samples = locations.map {
            LocationSample(
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude,
                timestamp: $0.timestamp,
                horizontalAccuracy: $0.horizontalAccuracy
            )
        }
        Task { @MainActor in
            for sample in samples {
                self.latest = sample
                self.onSample?(sample)
            }
        }
    }
}
```

- [ ] **Step 3: Build**

Run: BUILD
Expected: success. Warnings about sending `self` across actors in the delegate methods are acceptable in Swift 5 language mode; errors are not.

- [ ] **Step 4: Commit**

```bash
git add Info.plist Sources/RunPlan/Services/LocationService.swift
git commit -m "Add location service and permission text"
```

---

### Task 8: Outdoor sessions

**Goal:** `WorkoutSessionModel` tracks outdoor runs: it feeds GPS fixes to an `OutdoorTracker`, ends distance steps on distance, speaks splits and pace cues, checkpoints the tracker, and stops GPS when the run ends.

**Files:**
- Modify: `Sources/RunPlan/Workout/WorkoutSessionModel.swift` (full replacement)
- Modify: `Sources/RunPlan/App/AppModel.swift`

**Acceptance Criteria:**
- [ ] Outdoor sessions start GPS, record fixes (not counting while paused), and stop GPS on finish
- [ ] A covered distance step advances the engine; splits and pace cues are spoken
- [ ] The checkpoint carries the tracker, and a resumed outdoor run restores it
- [ ] Skip forward and back restart a distance step's measurement; fixes trigger a refresh; the checkpoint is written off the main actor,
  in order on one serial queue, and the delete at finish waits for any write in flight
- [ ] Treadmill sessions are unchanged; BUILD succeeds

**Verify:** BUILD → success

**Steps:**

- [ ] **Step 1: Replace `Sources/RunPlan/Workout/WorkoutSessionModel.swift`**

```swift
import Foundation
import Observation
import UIKit
import RunCore

/// Owns a `WorkoutEngine` for one workout and wires it to cues, haptics, a UI refresh timer
/// and the on-disk checkpoint. Outdoors it also feeds GPS fixes to an `OutdoorTracker`, which
/// measures distance, ends distance steps and produces split and pace cues. The engine does
/// the timing; this only polls it.
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
    /// Outdoor only: distance, pace and route so far.
    private(set) var tracker: OutdoorTracker?
    /// Outdoor only: mile splits, filled in when the workout finishes.
    private(set) var splits: [Split] = []

    private let engine: WorkoutEngine
    private var scheduler = CueScheduler()
    private let audio = AudioCueService()
    private let haptics = HapticsService()
    private let store: JSONStore
    private let location: LocationService?
    private var uiTimer: Timer?
    private var lastCheckpointSave = Date.distantPast

    /// Checkpoint writes and the final delete run in order on one queue, so an older write can
    /// never land after a newer one, or after the finished workout's checkpoint is deleted.
    private static let checkpointQueue = DispatchQueue(label: "RunPlan.checkpoint", qos: .utility)

    init(workout: Workout, mode: RunMode, store: JSONStore, location: LocationService) {
        self.workout = workout
        self.mode = mode
        self.startedAt = Date()
        self.store = store
        self.engine = WorkoutEngine(planSteps: workout.steps)
        self.location = mode == .outdoor ? location : nil
        self.tracker = mode == .outdoor ? OutdoorTracker() : nil
    }

    /// Resumes a workout that was in progress when the app was killed. It comes back paused.
    init(resuming active: ActiveWorkout, store: JSONStore, location: LocationService) {
        self.workout = active.workout
        self.mode = active.mode
        self.startedAt = active.startedAt
        self.store = store
        self.engine = WorkoutEngine(steps: StepExpander.expand(active.workout.steps), restoring: active.checkpoint)
        self.location = active.mode == .outdoor ? location : nil
        self.tracker = active.mode == .outdoor ? (active.outdoor ?? OutdoorTracker()) : nil
    }

    var isPaused: Bool { snapshot?.state == .paused }
    /// Time actually run, excluding pauses; skip back does not shorten it.
    var durationSeconds: Int { Int((snapshot?.activeElapsed ?? 0).rounded()) }
    var distanceMeters: Double { tracker?.totalMeters ?? 0 }
    /// Hidden once GPS is lost, since the pace window does not age by itself.
    var currentPace: Int? { hasSignal() ? tracker?.currentPace : nil }
    var route: [RoutePoint] { tracker?.route ?? [] }

    /// False outdoors when no usable fix has arrived for a while. Distance holds until it returns.
    func hasSignal(now: Date = Date()) -> Bool {
        tracker?.hasSignal(now: now) ?? true
    }

    /// Distance left in the current distance step, outdoors.
    var stepMetersRemaining: Double? {
        guard let snapshot, let tracker else { return nil }
        return tracker.stepMetersRemaining(for: snapshot)
    }

    func begin() {
        audio.activate()
        engine.start()
        UIApplication.shared.isIdleTimerDisabled = true
        startLocation()
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
        tracker?.restartStep()
        refresh(forceCheckpoint: true)
    }

    func skipBack() {
        engine.skipBack()
        tracker?.restartStep()
        refresh(forceCheckpoint: true)
    }

    func endEarly() {
        engine.end()
        refresh()
    }

    /// Call when the app returns to the foreground so the screen catches up at once. Also
    /// restarts GPS in case location permission was turned off and on again during the run.
    func handleForeground() {
        if !isFinished {
            location?.start(inBackground: true)
        }
        refresh()
    }

    private func startLocation() {
        guard let location else { return }
        location.onSample = { [weak self] sample in
            self?.record(sample)
        }
        location.start(inBackground: true)
    }

    /// Records a fix and refreshes straight away, so splits and distance steps are handled
    /// promptly even if the screen refresh timer is slowed while the phone is locked.
    private func record(_ sample: LocationSample) {
        tracker?.record(sample, now: Date(), counting: engine.state == .running)
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

        if handleOutdoorEvents(for: snapshot) {
            // The distance step is covered: move on, then refresh for the new step.
            engine.advanceToNextStep()
            refresh(forceCheckpoint: true)
            return
        }

        self.snapshot = snapshot

        if snapshot.state == .finished {
            finish(elapsed: snapshot.activeElapsed)
        } else {
            saveCheckpoint(force: forceCheckpoint)
        }
    }

    /// Speaks split and pace cues. Returns true when the current distance step is complete.
    private func handleOutdoorEvents(for snapshot: WorkoutEngine.Snapshot) -> Bool {
        guard var tracker else { return false }
        var stepComplete = false
        for event in tracker.events(for: snapshot, now: Date()) {
            switch event {
            case .split(let split):
                audio.speak(CueText.splitAnnouncement(split))
            case .paceCue(let cue):
                audio.speak(CueText.paceCue(cue))
            case .stepDistanceReached:
                stepComplete = true
            }
        }
        self.tracker = tracker
        return stepComplete
    }

    private func saveCheckpoint(force: Bool) {
        let now = Date()
        guard force || now.timeIntervalSince(lastCheckpointSave) >= 5 else { return }
        lastCheckpointSave = now
        let active = ActiveWorkout(
            workout: workout,
            mode: mode,
            startedAt: startedAt,
            checkpoint: engine.checkpoint(now: now),
            outdoor: tracker
        )
        // A long run's route makes this about 1 MB, so encode and write it off the main actor.
        let store = self.store
        let file = Self.checkpointFile
        Self.checkpointQueue.async {
            try? store.save(active, as: file)
        }
    }

    private func finish(elapsed: TimeInterval) {
        isFinished = true
        uiTimer?.invalidate()
        uiTimer = nil
        UIApplication.shared.isIdleTimerDisabled = false
        if let tracker {
            splits = tracker.finalSplits(elapsed: elapsed)
        }
        location?.onSample = nil
        location?.stop()
        // Waits behind any write still in flight, so the deleted checkpoint stays deleted.
        let store = self.store
        let file = Self.checkpointFile
        Self.checkpointQueue.sync {
            store.delete(file)
        }
    }

    /// Call once the summary has been saved or discarded.
    func releaseAudio() {
        audio.deactivate()
    }
}
```

- [ ] **Step 2: Give the app model a location service**

In `Sources/RunPlan/App/AppModel.swift`:

1. After the line `    private let plans: PlanStore`, add:

```swift
    /// Shared by the outdoor start sheet and outdoor sessions.
    let location = LocationService()
```

2. In `start(_:mode:)`, change `WorkoutSessionModel(workout: workout, mode: mode, store: store)` to `WorkoutSessionModel(workout: workout, mode: mode, store: store, location: location)`.

3. In `resumePending()`, change `WorkoutSessionModel(resuming: active, store: store)` to `WorkoutSessionModel(resuming: active, store: store, location: location)`.

- [ ] **Step 3: Build**

Run: BUILD
Expected: success.

- [ ] **Step 4: Commit**

```bash
git add Sources/RunPlan/Workout/WorkoutSessionModel.swift Sources/RunPlan/App/AppModel.swift
git commit -m "Track outdoor runs in the workout session"
```

---

### Task 9: Outdoor start flow and free run

**Goal:** Start offers Treadmill or Outdoor; Outdoor asks for location, waits for a GPS fix, or explains and offers treadmill when location is off; the Plan screen gets a Free run button.

**Files:**
- Create: `Sources/RunPlan/Workout/OutdoorStartView.swift`, `Sources/RunPlan/Workout/StartRunFlow.swift`
- Modify: `Sources/RunPlan/Workout/WorkoutDetailView.swift`, `Sources/RunPlan/Plan/PlanView.swift`

**Acceptance Criteria:**
- [ ] Choosing Outdoor opens a sheet that requests permission when undecided, starts GPS, and enables Start only once a fix passes the filter
- [ ] With location denied, the sheet explains, links to Settings, and offers "Use treadmill instead"
- [ ] With Precise Location off, the sheet says to turn it on and offers Open Settings
- [ ] Start greys out again if the fix goes stale, and the sheet always offers "Use treadmill instead"
- [ ] The session starts only after the sheet has closed; Cancel stops GPS
- [ ] The Plan screen's toolbar has Free run with the same Treadmill or Outdoor choice
- [ ] BUILD succeeds

**Verify:** BUILD → success

**Steps:**

- [ ] **Step 1: Create `Sources/RunPlan/Workout/OutdoorStartView.swift`**

```swift
import SwiftUI
import RunCore

/// Before an outdoor run: asks for location permission, then waits for a usable GPS fix. If
/// location is off, explains why and offers treadmill mode instead.
struct OutdoorStartView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// Called with the chosen mode just before the sheet closes.
    let onChoose: (RunMode) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                if app.location.isDenied {
                    deniedContent
                } else {
                    waitingContent
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Outdoor run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        app.location.stop()
                        dismiss()
                    }
                }
            }
            .onAppear { prepareLocation() }
            .onChange(of: app.location.authorization) { _, _ in prepareLocation() }
        }
        .interactiveDismissDisabled()
    }

    private func hasFix(at now: Date) -> Bool {
        guard let latest = app.location.latest else { return false }
        return SampleFilter.accepts(latest, now: now)
    }

    /// Re-evaluated every second as well as on each fix, so a fix that goes stale after GPS was
    /// ready (stepping indoors, say) disables Start again.
    private var waitingContent: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let ready = hasFix(at: context.date)
            VStack(spacing: 16) {
                if ready {
                    Image(systemName: "location.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("GPS ready").font(.title2.bold())
                } else {
                    ProgressView().controlSize(.large)
                    Text("Waiting for GPS…").font(.title2.bold())
                    Text(accuracyText(at: context.date))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                Button {
                    choose(.outdoor)
                } label: {
                    Text("Start").font(.title3.bold()).frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!ready)
                if app.location.isReducedAccuracy {
                    Button("Open Settings") { openSettings() }
                }
                Button("Use treadmill instead") { choose(.treadmill) }
            }
        }
    }

    private func accuracyText(at now: Date) -> String {
        if app.location.isReducedAccuracy {
            return "Precise Location is off for RunPlan. Turn it on in Settings so distance and pace can be measured."
        }
        guard let latest = app.location.latest, latest.horizontalAccuracy >= 0 else {
            return "Head outside with a clear view of the sky."
        }
        if latest.horizontalAccuracy <= SampleFilter.maxAccuracyMeters {
            // Accurate enough but too old: CoreLocation often hands over a cached fix first.
            return "Waiting for a fresh fix…"
        }
        return "Accuracy \(Int(latest.horizontalAccuracy)) m. Ready at \(Int(SampleFilter.maxAccuracyMeters)) m."
    }

    private var deniedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Location is off for RunPlan").font(.title2.bold())
            Text("Outdoor runs need your location to measure distance and pace. Turn it on in Settings, or do this run in treadmill mode.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Settings") { openSettings() }
            Button {
                choose(.treadmill)
            } label: {
                Text("Use treadmill instead").frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func prepareLocation() {
        if app.location.needsPermission {
            app.location.requestPermission()
        } else {
            app.location.start(inBackground: false)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func choose(_ mode: RunMode) {
        // Re-check at the tap: the fix may have gone stale since the last refresh.
        if mode == .outdoor, !hasFix(at: Date()) {
            return
        }
        if mode == .treadmill {
            app.location.stop()
        }
        onChoose(mode)
        dismiss()
    }
}
```

- [ ] **Step 2: Create `Sources/RunPlan/Workout/StartRunFlow.swift`**

```swift
import SwiftUI
import RunCore

/// The Start flow shared by planned workouts and free runs: choose Treadmill or Outdoor, and for
/// Outdoor pass through the GPS sheet first. The session starts only once the sheet has closed,
/// so the full-screen workout never presents over a closing sheet.
struct StartRunFlow: ViewModifier {
    @Environment(AppModel.self) private var app
    @Binding var isChoosing: Bool
    /// Called at start time, so a free run gets the current date.
    let workout: () -> Workout

    @State private var showingOutdoor = false
    @State private var pendingMode: RunMode?

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Where are you running?", isPresented: $isChoosing, titleVisibility: .visible) {
                Button("Treadmill") { app.start(workout(), mode: .treadmill) }
                Button("Outdoor") { showingOutdoor = true }
            }
            .sheet(isPresented: $showingOutdoor, onDismiss: startPending) {
                OutdoorStartView { mode in pendingMode = mode }
            }
    }

    private func startPending() {
        guard let mode = pendingMode else { return }
        pendingMode = nil
        app.start(workout(), mode: mode)
    }
}

extension View {
    func startRunFlow(isChoosing: Binding<Bool>, workout: @escaping () -> Workout) -> some View {
        modifier(StartRunFlow(isChoosing: isChoosing, workout: workout))
    }
}
```

- [ ] **Step 3: Use it on the workout detail screen**

In `Sources/RunPlan/Workout/WorkoutDetailView.swift`, replace:

```swift
        .confirmationDialog("Where are you running?", isPresented: $choosingMode, titleVisibility: .visible) {
            Button("Treadmill") { app.start(workout, mode: .treadmill) }
            Button("Outdoor (coming with GPS tracking)") {}.disabled(true)
        }
```

with:

```swift
        .startRunFlow(isChoosing: $choosingMode) { workout }
```

- [ ] **Step 4: Add Free run to the Plan screen**

In `Sources/RunPlan/Plan/PlanView.swift`:

1. Add a state property under `@Environment(AppModel.self) private var app`:

```swift
    @State private var choosingFreeRun = false
```

2. In the existing `.toolbar { ... }` (added in Task 5a), add this item after the Change plan item:

```swift
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Free run") { choosingFreeRun = true }
                }
```

3. Directly after the `.sheet(isPresented: $changingPlan) { ... }` modifier's closing brace, add:

```swift
            .startRunFlow(isChoosing: $choosingFreeRun) { FreeRun.workout() }
```

- [ ] **Step 5: Build**

Run: BUILD
Expected: success.

- [ ] **Step 6: Commit**

```bash
git add Sources/RunPlan/Workout/OutdoorStartView.swift Sources/RunPlan/Workout/StartRunFlow.swift Sources/RunPlan/Workout/WorkoutDetailView.swift Sources/RunPlan/Plan/PlanView.swift
git commit -m "Add the outdoor start flow and free run"
```

---

### Task 10: Outdoor live screen

**Goal:** Outdoors the live screen adds distance and current pace, shows distance left on distance steps, and warns when GPS is lost; free runs show elapsed time instead of planned progress.

**Files:**
- Modify: `Sources/RunPlan/Workout/LiveWorkoutView.swift` (full replacement)

**Acceptance Criteria:**
- [ ] Outdoors: miles so far and pace /mi (or "--:--"), and a yellow "GPS signal lost" banner when there's no signal
- [ ] A distance step outdoors shows the distance left; a timed step counts down; an open step counts up
- [ ] With nothing planned (free run) the progress bar is replaced by elapsed time, and a single-step run hides the step counter and next-step line
- [ ] Skip forward is disabled on the last step, so ending a run always goes through Stop and its confirmation
- [ ] The controls stay pinned at the bottom with the rest scrolling, the GPS banner fits one line, and each
  control has a VoiceOver label
- [ ] Treadmill layout unchanged apart from that; BUILD succeeds

**Verify:** BUILD → success

**Steps:**

- [ ] **Step 1: Replace `Sources/RunPlan/Workout/LiveWorkoutView.swift`**

```swift
import SwiftUI
import RunCore

/// Large, glanceable and high contrast: readable at arm's length on a treadmill console or
/// mid-stride outdoors. Outdoors it adds distance, pace and a GPS warning.
struct LiveWorkoutView: View {
    let session: WorkoutSessionModel

    @State private var confirmingEnd = false

    private var isOutdoor: Bool { session.mode == .outdoor }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let snapshot = session.snapshot {
                // The controls stay pinned at the bottom; everything above scrolls if a small
                // screen or large text would otherwise push them off.
                VStack(spacing: 12) {
                    ScrollView {
                        VStack(spacing: isOutdoor ? 14 : 20) {
                            if snapshot.stepCount > 1 {
                                Text("Step \(snapshot.stepIndex + 1) of \(snapshot.stepCount)")
                                    .font(.headline)
                                    .foregroundStyle(.gray)
                            }

                            Text(CueText.displayKind(snapshot.step.kind).uppercased())
                                .font(.system(size: isOutdoor ? 52 : 64, weight: .heavy))
                                .foregroundStyle(color(for: snapshot.step.kind))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)

                            Text(CueText.target(for: snapshot.step, mode: session.mode) ?? "No target")
                                .font(.system(size: isOutdoor ? 56 : 72, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)

                            Text(clock(for: snapshot))
                                .font(.system(size: isOutdoor ? 72 : 88, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)

                            if isOutdoor {
                                outdoorStats
                            }

                            progress(snapshot)

                            if snapshot.stepCount > 1 {
                                Text(nextText(snapshot))
                                    .font(.title3)
                                    .foregroundStyle(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .scrollBounceBehavior(.basedOnSize)

                    controls(snapshot)
                }
                .padding()
            }
        }
        .confirmationDialog("End this workout?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End workout", role: .destructive) { session.endEarly() }
        }
    }

    /// Re-checked every second: while paused nothing else redraws the screen, and the signal can
    /// still be lost.
    private var outdoorStats: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            outdoorStatsContent(now: context.date)
        }
    }

    private func outdoorStatsContent(now: Date) -> some View {
        VStack(spacing: 8) {
            if !session.hasSignal(now: now) {
                Label("GPS signal lost. Distance is paused.", systemImage: "location.slash")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.yellow, in: Capsule())
            }
            HStack(spacing: 40) {
                stat(String(format: "%.2f", Pace.miles(fromMeters: session.distanceMeters)), label: "miles")
                stat(session.currentPace.map { Pace.clock($0) } ?? "--:--", label: "pace /mi")
            }
        }
    }

    private func stat(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 40, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }

    @ViewBuilder
    private func progress(_ snapshot: WorkoutEngine.Snapshot) -> some View {
        if snapshot.totalPlanned > 0 {
            ProgressView(value: min(snapshot.totalElapsed, snapshot.totalPlanned), total: snapshot.totalPlanned)
                .tint(.white)

            Text("\(Pace.clock(Int(snapshot.totalElapsed))) of \(Pace.clock(Int(snapshot.totalPlanned)))")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(.gray)
        } else {
            Text("\(Pace.clock(Int(snapshot.activeElapsed))) elapsed")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(.gray)
        }
    }

    private func controls(_ snapshot: WorkoutEngine.Snapshot) -> some View {
        HStack(spacing: 24) {
            controlButton("backward.end.fill", label: "Back") { session.skipBack() }
            controlButton(session.isPaused ? "play.fill" : "pause.fill", label: session.isPaused ? "Resume" : "Pause") {
                if session.isPaused { session.resume() } else { session.pause() }
            }
            // On the last step, skipping forward would end the run without asking; Stop asks.
            controlButton("forward.end.fill", label: "Skip", enabled: snapshot.nextStep != nil) { session.skipForward() }
            controlButton("stop.fill", label: "End workout") { confirmingEnd = true }
        }
    }

    private func controlButton(_ systemName: String, label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 30))
                .frame(width: 72, height: 72)
                .background(Color.white.opacity(0.15), in: Circle())
                .foregroundStyle(.white)
        }
        .accessibilityLabel(label)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    /// Countdown for a timed step, distance left for a distance step outdoors, otherwise
    /// count-up.
    private func clock(for snapshot: WorkoutEngine.Snapshot) -> String {
        if let remaining = snapshot.remainingInStep {
            return Pace.clock(Int(remaining.rounded(.up)))
        }
        if let meters = session.stepMetersRemaining {
            return String(format: "%.2f mi", Pace.miles(fromMeters: meters))
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

- [ ] **Step 2: Build**

Run: BUILD
Expected: success.

- [ ] **Step 3: Commit**

```bash
git add Sources/RunPlan/Workout/LiveWorkoutView.swift
git commit -m "Show distance, pace and GPS state on the live screen"
```

---

### Task 11: Outdoor summary

**Goal:** Outdoors the summary shows measured distance, average pace, mile splits and a route map, and saves them in the record; free runs are saved without a workout ID.

**Files:**
- Modify: `Sources/RunPlan/Workout/SummaryView.swift` (full replacement)

**Acceptance Criteria:**
- [ ] Outdoors: distance from GPS (no text field), splits ("Mile n" and "Last x.xx mi"), and the route drawn on a map when there are two or more points
- [ ] Treadmill: unchanged (typed distance)
- [ ] The record carries splits and route; its `workoutID` is nil unless the workout is in the plan
- [ ] BUILD succeeds

**Verify:** BUILD → success

**Steps:**

- [ ] **Step 1: Replace `Sources/RunPlan/Workout/SummaryView.swift`**

```swift
import SwiftUI
import MapKit
// SwiftUI's Map lives in this cross-import overlay; xtool's build does not pull it in on its own.
import _MapKit_SwiftUI
import RunCore

/// One screen, every field skippable. Outdoors the distance is measured and the splits and
/// route are shown; on a treadmill the distance is typed in.
struct SummaryView: View {
    @Environment(AppModel.self) private var app
    let session: WorkoutSessionModel

    @State private var distanceText = ""
    @State private var effort = 0
    @State private var notes = ""

    private var isOutdoor: Bool { session.mode == .outdoor }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    LabeledContent("Time", value: Pace.clock(session.durationSeconds))
                    if isOutdoor {
                        LabeledContent("Distance", value: String(format: "%.2f mi", Pace.miles(fromMeters: distanceMeters)))
                    }
                    if let pace = Pace.secondsPerMile(distanceMeters: distanceMeters, durationSeconds: session.durationSeconds) {
                        LabeledContent("Average pace", value: "\(Pace.clock(pace)) /mi")
                    }
                }

                if isOutdoor {
                    if !session.splits.isEmpty {
                        Section("Splits") {
                            ForEach(session.splits, id: \.index) { split in
                                LabeledContent(splitLabel(split), value: Pace.clock(split.durationSeconds))
                            }
                        }
                    }
                    if session.route.count > 1 {
                        Section("Route") {
                            // Zoom only, so a drag on the map scrolls the form instead of panning.
                            Map(initialPosition: .automatic, interactionModes: [.zoom]) {
                                MapPolyline(coordinates: session.route.map {
                                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                                })
                                .stroke(.orange, lineWidth: 4)
                            }
                            .frame(height: 240)
                            .listRowInsets(EdgeInsets())
                        }
                    }
                } else {
                    Section("Distance (miles, from the treadmill)") {
                        TextField("Optional", text: $distanceText)
                            .keyboardType(.decimalPad)
                    }
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
        if isOutdoor { return session.distanceMeters }
        let normalized = distanceText.replacingOccurrences(of: ",", with: ".")
        guard let miles = Double(normalized), miles > 0 else { return 0 }
        return Pace.meters(fromMiles: miles)
    }

    private func splitLabel(_ split: Split) -> String {
        guard split.distanceMeters < Pace.metersPerMile - 1 else { return "Mile \(split.index)" }
        return String(format: "Last %.2f mi", Pace.miles(fromMeters: split.distanceMeters))
    }

    private var record: RunRecord {
        RunRecord(
            // A free run is never in the plan, so it gets no workout ID.
            workoutID: app.plan?.workout(id: session.workout.id) == nil ? nil : session.workout.id,
            title: session.workout.title,
            mode: session.mode,
            startedAt: session.startedAt,
            durationSeconds: session.durationSeconds,
            distanceMeters: distanceMeters,
            perceivedEffort: effort == 0 ? nil : effort,
            notes: notes,
            splits: session.splits,
            route: session.route
        )
    }
}
```

- [ ] **Step 2: Build**

Run: BUILD
Expected: success.

- [ ] **Step 3: Commit**

```bash
git add Sources/RunPlan/Workout/SummaryView.swift
git commit -m "Show splits and the route map in the outdoor summary"
```

---

### Task 12: Docs, final verification and outdoor check

**Goal:** Record the stage 4 decisions in the spec, add the outdoor checklist to the README, verify end to end, and install.

**Files:**
- Modify: `README.md`, `docs/superpowers/specs/2026-10-12-runplan-design.md`

**Acceptance Criteria:**
- [ ] The spec notes that auto-pause moved to stage 5, and how free runs and the GPS numbers work
- [ ] The README has an outdoor on-device checklist
- [ ] TEST passes in full and BUILD succeeds
- [ ] The app is installed on the phone and the checklist is handed to the user

**Verify:** TEST → `Executed N tests, with 0 failures`; BUILD → success

**Steps:**

- [ ] **Step 1: Add an implementation note to the spec**

In `docs/superpowers/specs/2026-10-12-runplan-design.md`, add this paragraph directly after the line `planned workout) is available from the Plan screen in either mode.`:

```markdown
Implementation note (stage 4, 2026-10-18): auto-pause moves to stage 5 with the Settings screen
that switches it on. A free run is one step with `StepMeasure.open`, which lasts until the runner
ends it. Fixes older than 5 s or less accurate than 20 m are dropped, jumps faster than 10 m/s are
ignored, the signal warning shows after 10 s without a usable fix, and a partial final split under
16 m is dropped. The exact rules are in `docs/superpowers/plans/2026-10-18-outdoor-gps.md`.
Changing the plan (onboarding prefilled from the current plan, then a confirmation) was added in
stage 4 at the user's request, ahead of the stage 5 Settings screen. Notes for stage 5: the pace
cue's 30 s timer restarts on one in-tolerance reading, so judge it outdoors and add a short grace
period if cues rarely fire; and `RunStore.all()` decodes every route, so the History screen
should load routes only when a run is opened.
```

- [ ] **Step 2: Add the outdoor checklist to the README**

Append to `README.md`:

```markdown

## On-device checklist (outdoor GPS)

- Start a workout outdoors for the first time: RunPlan asks for location, then waits for GPS and
  enables Start once it is ready.
- With location turned off in Settings: the start sheet explains and offers treadmill mode.
- Run with the phone locked: distance and the route keep recording, and cues keep playing.
- A planned distance step (the time trial) ends by itself when its distance is covered.
- Each mile is announced with its split, and running well off a target pace gives a pace cue.
- Walk somewhere with no signal for over 10 s: the live screen shows the GPS warning and distance
  holds.
- Force-quit mid-run and reopen: resuming keeps the distance and route so far.
- Save the summary: it shows distance, splits and the route map, and the run appears in Runs.
- Plan tab > Free run > Outdoor: runs until ended, with no planned workout marked done.
```

- [ ] **Step 3: Run the full verification**

Run: TEST
Expected: every test passes.

Run: BUILD
Expected: success.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/superpowers/specs/2026-10-12-runplan-design.md
git commit -m "Document outdoor GPS and its on-device checks"
```

- [ ] **Step 5: Install on the phone**

Follow README "Commands": make sure `tools/muxshim.py` is running in WSL, then run `xtool dev` from the repo root. Hand the outdoor checklist to the user; it needs a real run outside.
