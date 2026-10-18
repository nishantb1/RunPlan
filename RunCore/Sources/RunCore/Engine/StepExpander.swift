import Foundation

public enum StepExpander {
    /// Expands repeat groups into a flat queue, preserving order. A contiguous run of steps
    /// sharing the same non-nil `repeatGroup` forms one group; its repeat count is taken
    /// from the first step in the group that specifies one.
    public static func expand(_ steps: [Step]) -> [FlatStep] {
        var result: [FlatStep] = []
        var index = 0

        while index < steps.count {
            let step = steps[index]

            guard let groupID = step.repeatGroup else {
                result.append(flatten(step))
                index += 1
                continue
            }

            var groupSteps: [Step] = []
            var lookahead = index
            while lookahead < steps.count, steps[lookahead].repeatGroup == groupID {
                groupSteps.append(steps[lookahead])
                lookahead += 1
            }

            let repeatCount = groupSteps.compactMap(\.repeatCount).first ?? 1
            for _ in 0..<max(repeatCount, 0) {
                for groupStep in groupSteps {
                    result.append(flatten(groupStep))
                }
            }

            index = lookahead
        }

        return result
    }

    private static func flatten(_ step: Step) -> FlatStep {
        switch step.measure {
        case .time(let seconds):
            return FlatStep(
                sourceStepID: step.id,
                kind: step.kind,
                durationSeconds: seconds,
                distanceMeters: nil,
                targetPaceSecondsPerMile: step.targetPaceSecondsPerMile
            )
        case .distance(let meters):
            return FlatStep(
                sourceStepID: step.id,
                kind: step.kind,
                durationSeconds: nil,
                distanceMeters: meters,
                targetPaceSecondsPerMile: step.targetPaceSecondsPerMile
            )
        case .open:
            return FlatStep(
                sourceStepID: step.id,
                kind: step.kind,
                durationSeconds: nil,
                distanceMeters: nil,
                targetPaceSecondsPerMile: step.targetPaceSecondsPerMile
            )
        }
    }
}
