import SwiftUI
import RunCore

/// The training plan: the next workout, then every week with its workouts.
struct PlanView: View {
    @Environment(AppModel.self) private var app
    @State private var changingPlan = false
    /// Answers to fill the change-plan screen with; nil uses the current plan's.
    @State private var draft: Profile?
    @State private var choosingFreeRun = false

    var body: some View {
        NavigationStack {
            List {
                if let plan = app.plan {
                    if let suggestion = app.paceSuggestion {
                        PaceSuggestionCard(suggestion: suggestion)
                    }
                    if let next = plan.nextWorkout(onOrAfter: Date()) {
                        Section(nextHeader(next)) {
                            NavigationLink(value: next.id) { WorkoutRow(workout: next) }
                        }
                    } else {
                        PlanCompleteCard(plan: plan) { profile in
                            draft = profile
                            changingPlan = true
                        }
                    }
                    ForEach(plan.weeks) { week in
                        Section(weekHeader(week)) {
                            ForEach(week.workouts) { workout in
                                NavigationLink(value: workout.id) { WorkoutRow(workout: workout) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Plan")
            .navigationDestination(for: UUID.self) { id in
                WorkoutDetailView(workoutID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Change plan") {
                        draft = nil
                        changingPlan = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Free run") { choosingFreeRun = true }
                }
            }
            .sheet(isPresented: $changingPlan) {
                OnboardingView(changing: draft ?? app.plan?.profile)
            }
            .startRunFlow(isChoosing: $choosingFreeRun) { FreeRun.workout() }
        }
    }

    private func nextHeader(_ next: Workout) -> String {
        guard Calendar.current.isDateInToday(next.date) else { return "Next" }
        return "Today"
    }

    private func weekHeader(_ week: Week) -> String {
        let done = week.workouts.filter { $0.recordID != nil }.count
        return "Week \(week.number) · \(week.kind.displayName) · \(done) of \(week.workouts.count) done"
    }
}
