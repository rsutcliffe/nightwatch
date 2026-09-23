import SwiftUI
import SkyCore

struct DetailView: View {
    @EnvironmentObject var store: Store
    let target: RankedTarget
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Button(action: onBack) { Image(systemName: "chevron.left") }; Text(target.group.displayName).font(.caption).foregroundStyle(Theme.dim) }
                let fov = FieldOfView(widthDeg: max(0.05, store.config.fov.widthDeg), heightDeg: max(0.05, store.config.fov.heightDeg))   // hand-edited config can hold 0
                let thumbH: CGFloat = 260
                let thumbW: CGFloat = thumbH * fov.widthDeg / fov.heightDeg
                ZStack {
                    ThumbnailView(target: target).frame(width: thumbW, height: thumbH)
                    if target.group != .constellations {
                        let fovDeg = Thumbnails.fovDeg(for: target, fov: fov)
                        let w = thumbW * fov.widthDeg / fovDeg
                        RoundedRectangle(cornerRadius: 4).stroke(Theme.accent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .frame(width: w, height: w * fov.heightDeg / fov.widthDeg)
                    }
                }
                .frame(maxWidth: .infinity)
                Text("dashed = your field of view").font(.caption2).foregroundStyle(Theme.dim).frame(maxWidth: .infinity, alignment: .trailing)
                Text(target.name).font(.title2.weight(.semibold))
                Text(target.subtitle + (target.sizeArcmin.map { String(format: " · %.0f′", $0) } ?? "") + (target.magnitude.map { String(format: " · mag %.1f", $0) } ?? "")).foregroundStyle(Theme.dim)
                if let s = store.site, let w = store.plan?.primary {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        tile("Best", "\(Copy.hhmm(target.peakTime, site: s)) · \(Int(target.peakAltDeg))°")
                        tile("Above \(Int(store.config.goRule.minAltitudeDeg))°", "\(Int(target.visibleFraction * 100))% of window")
                        tile("Moon sep.", "\(Int(target.moonSepDeg))°")
                        tile("Suggested", String(format: "%.0f min stack", min(w.hours, 3) * 60))
                    }
                    altitudeCurve(site: s, window: w)
                }
                Text(String(format: "RA %.2fh · Dec %+.1f°", target.raHours, target.decDeg)).font(.caption).foregroundStyle(Theme.dim)
            }.padding(16)
        }
        .background(Theme.bg).foregroundStyle(Theme.text)
    }

    private func tile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(label).font(.caption2).foregroundStyle(Theme.dim); Text(value).font(.callout.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7) }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Theme.card).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// Altitude from sunset to sunrise, clear window shaded, 30° floor drawn.
    private func altitudeCurve(site: Site, window: ClearWindow) -> some View {
        let night = store.plan!.night
        let span = night.sunrise.timeIntervalSince(night.sunset)
        let samples: [(Double, Double)] = stride(from: 0.0, through: 1.0, by: 1.0 / 48).map { f in
            let t = night.sunset.addingTimeInterval(f * span)
            return (f, Ephemeris.altAz(raHours: target.raHours, decDeg: target.decDeg, at: t, site: site).alt)
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text("ALTITUDE TONIGHT").font(.caption).foregroundStyle(Theme.dim)
            GeometryReader { g in
                let x = { (f: Double) in g.size.width * f }
                let y = { (alt: Double) in g.size.height * (1 - max(0, min(90, alt)) / 90) }
                Rectangle().fill(Theme.accent.opacity(0.08))
                    .frame(width: x(window.end.timeIntervalSince(night.sunset) / span) - x(window.start.timeIntervalSince(night.sunset) / span))
                    .offset(x: x(window.start.timeIntervalSince(night.sunset) / span))
                Path { p in p.move(to: CGPoint(x: 0, y: y(store.config.goRule.minAltitudeDeg))); p.addLine(to: CGPoint(x: g.size.width, y: y(store.config.goRule.minAltitudeDeg))) }.stroke(Theme.line)
                Path { p in
                    for (i, s) in samples.enumerated() { i == 0 ? p.move(to: CGPoint(x: x(s.0), y: y(s.1))) : p.addLine(to: CGPoint(x: x(s.0), y: y(s.1))) }
                }.stroke(Theme.accent, lineWidth: 2)
            }.frame(height: 70)
            HStack { Text(Copy.hhmm(night.sunset, site: site)); Spacer(); Text(Copy.hhmm(night.sunrise, site: site)) }.font(.caption2).foregroundStyle(Theme.dim)
        }
    }
}
