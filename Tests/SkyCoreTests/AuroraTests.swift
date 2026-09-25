import Testing
import Foundation
@testable import SkyCore

private let testSite = Site(name: "Test site", latitude: 54.0, longitude: -1.5, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
private let copy = Copy(flavour: .watch)

private func xml(_ level: String) -> Data {
    Data("""
    <?xml version='1.0' encoding='UTF-8' standalone='yes'?>
    <!DOCTYPE current_status PUBLIC "-//AuroraWatch-API//DTD REST 0.2.5//EN" "http://aurorawatch-api.lancs.ac.uk/0.2.5/aurorawatch-api.dtd">
    <current_status api_version="0.2.5"><updated><datetime>2026-09-24T20:33:32+0000</datetime></updated><site_status project_id="project:AWN" site_id="site:AWN:SUM" site_url="http://aurorawatch-api.lancs.ac.uk/0.2.5/project/awn/sum.xml" status_id="\(level)"/></current_status>
    """.utf8)
}

@Test func auroraWatchParsesEveryLevelAndTheTime() throws {
    for l in AuroraLevel.allCases {
        let s = try AuroraWatch.parse(xml(l.rawValue))
        #expect(s.level == l)
        #expect(s.updated == utc(2026, 9, 24, 20, 33).addingTimeInterval(32))
    }
    #expect(throws: (any Error).self) { try AuroraWatch.parse(Data("<current_status/>".utf8)) }
    #expect(AuroraLevel.green < .yellow && .yellow < .amber && .amber < .red)
}

private func hours(at t0: Date, cloud: Int) -> [HourlyConditions] {
    [HourlyConditions(time: t0, cloudTotal: cloud, cloudLow: nil, cloudMid: nil, cloudHigh: nil, tempC: nil, dewPointC: nil, humidityPct: nil,
                      windKmh: nil, gustKmh: nil, visibilityM: nil, seeing: nil, transparency: nil)]
}
private var on: AuroraSettings { var a = AuroraSettings(); a.enabled = true; return a }

@Test func auroraAlertRule() throws {
    let now = utc(2026, 9, 24, 22, 10)           // 23:10 BST: Sun far below -12 deg, outside default quiet hours
    let hr = hours(at: utc(2026, 9, 24, 22, 0), cloud: 10)
    func decide(_ level: AuroraLevel, at t: Date = now, hours h: [HourlyConditions]? = nil, settings: AuroraSettings? = nil, state: AuroraAlertState? = nil) -> (AlertNotification?, AuroraAlertState) {
        let r = AuroraAlert.decide(status: AuroraStatus(level: level, updated: t), now: t, site: testSite, nightKey: "2026-09-24", hours: h ?? hr,
                                   rule: GoRule(), settings: settings ?? on, alerts: AlertSettings(), state: state, copy: copy)
        return (r.notification, r.state)
    }
    #expect(decide(.amber, settings: AuroraSettings()).0 == nil)          // disabled
    #expect(decide(.yellow).0 == nil)                                     // below the amber threshold
    let (n, s) = decide(.amber)
    let note = try #require(n)
    #expect(note.kind == .aurora)
    #expect(note.title == "Aurora alert: amber · clear at Test site now")
    #expect(note.body == "AuroraWatch UK reports amber. Cloud 10% this hour.")
    #expect(decide(.amber, state: s).0 == nil)                            // once per level per night
    #expect(decide(.red, state: s).0?.title == "Aurora alert: red · clear at Test site now")   // a rise fires again
    #expect(decide(.amber, at: utc(2026, 9, 24, 13, 0), hours: hours(at: utc(2026, 9, 24, 13, 0), cloud: 10)).0 == nil)   // daylight
    #expect(decide(.amber, hours: hours(at: utc(2026, 9, 24, 22, 0), cloud: 80)).0 == nil)   // cloudy
    #expect(decide(.amber, hours: []).0 == nil)                           // no forecast for this hour
    #expect(decide(.amber, at: utc(2026, 9, 24, 23, 30), hours: hours(at: utc(2026, 9, 24, 23, 0), cloud: 10)).0 == nil)   // 00:30 BST, quiet hours
    let old = AuroraAlertState(nightKey: "2026-09-23", lastLevel: .red)
    #expect(decide(.amber, state: old).0 != nil)                          // a new night resets
}

@Test func auroraSettingsDecodeLeniently() throws {
    #expect(Config.default.aurora == AuroraSettings())
    #expect(!AuroraSettings().enabled && AuroraSettings().threshold == .amber)
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("config.json")
    try Data(#"{"aurora":{"enabled":true,"threshold":"purple"}}"#.utf8).write(to: url)
    let c = try ConfigStore.load(from: url)
    #expect(c.aurora.enabled && c.aurora.threshold == .amber)
    try Data(#"{"sites":[]}"#.utf8).write(to: url)
    #expect(try ConfigStore.load(from: url).aurora == AuroraSettings())
}

@Test func auroraStatusFromAnEarlierNightNeverAlerts() {
    let now = utc(2026, 9, 24, 22, 10)
    let stale = AuroraStatus(level: .red, updated: now.addingTimeInterval(-15 * 3600))   // cached at dawn, Mac woke offline
    let r = AuroraAlert.decide(status: stale, now: now, site: testSite, nightKey: "2026-09-24", hours: hours(at: utc(2026, 9, 24, 22, 0), cloud: 10),
                               rule: GoRule(), settings: on, alerts: AlertSettings(), state: nil, copy: copy)
    #expect(r.notification == nil)
}

@Test func auroraThresholdIsNeverBelowYellow() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("config.json")
    try Data(#"{"aurora":{"enabled":true,"threshold":"green"}}"#.utf8).write(to: url)
    #expect(try ConfigStore.load(from: url).aurora.threshold == .yellow)
}

/// AuroraWatch UK's own colours, from https://aurorawatch-api.lancs.ac.uk/0.2/status-descriptions.xml (owner ruling
/// 25 September 2026: the popover uses them as published).
@Test func auroraLevelsUseAuroraWatchColours() {
    #expect(AuroraLevel.allCases.map(\.hex) == [0x33FF33, 0xFFFF00, 0xFF9900, 0xFF0000])
}
