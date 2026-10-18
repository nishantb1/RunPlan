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
    var durationSeconds: Int { Int((snapshot?.totalElapsed ?? 0).rounded()) }
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

    /// Call when the app returns to the foreground so the screen catches up at once.
    func handleForeground() {
        refresh()
    }

    private func startLocation() {
        guard let location else { return }
        location.onSample = { [weak self] sample in
            self?.record(sample)
        }
        location.start()
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
            finish(elapsed: snapshot.totalElapsed)
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
        Task.detached(priority: .utility) {
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
        store.delete(Self.checkpointFile)
    }

    /// Call once the summary has been saved or discarded.
    func releaseAudio() {
        audio.deactivate()
    }
}
