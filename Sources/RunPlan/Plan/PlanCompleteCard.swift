import SwiftUI
import RunCore

/// Shown when the plan is over: what's next, starting from the finale's time.
struct PlanCompleteCard: View {
    @Environment(AppModel.self) private var app
    let plan: Plan
    /// Opens the change-plan screen filled in with these answers, or the current plan's.
    let choose: (Profile?) -> Void

    var body: some View {
        let distance = plan.profile.goal.distance
        let finale = FollowUp.finaleSeconds(of: plan, records: app.records)
        Section {
            if let finale {
                LabeledContent("Your \(distance.displayName)", value: Pace.clock(finale))
            }
            Button("Get faster at \(distance.displayName)") {
                choose(FollowUp.profile(after: plan, distance: distance, finaleSeconds: finale, start: Date()))
            }
            if distance == .fiveK {
                Button("Build to 10K") {
                    choose(FollowUp.profile(after: plan, distance: .tenK, finaleSeconds: finale, start: Date()))
                }
            }
            Button("Something else") { choose(nil) }
        } header: {
            Text("Plan complete")
        } footer: {
            Text(finale == nil
                 ? "Your next plan starts from running 20 minutes. You can change any answer before it's made."
                 : "Your next plan's paces come from this time, taken from your final run less the walking. You can change it before the plan is made.")
        }
    }
}
