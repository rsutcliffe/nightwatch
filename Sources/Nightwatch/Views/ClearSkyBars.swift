import SwiftUI
import SkyCore

/// One column per hour of the plan's darkness, filled to the clear-sky share (100 − cloud). Hours inside a clear window
/// are red with a glow, the others bar.cloudy. Shared by the popover and the Targets header.
struct ClearSkyBars: View {
    let plan: NightPlan
    let site: Site
    var trackHeight: CGFloat = 37
    var labels = true
    var source: String? = nil

    private func lit(_ h: HourlyConditions) -> Bool { plan.windows.contains { $0.overlapsHour(startingAt: h.time) } }

    @ViewBuilder var body: some View {
        if !plan.darkHours.isEmpty { chart }
    }

    private var chart: some View {
        let peak = plan.darkHours.min { $0.cloudTotal < $1.cloudTotal }
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 3.4) {
                ForEach(plan.darkHours, id: \.time) { h in
                    let clear = CGFloat(max(0, min(100, 100 - h.cloudTotal))) / 100
                    VStack(spacing: 2) {
                        if labels, h.time == peak?.time, h.cloudTotal < 100 {
                            Text("\(Int(clear * 100))%").font(.system(size: 8, weight: .medium)).foregroundStyle(Tokens.textPrimary).fixedSize()
                        }
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 2.5).fill(Tokens.surfaceTrack)
                            RoundedRectangle(cornerRadius: 2.5).fill(lit(h) ? Tokens.accentClear : Tokens.barCloudy)
                                .frame(height: trackHeight * clear)
                                .shadow(color: lit(h) ? Tokens.accentClear.opacity(0.7) : .clear, radius: 3)
                        }
                        .frame(height: trackHeight)
                        if labels {
                            Text(String(Copy.hhmm(h.time, site: site).prefix(2))).font(.system(size: 8.5)).foregroundStyle(Tokens.textSecondary).fixedSize()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if labels {
                Text("Clear sky by hour" + (source.map { " · \($0)" } ?? "")).font(.system(size: 9)).foregroundStyle(Tokens.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(peak))
    }

    private func label(_ peak: HourlyConditions?) -> String {
        var s = "Clear sky by hour."
        if let p = peak { s += " Clearest \(Copy.hhmm(p.time, site: site)) at \(max(0, 100 - p.cloudTotal))% clear." }
        if let w = plan.primary { s += " Clear window \(Copy.hhmm(w.start, site: site)) to \(Copy.hhmm(w.end, site: site))." }
        return s
    }
}
