import UserNotifications
import SkyCore

enum Notifier {
    static func requestAuthorisation() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func post(_ n: AlertNotification) {
        let content = UNMutableNotificationContent()
        content.title = n.title
        content.body = n.body
        content.sound = n.kind == .go || n.kind == .aurora ? .default : nil   // aurora is brief: worth a sound (v0.6.6)
        let req = UNNotificationRequest(identifier: "nightwatch-\(n.kind)-\(Int(Date().timeIntervalSince1970))", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
