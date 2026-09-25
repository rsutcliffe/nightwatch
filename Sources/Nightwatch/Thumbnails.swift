import AppKit
import SwiftUI
import SkyCore

/// DSS2 colour cutouts from CDS hips2fits at the user's field of view (or 1.5 × the object when it is bigger), cached forever per object and FOV.
enum Thumbnails {
    static let dir = Store.cacheDir.appendingPathComponent("thumbs", isDirectory: true)

    static func fovDeg(for t: RankedTarget, fov: FieldOfView) -> Double {
        let objectDeg = (t.sizeArcmin ?? 0) / 60
        return max(fov.widthDeg, objectDeg * 1.5, 0.05)
    }

    static func url(for t: RankedTarget, fov: FieldOfView) -> URL {
        var c = URLComponents(string: "https://alasky.cds.unistra.fr/hips-image-services/hips2fits")!
        let f = fovDeg(for: t, fov: fov)
        c.queryItems = [
            .init(name: "hips", value: "CDS/P/DSS2/color"),
            .init(name: "ra", value: String(format: "%.5f", t.raHours * 15)),
            .init(name: "dec", value: String(format: "%.5f", t.decDeg)),
            .init(name: "fov", value: String(format: "%.3f", f)),
            .init(name: "width", value: "480"),
            .init(name: "height", value: String(Int(480 * max(0.05, fov.heightDeg) / max(0.05, fov.widthDeg)))),
            .init(name: "projection", value: "TAN"),
            .init(name: "format", value: "jpg")
        ]
        return c.url!
    }

    static func file(for t: RankedTarget, fov: FieldOfView) -> URL {
        dir.appendingPathComponent("\(t.id)-\(String(format: "%.2fx%.2f", fov.widthDeg, fov.heightDeg)).jpg")
    }

    static func image(for t: RankedTarget, fov: FieldOfView) async -> NSImage? {
        // Planets and the Moon get real photographs, not a survey cutout.
        if t.id == "moon" { return await MoonImages.image(at: t.peakTime) }
        if let p = PlanetImages.planet(forTargetID: t.id) { return PlanetImages.url(for: p).flatMap { NSImage(contentsOf: $0) } }
        guard t.group != .constellations, t.group != .planets else { return nil }
        let f = file(for: t, fov: fov)
        if let img = NSImage(contentsOf: f) { return img }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? await URLSessionFetcher().get(url(for: t, fov: fov)), let img = NSImage(data: data) else { return nil }
        try? data.write(to: f, options: .atomic)
        return img
    }
}

/// `art`: a constellation's artwork, loaded once per card in the same task as the photo thumbnails, never in `body`.
final class ThumbnailLoader: ObservableObject {
    @Published var image: NSImage?
    @Published var art: ConstellationArt?
}

struct ThumbnailView: View {
    @EnvironmentObject var store: Store
    let target: RankedTarget
    @StateObject private var loader = ThumbnailLoader()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.055, green: 0.063, blue: 0.094))
            if let image = loader.image {
                // The image lives in an overlay so its natural size never widens the layout; the card decides the size.
                Color.clear
                    .overlay(Image(nsImage: image).resizable().aspectRatio(contentMode: .fill))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let art = loader.art {
                art.padding(4)
            } else {
                Image(systemName: Theme.glyph(for: target.group)).font(.title2).foregroundStyle(Theme.dim)
            }
        }
        .task(id: target.id) {
            if target.group == .constellations { loader.art = ConstellationArt(id: target.id); return }
            loader.image = await Thumbnails.image(for: target, fov: store.config.fov)
        }
    }
}

/// The owner's constellation artwork (v0.6.2): the figure with its star plot on top, fitted rather than cropped.
/// The build copies Resources/Constellations into the app; `scripts/import-constellations.sh` makes the files.
struct ConstellationArt: View {
    let figure: NSImage
    let plot: NSImage

    init?(id: String) {
        func layer(_ name: String) -> NSImage? {
            Bundle.main.url(forResource: "\(id)-\(name)", withExtension: "heic", subdirectory: "Constellations").flatMap(NSImage.init(contentsOf:))
        }
        guard let f = layer("figure"), let p = layer("plot") else { return nil }
        figure = f; plot = p
    }

    var body: some View {
        ZStack {
            Image(nsImage: figure).resizable().aspectRatio(contentMode: .fit)
            Image(nsImage: plot).resizable().aspectRatio(contentMode: .fit)
        }
        .accessibilityHidden(true)
    }
}
