import SwiftUI
import SkyCore

/// Amber warning dot with a soft glow. Always sits beside a text label: colour is never the only signal.
struct WarningDot: View {
    var size: CGFloat = 5
    var body: some View {
        Circle().fill(Tokens.statusWarning).frame(width: size, height: size)
            .shadow(color: Tokens.statusWarning.opacity(0.7), radius: 2).accessibilityHidden(true)
    }
}

/// A popover stat tile: label over value, an optional amber hint, and a warning state (amber outline and dot).
/// A missing value reads "No data" in the secondary colour. Values wrap rather than truncate.
struct StatTile: View {
    let label: String
    let value: String?
    var hint: String? = nil
    var warning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundStyle(Tokens.textSecondary)
            Text(value ?? "No data").font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(value == nil ? Tokens.textSecondary : Tokens.textPrimary).fixedSize(horizontal: false, vertical: true)
            if let hint { Text(hint).font(.system(size: 9)).foregroundStyle(Tokens.statusWarning).fixedSize(horizontal: false, vertical: true) }
        }
        .padding(9).frame(maxWidth: .infinity, minHeight: 49.5, alignment: .leading)
        .overlay(alignment: .topTrailing) { if warning { WarningDot(size: 5).padding(7) } }
        .overlay { if warning { RoundedRectangle(cornerRadius: 8).stroke(Tokens.statusWarning.opacity(0.59), lineWidth: 0.75) } }
        .accessibilityElement(children: .combine)
        .nightwatchGlass(in: RoundedRectangle(cornerRadius: 8), fill: Tokens.surfaceTile, tint: Tokens.surfaceTile)
    }
}

/// Amber dot and "{n} h ago" beside any timestamp older than the six-hour stale rule.
struct StaleBadge: View {
    let fetchedAt: Date
    var body: some View {
        HStack(spacing: 4) { WarningDot(size: 5); Text(Copy.hoursAgo(fetchedAt, now: Date())) }
            .font(.system(size: 10)).foregroundStyle(Tokens.statusWarning)
            .accessibilityElement(children: .combine)
    }
}

/// A small glass chip on a card: neutral text, or amber with an icon for a warning. Never red.
struct Chip: View {
    let text: String
    var icon: String? = nil
    var warning = false
    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).accessibilityHidden(true) }
            Text(text)
        }
        .font(.system(size: 9.5, weight: .medium))
        .foregroundStyle(warning ? Tokens.statusWarning : Tokens.textPrimary)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .nightwatchGlass(in: Capsule(), fill: Color.black.opacity(0.55))
    }
}
