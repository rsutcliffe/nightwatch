import SwiftUI
import SkyCore
import PhoneCore

/// A press scales the control down at once so the touch is seen to be heard, and springs back. A press that is dragged away
/// from the control, or cancelled by a scroll, ends without acting (the button's own behaviour), and the scale shows it.
public struct PressStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// A card: the surface the tiles, bars and lists sit on.
struct Card<Content: View>: View {
    @Environment(\.phoneTheme) private var theme
    var padding: CGFloat = 12
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.hairline, lineWidth: 1))
    }
}

/// Waiting text that says what is happening, and breathes gently. Still under Reduce Motion.
struct WaitingText: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false
    var body: some View {
        Text(text).font(.callout).secondary()
            .opacity(dim ? 0.45 : 1)
            .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { dim = true } } }
    }
}

/// A screen's empty state: what is missing and what to do about it.
struct EmptyState: View {
    let title: String
    let message: String
    var action: (title: String, run: () -> Void)?
    @Environment(\.phoneTheme) private var theme
    var body: some View {
        VStack(spacing: 10) {
            Text(title).font(.title3.weight(.medium))
            Text(message).font(.callout).secondary().multilineTextAlignment(.center)
            if let action {
                Button(action: action.run) {
                    Text(action.title).font(.body.weight(.medium)).frame(maxWidth: 280).padding(.vertical, 14)
                        .background(theme.accent, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(theme.isRed ? Color.black : Color.white)
                }
                .buttonStyle(PressStyle())
                .padding(.top, 6)
            }
        }
        .padding(24)
    }
}

/// The big blue (or red) button at the foot of a screen: low on the screen, wide, easy to reach with a thumb.
struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.phoneTheme) private var theme
    var body: some View {
        Button(action: action) {
            Text(title).font(.body.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(theme.accent, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(theme.isRed ? Color.black : Color.white)
        }
        .buttonStyle(PressStyle())
        .sensoryFeedback(.selection, trigger: title)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void
    @Environment(\.phoneTheme) private var theme
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.callout).frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(theme.track, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(PressStyle())
    }
}
