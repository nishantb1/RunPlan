import SwiftUI
import RunCore

/// The Start flow shared by planned workouts and free runs: choose Treadmill or Outdoor, and for
/// Outdoor pass through the GPS sheet first. The session starts only once the sheet has closed,
/// so the full-screen workout never presents over a closing sheet.
struct StartRunFlow: ViewModifier {
    @Environment(AppModel.self) private var app
    @Binding var isChoosing: Bool
    /// Called at start time, so a free run gets the current date.
    let workout: () -> Workout

    @State private var showingOutdoor = false
    @State private var pendingMode: RunMode?

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Where are you running?", isPresented: $isChoosing, titleVisibility: .visible) {
                Button("Treadmill") { app.start(workout(), mode: .treadmill) }
                Button("Outdoor") { showingOutdoor = true }
            }
            .sheet(isPresented: $showingOutdoor, onDismiss: startPending) {
                OutdoorStartView { mode in pendingMode = mode }
            }
    }

    private func startPending() {
        guard let mode = pendingMode else { return }
        pendingMode = nil
        app.start(workout(), mode: mode)
    }
}

extension View {
    func startRunFlow(isChoosing: Binding<Bool>, workout: @escaping () -> Workout) -> some View {
        modifier(StartRunFlow(isChoosing: isChoosing, workout: workout))
    }
}
