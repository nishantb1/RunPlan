import SwiftUI
import UIKit

extension Color {
    /// The one chart colour: an orange checked for lightness, chroma and contrast against the
    /// light and dark backgrounds with the data-visualisation palette validator (#C85A12 light,
    /// #D86A24 dark). The system orange fails both: too faint on white, too light on black.
    static let chartAccent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xD8 / 255, green: 0x6A / 255, blue: 0x24 / 255, alpha: 1)
            : UIColor(red: 0xC8 / 255, green: 0x5A / 255, blue: 0x12 / 255, alpha: 1)
    })
}
