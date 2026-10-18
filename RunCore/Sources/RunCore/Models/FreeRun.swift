import Foundation

/// A run with no plan: one open run step that lasts until the runner ends it. A free run is
/// never part of the plan, so its record has no workout ID.
public enum FreeRun {
    public static let title = "Free run"

    public static func workout(on date: Date = Date()) -> Workout {
        Workout(date: date, kind: .easy, title: title, steps: [Step(kind: .run, measure: .open)])
    }
}
