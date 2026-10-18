import Foundation

/// The pieces of the Tonight hero, cut from wording that already exists: the snapshot's window ("20:11-05:38 · 9.4 h") and the
/// tiles. Nothing here is new wording beyond joining and lower-casing, so it stays the Mac's wording.
public struct TonightHero: Equatable, Sendable {
    /// "20:11-05:38".
    public var times: String?
    /// "9.4 hours".
    public var hours: String?
    /// "medium dew risk", or "frost likely" when the night drops to 0 degrees. Nil when there is no dew figure.
    public var dewLine: String?
    /// "Moon down tonight", or "Moon 35% · Sets 20:36": the Moon note under the clear-hours line.
    public var moonNote: String
    /// "Seeing 0.5-0.75" · Wind 10 km/h · Transparency good": what the fainter tiles said, as one line. Empty when none is known.
    public var conditions: String

    public static func make(window: String?, tiles: TonightTiles) -> TonightHero {
        var times: String?, hours: String?
        if let window {
            let parts = window.components(separatedBy: " · ")
            times = parts.first
            hours = parts.dropFirst().first.map { $0.hasSuffix(" h") ? String($0.dropLast(2)) + " hours" : $0 }
        }
        let dewLine = tiles.dewLabel == "Frost likely" ? "frost likely" : tiles.dew.map { "\($0.lowercased()) dew risk" }
        let conditions = [tiles.seeing.map { "Seeing \($0)" },
                          tiles.wind.map { "Wind \($0)" },
                          tiles.transparency.map { "Transparency \($0.lowercased())" }]
            .compactMap { $0 }.joined(separator: " · ")
        let moonNote = tiles.moon == "Down" ? "Moon down tonight" : "Moon \(tiles.moon)" + (tiles.moonLine.map { " · \($0)" } ?? "")
        return TonightHero(times: times, hours: hours, dewLine: dewLine, moonNote: moonNote, conditions: conditions)
    }
}

extension TonightModel {
    public var hero: TonightHero { TonightHero.make(window: snapshot.window, tiles: tiles) }
}
