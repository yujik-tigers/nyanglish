//
//  AttendanceNotificationScheduler.swift
//  Nyanglish
//
//  Created by OpenAI on 5/25/26.
//

import Foundation
import UserNotifications

enum AttendanceNotificationScheduler {
    static let notificationIdentifier = "daily-attendance-reminder"
    static let testNotificationIdentifier = "test-attendance-reminder"
    private static let scheduledReminderDays = 60

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func scheduleDailyReminder(
        hour: Int,
        minute: Int,
        checkedDateKeys: Set<String>
    ) async throws {
        let pendingReminderIdentifiers = reminderIdentifiersFromToday()
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier] + pendingReminderIdentifiers
        )

        let content = UNMutableNotificationContent()
        content.title = "Today's Nyanglish"
        content.body = "Check in to unlock today's English expression."
        content.sound = .default

        for reminderDate in reminderDatesFromToday(hour: hour, minute: minute, checkedDateKeys: checkedDateKeys) {
            let dateKey = reminderDate.nyanglishDateKey
            var dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            dateComponents.second = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(
                identifier: reminderIdentifier(for: dateKey),
                content: content,
                trigger: trigger
            )

            try await UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier] + reminderIdentifiersFromToday()
        )
    }

    static func scheduleTestReminder(after seconds: TimeInterval = 5) async throws {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [testNotificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "Your Nyanglish notification is working."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: testNotificationIdentifier,
            content: content,
            trigger: trigger
        )

        try await UNUserNotificationCenter.current().add(request)
    }

    private static func reminderDatesFromToday(
        hour: Int,
        minute: Int,
        checkedDateKeys: Set<String>
    ) -> [Date] {
        let calendar = Calendar.current
        let now = Date.now
        let today = calendar.startOfDay(for: now)

        return (0..<scheduledReminderDays).compactMap { dayOffset in
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                return nil
            }

            let dateKey = day.nyanglishDateKey
            guard !checkedDateKeys.contains(dateKey) else {
                return nil
            }

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            components.second = 0

            guard let reminderDate = calendar.date(from: components), reminderDate > now else {
                return nil
            }

            return reminderDate
        }
    }

    private static func reminderIdentifiersFromToday() -> [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return (0..<scheduledReminderDays).compactMap { dayOffset in
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                return nil
            }

            return reminderIdentifier(for: day.nyanglishDateKey)
        }
    }

    private static func reminderIdentifier(for dateKey: String) -> String {
        "\(notificationIdentifier)-\(dateKey)"
    }
}
