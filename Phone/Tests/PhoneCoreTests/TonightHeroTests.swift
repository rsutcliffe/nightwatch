import Testing
import Foundation
@testable import PhoneCore

private func tiles(seeing: String? = "0.5-0.75\"", wind: String? = "10 km/h", dewLabel: String = "Dew risk", dew: String? = "Medium",
                   transparency: String? = "Good") -> TonightTiles {
    TonightTiles(dark: "20:11-05:38", moon: "Down", moonLine: "tonight", seeing: seeing, wind: wind, dewLabel: dewLabel, dew: dew,
                 dewHint: nil, transparency: transparency, moonAt: nil)
}

@Test func theHeroSplitsTheWindowAndJoinsTheConditions() {
    let h = TonightHero.make(window: "20:11-05:38 · 9.4 h", tiles: tiles())
    #expect(h.times == "20:11-05:38")
    #expect(h.hours == "9.4 hours")
    #expect(h.dewLine == "medium dew risk")
    #expect(h.moonNote == "Moon down tonight")
    #expect(h.conditions == "Seeing 0.5-0.75\" · Wind 10 km/h · Transparency good")
}

@Test func aNightWithoutAWindowHasNoTimesOrHours() {
    let h = TonightHero.make(window: nil, tiles: tiles())
    #expect(h.times == nil && h.hours == nil)
}

@Test func frostReplacesTheDewLineAndMissingFiguresAreLeftOut() {
    let h = TonightHero.make(window: "21:00-04:00 · 7.0 h", tiles: tiles(seeing: nil, wind: nil, dewLabel: "Frost likely", dew: "Low", transparency: "Fair"))
    #expect(h.dewLine == "frost likely")
    #expect(h.conditions == "Transparency fair")
    #expect(TonightHero.make(window: nil, tiles: tiles(seeing: nil, wind: nil, dew: nil, transparency: nil)).conditions.isEmpty)
}

@Test func aLitMoonNamesItsPhaseAndWhenItSets() {
    var t = tiles()
    t.moon = "35%"; t.moonLine = "Sets 20:36"
    #expect(TonightHero.make(window: nil, tiles: t).moonNote == "Moon 35% · Sets 20:36")
}
