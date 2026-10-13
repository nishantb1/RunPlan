import Foundation

public struct Workout: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var date: Date
    public var kind: WorkoutKind
    public var title: String
    public var steps: [Step]
    /// Set once the workout has been completed and saved.
    public var recordID: UUID?

    public init(
        id: UUID = UUID(),
        date: Date,
        kind: WorkoutKind,
        title: String,
        steps: [Step],
        recordID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.title = title
        self.steps = steps
        self.recordID = recordID
    }
}
