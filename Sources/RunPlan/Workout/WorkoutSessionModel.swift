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

    let id = UUID()
    let workout: Workout
    let mode: RunMode
    let startedAt: Date

    private(set) var snapshot: WorkoutEngine.Snapshot?
    private(set) var isFinished = false
    /// True once the runner ended the workout before its last step finished.
    private(set) var endedEarly = false
    /// Outdoor only: distance, pace and route so far.
    private(set) var tracker: OutdoorTracker?
    /// Outdoor only: mile splits, filled in when the workout finishes.
    private(set) var splits: [Split] = []

    private let engine: WorkoutEngine
    private var scheduler = CueScheduler()
    private let audio = AudioCueService()
    private let haptics = HapticsService()
    private let checkpoints: ActiveWorkoutStore
    private let location: LocationService?
    private let settings: AppSettings
    /// Outdoors with auto-pause on only.
    private var autoPause: AutoPauseDetector?
    private var uiTimer: Timer?
    private var lastCheckpointSave = Date.distantPast
    private var lastRouteSave = Date.distantPast
    /// Points in the route when it was last written; nil until the first write.
    private var savedRouteCount: Int?

    /// Checkpoint writes and the final delete run in order on one queue, so an older write can
    /// never land after a newer one, or after the finished workout's checkpoint is deleted.
    private static let checkpointQueue = DispatchQueue(label: "RunPlan.checkpoint", qos: .utility)

    init(workout: Workout, mode: RunMode, store: JSONStore, location: LocationService, settings: AppSettings) {
        self.workout = workout
        self.mode = mode
        self.startedAt = Date()
        self.checkpoints = ActiveWorkoutStore(store: store)
        self.engine = WorkoutEngine(planSteps: workout.steps(for: mode))
        self.location = mode == .outdoor ? location : nil
        self.tracker = mode == .outdoor ? OutdoorTracker() : nil
        self.settings = settings
        self.autoPause = mode == .outdoor && settings.autoPause ? AutoPauseDetector() : nil
    }

    /// Resumes a workout that was in progress when the app was killed. It comes back paused.
    init(resuming active: ActiveWorkout, store: JSONStore, location: LocationService, settings: AppSettings) {
        self.workout = active.workout
        self.mode = active.mode
        self.startedAt = active.startedAt
        self.checkpoints = ActiveWorkoutStore(store: store)
        self.engine = WorkoutEngine(steps: StepExpander.expand(active.workout.steps(for: active.mode)), restoring: active.checkpoint)
        self.location = active.mode == .outdoor ? location : nil
        if active.mode == .outdoor {
            // The runner may have moved since the crash, so the route breaks here.
            var tracker = active.outdoor ?? OutdoorTracker()
            tracker.breakRoute()
            self.tracker = tracker
        } else {
            self.tracker = nil
        }
        self.settings = settings
        self.autoPause = active.mode == .outdoor && settings.autoPause ? AutoPauseDetector() : nil
    }

    var isPaused: Bool { snapshot?.state == .paused }
    var isAutoPaused: Bool { autoPause?.isAutoPaused ?? false }
    /// Time actually run, excluding pauses; skip back does not shorten it.
    var durationSeconds: Int { Int((snapshot?.activeElapsed ?? 0).rounded()) }
    var distanceMeters: Double { tracker?.totalMeters ?? 0 }
    /// Hidden once GPS is lost, since the pace window does not age by itself.
    var currentPace: Int? { hasSignal() ? tracker?.currentPace : nil }
    var route: [RoutePoint] { tracker?.route ?? [] }
    /// Outdoor only: time and distance during run steps, for pace suggestions.
    var runSeconds: Int? { tracker?.runSeconds }
    var runMeters: Double? { tracker?.runMeters }

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
        audio.activate(duckingOthers: settings.voiceCues)
        engine.start()
        UIApplication.shared.isIdleTimerDisabled = settings.keepScreenAwake
        startLocation()
        refresh()
        startUITimer()
    }

    func pause() {
        autoPause?.manualOverride()
        engine.pause()
        tracker?.breakRoute()
        refresh(forceCheckpoint: true)
    }

    func resume() {
        autoPause?.manualOverride()
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
        endedEarly = true
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
            tracker?.breakRoute()
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
                speak(CueText.announcement(for: step, mode: mode))
                haptics.stepTransition()
            case .countdownBeep:
                audio.playCountdownBeep()
            case .finished:
                speak("Workout complete.")
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
                speak(CueText.splitAnnouncement(split))
            case .paceCue(let cue):
                speak(CueText.paceCue(cue))
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
        // The route (about 1 MB on a long run) is written only when it has grown: every 30 s, or
        // every 5 s on pauses, skips and auto-pauses. See `ActiveWorkoutStore`.
        let routeCount = tracker?.route.count
        let includingRoute = routeCount != nil && routeCount != savedRouteCount
            && now.timeIntervalSince(lastRouteSave) >= (force ? 5 : 30)
        if includingRoute {
            lastRouteSave = now
            savedRouteCount = routeCount
        }
        let active = ActiveWorkout(
            workout: workout,
            mode: mode,
            startedAt: startedAt,
            checkpoint: engine.checkpoint(now: now),
            outdoor: tracker
        )
        // Encode and write off the main actor.
        let checkpoints = self.checkpoints
        Self.checkpointQueue.async {
            try? checkpoints.save(active, includingRoute: includingRoute)
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
        let checkpoints = self.checkpoints
        Self.checkpointQueue.sync {
            checkpoints.delete()
        }
    }

    /// Call once the summary has been saved or discarded.
    func releaseAudio() {
        audio.deactivate()
    }
}
