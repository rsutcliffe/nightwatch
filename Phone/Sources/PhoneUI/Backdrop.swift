import SwiftUI

/// A quiet field of stars behind the screen, the same every time for a given place and night, so it never flickers or
/// costs anything after the first draw. Red mode: dim red stars on black. Off under Reduce Transparency.
struct StarField: View {
    let seed: String
    @Environment(\.phoneTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Small deterministic generator (SplitMix64) so the same seed always draws the same sky.
    private struct Generator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    var body: some View {
        if reduceTransparency { Color.clear } else {
            Canvas { ctx, size in
                var g = Generator(state: seed.utf8.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1)) &* 1099511628211 })
                let count = Int(size.width * size.height / 5200)
                for _ in 0..<count {
                    let x = Double.random(in: 0..<size.width, using: &g), y = Double.random(in: 0..<size.height, using: &g)
                    let bright = Double.random(in: 0...1, using: &g)
                    let r = bright > 0.96 ? 1.3 : bright > 0.8 ? 0.9 : 0.6
                    let alpha = (theme.isRed ? 0.22 : 0.5) * (0.35 + 0.65 * bright)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color((theme.isRed ? Color(hex: 0xC0180E) : Color.white).opacity(alpha)))
                }
            }
            .allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

/// The hero card: a dusk-to-night gradient that follows the verdict, with a lit top edge.
struct HeroSurface: ViewModifier {
    let clear: Bool
    var padding: CGFloat = 16
    @Environment(\.phoneTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: clear ? theme.heroClear : theme.heroDull, startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(
                LinearGradient(colors: [theme.highlight, theme.outline], startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }
}

extension View {
    func heroSurface(clear: Bool, padding: CGFloat = 16) -> some View { modifier(HeroSurface(clear: clear, padding: padding)) }
}
