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
