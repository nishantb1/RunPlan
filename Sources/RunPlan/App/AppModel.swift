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

    /// Saves the finished session as a run, marks its planned workout done, and closes it. If the
    /// run cannot be written, the session stays open so Save can be tried again.
    func save(_ record: RunRecord) {
        do {
            try runs.save(record)
        } catch {
            return
        }
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
