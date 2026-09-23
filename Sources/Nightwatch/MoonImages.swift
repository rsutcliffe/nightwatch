import AppKit
import SwiftUI
import SkyCore

/// Real Moon image for the hour in question, from NASA SVS Dial-a-Moon, cached per UTC hour.
enum MoonImages {
    static let dir = Store.cacheDir.appendingPathComponent("moon", isDirectory: true)

    static func image(at date: Date) async -> NSImage? {
        let file = dir.appendingPathComponent("\(MoonImage.hourKey(for: date)).jpg")
        if let img = NSImage(contentsOf: file) { return img }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fetcher = URLSessionFetcher()
        guard let meta = try? await fetcher.get(MoonImage.apiURL(for: date)),
              let info = try? MoonImage.parse(meta),
              let data = try? await fetcher.get(info.imageURL),
              let img = NSImage(data: data) else { return nil }
        try? data.write(to: file, options: .atomic)
        return img
    }
}

final class MoonLoader: ObservableObject { @Published var image: NSImage? }

/// The Moon tile of the popover: the rendered Moon for the night beside illumination and set time.
struct MoonTile: View {
    let label: String
    let value: String
    let at: Date
    @StateObject private var loader = MoonLoader()

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color(red: 0.055, green: 0.063, blue: 0.094))
                if let img = loader.image {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill).clipShape(Circle())
                } else {
                    Image(systemName: "moon").font(.caption).foregroundStyle(Theme.dim)
                }
            }.frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2).foregroundStyle(Theme.dim)
                Text(value).font(.callout.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Theme.card).clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: MoonImage.hourKey(for: at)) { loader.image = await MoonImages.image(at: at) }
    }
}
