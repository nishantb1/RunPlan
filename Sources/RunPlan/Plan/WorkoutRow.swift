import SwiftUI
import RunCore

/// A planned workout in a list: done mark, title and date.
struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDone ? Color.green : Color.secondary)
                .accessibilityLabel(isDone ? "Completed" : "Not completed")
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.title).font(.headline)
                Text(workout.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isDone: Bool { workout.recordID != nil }
}
