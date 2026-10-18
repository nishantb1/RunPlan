import Foundation

/// How much of the plan is done: workouts with a saved run, out of all workouts.
public struct PlanProgress: Equatable, Sendable {
    public let completed: Int
    public let total: Int

    public init(plan: Plan) {
        let workouts = plan.workouts
        total = workouts.count
        completed = workouts.filter { $0.recordID != nil }.count
    }

    public var fraction: Double {
        total == 0 ? 0 : Double(completed) / Double(total)
    }
}
