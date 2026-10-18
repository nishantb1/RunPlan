import Foundation

/// A generated training plan and the profile it was generated from.
public struct Plan: Codable, Equatable, Sendable {
    public var profile: Profile
    public var weeks: [Week]

    public init(profile: Profile, weeks: [Week]) {
        self.profile = profile
        self.weeks = weeks
    }

    /// Every workout, week by week.
    public var workouts: [Workout] {
        weeks.flatMap(\.workouts)
    }

    public func workout(id: UUID) -> Workout? {
        workouts.first { $0.id == id }
    }

    /// The earliest workout not yet completed that falls on or after the day containing
    /// `date`. Missed workouts on earlier days are skipped.
    /// Assumes `calendar` uses the time zone the plan was generated in.
    public func nextWorkout(onOrAfter date: Date, calendar: Calendar = .current) -> Workout? {
        let day = calendar.startOfDay(for: date)
        return workouts
            .filter { $0.recordID == nil && $0.date >= day }
            .min { $0.date < $1.date }
    }

    public mutating func markCompleted(workoutID: UUID, recordID: UUID) {
        modifyWorkout(id: workoutID, resort: false) { $0.recordID = recordID }
    }

    /// Replaces the workout with the same ID and keeps its week in date order. The workout stays
    /// in its original week even if its new date falls in another week's range.
    public mutating func update(_ workout: Workout) {
        modifyWorkout(id: workout.id, resort: true) { $0 = workout }
    }

    private mutating func modifyWorkout(id: UUID, resort: Bool, _ change: (inout Workout) -> Void) {
        for weekIndex in weeks.indices {
            guard let index = weeks[weekIndex].workouts.firstIndex(where: { $0.id == id }) else { continue }
            change(&weeks[weekIndex].workouts[index])
            if resort {
                weeks[weekIndex].workouts.sort { $0.date < $1.date }
            }
            return
        }
    }
}
