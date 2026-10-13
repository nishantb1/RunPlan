import SwiftUI

/// Shows the live screen while the workout runs, then the summary.
struct SessionContainerView: View {
    let session: WorkoutSessionModel

    var body: some View {
        if session.isFinished {
            SummaryView(session: session)
        } else {
            LiveWorkoutView(session: session)
        }
    }
}
