//
//  NyanglishTests.swift
//  NyanglishTests
//
//  Created by Seoyeon Kim on 5/10/26.
//

import Foundation
import SwiftData
import Testing
import UIKit
@testable import Nyanglish

struct NyanglishTests {
    @Test func installedDateRangeIncludesProvidedTodayFirst() throws {
        let today = try #require(Date.nyanglishDate(fromKey: "2026-07-19"))

        let dateKeys = InstalledDateRange.dateKeys(
            installedDateKey: "2026-07-17",
            today: today
        )

        #expect(dateKeys == ["2026-07-19", "2026-07-18", "2026-07-17"])
    }

    @Test func installedDateRangeClampsFutureInstalledDateToToday() throws {
        let today = try #require(Date.nyanglishDate(fromKey: "2026-07-19"))

        let dateKeys = InstalledDateRange.dateKeys(
            installedDateKey: "2026-07-21",
            today: today
        )

        #expect(dateKeys == ["2026-07-19"])
    }

    @Test func widgetRefreshUsesThirtyMinuteIntervalWhenNotNearMidnight() throws {
        let calendar = Self.testCalendar
        let now = try Self.date(year: 2026, month: 7, day: 19, hour: 12, minute: 0, second: 0)
        let expected = try Self.date(year: 2026, month: 7, day: 19, hour: 12, minute: 30, second: 0)

        let refreshDate = Date.nyanglishWidgetRefreshDate(after: now, calendar: calendar)

        #expect(refreshDate == expected)
    }

    @Test func widgetRefreshUsesNextMidnightWhenItIsCloserThanThirtyMinutes() throws {
        let calendar = Self.testCalendar
        let now = try Self.date(year: 2026, month: 7, day: 19, hour: 23, minute: 45, second: 0)
        let expected = try Self.date(year: 2026, month: 7, day: 20, hour: 0, minute: 0, second: 5)

        let refreshDate = Date.nyanglishWidgetRefreshDate(after: now, calendar: calendar)

        #expect(refreshDate == expected)
    }

    @Test func deepLinkRecognizesTodayContentURL() throws {
        let url = try #require(URL(string: "nyanglish://content/today"))

        #expect(NyanglishDeepLink(url: url) == .todayContent)
    }

    @MainActor
    @Test func contentPreparationStateTracksPreparingFailedAndClear() {
        let dateKey = "2099-12-31"
        DailyContentPreparationStateStore.clearAll()

        DailyContentPreparationStateStore.markPreparing(for: dateKey)
        #expect(DailyContentPreparationStateStore.status(for: dateKey) == .preparing)

        DailyContentPreparationStateStore.markFailed("Image failed", for: dateKey)
        #expect(DailyContentPreparationStateStore.status(for: dateKey) == .failed("Image failed"))

        DailyContentPreparationStateStore.clear(for: dateKey)
        #expect(DailyContentPreparationStateStore.status(for: dateKey) == nil)
    }

    @MainActor
    @Test func contentPreparationStateExpiresStalePreparingStatus() throws {
        let dateKey = "2099-12-31"
        let now = try Self.date(year: 2099, month: 12, day: 31, hour: 9, minute: 0, second: 0)
        let staleStart = try #require(Calendar.current.date(byAdding: .second, value: -91, to: now))
        DailyContentPreparationStateStore.clearAll()

        DailyContentPreparationStateStore.markPreparing(for: dateKey, startedAt: staleStart)

        #expect(
            DailyContentPreparationStateStore.status(for: dateKey, now: now) ==
                .failed("Couldn't prepare today's content. Please try again.")
        )
    }

    @MainActor
    @Test func widgetSnapshotStoresContentForMatchingDateOnly() {
        let dateKey = "2099-12-30"
        DailyContentWidgetSnapshotStore.clearAll()

        let snapshot = DailyContentWidgetSnapshot(
            dateKey: dateKey,
            category: "Meme",
            topic: "Topic",
            translation: "Translation",
            sourceText: "Source",
            imageURL: "https://example.com/image.png"
        )

        DailyContentWidgetSnapshotStore.save(snapshot)

        #expect(DailyContentWidgetSnapshotStore.snapshot(for: dateKey) == snapshot)
        #expect(DailyContentWidgetSnapshotStore.snapshot(for: "2099-12-29") == nil)

        DailyContentWidgetSnapshotStore.clear(for: dateKey)
        #expect(DailyContentWidgetSnapshotStore.snapshot(for: dateKey) == nil)
    }

    @MainActor
    @Test func sharedStateSynchronizerRestoresAttendanceAndContentFromSnapshot() throws {
        let dateKey = Date.now.nyanglishDateKey
        AttendanceSyncStore.clearAll()
        DailyContentWidgetSnapshotStore.clearAll()

        let container = try ModelContainer(
            for: DailyContentItem.self,
            AttendanceRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let snapshot = DailyContentWidgetSnapshot(
            dateKey: dateKey,
            category: "Meme",
            topic: "Topic",
            translation: "Translation",
            sourceText: "Source",
            imageURL: "https://example.com/image.png"
        )

        AttendanceSyncStore.markAttendanceChecked(for: dateKey)
        DailyContentWidgetSnapshotStore.save(snapshot)

        let didChange = DailyContentSharedStateSynchronizer.synchronizeTodayFromSharedStores(in: context)

        let attendanceDescriptor = FetchDescriptor<AttendanceRecord>(
            predicate: #Predicate { record in
                record.dateKey == dateKey
            }
        )
        let contentDescriptor = FetchDescriptor<DailyContentItem>(
            predicate: #Predicate { content in
                content.dateKey == dateKey
            }
        )

        #expect(didChange)
        #expect(try context.fetch(attendanceDescriptor).count == 1)
        #expect(try context.fetch(contentDescriptor).first?.imageURL == snapshot.imageURL)

        AttendanceSyncStore.clearAll()
        DailyContentWidgetSnapshotStore.clearAll()
    }

    @Test func widgetThumbnailIsStoredSeparatelyFromOriginalImage() async throws {
        let dateKey = "2099-12-28"
        let imageURL = "https://example.com/widget-thumbnail-test.png"
        let originalData = try Self.imageData(size: CGSize(width: 1200, height: 800), color: .systemBlue)

        let thumbnailData = try await DailyContentImageCache.prepareWidgetThumbnail(
            for: dateKey,
            imageURL: imageURL,
            sourceData: originalData
        )

        #expect(DailyContentImageCache.cachedWidgetThumbnailData(for: dateKey, imageURL: imageURL) == thumbnailData)
        #expect(thumbnailData.count < originalData.count)
    }

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60)!
        return calendar
    }

    private static func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int
    ) throws -> Date {
        let components = DateComponents(
            calendar: testCalendar,
            timeZone: testCalendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )

        return try #require(components.date)
    }

    private static func imageData(size: CGSize, color: UIColor) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        return try #require(image.pngData())
    }
}
