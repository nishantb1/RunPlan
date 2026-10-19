# RunPlan design

Date: 2026-10-12
Status: design approved in conversation, awaiting spec review

## Purpose

RunPlan is a personal iOS running app in the style of Runna: it builds a training plan from a
goal, guides each workout with spoken cues, records outdoor runs with GPS, and shows history and
progress. It is built for one person, sideloaded with xtool from a Windows PC, and has no server.

It is modelled on Runna's publicly visible behaviour. No Runna code, artwork, text or branding is
used, and the plan logic is written from standard training principles.

## Constraints

- **Platform:** iPhone only, iOS 17+, SwiftUI.
- **Build:** xtool on Windows via WSL, per https://xtool.sh/documentation/xtool/installation-linux.
  The project is a Swift package with an `xtool.yml`, not an Xcode project.
- **Signing:** free Apple ID with xtool's password login. Installs expire after 7 days and are
  renewed by running `xtool dev` again. At most 3 sideloaded apps at once.
- **Entitlements:** none. Location, background audio and background location need only
  `Info.plist` keys, which work with a free account. Anything needing an entitlement (HealthKit)
  is out of scope.
- **Dependencies:** no third-party packages. Foundation, SwiftUI, AVFoundation, CoreLocation,
  MapKit and Swift Charts only.
- **Persistence:** JSON files in the app's Documents directory. SwiftData is avoided because its
  macros are a build risk when cross-compiling from Linux, and JSON is testable off-device.
- **Offline:** everything works with no network. Map tiles are the only thing that needs data.

## Project layout

Repo: `C:\Users\bobba\Documents\RunPlan`. PaceKeeper (`Documents\Running App`) is left untouched;
its `TimerEngine.swift` and `TimerEngineTests.swift` are copied in as the starting point for the
workout engine.

```
Package.swift
xtool.yml                 bundleID, infoPath, iconPath
Info.plist                extra keys only (see below)
Resources/AppIcon.png
Sources/RunCore/          no SwiftUI, UIKit, CoreLocation or AVFoundation imports
  Models/                 Plan, Week, Workout, Step, RunRecord, Profile
  Planning/               PlanGenerator, PaceCalculator, plan templates
  Engine/                 StepExpander, WorkoutEngine
  Tracking/               DistanceAccumulator, PaceSmoother
  Stats/                  WeeklyStats, PlanProgress
  Storage/                JSONStore
Sources/RunPlan/          the app
  App/                    entry point, root tabs
  Onboarding/
  Plan/
  Workout/                live screen, summary
  History/
  Progress/
  Services/               LocationService, AudioCueService, HapticsService
Tests/RunCoreTests/
```

Implementation note (2026-10-12): `RunCore` is built as a nested package at `RunCore/` with its own
`Package.swift`, not as a second target of the root package, because `swift test` on Linux would
otherwise try to compile the SwiftUI target. The app icon was added during stage 3 (`Resources/AppIcon.png`, drawn by `tools/make_icon.py`).

`RunCore` is the only module with unit tests. It builds and tests on Linux with `swift test`, so
its logic is verified without a phone. Conventions carry over from PaceKeeper: MVVM, `@Observable`,
value types, one type per file, no force unwrapping outside tests.

`Info.plist` adds: `CFBundleDisplayName`, `UIBackgroundModes` (`audio`, `location`),
`NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`.

## Data model

```
Profile
  goal: Goal                 distance (.fiveK | .tenK), targetSeconds: Int? (nil = just finish)
  fitness: Fitness           .newRunner | .runsFiveMinutes | .runsTwentyMinutes
                             | .recentRace(distance, seconds)
  daysPerWeek: Int           2...5
  runDays: [Weekday]
  planWeeks: Int             6...16
  startDate: Date
  units: .miles              fixed in v1

Plan
  profile: Profile
  weeks: [Week]

Week
  number: Int
  kind: .build | .cutback | .taper
  workouts: [Workout]

Workout
  id: UUID
  date: Date
  kind: .walkRun | .easy | .intervals | .tempo | .longRun | .timeTrial
  title: String
  steps: [Step]
  recordID: UUID?            set when completed

Step
  kind: .warmup | .run | .walk | .recovery | .cooldown
  measure: .time(seconds) | .distance(meters)
  targetPaceSecondsPerMile: Int?     nil = no target (walks, open efforts)
  repeatGroup: Int?
  repeatCount: Int?

RunRecord
  id: UUID
  workoutID: UUID?           nil for a free run
  mode: .treadmill | .outdoor
  startedAt: Date
  durationSeconds: Int
  distanceMeters: Double
  perceivedEffort: Int?      1...5
  notes: String
  splits: [Split]            per mile
  route: [RoutePoint]        outdoor only; lat, lon, timestamp
```

