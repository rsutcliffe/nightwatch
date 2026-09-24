import SwiftUI

/// Liquid Glass on macOS 26 and later with Reduce Transparency off; the solid `fill` otherwise (spec §3).
/// Apply it after every other appearance modifier, as Apple's guidance asks.
struct NightwatchGlass<S: Shape>: ViewModifier {
    let shape: S
    let fill: Color
    let tint: Color
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(macOS 26, *), !reduceTransparency {
            content.glassEffect(.regular.tint(tint), in: shape)
        } else {
            content.background(fill, in: shape)
        }
    }
}

extension View {
    func nightwatchGlass(in shape: some Shape, fill: Color = Tokens.targetsBackground, tint: Color = Tokens.glassTint) -> some View {
        modifier(NightwatchGlass(shape: shape, fill: fill, tint: tint))
    }
}

/// One `GlassEffectContainer` around a group of glass views, as Apple advises for performance; a plain group otherwise.
struct GlassGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if #available(macOS 26, *), !reduceTransparency {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}
