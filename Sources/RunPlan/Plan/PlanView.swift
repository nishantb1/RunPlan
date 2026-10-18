import SwiftUI
import RunCore

/// The training plan: the next workout, then every week with its workouts.
struct PlanView: View {
    @Environment(AppModel.self) private var app
    @State private var changingPlan = false
    @State private var choosingFreeRun = false

    var body: some View {
        NavigationStack {
            List {
                if let plan = app.plan {
                    let next = plan.nextWorkout(onOrAfter: Date())
                    Section(nextHeader(next)) {
                        if let next {
                            NavigationLink(value: next.id) { WorkoutRow(workout: next) }
                        } else {
                            Text("Plan complete").foregroundStyle(.secondary)
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
                    Button("Change plan") { changingPlan = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Free run") { choosingFreeRun = true }
                }
            }
            .sheet(isPresented: $changingPlan) {
                OnboardingView(changing: app.plan?.profile)
            }
            .startRunFlow(isChoosing: $choosingFreeRun) { FreeRun.workout() }
        }
    }

    private func nextHeader(_ next: Workout?) -> String {
        guard let next, Calendar.current.isDateInToday(next.date) else { return "Next" }
        return "Today"
    }

    private func weekHeader(_ week: Week) -> String {
        let done = week.workouts.filter { $0.recordID != nil }.count
        return "Week \(week.number) · \(week.kind.displayName) · \(done) of \(week.workouts.count) done"
    }
}
