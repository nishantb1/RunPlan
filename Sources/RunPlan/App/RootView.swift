import SwiftUI
import RunCore

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var app = app

        Group {
            if app.plan == nil {
                OnboardingView()
            } else {
                TabView {
                    PlanView()
                        .tabItem { Label("Plan", systemImage: "calendar") }
                    HistoryView()
                        .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                }
            }
        }
        .fullScreenCover(item: $app.session) { session in
            SessionContainerView(session: session)
        }
        .alert(
            "Resume your workout?",
            isPresented: Binding(
                get: { app.pendingResume != nil && app.session == nil },
                set: { if !$0 { app.pendingResume = nil } }
            )
        ) {
            Button("Resume") { app.resumePending() }
            Button("Discard", role: .destructive) { app.discardPending() }
        } message: {
            Text("A workout was in progress when the app closed. It will resume paused.")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                app.session?.handleForeground()
            }
        }
    }
}
