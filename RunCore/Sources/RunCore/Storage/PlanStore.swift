import Foundation

/// The training plan, stored as one file. The profile it was generated from is inside it.
public struct PlanStore: Sendable {
    private static let file = "plan.json"
    private let store: JSONStore

    public init(store: JSONStore) {
        self.store = store
    }

    public func load() -> Plan? {
        store.load(Plan.self, from: Self.file)
    }

    public func save(_ plan: Plan) throws {
        try store.save(plan, as: Self.file)
    }
}
