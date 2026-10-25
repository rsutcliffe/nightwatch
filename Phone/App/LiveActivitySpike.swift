import ActivityKit
import Foundation
import PhoneCore
import PhoneWidgetUI

/// SPIKE (25 October 2026): does a Live Activity start on a schedule, with the app closed and no server, and what happens at the
/// end of the window? Driven by launch arguments only, never by the real alert code:
///   -spikeLiveActivity   schedule one to start in 40 s and run for 120 s
///   -spikeReport         print every Live Activity this app holds, with its state
/// Everything is read from the console: `log show --predicate 'eventMessage CONTAINS "LASpike"'`.
enum LiveActivitySpike {
    static func schedule(startIn: TimeInterval = 30, window: TimeInterval = 60) {
        guard #available(iOS 26.0, *) else { NSLog("LASpike: scheduled start needs iOS 26"); return }   // the app supports iOS 17
        let info = ActivityAuthorizationInfo()
        NSLog("LASpike enabled=\(info.areActivitiesEnabled)")
        guard info.areActivitiesEnabled else { return }
        let start = Date().addingTimeInterval(startIn), end = start.addingTimeInterval(window)
        let attributes = ClearWindowAttributes(siteName: DemoData.site.name, windowStart: start, windowEnd: end)
        let state = ClearWindowAttributes.ContentState(score: 78, headline: "Clear window tonight")
        let alert = AlertConfiguration(title: "Clear window starts", body: "Score 78, clear for two minutes", sound: .default)
        do {
            let activity = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: end), pushType: nil,
                                                style: .standard, alertConfiguration: alert, start: start)
            NSLog("LASpike requested id=\(activity.id) state=\(activity.activityState) start=\(start) end=\(end)")
            Task { for await s in activity.activityStateUpdates { NSLog("LASpike state -> \(s) at \(Date())") } }
        } catch { NSLog("LASpike request failed: \(String(reflecting: error))") }
    }

    static func report() {
        let all = Activity<ClearWindowAttributes>.activities
        NSLog("LASpike report: \(all.count) activities at \(Date())")
        for a in all { NSLog("LASpike report id=\(a.id) state=\(a.activityState) end=\(a.attributes.windowEnd)") }
    }
}
