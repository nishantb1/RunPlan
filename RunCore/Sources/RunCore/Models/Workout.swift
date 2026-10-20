import Foundation

public struct Workout: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var date: Date
    public var kind: WorkoutKind
    public var title: String
    public var steps: [Step]
    /// Set once the workout has been completed and saved.
    public var recordID: UUID?
    /// The pace targets are only a treadmill speed to set; outdoors the steps run without them,
    /// so there is no target shown or spoken and no pace cue. Set on a new runner's workouts.
    public var treadmillTargetsOnly: Bool

    public init(
        id: UUID = UUID(),
        date: Date,
        kind: WorkoutKind,
        title: String,
        steps: [Step],
        recordID: UUID? = nil,
        treadmillTargetsOnly: Bool = false
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.title = title
        self.steps = steps
        self.recordID = recordID
        self.treadmillTargetsOnly = treadmillTargetsOnly
    }

    /// `treadmillTargetsOnly` defaults to false when missing, so workouts saved by an older
    /// build still load.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        kind = try container.decode(WorkoutKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        steps = try container.decode([Step].self, forKey: .steps)
        recordID = try container.decodeIfPresent(UUID.self, forKey: .recordID)
        treadmillTargetsOnly = try container.decodeIfPresent(Bool.self, forKey: .treadmillTargetsOnly) ?? false
    }

    /// The steps to run in `mode`: outdoors, treadmill-only targets are dropped.
    public func steps(for mode: RunMode) -> [Step] {
        guard mode == .outdoor, treadmillTargetsOnly else { return steps }
        return steps.map { step in
            var step = step
            step.targetPaceSecondsPerMile = nil
            return step
        }
    }
}
