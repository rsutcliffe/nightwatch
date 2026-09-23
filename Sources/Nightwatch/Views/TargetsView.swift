import SwiftUI
import SkyCore

struct TargetsView: View { var body: some View { Text("Targets") } }

struct ThumbnailView: View {
    let target: RankedTarget
    var body: some View { RoundedRectangle(cornerRadius: 8).fill(Theme.card).overlay(Image(systemName: Theme.glyph(for: target.group)).foregroundStyle(Theme.dim)) }
}
