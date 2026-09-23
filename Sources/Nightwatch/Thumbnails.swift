import AppKit
import SwiftUI
import SkyCore

/// DSS2 colour cutouts from CDS hips2fits at the user's field of view (or 1.5 × the object when it is bigger), cached forever per object and FOV.
enum Thumbnails {
    static let dir = Store.cacheDir.appendingPathComponent("thumbs", isDirectory: true)

    static func fovDeg(for t: RankedTarget, fov: FieldOfView) -> Double {
        let objectDeg = (t.sizeArcmin ?? 0) / 60
        return max(fov.widthDeg, objectDeg * 1.5)
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
            .init(name: "height", value: String(Int(480 * fov.heightDeg / fov.widthDeg))),
            .init(name: "projection", value: "TAN"),
            .init(name: "format", value: "jpg")
        ]
        return c.url!
    }

    static func file(for t: RankedTarget, fov: FieldOfView) -> URL {
        dir.appendingPathComponent("\(t.id)-\(String(format: "%.2fx%.2f", fov.widthDeg, fov.heightDeg)).jpg")
    }

    static func image(for t: RankedTarget, fov: FieldOfView) async -> NSImage? {
        guard t.group != .constellations, t.group != .planets else { return nil }
        let f = file(for: t, fov: fov)
        if let img = NSImage(contentsOf: f) { return img }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? await URLSessionFetcher().get(url(for: t, fov: fov)), let img = NSImage(data: data) else { return nil }
        try? data.write(to: f, options: .atomic)
        return img
    }
}

final class ThumbnailLoader: ObservableObject { @Published var image: NSImage? }

struct ThumbnailView: View {
    @EnvironmentObject var store: Store
    let target: RankedTarget
    @StateObject private var loader = ThumbnailLoader()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.055, green: 0.063, blue: 0.094))
            if let image = loader.image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill).clipShape(RoundedRectangle(cornerRadius: 8))
            } else if target.group == .constellations, let c = store.constellation(target.id) {
                ConstellationFigure(constellation: c).padding(6)
            } else {
                Image(systemName: Theme.glyph(for: target.group)).font(.title2).foregroundStyle(Theme.dim)
            }
        }
        .task(id: target.id) { loader.image = await Thumbnails.image(for: target, fov: store.config.fov) }
    }
}

/// Stick figure drawn from the d3-celestial polylines, normalised into the view.
struct ConstellationFigure: View {
    let constellation: Constellation
    var body: some View {
        GeometryReader { g in
            let pts = constellation.lines.flatMap { $0 }
            let ras = pts.map { $0[0] }, decs = pts.map { $0[1] }
            if let minRA = ras.min(), let maxRA = ras.max(), let minDec = decs.min(), let maxDec = decs.max(), maxRA > minRA, maxDec > minDec {
                Path { p in
                    for line in constellation.lines {
                        for (i, pt) in line.enumerated() {
                            let x = g.size.width * (1 - (pt[0] - minRA) / (maxRA - minRA))   // RA increases to the left
                            let y = g.size.height * (1 - (pt[1] - minDec) / (maxDec - minDec))
                            i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }.stroke(Theme.accent.opacity(0.8), lineWidth: 1)
            }
        }
    }
}
