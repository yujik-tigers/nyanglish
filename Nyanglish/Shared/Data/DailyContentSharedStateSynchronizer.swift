//
//  DailyContentSharedStateSynchronizer.swift
//  Nyanglish
//
//  Created by OpenAI on 7/19/26.
//

import Foundation
import SwiftData

enum DailyContentSharedStateSynchronizer {
    @MainActor
    @discardableResult
    static func synchronizeTodayFromSharedStores(
        in context: ModelContext,
        today: Date = .now
    ) -> Bool {
        let todayKey = today.nyanglishDateKey
        var didChange = false

        do {
            if AttendanceSyncStore.hasCheckedAttendance(for: todayKey),
               try !hasAttendanceRecord(for: todayKey, in: context) {
                context.insert(AttendanceRecord(dateKey: todayKey))
                didChange = true
            }

            if let snapshot = DailyContentWidgetSnapshotStore.snapshot(for: todayKey),
               try storedContent(for: todayKey, in: context) == nil {
                context.insert(snapshot.dailyContentItem())
                didChange = true
            }

            if didChange {
                try context.save()
            }

            return didChange
        } catch {
            context.rollback()
            return false
        }
    }

    @MainActor
    private static func hasAttendanceRecord(for dateKey: String, in context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<AttendanceRecord>(
            predicate: #Predicate { record in
                record.dateKey == dateKey
            }
        )
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }

    @MainActor
    private static func storedContent(for dateKey: String, in context: ModelContext) throws -> DailyContentItem? {
        var descriptor = FetchDescriptor<DailyContentItem>(
            predicate: #Predicate { content in
                content.dateKey == dateKey
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