Targets are stored once as pace (seconds per mile). Treadmill mode displays the same target
converted to mph, rounded to 0.1.

Storage is three files: `profile.json`, `plan.json`, and `records/<id>.json` per run, so a long
history never rewrites one large file.

Implementation note (stage 3, 2026-10-18): the profile is stored inside `plan.json` rather than
in its own `profile.json`, since a plan is always generated from exactly one profile.
`Profile.daysPerWeek` is derived from `runDays`, and the fixed `units` field is omitted until
kilometres are supported. The generator's exact numbers (walk-run ladder, session lengths, caps)
are in `docs/superpowers/plans/2026-10-18-plan-generation.md`.

## Plan generator

`PlanGenerator.generate(profile) -> Plan` is a pure, deterministic function.

1. **Paces.** `PaceCalculator` derives easy, tempo, interval and goal pace from the goal time, or
   from the recent race time if the goal is "just finish". A new runner with no times gets
   conservative fixed defaults and no pace targets on walk-run steps.
2. **Phases.** Runners who cannot yet run 20 minutes start with a walk-run phase that lengthens the
   run intervals until they reach 20 to 30 minutes continuous. Everyone then follows build weeks.
3. **Weekly shape.** Per week: one long run, at most one quality session (intervals or tempo,
   alternating), and the remaining days easy. With 2 days per week there is one quality or
   walk-run session and one long run.
4. **Progression.** Weekly volume rises by no more than about 10 percent. Every fourth week is a
   cutback at about 75 percent. The final week is a taper ending in a goal-distance time trial.
5. **Safety checks.** If the goal time implies a pace faster than the fitness level can plausibly
   reach in the chosen weeks, onboarding warns and offers a longer plan or "just finish".

Workouts stay editable after generation: steps, paces and dates can be changed in the Plan screen.
Regenerating the plan keeps completed runs in history.

## Workout engine

`WorkoutEngine` extends PaceKeeper's wall-clock design: it stores the start timestamp and derives
the current step from elapsed time on every tick and on every return to the foreground. A UI timer
only refreshes the display.

- Repeat groups are expanded to a flat step queue at start.
- **Time steps** advance on elapsed time in both modes.
- **Distance steps** advance on GPS distance in outdoor mode. In treadmill mode they are open
  ended and advanced manually, as in PaceKeeper.
- Controls: pause, resume, skip forward, skip back, end early. Outdoor mode has optional
  auto-pause when movement stops.
- Cues: spoken announcement of each step and its target, 3-2-1 beeps before each change, and a
  haptic at each change. Audio uses the playback category with ducking so cues play over music.
- Outdoor mode adds a spoken split at each mile and a pace cue when the smoothed pace is more than
  15 seconds per mile off target for 30 seconds.

## GPS tracking

`LocationService` wraps CoreLocation with background updates enabled and fitness activity type.
`RunCore` receives plain location samples, so the filtering is unit tested:

- Samples with horizontal accuracy worse than 20 m, or older than 5 s, are dropped.
- `DistanceAccumulator` sums distance between accepted samples and ignores jumps that imply
  an impossible speed.
- `PaceSmoother` reports pace over a rolling 15 second window.

The route is stored with the record and drawn on a MapKit map in the run summary. A free run (no
planned workout) is available from the Plan screen in either mode.

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

Implementation note (stage 5, 2026-10-18): settings live in `settings.json` and a workout reads
them when it starts; voice cues off keeps the countdown beeps and stops lowering music.
Auto-pause (outdoors, off by default) pauses after speed over the last 6 s falls below 0.5 m/s
and resumes above 1.2 m/s once clear of GPS accuracy from where the runner stopped; a manual pause is never resumed automatically. Routes are stored in `routes/<id>.json`, so History
lists runs without loading them; older records keep their route inside and still show it. The
chart colour is #C85A12 (light) and #D86A24 (dark), validated for lightness, chroma and contrast.
Still deferred: a grace period for the pace cue (waiting on an outdoor run), writing the route to
the crash checkpoint less often, and drawing the route across a pause.

