//
//  NotificationManager.swift
//  LUMEN
//
//  Schedules the AM/PM ritual reminders via UserNotifications.
//

import Foundation
import UserNotifications

@MainActor
enum NotificationManager {

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func scheduleReminders(wake: Date, windDown: Date, enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["lumen.am", "lumen.pm"])
        guard enabled else { return }

        schedule(id: "lumen.am", date: wake,
                 title: "Your morning ritual awaits",
                 body: "A few quiet minutes for yourself before the day begins.")
        schedule(id: "lumen.pm", date: windDown,
                 title: "Time to wind down",
                 body: "Close the day with your evening ritual.")
    }

    private static func schedule(id: String, date: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
