import Foundation
import RunCore

/// "Mile 3" for a whole mile, "Last 0.42 mi" for the partial split at the end.
enum SplitLabel {
    static func text(for split: Split) -> String {
        guard split.distanceMeters < Pace.metersPerMile - 1 else { return "Mile \(split.index)" }
        return String(format: "Last %.2f mi", Pace.miles(fromMeters: split.distanceMeters))
    }
}