Implementation note (v1 polish, 2026-10-18): older records' routes move to their own files at
launch, and saving a listed record never drops one. Auto-pause waits until the runner has set
off from the most accurate early fix, so it never pauses while GPS settles at the start. The
crash checkpoint keeps its route in `active-route.json`, written after the rest and only when
the route has grown (about every 30 s, or 5 s on pauses, skips and step changes); the rest is still written every
5 s. Each pause, and a restore after a crash, breaks the route: the map draws no line across it
and ground covered while paused is no longer counted, even with no GPS fix. Still deferred: a
grace period for the pace cue (waiting on an outdoor run).

## Screens

1. **Onboarding:** goal, fitness, days and run days, plan length, start date, then a preview of the
   generated plan before saving.
2. **Plan:** today's workout at the top, then weeks with completion state. Tapping a workout shows
   its steps, an Edit button and Start.
3. **Start sheet:** choose Treadmill or Outdoor. Outdoor waits for a GPS fix before starting.
4. **Live workout:** dark, high contrast. Step kind and target dominate; below them time or
   distance left, overall progress, and the next step. Outdoor mode adds current pace and distance.
5. **Summary:** distance (typed in for treadmill, measured for outdoor), time, average pace,
   splits, map for outdoor, effort 1 to 5, note. Every input is skippable.
6. **History:** list of runs, newest first, each opening its summary.
7. **Progress:** weekly distance bars, average pace trend, plan completion, longest run.
8. **Settings:** keep screen awake, auto-pause, voice cues on or off, regenerate plan, reset.

## Error handling

- **Location denied or unavailable:** outdoor mode explains why and offers treadmill mode.
- **GPS lost mid-run:** time keeps running, distance holds, and the live screen shows a signal
  warning. Distance steps can be advanced manually.
- **App killed mid-workout:** engine state is checkpointed to disk every few seconds. On next
  launch the app offers to resume or save what was recorded.
- **Corrupt or missing JSON:** the bad file is renamed aside and the app starts clean for that
  file, never crashing on launch.

## Testing

Unit tests in `RunCoreTests`, run in WSL with `swift test`:

- Plan generator: valid plan for every combination of goal, fitness, days (2 to 5) and length
  (6 to 16 weeks); progression and cutback rules hold; no week exceeds the day count; the plan
  ends in a time trial.
- Pace calculator: known input times give expected paces; pace to mph conversion.
- Workout engine: PaceKeeper's existing cases, plus distance steps in both modes.
- Tracking: filtering, distance accumulation and pace smoothing against recorded sample sets.
- Stats and storage: weekly totals, round-trip encoding, corrupt-file recovery.

On-device checks that only the user can make: GPS accuracy outdoors, cues over music, behaviour
with the screen locked, and resume after the app is killed. Each build stage lists its checks.

## Build stages

Each stage ends with an installable build.

1. **Toolchain.** WSL with Ubuntu, Swift 6.4, usbmuxd, USB passthrough with usbipd, Xcode 27
   `Xcode.xip`, xtool, `xtool setup`, then `xtool new` and `xtool dev` to put an empty app on the
   phone. Fallbacks, in order: the iTunes relay from xtool issue 19 if `muxError` appears; building
   the app with xtool and installing the `.ipa` with a Windows sideloading tool. If building on
   `/mnt/c` is unreliable, builds run from a synced copy inside the WSL filesystem.
2. **Guided workouts, treadmill mode.** Models, storage, workout engine, cues, live screen and
   summary, with one hand-written sample workout.
3. **Plan generation.** Pace calculator, generator, onboarding, Plan screen and editing.
4. **Outdoor GPS.** Location service, tracking maths, outdoor live screen, route map, free run.
5. **History and progress.** Run list, stats and charts, settings.

## Out of scope for v1

Accounts, sync and backup, Apple Watch, Apple Health, Strava or other integrations, reminders and
notifications, half and full marathon plans, kilometres, social features, iPad layout.
