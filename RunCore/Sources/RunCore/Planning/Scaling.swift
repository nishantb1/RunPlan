import Foundation

/// Integer scaling with halves rounded up, so plan lengths are exact and identical on every
/// platform.
enum Scaling {
    /// `value × numerator / denominator`, rounded to the nearest whole number. Inputs must be
    /// non-negative and `denominator` positive.
    static func round(_ value: Int, times numerator: Int, over denominator: Int) -> Int {
        (2 * value * numerator + denominator) / (2 * denominator)
    }
}
