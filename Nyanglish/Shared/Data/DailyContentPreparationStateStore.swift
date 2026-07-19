//
//  DailyContentPreparationStateStore.swift
//  Nyanglish
//
//  Created by OpenAI on 7/19/26.
//

import Foundation

enum DailyContentPreparationStatus: Equatable {
    case preparing
    case failed(String)
}

enum DailyContentPreparationStateStore {
    static let preparationTimeout: TimeInterval = 90

    private static let dateKeyKey = "dailyContentPreparation.dateKey"
    private static let statusKey = "dailyContentPreparation.status"
    private static let messageKey = "dailyContentPreparation.message"
    private static let startedAtKey = "dailyContentPreparation.startedAt"

    static func status(
        for dateKey: String,
        now: Date = .now,
        preparationTimeout: TimeInterval = Self.preparationTimeout
    ) -> DailyContentPreparationStatus? {
        guard let defaults,
              defaults.string(forKey: dateKeyKey) == dateKey,
              let status = defaults.string(forKey: statusKey) else {
            return nil
        }

        switch status {
        case "preparing":
            let startedAt = defaults.object(forKey: startedAtKey) as? Date ?? now
            guard now.timeIntervalSince(startedAt) <= preparationTimeout else {
                return .failed("Couldn't prepare today's content. Please try again.")
            }

            return .preparing
        case "failed":
            return .failed(defaults.string(forKey: messageKey) ?? "Couldn't prepare today's content.")
        default:
            return nil
        }
    }

    static func markPreparing(for dateKey: String, startedAt: Date = .now) {
        guard let defaults else {
            return
        }

        defaults.set(dateKey, forKey: dateKeyKey)
        defaults.set("preparing", forKey: statusKey)
        defaults.set(startedAt, forKey: startedAtKey)
        defaults.removeObject(forKey: messageKey)
        defaults.synchronize()
    }

    static func markFailed(_ message: String, for dateKey: String) {
        guard let defaults else {
            return
        }

        defaults.set(dateKey, forKey: dateKeyKey)
        defaults.set("failed", forKey: statusKey)
        defaults.set(message, forKey: messageKey)
        defaults.removeObject(forKey: startedAtKey)
        defaults.synchronize()
    }

    static func clear(for dateKey: String) {
        guard let defaults,
              defaults.string(forKey: dateKeyKey) == dateKey else {
            return
        }

        defaults.removeObject(forKey: dateKeyKey)
        defaults.removeObject(forKey: statusKey)
        defaults.removeObject(forKey: messageKey)
        defaults.removeObject(forKey: startedAtKey)
        defaults.synchronize()
    }

    static func clearAll() {
        guard let defaults else {
            return
        }

        defaults.removeObject(forKey: dateKeyKey)
        defaults.removeObject(forKey: statusKey)
        defaults.removeObject(forKey: messageKey)
        defaults.removeObject(forKey: startedAtKey)
        defaults.synchronize()
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: NyanglishModelStore.appGroupIdentifier)
    }
}
