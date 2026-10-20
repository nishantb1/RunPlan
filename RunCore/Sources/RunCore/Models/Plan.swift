import Foundation

/// A generated training plan and the profile it was generated from.
public struct Plan: Codable, Equatable, Sendable {
    public var profile: Profile
    public var weeks: [Week]
    /// Seconds per mile added to the generated run paces by accepted pace suggestions; negative
    /// is faster. Walk targets are never shifted.
    public var paceOffset: Int
    /// When a pace suggestion was last accepted or dismissed. Only later runs count as evidence
    /// for the next one.
    public var paceCheckedAt: Date?

    public init(profile: Profile, weeks: [Week], paceOffset: Int = 0, paceCheckedAt: Date? = nil) {
        self.profile = profile
        self.weeks = weeks
        self.paceOffset = paceOffset
        self.paceCheckedAt = paceCheckedAt
    }

    /// `paceOffset` is 0 when missing, so plans saved by an older build still load.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(Profile.self, forKey: .profile)
        weeks = try container.decode([Week].self, forKey: .weeks)
        paceOffset = try container.decodeIfPresent(Int.self, forKey: .paceOffset) ?? 0
        paceCheckedAt = try container.decodeIfPresent(Date.self, forKey: .paceCheckedAt)
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

    /// Moves a workout not yet done one day later, with the later not-done workouts in its week,
    /// so no two runs end up on the same day. One that would leave its week's 7 days is dropped,
    /// except the plan's last workout, which may end the plan a day later.
    /// Assumes `calendar` uses the time zone the plan was generated in.
    public mutating func pushBack(workoutID: UUID, calendar: Calendar = .current) {
        guard let weekIndex = weeks.firstIndex(where: { $0.workouts.contains { $0.id == workoutID } }) else { return }
        let week = weeks[weekIndex]
        guard let index = week.workouts.firstIndex(where: { $0.id == workoutID }),
              week.workouts[index].recordID == nil,
              let weekEnd = calendar.date(byAdding: .day, value: week.number * 7, to: calendar.startOfDay(for: profile.startDate)) else {
            return
        }
        let lastID = workouts.last?.id
        var moved = Array(week.workouts[..<index])
        for var workout in week.workouts[index...] {
            if workout.recordID == nil {
                workout.date = calendar.date(byAdding: .day, value: 1, to: workout.date) ?? workout.date
                if workout.date >= weekEnd && workout.id != lastID { continue }
            }
            moved.append(workout)
        }
        weeks[weekIndex].workouts = moved.sorted { $0.date < $1.date }
    }

    /// Accepts a pace suggestion: every target in workouts not yet done shifts by `change`
    /// seconds per mile, except walk targets, and later plan rebuilds keep the change.
    public mutating func applyPaceChange(_ change: Int, at date: Date) {
        for weekIndex in weeks.indices {
            for workoutIndex in weeks[weekIndex].workouts.indices where weeks[weekIndex].workouts[workoutIndex].recordID == nil {
                for stepIndex in weeks[weekIndex].workouts[workoutIndex].steps.indices {
                    guard let pace = weeks[weekIndex].workouts[workoutIndex].steps[stepIndex].targetPaceSecondsPerMile,
                          pace != WorkoutBuilder.walkPaceSecondsPerMile else { continue }
                    weeks[weekIndex].workouts[workoutIndex].steps[stepIndex].targetPaceSecondsPerMile = pace + change
                }
            }
        }
        paceOffset += change
        paceCheckedAt = date
    }

    /// Declines a pace suggestion until new runs give fresh evidence.
    public mutating func dismissPaceSuggestion(at date: Date) {
        paceCheckedAt = date
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
