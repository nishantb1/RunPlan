import Foundation

public enum StepResolver {
    /// Resolves the current step for an elapsed time, purely from arithmetic. This is what
    /// lets the engine recompute correctly after any length of backgrounding.
    ///
    /// At exactly `elapsed == stepEnd` the step has fully elapsed and the next one is current.
    public static func resolve(steps: [FlatStep], elapsed: TimeInterval) -> StepResolution? {
        guard !steps.isEmpty else { return nil }

        var cumulative: TimeInterval = 0
        for (index, step) in steps.enumerated() {
            guard let duration = step.durationSeconds else {
                return StepResolution(
                    index: index,
                    elapsedInStep: max(0, elapsed - cumulative),
                    remainingInStep: nil,
                    isOpenEnded: true,
                    isPastEnd: false
                )
            }

            let stepEnd = cumulative + TimeInterval(duration)
            if elapsed < stepEnd {
                return StepResolution(
                    index: index,
                    elapsedInStep: elapsed - cumulative,
                    remainingInStep: stepEnd - elapsed,
                    isOpenEnded: false,
                    isPastEnd: false
                )
            }
            cumulative = stepEnd
        }

        return StepResolution(
            index: steps.count - 1,
            elapsedInStep: elapsed - cumulative,
            remainingInStep: 0,
            isOpenEnded: false,
            isPastEnd: true
        )
    }
}
