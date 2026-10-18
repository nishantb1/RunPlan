import Foundation

/// One rung of the walk-run ladder: `repeats` × (run, walk), in seconds.
struct WalkRunLevel: Equatable, Sendable {
    /// Running time per session rises or holds on every rung, ending at 3 × 8 minutes, after
    /// which the plan switches to continuous running.
    static let ladder: [WalkRunLevel] = [
        WalkRunLevel(runSeconds: 60, walkSeconds: 90, repeats: 8),
        WalkRunLevel(runSeconds: 90, walkSeconds: 90, repeats: 7),
        WalkRunLevel(runSeconds: 120, walkSeconds: 90, repeats: 6),
        WalkRunLevel(runSeconds: 180, walkSeconds: 90, repeats: 5),
        WalkRunLevel(runSeconds: 240, walkSeconds: 60, repeats: 5),
        WalkRunLevel(runSeconds: 360, walkSeconds: 60, repeats: 4),
        WalkRunLevel(runSeconds: 480, walkSeconds: 60, repeats: 3),
    ]

    let runSeconds: Int
    let walkSeconds: Int
    let repeats: Int

    /// The rung a runner starts on, or nil when they can already run 20 minutes.
    static func startIndex(for fitness: Fitness) -> Int? {
        switch fitness {
        case .newRunner: return 0
        case .runsFiveMinutes: return 4
        case .runsTwentyMinutes, .recentRace: return nil
        }
    }
}
