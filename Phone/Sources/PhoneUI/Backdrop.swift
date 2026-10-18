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

    /// The backdrop photographs, bundled and read once each: a wide one for landscape screens and a tall crop for portrait. The Unsplash
    /// Milky Way (William Zhang, credited in the README) stays as the fallback.
    private static func load(_ name: String) -> Image? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "Backdrop"),
              let data = try? Data(contentsOf: url) else { return nil }
        return Image(platformData: data)
    }
    private static let fallback: Image? = load("milky-way")
    private static let wide: Image? = load("night-sky-wide") ?? fallback
    private static let tall: Image? = load("night-sky-tall") ?? fallback

    var body: some View {
        if reduceTransparency { Color.clear } else if Self.wide != nil || Self.tall != nil {
            // The real sky, held back so the cards on it stay readable: darker towards the foot, one red hue in red mode.
            GeometryReader { geo in
                (geo.size.width > geo.size.height ? Self.wide : Self.tall)?.resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped()
                    .saturation(theme.isRed ? 0 : 1).colorMultiply(theme.isRed ? Color(hex: 0xC0180E) : .white)
                    .overlay(LinearGradient(colors: [theme.background.opacity(theme.isRed ? 0.50 : 0.16), theme.background.opacity(0.78)],
                                            startPoint: .top, endPoint: .bottom))
            }
            .allowsHitTesting(false).accessibilityHidden(true)
        } else {
            Canvas { ctx, size in
                var g = Generator(state: seed.utf8.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1)) &* 1099511628211 })
                func unit() -> Double { Double.random(in: 0..<1, using: &g) }
                let red = theme.isRed
                let tint = red ? Color(hex: 0xC0180E) : Color.white
                let glow = red ? Color(hex: 0x6A0A06) : Color(hex: 0x4A5FB8)

                // The Milky Way: a soft diagonal band with the faint stars crowded along it.
                let tilt = (unit() - 0.5) * 0.5 + 0.55
                let start = CGPoint(x: -size.width * 0.1, y: size.height * (0.10 + 0.12 * unit()))
                let end = CGPoint(x: size.width * 1.1, y: start.y + size.height * 0.45 * (0.7 + tilt))
                let mid = CGPoint(x: size.width * 0.5, y: (start.y + end.y) / 2 - size.height * 0.08)
                var band = Path(); band.move(to: start); band.addQuadCurve(to: end, control: mid)
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: min(size.width, size.height) * 0.09))
                    layer.stroke(band, with: .color(glow.opacity(red ? 0.34 : 0.55)), lineWidth: min(size.width, size.height) * 0.30)
                }
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: min(size.width, size.height) * 0.03))
                    layer.stroke(band, with: .color(tint.opacity(red ? 0.08 : 0.13)), lineWidth: min(size.width, size.height) * 0.09)
                }
                let along = Int(size.width * size.height / 900)
                for _ in 0..<along {
                    let t = unit()
                    let u = 1 - t
                    let x = u * u * start.x + 2 * u * t * mid.x + t * t * end.x
                    let y = u * u * start.y + 2 * u * t * mid.y + t * t * end.y
                    let spread = min(size.width, size.height) * 0.14
                    let dx = (unit() + unit() + unit() - 1.5) * spread, dy = (unit() + unit() + unit() - 1.5) * spread
                    let r = 0.45 + 0.7 * unit()
                    ctx.fill(Path(ellipseIn: CGRect(x: x + dx - r, y: y + dy - r, width: r * 2, height: r * 2)),
                             with: .color(tint.opacity((red ? 0.30 : 0.55) * (0.3 + 0.7 * unit()))))
                }

                // Scattered stars of several sizes; the brightest get a halo and a glint.
                let scattered = Int(size.width * size.height / 7000)
                for _ in 0..<scattered {
                    let x = unit() * size.width, y = unit() * size.height, m = unit()
                    let r = m > 0.97 ? 1.9 : m > 0.85 ? 1.3 : 0.8
                    let a = (red ? 0.38 : 0.85) * (0.4 + 0.6 * m)
                    if m > 0.97 {
                        
                        var glint = Path()
                        glint.move(to: CGPoint(x: x - 5, y: y)); glint.addLine(to: CGPoint(x: x + 5, y: y))
                        glint.move(to: CGPoint(x: x, y: y - 5)); glint.addLine(to: CGPoint(x: x, y: y + 5))
                        ctx.stroke(glint, with: .color(tint.opacity(a * 0.35)), lineWidth: 0.5)
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(tint.opacity(a)))
                }
            }
            .background(LinearGradient(colors: [theme.skyTop, theme.background], startPoint: .top, endPoint: .center))
            .allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

/// The hero card: a dusk-to-night gradient that follows the verdict, with a lit top edge.
struct HeroSurface: ViewModifier {
    let clear: Bool
    /// A constellation's figure and star plot (the owner's art), drawn faint at the trailing edge.
    var figure: (Data, Data)? = nil
    var padding: CGFloat = 16
    @Environment(\.phoneTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .bottomTrailing) {
                if let figure, let f = Image(platformData: figure.0), let p = Image(platformData: figure.1) {
                    ZStack { f.resizable().scaledToFit(); p.resizable().scaledToFit() }
                        .saturation(theme.isRed ? 0 : 1).colorMultiply(theme.isRed ? Color(hex: 0xC0180E) : .white)
                        .opacity(0.13).padding(10).offset(x: 14, y: 14).accessibilityHidden(true)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            }
            .background(LinearGradient(colors: clear ? theme.heroClear : theme.heroDull, startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(
                LinearGradient(colors: [theme.highlight, theme.outline], startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }
}

extension View {
    func heroSurface(clear: Bool, padding: CGFloat = 16, figure: (Data, Data)? = nil) -> some View {
        modifier(HeroSurface(clear: clear, figure: figure, padding: padding))
    }
}
