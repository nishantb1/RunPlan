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
            Picker("Seconds", selection: secondsPart) {
                ForEach(0..<60, id: \.self) { Text(String(format: "%02d s", $0)).tag($0) }
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 150)
    }

    private var minutes: Binding<Int> {
        Binding(
            get: { min(max(seconds / 60, minuteRange.lowerBound), minuteRange.upperBound) },
            set: { seconds = $0 * 60 + seconds % 60 }
        )
    }

    private var secondsPart: Binding<Int> {
        Binding(
            get: { seconds % 60 },
            set: { seconds = (seconds / 60) * 60 + $0 }
        )
    }
}
