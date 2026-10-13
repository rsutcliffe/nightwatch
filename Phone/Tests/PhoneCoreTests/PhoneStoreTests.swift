import Testing
import Foundation
import SkyCore
@testable import PhoneCore

final class Clock: @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
}

final class Calls: @unchecked Sendable {
    var fetches = 0
    var askedPrimary: [Bool] = []
    var failing = false
    var source: String? = "Apple Weather"
}

final class FakeScheduler: NotificationScheduling, @unchecked Sendable {
    var authorised = true
    var posted: [AlertNotification] = []
    var queue: [ScheduledAlert] = []
    func isAuthorised() async -> Bool { authorised }
    func post(_ notification: AlertNotification) async { posted.append(notification) }
    func replaceScheduled(_ alerts: [ScheduledAlert]) async { queue = alerts }
}

struct Failure: Error {}

@MainActor private func makeStore(clock: Clock, calls: Calls, scheduler: FakeScheduler = FakeScheduler(), withSite: Bool = true,
                                  directory: URL = FileManager.default.temporaryDirectory.appendingPathComponent("phonestore-\(UUID().uuidString)")) -> PhoneStore {
    let store = PhoneStore(directory: directory, provider: { site, now, ask in
        calls.fetches += 1
        calls.askedPrimary.append(ask)
        if calls.failing { throw Failure() }
        return forecast(fetchedAt: now, source: calls.source, site: site)
    }, scheduler: scheduler, clock: { clock.now })
    if withSite {
        store.config.sites = [sheffield]
        store.config.activeSiteName = "Sheffield"
    }
    return store
}

@MainActor @Test func withNoSiteThePageAsksWhereYouObserveFrom() async {
    let store = makeStore(clock: Clock(utc(2026, 9, 23, 12)), calls: Calls(), withSite: false)
    await store.refresh()
    #expect(store.phase == .needsSite)
    #expect(store.tonight == nil)
}

@MainActor @Test func theFirstRefreshFetchesAndBuildsTonight() async {
    let calls = Calls()
    let store = makeStore(clock: Clock(utc(2026, 9, 23, 12)), calls: calls)
    await store.refresh()
    #expect(calls.fetches == 1)
    #expect(store.phase == .ready)
    #expect(store.tonight?.snapshot.headline == "Clear window tonight")
    #expect(store.offline == false)
}

@MainActor @Test func aFreshForecastIsNotFetchedAgainUnlessAskedFor() async {
    let clock = Clock(utc(2026, 9, 23, 12)), calls = Calls()
    let store = makeStore(clock: clock, calls: calls)
    await store.refresh()
    clock.now = clock.now.addingTimeInterval(10 * 60)
    await store.refresh()
    #expect(calls.fetches == 1)
    await store.refresh(force: true)
    #expect(calls.fetches == 2)
    clock.now = clock.now.addingTimeInterval(45 * 60)
    await store.refresh()
    #expect(calls.fetches == 3)
}

@MainActor @Test func theForecastSurvivesARestart() async {
    let clock = Clock(utc(2026, 9, 23, 12)), calls = Calls()
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("phonestore-\(UUID().uuidString)")
    let first = makeStore(clock: clock, calls: calls, directory: dir)
    first.saveConfig()
    await first.refresh()
    let second = makeStore(clock: clock, calls: calls, withSite: false, directory: dir)
    await second.refresh(connectivity: .offline)
    #expect(second.phase == .ready)   // config and forecast came back from disk, and no connection was needed
    #expect(second.offline)
    #expect(second.tonight != nil)
    #expect(calls.fetches == 1)
}

@MainActor @Test func noConnectionWithNothingSavedSaysSo() async {
    let calls = Calls()
    let store = makeStore(clock: Clock(utc(2026, 9, 23, 12)), calls: calls)
    await store.refresh(connectivity: .offline)
    #expect(calls.fetches == 0)
    if case .failed(let message) = store.phase { #expect(message.contains("no forecast saved")) } else { Issue.record("expected a failure") }
}

@MainActor @Test func aFailedFetchKeepsTheSavedAnswerAndFlagsItOffline() async {
    let clock = Clock(utc(2026, 9, 23, 12)), calls = Calls()
    let store = makeStore(clock: clock, calls: calls)
    await store.refresh()
    calls.failing = true
    clock.now = clock.now.addingTimeInterval(60 * 60)
    await store.refresh()
    #expect(store.offline)
    #expect(store.phase == .ready)
    #expect(store.tonight != nil)
}

@MainActor @Test func aRefusalFromAppleWeatherIsLeftAloneForFiveMinutes() async {
    let clock = Clock(utc(2026, 9, 23, 12)), calls = Calls()
    calls.source = "Open-Meteo"   // Apple Weather did not answer
    let store = makeStore(clock: clock, calls: calls)
    await store.refresh()
    #expect(calls.askedPrimary == [true])
    clock.now = clock.now.addingTimeInterval(2 * 60)
    await store.refresh(force: true)
    #expect(calls.askedPrimary == [true, false])
    clock.now = clock.now.addingTimeInterval(4 * 60)
    await store.refresh(force: true)
    #expect(calls.askedPrimary == [true, false, true])
}

@MainActor @Test func alertsAreQueuedOnlyWhenAllowed() async throws {
    let clock = Clock(utc(2026, 9, 23, 12)), calls = Calls(), scheduler = FakeScheduler()
    let store = makeStore(clock: clock, calls: calls, scheduler: scheduler)
    scheduler.authorised = false
    await store.refresh()
    #expect(scheduler.queue.isEmpty)
    scheduler.authorised = true
    await store.refresh(force: true)
    // Opened at 13:00 BST, the heads-up (about 17:50 BST) is inside the six-hour freshness rule and is queued. The pre-window
    // nudge would fire more than six hours after this forecast was fetched, so it waits for a later refresh.
    #expect(scheduler.queue.map(\.kind) == ["headsUp"])
    store.config.notifyEnabled = false
    scheduler.queue = []
    await store.refresh(force: true)
    #expect(scheduler.queue.isEmpty)   // switched off in Settings: nothing is queued
}

@MainActor @Test func aHeadsUpDueWhenTheAppOpensIsPostedOnceOnly() async throws {
    let p = try plans()
    let due = AlertEngine.dueTimes(tonight: p.tonight, settings: AlertSettings())
    let clock = Clock(due[0].addingTimeInterval(120)), calls = Calls(), scheduler = FakeScheduler()
    let store = makeStore(clock: clock, calls: calls, scheduler: scheduler)
    await store.refresh()
    #expect(scheduler.posted.map(\.kind) == [.headsUp])
    clock.now = clock.now.addingTimeInterval(60)
    await store.refresh(force: true)
    #expect(scheduler.posted.count == 1)   // not sent again on the next refresh
}
