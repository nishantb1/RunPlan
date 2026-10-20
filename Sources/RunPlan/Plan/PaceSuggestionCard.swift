import SwiftUI
import RunCore

/// Offers a faster or slower run speed when recent runs call for one.
struct PaceSuggestionCard: View {
    @Environment(AppModel.self) private var app
    let suggestion: PaceSuggestion

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(reason)
                Text("Run speed \(mph(suggestion.currentEasy)) → \(mph(suggestion.suggestedEasy)) mph")
                    .font(.headline)
                Text("\(Pace.clock(suggestion.currentEasy)) → \(Pace.clock(suggestion.suggestedEasy)) /mi")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack {
                Button("Update") { app.acceptPaceSuggestion(suggestion) }
                    .buttonStyle(.borderedProminent)
                Spacer()
                Button("Not now") { app.dismissPaceSuggestion() }
                    .buttonStyle(.bordered)
            }
        } header: {
            Text(suggestion.change < 0 ? "Faster run speed" : "Slower run speed")
        } footer: {
            Text("Updates the run targets in every workout you haven't done. Walks stay at 3.0 mph.")
        }
    }

    private var reason: String {
        switch suggestion.reason {
        case .ranFaster: return "Your last 3 runs were faster than planned."
        case .ranSlower: return "Your last 3 runs were slower than planned."
        case .feltEasy: return "Your last 2 runs felt too easy."
        case .feltHard: return "Your last 2 runs felt too hard."
        }
    }

    private func mph(_ pace: Int) -> String {
        String(format: "%.1f", Pace.mph(fromSecondsPerMile: pace))
    }
}
