#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import SwiftUI

/// SPIKE (25 October 2026): the clear window as a Live Activity. Static facts in the attributes, nothing in the content state
/// that needs a server: the countdown is drawn by the system from the two dates, so it stays right with the app closed.
public struct ClearWindowAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var score: Int
        public var headline: String
        public init(score: Int, headline: String) { self.score = score; self.headline = headline }
    }
    public var siteName: String
    public var windowStart: Date
    public var windowEnd: Date
    public init(siteName: String, windowStart: Date, windowEnd: Date) {
        self.siteName = siteName; self.windowStart = windowStart; self.windowEnd = windowEnd
    }
}

/// The Lock Screen and StandBy card.
public struct ClearWindowLockView: View {
    let attributes: ClearWindowAttributes
    let state: ClearWindowAttributes.ContentState
    /// True from the content's stale date, which the system applies by itself: this is how the card says the window is over with no app running.
    let isStale: Bool
    public init(attributes: ClearWindowAttributes, state: ClearWindowAttributes.ContentState, isStale: Bool = false) {
        self.attributes = attributes; self.state = state; self.isStale = isStale
    }
    private let lit = Color(red: 0.957, green: 0.945, blue: 0.918)
    public var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("\(state.score)").font(.system(size: 40, weight: .bold)).monospacedDigit().foregroundStyle(lit)
            VStack(alignment: .leading, spacing: 2) {
                Text(attributes.siteName.uppercased()).font(.caption2.weight(.semibold)).tracking(1.4).foregroundStyle(.secondary).lineLimit(1)
                Text(state.headline).font(.subheadline.weight(.heavy)).foregroundStyle(lit).lineLimit(1)
                if isStale {
                    Text("Clear window over").font(.caption).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Text("clear for").font(.caption).foregroundStyle(.secondary)
                        Text(timerInterval: attributes.windowStart...attributes.windowEnd, countsDown: true)
                            .font(.caption.weight(.medium)).monospacedDigit().foregroundStyle(lit)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }
}
#endif
