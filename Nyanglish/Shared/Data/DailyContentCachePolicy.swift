//
//  DailyContentCachePolicy.swift
//  Nyanglish
//
//  Created by OpenAI on 6/7/26.
//

import Foundation
import SwiftData

enum DailyContentCachePolicy {
    static let retentionDays = 60

    static func shouldCacheContent(for dateKey: String, today: Date = .now) -> Bool {
        guard let date = Date.nyanglishDate(fromKey: dateKey) else {
            return true
        }

        return Calendar.current.startOfDay(for: date) >= cutoffDate(today: today)
    }

    @MainActor
    static func pruneExpiredContent(in context: ModelContext, today: Date = .now) {
        let cutoffDate = cutoffDate(today: today)
        let descriptor = FetchDescriptor<DailyContentItem>(
            predicate: #Predicate { item in
                item.date < cutoffDate
            }
        )

        do {
            let expiredContents = try context.fetch(descriptor)
            guard !expiredContents.isEmpty else {
                DailyContentSupplementStore.pruneFullTranslations(before: cutoffDate)
                return
            }

            expiredContents.forEach(context.delete)
            try context.save()
            DailyContentSupplementStore.pruneFullTranslations(before: cutoffDate)
        } catch {
            context.rollback()
        }
    }

    private static func cutoffDate(today: Date) -> Date {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        return calendar.date(byAdding: .day, value: -retentionDays, to: todayStart) ?? todayStart
    }
}
