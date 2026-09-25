import SwiftUI

/// Amber warning dot with a soft glow. Always sits beside a text label: colour is never the only signal.
public struct WarningDot: View {
    var size: CGFloat
    public init(size: CGFloat = 5) { self.size = size }
    public var body: some View {
        Circle().fill(Tokens.statusWarning).frame(width: size, height: size)
            .shadow(color: Tokens.statusWarning.opacity(0.7), radius: 2).accessibilityHidden(true)
    }
}
