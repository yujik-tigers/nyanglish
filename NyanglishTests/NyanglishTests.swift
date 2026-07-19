//
//  NyanglishTests.swift
//  NyanglishTests
//
//  Created by Seoyeon Kim on 5/10/26.
//

import Foundation
import Testing
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
}
