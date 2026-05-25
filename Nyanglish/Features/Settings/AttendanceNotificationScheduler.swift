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

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func scheduleDailyReminder(hour: Int, minute: Int) async throws {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "오늘의 냥글리쉬"
        content.body = "출석하고 오늘의 밈 표현을 확인해보세요."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        try await UNUserNotificationCenter.current().add(request)
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }

    static func scheduleTestReminder(after seconds: TimeInterval = 5) async throws {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [testNotificationIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "테스트 알림"
        content.body = "냥글리쉬 알림이 정상적으로 도착했습니다."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: testNotificationIdentifier,
            content: content,
            trigger: trigger
        )

        try await UNUserNotificationCenter.current().add(request)
    }
}
