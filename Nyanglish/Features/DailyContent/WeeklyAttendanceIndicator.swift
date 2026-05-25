//
//  WeeklyAttendanceIndicator.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/14/26.
//

import SwiftUI

struct WeeklyAttendanceIndicator: View {
    let selectedDateKey: String
    let availableDateKeys: Set<String>
    let checkedDateKeys: Set<String>
    let onSelectDate: (String) -> Void

    private var weekDays: [WeekDay] {
        guard let selectedDate = Date.nyanglishDate(fromKey: selectedDateKey) else {
            return []
        }

        return Date.nyanglishWeekDateKeys(containing: selectedDate).compactMap { dateKey in
            guard let date = Date.nyanglishDate(fromKey: dateKey) else {
                return nil
            }

            return WeekDay(
                dateKey: dateKey,
                dayNumber: Calendar.current.component(.day, from: date),
                weekdaySymbol: Self.weekdaySymbol(for: date),
                isToday: Calendar.current.isDateInToday(date),
                isAvailable: availableDateKeys.contains(dateKey)
            )
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let spacing = Self.daySpacing
            let availableCellWidth = (proxy.size.width - spacing * CGFloat(max(weekDays.count - 1, 0))) / CGFloat(max(weekDays.count, 1))
            let cellSize = min(Self.maxCellSize, max(Self.minCellSize, availableCellWidth))
            let circleSize = cellSize * 0.78

            HStack(spacing: spacing) {
                ForEach(weekDays) { day in
                    dayCell(day, cellSize: cellSize, circleSize: circleSize)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard day.isAvailable else {
                                return
                            }

                            onSelectDate(day.dateKey)
                        }
                        .accessibilityAddTraits(day.dateKey == selectedDateKey ? [.isSelected] : [])
                        .accessibilityHint(day.isAvailable ? "해당 날짜로 이동합니다." : "아직 이동할 수 없는 날짜입니다.")
                }
            }
        }
        .frame(height: 76)
    }

    private func dayCell(_ day: WeekDay, cellSize: CGFloat, circleSize: CGFloat) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: cellSize * 0.26)
                    .fill(Color("AttendanceBadgeBackground").opacity(day.dateKey == selectedDateKey ? 0.16 : 0))
                    .frame(width: cellSize, height: cellSize)

                Circle()
                    .fill(circleColor(for: day))
                    .frame(width: circleSize, height: circleSize)

                Text("\(day.dayNumber)")
                    .font(.system(size: max(13, circleSize * 0.42), weight: .bold))
                    .foregroundStyle(textColor(for: day))

                if checkedDateKeys.contains(day.dateKey) {
                    AttendanceStamp(size: circleSize * 0.57)
                }

                if day.isToday {
                    Text("TODAY")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                        .offset(y: -(cellSize / 2 + 5))
                }
            }
            .frame(width: cellSize, height: cellSize)

            Text(day.weekdaySymbol)
                .font(.caption.weight(day.dateKey == selectedDateKey ? .bold : .semibold))
                .foregroundStyle(day.dateKey == selectedDateKey ? .primary : .secondary)
                .frame(height: 14)
        }
        .frame(height: 76)
    }

    private func circleColor(for day: WeekDay) -> Color {
        if checkedDateKeys.contains(day.dateKey) {
            return Color("PrimaryButtonBackground")
        }

        if day.isAvailable {
            return Color("AttendancePendingColor")
        }

        if day.dateKey == selectedDateKey {
            return Color(.systemGray)
        }

        return Color(.systemGray5)
    }

    private func textColor(for day: WeekDay) -> Color {
        if checkedDateKeys.contains(day.dateKey) {
            return Color("AttendanceBadgeBackground")
        }

        if day.dateKey == selectedDateKey || day.isAvailable {
            return .white
        }

        return .secondary
    }

    private static func weekdaySymbol(for date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        return ["S", "M", "T", "W", "T", "F", "S"][weekday - 1]
    }

    private static let daySpacing: CGFloat = 6
    private static let minCellSize: CGFloat = 36
    private static let maxCellSize: CGFloat = 54
}

struct AttendanceStamp: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "pawprint.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Color("AttendanceBadgeBackground").opacity(0.36))
            .accessibilityHidden(true)
    }
}

private struct WeekDay: Identifiable {
    let dateKey: String
    let dayNumber: Int
    let weekdaySymbol: String
    let isToday: Bool
    let isAvailable: Bool

    var id: String {
        dateKey
    }
}
