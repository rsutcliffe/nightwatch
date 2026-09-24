import SwiftUI

struct AboutView: View {
    private let notice = (try? String(contentsOfFile: Bundle.main.path(forResource: "NOTICE", ofType: nil) ?? "", encoding: .utf8)) ?? ""

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "star").font(.system(size: 36)).foregroundStyle(Theme.accent)
            Text("Nightwatch").font(.title2.weight(.semibold))
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev") · MIT licence").font(.caption).foregroundStyle(Theme.dim)
            ScrollView { Text(notice.isEmpty ? "See NOTICE in the repository for data attributions." : notice).font(.caption).frame(maxWidth: .infinity, alignment: .leading) }
                .padding(10).background(Theme.card).clipShape(RoundedRectangle(cornerRadius: 8))
            Text("Weather data by Open-Meteo.com, or Apple Weather when signed for WeatherKit. DSS images copyright AAO, SERC, Caltech and AURA via CDS hips2fits.").font(.caption2).foregroundStyle(Theme.dim).multilineTextAlignment(.center)
            Text("Aurora alert status from AuroraWatch UK, Lancaster University.").font(.caption2).foregroundStyle(Theme.dim)
            Text("Darkness bands (Very dark to Bright) are Nightwatch's own thresholds on VIIRS upward radiance, not a Bortle class.").font(.caption2).foregroundStyle(Theme.dim)
            TurtleGlyph().frame(width: 28, height: 18).foregroundStyle(Theme.dim.opacity(0.6))
        }
        .padding(20).frame(width: 420).background(Theme.bg).foregroundStyle(Theme.text).preferredColorScheme(.dark)
    }
}

/// Small original turtle silhouette. Unlabelled, decorative.
struct TurtleGlyph: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            var shell = Path(); shell.addEllipse(in: CGRect(x: w * 0.2, y: h * 0.1, width: w * 0.6, height: h * 0.7))
            var head = Path(); head.addEllipse(in: CGRect(x: w * 0.78, y: h * 0.35, width: w * 0.2, height: h * 0.3))
            var legs = Path()
            for x in [0.25, 0.65] { legs.addEllipse(in: CGRect(x: w * x, y: h * 0.7, width: w * 0.12, height: h * 0.28)) }
            ctx.fill(shell, with: .foreground); ctx.fill(head, with: .foreground); ctx.fill(legs, with: .foreground)
        }
    }
}
