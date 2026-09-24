import SwiftUI

/// Amber warning dot with a soft glow. Always sits beside a text label: colour is never the only signal.
struct WarningDot: View {
    var size: CGFloat = 5
    var body: some View {
        Circle().fill(Tokens.statusWarning).frame(width: size, height: size)
            .shadow(color: Tokens.statusWarning.opacity(0.7), radius: 2).accessibilityHidden(true)
    }
}
