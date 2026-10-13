import UIKit

/// Fires haptic feedback on each step transition.
final class HapticsService {
    private let generator = UIImpactFeedbackGenerator(style: .medium)

    init() {
        generator.prepare()
    }

    func stepTransition() {
        generator.impactOccurred()
        generator.prepare()
    }
}
