//
//  AttendanceSyncStore.swift
//  Nyanglish
//
//  Created by OpenAI on 6/7/26.
//

import Foundation

enum AttendanceSyncStore {
    private static let checkedDateKey = "attendanceSync.checkedDateKey"
    private static let checkedAtKey = "attendanceSync.checkedAt"
    private static let changeTokenKey = "attendanceSync.changeToken"

    static func hasCheckedAttendance(for dateKey: String) -> Bool {
        guard let defaults else {
            return false
        }

        return defaults.string(forKey: checkedDateKey) == dateKey
    }

    static func markAttendanceChecked(for dateKey: String, checkedAt: Date = .now) {
        guard let defaults else {
            return
        }

        defaults.set(dateKey, forKey: checkedDateKey)
        defaults.set(checkedAt, forKey: checkedAtKey)
        defaults.set(UUID().uuidString, forKey: changeTokenKey)
        defaults.synchronize()
    }

    static func clearAttendance(for dateKey: String) {
        guard let defaults,
              defaults.string(forKey: checkedDateKey) == dateKey else {
            return
        }

        clearAll()
    }

    static func clearAll() {
        guard let defaults else {
            return
        }

        defaults.removeObject(forKey: checkedDateKey)
        defaults.removeObject(forKey: checkedAtKey)
        defaults.set(UUID().uuidString, forKey: changeTokenKey)
        defaults.synchronize()
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: NyanglishModelStore.appGroupIdentifier)
    }
}
