import Foundation

/// Hand-written workouts used until the plan generator exists.
public enum SampleWorkouts {
    /// 5 min walk, 6 x (1:30 run at 4.7 mph, 2:00 walk at 2.5 mph), 3 min walk.
    public static func runWalk(on date: Date = Date()) -> Workout {
        let walkPace = Pace.secondsPerMile(fromMph: 2.5)
        let runPace = Pace.secondsPerMile(fromMph: 4.7)
        return Workout(
            date: date,
            kind: .walkRun,
            title: "Run-walk intervals",
            steps: [
                Step(kind: .warmup, measure: .time(seconds: 300), targetPaceSecondsPerMile: walkPace),
                Step(kind: .run, measure: .time(seconds: 90), targetPaceSecondsPerMile: runPace, repeatGroup: 1, repeatCount: 6),
                Step(kind: .walk, measure: .time(seconds: 120), targetPaceSecondsPerMile: walkPace, repeatGroup: 1, repeatCount: 6),
                Step(kind: .cooldown, measure: .time(seconds: 180), targetPaceSecondsPerMile: walkPace),
            ]
        )
    }
}
