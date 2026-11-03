import Foundation
import Testing
@testable import SkyCore

@Suite struct ReviewPromptTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    func window(_ start: Date) -> ClearWindow { ClearWindow(start: start, end: start.addingTimeInterval(4 * 3600)) }

    @Test func notAskedBeforeThreeDifferentNights() {
        var p = ReviewPrompt()
        #expect(p.opened(onNight: "a", now: t0) == false)
        #expect(p.opened(onNight: "a", now: t0.addingTimeInterval(60)) == false)   // the same night again does not count
        #expect(p.opened(onNight: "b", now: t0) == false)
    }

    @Test func askedOnTheThirdNightThenLeftAloneFor120Days() {
        var p = ReviewPrompt()
        _ = p.opened(onNight: "a", now: t0); _ = p.opened(onNight: "b", now: t0)
        #expect(p.opened(onNight: "c", now: t0) == true)
        for n in ["d", "e", "f", "g"] { #expect(p.opened(onNight: n, now: t0.addingTimeInterval(86_400 * 30)) == false) }
        let later = t0.addingTimeInterval(ReviewPrompt.minimumGap + 1)
        #expect(p.opened(onNight: "h", now: later) == false)
        #expect(p.opened(onNight: "i", now: later) == false)
        #expect(p.opened(onNight: "j", now: later) == true)   // three new nights after the gap
    }

    @Test func aNightCountsOnlyInsideTheClearWindowOfAQualifyingDarkPlan() {
        let w = window(t0)
        let inside = t0.addingTimeInterval(3600)
        #expect(ReviewPrompt.clearNight(mode: .dark, qualifies: true, primary: w, now: inside) != nil)
        #expect(ReviewPrompt.clearNight(mode: .dark, qualifies: true, primary: w, now: t0.addingTimeInterval(-60)) == nil)
        #expect(ReviewPrompt.clearNight(mode: .dark, qualifies: true, primary: w, now: w.end) == nil)
        #expect(ReviewPrompt.clearNight(mode: .dark, qualifies: false, primary: w, now: inside) == nil)
        #expect(ReviewPrompt.clearNight(mode: .dark, qualifies: true, primary: nil, now: inside) == nil)
        #expect(ReviewPrompt.clearNight(mode: .dark, qualifies: true, primary: w, now: inside) == ReviewPrompt.clearNight(mode: .dark, qualifies: true, primary: w, now: inside.addingTimeInterval(600)))
        #expect(ReviewPrompt.clearNight(mode: .dark, qualifies: true, primary: w, now: inside) != ReviewPrompt.clearNight(mode: .dark, qualifies: true, primary: window(t0.addingTimeInterval(86_400)), now: inside.addingTimeInterval(86_400)))
    }

    @Test func theStateSurvivesBetweenLaunches() throws {
        let suite = UserDefaults(suiteName: "reviewprompt-\(UUID())")!
        var p = ReviewPrompt()
        _ = p.opened(onNight: "a", now: t0); _ = p.opened(onNight: "b", now: t0)
        suite.set(try JSONEncoder().encode(p), forKey: "reviewPrompt")
        let back = try JSONDecoder().decode(ReviewPrompt.self, from: suite.data(forKey: "reviewPrompt")!)
        var again = back
        #expect(again.opened(onNight: "c", now: t0) == true)
    }
}
