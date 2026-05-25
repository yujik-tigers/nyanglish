//
//  InstalledDateRange.swift
//  Nyanglish
//
//  Created by OpenAI on 5/23/26.
//

import Foundation

enum InstalledDateRange {
    static func dateKeys(installedDateKey: String, today: Date = .now) -> [String] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        let installedDate = Date.nyanglishDate(fromKey: installedDateKey) ?? todayStart
        let startDate = min(installedDate, todayStart)

        return Date.nyanglishDateKeys(from: startDate, through: todayStart).filter { dateKey in
            guard let date = Date.nyanglishDate(fromKey: dateKey) else {
                return false
            }

            return date <= todayStart
        }
    }
}
