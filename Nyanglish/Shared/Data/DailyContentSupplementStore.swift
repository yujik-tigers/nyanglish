//
//  DailyContentSupplementStore.swift
//  Nyanglish
//
//  Created by OpenAI on 5/25/26.
//

import Foundation

enum DailyContentSupplementStore {
    private static let fullTranslationPrefix = "dailyContent.fullTranslation."

    static func fullTranslation(for dateKey: String) -> String? {
        guard let defaults = UserDefaults(suiteName: NyanglishModelStore.appGroupIdentifier) else {
            return nil
        }

        return defaults.string(forKey: fullTranslationPrefix + dateKey)
    }

    static func saveFullTranslation(_ fullTranslation: String?, for dateKey: String) {
        guard let defaults = UserDefaults(suiteName: NyanglishModelStore.appGroupIdentifier) else {
            return
        }

        let key = fullTranslationPrefix + dateKey
        if let fullTranslation,
           !fullTranslation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defaults.set(fullTranslation, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
