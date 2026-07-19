//
//  DailyContentPreparationService.swift
//  Nyanglish
//
//  Created by OpenAI on 7/19/26.
//

import Foundation
import SwiftData

enum DailyContentPreparationService {
    @MainActor
    static func prepareContentAndAttendance(
        for dateKey: String,
        in context: ModelContext,
        requiresImageCache: Bool = true
    ) async throws {
        DailyContentPreparationStateStore.markPreparing(for: dateKey)

        do {
            let content = try await preparedContent(for: dateKey, in: context)
            if requiresImageCache {
                let imageData = try await DailyContentImageCache.imageData(
                    for: dateKey,
                    imageURL: content.imageURL,
                    shouldCache: true
                )
                _ = try await DailyContentImageCache.prepareWidgetThumbnail(
                    for: dateKey,
                    imageURL: content.imageURL,
                    sourceData: imageData
                )
            }

            if try !hasAttendanceRecord(for: dateKey, in: context) {
                context.insert(AttendanceRecord(dateKey: dateKey))
            }

            try context.save()
            DailyContentCachePolicy.pruneExpiredContent(in: context)
            AttendanceSyncStore.markAttendanceChecked(for: dateKey)
            DailyContentWidgetSnapshotStore.save(DailyContentWidgetSnapshot(content: content))
            DailyContentPreparationStateStore.clear(for: dateKey)
        } catch {
            context.rollback()
            DailyContentPreparationStateStore.markFailed(error.localizedDescription, for: dateKey)
            throw error
        }
    }

    @MainActor
    static func preparedContent(for dateKey: String, in context: ModelContext) async throws -> DailyContentItem {
        if let storedContent = try storedContent(for: dateKey, in: context) {
            return storedContent
        }

        let content = try await DailyContentRepository.fetchContent(for: dateKey)
        context.insert(content)
        return content
    }

    @MainActor
    static func storedContent(for dateKey: String, in context: ModelContext) throws -> DailyContentItem? {
        var descriptor = FetchDescriptor<DailyContentItem>(
            predicate: #Predicate { content in
                content.dateKey == dateKey
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    static func hasAttendanceRecord(for dateKey: String, in context: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<AttendanceRecord>(
            predicate: #Predicate { record in
                record.dateKey == dateKey
            }
        )
        descriptor.fetchLimit = 1
        return try !context.fetch(descriptor).isEmpty
    }
}
