import SwiftUI

/// Minute and second wheels bound to a total number of seconds.
struct DurationPicker: View {
    @Binding var seconds: Int
    let minuteRange: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 0) {
            Picker("Minutes", selection: minutes) {
                ForEach(minuteRange, id: \.self) { Text("\($0) min").tag($0) }
            }
            .frame(maxWidth: .infinity)
            .clipped()
            Picker("Seconds", selection: secondsPart) {
                ForEach(0..<60, id: \.self) { Text(String(format: "%02d s", $0)).tag($0) }
            }
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .pickerStyle(.wheel)
        .frame(height: 150)
    }

    /// The minute the wheel shows. Both bindings write from it, so the wheels and the value agree
    /// even when `seconds` starts outside `minuteRange`.
    private var clampedMinutes: Int {
        min(max(seconds / 60, minuteRange.lowerBound), minuteRange.upperBound)
    }

    private var minutes: Binding<Int> {
        Binding(
            get: { clampedMinutes },
            set: { seconds = $0 * 60 + seconds % 60 }
        )
    }

    private var secondsPart: Binding<Int> {
        Binding(
            get: { seconds % 60 },
            set: { seconds = clampedMinutes * 60 + $0 }
        )
    }
}
