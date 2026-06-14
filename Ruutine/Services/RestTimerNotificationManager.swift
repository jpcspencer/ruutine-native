import UserNotifications

enum RestTimerNotificationManager {
    static let notificationID = "ruutine.rest-timer.end"

    static func scheduleRestEnd(at endDate: Date) {
        Task {
            guard await requestAuthorizationIfNeeded() else { return }

            let interval = endDate.timeIntervalSinceNow
            guard interval > 0 else { return }

            let content = UNMutableNotificationContent()
            content.title = "Rest over — time for your next set."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: notificationID,
                content: content,
                trigger: trigger
            )

            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [notificationID])
            try? await center.add(request)
        }
    }

    static func cancelRestEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationID]
        )
    }

    private static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }
}
