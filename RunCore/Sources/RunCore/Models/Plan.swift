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
    public func nextWorkout(onOrAfter date: Date, calendar: Calendar = .current) -> Workout? {
        let day = calendar.startOfDay(for: date)
        return workouts
            .filter { $0.recordID == nil && $0.date >= day }
            .min { $0.date < $1.date }
    }

    public mutating func markCompleted(workoutID: UUID, recordID: UUID) {
        modifyWorkout(id: workoutID) { $0.recordID = recordID }
    }

    /// Replaces the workout with the same ID and keeps its week in date order.
    public mutating func update(_ workout: Workout) {
        modifyWorkout(id: workout.id) { $0 = workout }
    }

    private mutating func modifyWorkout(id: UUID, _ change: (inout Workout) -> Void) {
        for weekIndex in weeks.indices {
            guard let index = weeks[weekIndex].workouts.firstIndex(where: { $0.id == id }) else { continue }
            change(&weeks[weekIndex].workouts[index])
            weeks[weekIndex].workouts.sort { $0.date < $1.date }
            return
        }
    }
}
