import Foundation

/// Repeat groups as an editor sees them: one repeat count per group, edited on its first step.
extension Workout {

    /// True when the step at `index` is the first of a repeat group.
    public func startsRepeatGroup(at index: Int) -> Bool {
        guard steps.indices.contains(index), let group = steps[index].repeatGroup else { return false }
        return index == 0 || steps[index - 1].repeatGroup != group
    }

    /// The repeat count of the group containing `index`, read the way `StepExpander` reads it.
    /// 1 for a step outside any group.
    public func repeatCount(ofGroupAt index: Int) -> Int {
        groupIndices(at: index).compactMap { steps[$0].repeatCount }.first ?? 1
    }

    /// Sets the repeat count on every step of the group containing `index`.
    public mutating func setRepeatCount(_ count: Int, ofGroupAt index: Int) {
        for stepIndex in groupIndices(at: index) {
            steps[stepIndex].repeatCount = count
        }
    }

    /// Indices of the contiguous steps sharing the repeat group at `index`; empty when the step
    /// is not in a group.
    private func groupIndices(at index: Int) -> [Int] {
        guard steps.indices.contains(index), let group = steps[index].repeatGroup else { return [] }
        var lower = index
        while lower > 0, steps[lower - 1].repeatGroup == group { lower -= 1 }
        var upper = index
        while upper + 1 < steps.count, steps[upper + 1].repeatGroup == group { upper += 1 }
        return Array(lower...upper)
    }
}
