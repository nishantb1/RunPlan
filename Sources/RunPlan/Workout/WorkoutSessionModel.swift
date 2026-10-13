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
