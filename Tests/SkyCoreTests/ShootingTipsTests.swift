import Testing
import Foundation
@testable import SkyCore

private let site = Site(name: "Test site", latitude: 54.0, longitude: -1.5, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
private func target(_ id: String, _ group: TargetGroup, _ type: String) -> RankedTarget {
    var t = RankedTarget(id: id, name: id, subtitle: "", group: group, raHours: 0, decDeg: 0, sizeArcmin: 10, magnitude: 8, fit: .fits,
                         peakAltDeg: 70, peakTime: utc(2026, 9, 26, 0, 30), moonSepDeg: 60, moonWashed: false, visibleFraction: 1)
    t.typeName = type
    t.viewable = ClearWindow(start: utc(2026, 9, 25, 22, 0), end: utc(2026, 9, 26, 3, 0))
    return t
}

@Test func dwarfTipsFollowTheManualAndTheWindow() {
    let tip = ShootingTips.tip(for: target("NGC0281", .nebulae, "Emission nebula"), presetID: "dwarf-mini", presetName: "DwarfLab DWARF Mini", stackMinutes: 180, site: site)
    #expect(tip.title == "How to shoot this with your DwarfLab DWARF Mini")
    #expect(tip.rows.first { $0.label == "Filter" }?.text.hasPrefix("Duo-Band") == true)
    #expect(tip.rows.first { $0.label == "Exposure" }?.text == "15–60 s per frame at gain 60–80 (try 30 s).")
    #expect(tip.rows.first { $0.label == "Frames" }?.text == "200–400 recommended; 360 × 30 s fills 3 h of tonight's window.")
    #expect(tip.rows.last?.text == "Start at 23:00, when it is clear and high enough; it is best at 01:30.")
    #expect(tip.source == "Settings from DWARFLAB's user manual.")
    let galaxy = ShootingTips.tip(for: target("NGC0224", .galaxies, "Galaxy"), presetID: "dwarf-3", presetName: "DwarfLab DWARF 3", stackMinutes: 90, site: site)
    #expect(galaxy.rows.first { $0.label == "Filter" }?.text.hasPrefix("Astro") == true)
    #expect(galaxy.rows.first { $0.label == "Frames" }?.text == "200–400 recommended; 180 × 30 s fills 1.5 h of tonight's window.")
}

@Test func seestarSwitchesItsFilterByTheKindOfLight() {
    let em = ShootingTips.tip(for: target("NGC7000", .nebulae, "Emission nebula"), presetID: "seestar-s50", presetName: "ZWO Seestar S50", stackMinutes: 60, site: site)
    #expect(em.rows.first { $0.label == "Filter" }?.text.hasPrefix("Light-pollution filter on") == true)
    #expect(em.rows.first { $0.label == "Frames" }?.text.contains("about 360 frames") == true)
    let cl = ShootingTips.tip(for: target("M13", .clusters, "Globular cluster"), presetID: "seestar-s50", presetName: "ZWO Seestar S50", stackMinutes: 60, site: site)
    #expect(cl.rows.first { $0.label == "Filter" }?.text.hasPrefix("Light-pollution filter off") == true)
}

@Test func noNumbersWithoutAVerifiedSource() {
    let planet = ShootingTips.tip(for: target("planet-saturn", .planets, "Planet"), presetID: "dwarf-mini", presetName: "DwarfLab DWARF Mini", stackMinutes: 180, site: site)
    #expect(planet.source == nil && !planet.rows.contains { $0.label == "Exposure" })
    let noWindow = ShootingTips.tip(for: target("NGC0281", .nebulae, "Emission nebula"), presetID: "dwarf-mini", presetName: "DwarfLab DWARF Mini", stackMinutes: nil, site: site)
    #expect(noWindow.rows.first { $0.label == "Frames" }?.text == "200–400 recommended.")
    let custom = ShootingTips.tip(for: target("NGC0281", .nebulae, "Nebula"), presetID: nil, presetName: nil, stackMinutes: 120, site: site)
    #expect(custom.title == "How to shoot this with your telescope" && custom.source == nil)
    #expect(custom.rows.first { $0.label == "Filter" }?.text.contains("if it glows red") == true)
}

@Test func releaseCheckComparesVersionsNumerically() {
    #expect(ReleaseCheck.isNewer("0.6.7", than: "0.6.6") && ReleaseCheck.isNewer("0.10.0", than: "0.9.1") && ReleaseCheck.isNewer("1.0", than: "0.9.9"))
    #expect(!ReleaseCheck.isNewer("0.6.6", than: "0.6.6") && !ReleaseCheck.isNewer("0.6.5", than: "0.6.6") && !ReleaseCheck.isNewer("0.6", than: "0.6.0"))
    let json = #"{"tag_name":"v0.6.7","html_url":"https://github.com/rsutcliffe/nightwatch/releases/tag/v0.6.7","draft":false,"prerelease":false}"#
    #expect(ReleaseCheck.parse(Data(json.utf8)) == ReleaseCheck.Latest(version: "0.6.7", url: URL(string: "https://github.com/rsutcliffe/nightwatch/releases/tag/v0.6.7")!))
    #expect(ReleaseCheck.parse(Data(#"{"tag_name":"v0.7.0","html_url":"https://x","prerelease":true}"#.utf8)) == nil)
    #expect(ReleaseCheck.parse(Data("not json".utf8)) == nil)
}

@Test func newConfigsWelcomeButOldOnesDoNot() throws {
    #expect(!Config().welcomed && Config().checkForUpdates)
    let old = try JSONDecoder().decode(Config.self, from: Data(#"{"sites":[]}"#.utf8))
    #expect(old.welcomed && old.checkForUpdates)
}
