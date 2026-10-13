import SwiftUI

@main
struct RunPlanApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
        }
    }
}
