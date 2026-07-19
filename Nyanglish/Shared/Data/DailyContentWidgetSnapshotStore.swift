//
//  DailyContentWidgetSnapshotStore.swift
//  Nyanglish
//
//  Created by OpenAI on 7/19/26.
//

import Foundation

struct DailyContentWidgetSnapshot: Codable, Equatable {
    let dateKey: String
    let checkedAt: Date
    let category: String
    let topic: String
    let translation: String
    let sourceText: String
    let imageURL: String?

    init(content: DailyContentItem, checkedAt: Date = .now) {
        dateKey = content.dateKey
        self.checkedAt = checkedAt
        category = content.category
        topic = content.topic
        translation = content.translation
        sourceText = content.sourceText
        imageURL = content.imageURL
    }

    init(
        dateKey: String,
        checkedAt: Date = .now,
        category: String,
        topic: String,
        translation: String,
        sourceText: String,
        imageURL: String?
    ) {
        self.dateKey = dateKey
        self.checkedAt = checkedAt
        self.category = category
        self.topic = topic
        self.translation = translation
        self.sourceText = sourceText
        self.imageURL = imageURL
    }

    func dailyContentItem() -> DailyContentItem {
        DailyContentItem(
            dateKey: dateKey,
            date: Date.nyanglishDate(fromKey: dateKey) ?? checkedAt,
            category: category,
            topic: topic,
            translation: translation,
            sourceText: sourceText,
            imageURL: imageURL
        )
    }
}

enum DailyContentWidgetSnapshotStore {
    private static let snapshotKey = "dailyContentWidgetSnapshot.current"

    static func snapshot(for dateKey: String) -> DailyContentWidgetSnapshot? {
        guard let data = defaults?.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(DailyContentWidgetSnapshot.self, from: data),
              snapshot.dateKey == dateKey else {
            return nil
        }

        return snapshot
    }

    static func save(_ snapshot: DailyContentWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }

        defaults?.set(data, forKey: snapshotKey)
        defaults?.synchronize()
    }

    static func clear(for dateKey: String) {
        guard snapshot(for: dateKey) != nil else {
            return
        }

        defaults?.removeObject(forKey: snapshotKey)
        defaults?.synchronize()
    }

    static func clearAll() {
        defaults?.removeObject(forKey: snapshotKey)
        defaults?.synchronize()
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: NyanglishModelStore.appGroupIdentifier)
    }
}
