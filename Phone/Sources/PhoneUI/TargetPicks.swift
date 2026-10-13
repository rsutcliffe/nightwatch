import SwiftUI
import SkyCore
import PhoneCore

/// The SF Symbol for a target group, as on the Mac (its `TargetGroup.symbolName` lives in the Mac-only `NightwatchUI`).
extension TargetGroup {
    var phoneSymbol: String {
        switch self {
        case .nebulae: "cloud.fill"
        case .galaxies: "hurricane"
        case .clusters: "sparkles"
        case .stars: "star.fill"
        case .planets: "circle.circle"
        case .events: "calendar"
        case .constellations: "point.3.connected.trianglepath.dotted"
        }
    }
}

/// A DSS2 survey cutout for a target, from disk when it is there and from CDS when it is not and the connection allows it.
/// Kept per object and field of view, as the Mac keeps them, and dropped when not shown for 30 days.
@MainActor
final class SurveyLoader: ObservableObject {
    @Published var data: Data?

    func load(url: URL, cacheName: String, allowDownload: Bool) async {
        let dir = ImageCache.directory("thumbs")
        let file = dir.appendingPathComponent(cacheName)
        if let cached = ImageCache.load(file) {
            data = cached
            if ThumbnailFiles.needsTouch(modified: (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date, now: .now) {
                try? FileManager.default.setAttributes([.modificationDate: Date.now], ofItemAtPath: file.path)
            }
            return
        }
        guard allowDownload else { return }
        guard let bytes = try? await URLSessionFetcher(timeout: 20).get(url), Image(platformData: bytes) != nil else { return }
        ImageCache.save(bytes, to: file)
        Self.pruneStale(in: dir)
        data = bytes
    }

    private static func pruneStale(in dir: URL) {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return }
        var modified: [String: Date] = [:]
        for n in names { modified[n] = (try? fm.attributesOfItem(atPath: dir.appendingPathComponent(n).path))?[.modificationDate] as? Date }
        for n in ThumbnailFiles.staleImages(names: names, modified: modified, now: .now) { try? fm.removeItem(at: dir.appendingPathComponent(n)) }
    }
}

/// A heic from the app's bundled artwork folders (the owner's constellation and Milky Way art, copied from the Mac app).
private func bundledArt(_ name: String, folder: String) -> Data? {
    Bundle.main.url(forResource: name, withExtension: "heic", subdirectory: folder).flatMap { try? Data(contentsOf: $0) }
}

/// A target's picture on the same dark tile the Mac uses, chosen by `TargetPick.picture`. Photographs, and only photographs,
/// are drawn in one red hue in red mode.
struct TargetPicture: View {
    let pick: TargetPick
    @StateObject private var survey = SurveyLoader()
    @StateObject private var moon = MoonLoader()
    @Environment(\.phoneTheme) private var theme
    @Environment(\.allowsOptionalDownloads) private var allowsDownloads

    private func photo(_ data: Data, fill: Bool = true) -> some View {
        Group {
            if let img = Image(platformData: data) {
                img.resizable().aspectRatio(contentMode: fill ? .fill : .fit)
                    .saturation(theme.isRed ? 0 : 1).colorMultiply(theme.isRed ? Color(hex: 0xC0180E) : .white)
            }
        }
    }

    var body: some View {
        ZStack {
            Color(hex: 0x0E1018)
            switch pick.picture {
            case .survey(let url, let name):
                if let d = survey.data { Color.clear.overlay(photo(d)).transition(.opacity) } else { symbol }
                Color.clear.task(id: name) { await survey.load(url: url, cacheName: name, allowDownload: allowsDownloads) }
            case .moon(let at):
                if let d = moon.data { Color.clear.overlay(photo(d)).transition(.opacity) } else { symbol }
                Color.clear.task(id: MoonImage.hourKey(for: at)) { await moon.load(at: at, allowDownload: allowsDownloads) }
            case .planet(let name):
                if let p = Planet(rawValue: name), let u = PlanetImages.url(for: p), let d = try? Data(contentsOf: u) { Color.clear.overlay(photo(d)) } else { symbol }
            case .constellation(let id):
                if let f = bundledArt("\(id)-figure", folder: "Constellations"), let p = bundledArt("\(id)-plot", folder: "Constellations") {
                    ZStack { art(f); art(p) }.padding(4)
                } else { symbol }
            case .milkyWay(let id):
                if let d = bundledArt(id, folder: "Events") { art(d).padding(4) } else { symbol }
            case .symbol:
                symbol
            }
        }
        .animation(.easeOut(duration: 0.3), value: survey.data != nil || moon.data != nil)
        .accessibilityHidden(true)
    }

    private func art(_ data: Data) -> some View {
        Group { if let img = Image(platformData: data) { img.resizable().aspectRatio(contentMode: .fit).opacity(theme.isRed ? 0.7 : 1)
            .saturation(theme.isRed ? 0 : 1).colorMultiply(theme.isRed ? Color(hex: 0xC0180E) : .white) } }
    }

    private var symbol: some View {
        Image(systemName: pick.group.phoneSymbol).font(.title2).foregroundStyle(theme.textSecondary)
    }
}

/// "BEST TONIGHT": the Mac popover's three tiles, a picture over the catalogue ID, the name, and when it is highest.
struct PicksSection: View {
    let model: TonightModel
    var pictureHeight: CGFloat = 78
    @Environment(\.phoneTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.allowsOptionalDownloads) private var allowsDownloads

    private var needsPhotos: Bool { model.picks.contains { if case .survey = $0.picture { true } else { false } } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.picksHeading).font(.caption.weight(.medium)).tracking(0.8).secondary()
            if let note = model.picksNote { Text(note).font(.footnote).secondary().fixedSize(horizontal: false, vertical: true) }
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
            layout {
                ForEach(model.picks) { p in
                    VStack(alignment: .leading, spacing: 3) {
                        TargetPicture(pick: p).frame(height: typeSize.isAccessibilitySize ? 150 : pictureHeight).clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(p.title).font(.footnote.weight(.bold)).lineLimit(1)
                        Text(p.line).font(.caption).secondary().lineLimit(1)
                        Text(p.best).font(.caption2.weight(.medium)).monospacedDigit().foregroundStyle(theme.bestLine).lineLimit(1).minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
            if needsPhotos && !allowsDownloads {
                Text("Target photos load only on a connection without data limits.").font(.caption2).secondary()
            }
        }
    }
}
