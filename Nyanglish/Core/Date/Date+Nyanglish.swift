//
//  Date+Nyanglish.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/13/26.
//

import Foundation

extension Date {
    var nyanglishDateKey: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    var nyanglishDisplayText: String {
        Self.nyanglishDateFormatter.string(from: self)
    }

    static func nyanglishDate(fromKey key: String) -> Date? {
        Self.nyanglishKeyFormatter.date(from: key)
    }

    static func nyanglishSundayStartOfWeek(containing date: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        return calendar.date(byAdding: .day, value: -(weekday - 1), to: startOfDay) ?? startOfDay
    }

    static func nyanglishWeekDateKeys(containing date: Date) -> [String] {
        let startOfWeek = nyanglishSundayStartOfWeek(containing: date)

        return (0..<7).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: startOfWeek)?
                .nyanglishDateKey
        }
    }

    static func nyanglishMonthGridDates(containing date: Date) -> [Date] {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: date) else {
            return []
        }

        let gridStart = nyanglishSundayStartOfWeek(containing: monthInterval.start)
        let endOfMonth = Calendar.current.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.end
        let lastWeekStart = nyanglishSundayStartOfWeek(containing: endOfMonth)
        let gridEnd = Calendar.current.date(byAdding: .day, value: 7, to: lastWeekStart) ?? monthInterval.end

        var dates: [Date] = []
        var current = gridStart

        while current < gridEnd {
            dates.append(current)

            guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: current) else {
                break
            }

            current = nextDay
        }

        return dates
    }

    static func nyanglishDateKeys(from startDate: Date, through endDate: Date) -> [String] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        guard start <= end else {
            return []
        }

        var keys: [String] = []
        var current = end

        while current >= start {
            keys.append(current.nyanglishDateKey)

            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: current) else {
                break
            }

            current = previousDate
        }

        return keys
    }

    static func nyanglishWidgetRefreshDate(after now: Date = .now, calendar: Calendar = .current) -> Date {
        let intervalRefresh = calendar.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? intervalRefresh
        let midnightRefresh = nextDay.addingTimeInterval(5)
        return min(intervalRefresh, midnightRefresh)
    }

    private static let nyanglishDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()

    private static let nyanglishKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()
}
