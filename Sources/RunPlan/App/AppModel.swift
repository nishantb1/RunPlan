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
    private let settingsStore: SettingsStore
    private let checkpoints: ActiveWorkoutStore
    /// Shared by the outdoor start sheet and outdoor sessions.
    let location = LocationService()

    private(set) var records: [RunRecord] = []
    /// nil until onboarding has created one.
    private(set) var plan: Plan?
    /// Read by each workout when it starts.
    private(set) var settings: AppSettings

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
        settingsStore = SettingsStore(store: store)
        checkpoints = ActiveWorkoutStore(store: store)
        settings = settingsStore.load()
        // Runs saved before routes had their own files: move any route still inside one.
        runs.moveEmbeddedRoutes()
        records = runs.all()
        plan = plans.load()
        pendingResume = checkpoints.load()
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

    /// A change to the plan's run paces that recent runs call for, if any.
    var paceSuggestion: PaceSuggestion? {
        plan.flatMap { PaceInsight.suggestion(for: $0, records: records) }
    }

    func acceptPaceSuggestion(_ suggestion: PaceSuggestion) {
        plan?.applyPaceChange(suggestion.change, at: Date())
        persistPlan()
    }

    func dismissPaceSuggestion() {
        plan?.dismissPaceSuggestion(at: Date())
        persistPlan()
    }

    /// Moves a planned workout, and the rest of its week, one day later.
    func pushBack(_ workout: Workout) {
        plan?.pushBack(workoutID: workout.id)
        persistPlan()
    }

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
        checkpoints.delete()
        plan = nil
        records = []
        settings = AppSettings()
        pendingResume = nil
    }

    func start(_ workout: Workout, mode: RunMode) {
        let session = WorkoutSessionModel(workout: workout, mode: mode, store: store, location: location, settings: settings)
        self.session = session
        session.begin()
    }

    func resumePending() {
        guard let active = pendingResume else { return }
        pendingResume = nil
        let session = WorkoutSessionModel(resuming: active, store: store, location: location, settings: settings)
        self.session = session
        session.begin()
    }

    func discardPending() {
        pendingResume = nil
        checkpoints.delete()
    }

    /// Saves the finished session as a run, marks its planned workout done, and closes it. If the
    /// run cannot be written, the session stays open so Save can be tried again. Any saved run
    /// completes its workout, even one ended early; running a completed workout again links it
    /// to the newer run, and the older run stays in history.
    func save(_ record: RunRecord) {
        do {
            try runs.save(record)
        } catch {
            return
        }
        records = runs.all()
        if let workoutID = record.workoutID {
            plan?.markCompleted(workoutID: workoutID, recordID: record.id)
            if record.feeling == .tooHard, let current = plan {
                plan = PlanGenerator.holdingStep(after: workoutID, in: current)
            }
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
