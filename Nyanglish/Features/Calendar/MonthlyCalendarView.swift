//
//  MonthlyCalendarView.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/14/26.
//

import SwiftUI

struct MonthlyCalendarView: View {
    let selectedDateKey: String
    let availableDateKeys: Set<String>
    let checkedDateKeys: Set<String>
    let onSelectDate: (String) -> Void

    @State private var visibleMonthDate: Date
    @State private var blockedSwipeOffset: CGFloat = 0

    private var selectedDate: Date {
        Date.nyanglishDate(fromKey: selectedDateKey) ?? .now
    }

    private var today: Date {
        Calendar.current.startOfDay(for: .now)
    }

    init(
        selectedDateKey: String,
        availableDateKeys: Set<String>,
        checkedDateKeys: Set<String>,
        onSelectDate: @escaping (String) -> Void
    ) {
        self.selectedDateKey = selectedDateKey
        self.availableDateKeys = availableDateKeys
        self.checkedDateKeys = checkedDateKeys
        self.onSelectDate = onSelectDate
        _visibleMonthDate = State(initialValue: Date.nyanglishDate(fromKey: selectedDateKey) ?? .now)
    }

    private var monthDays: [MonthDay] {
        Date.nyanglishMonthGridDates(containing: visibleMonthDate).map { date in
            let dateKey = date.nyanglishDateKey
            return MonthDay(
                date: date,
                dateKey: dateKey,
                isCurrentMonth: Calendar.current.isDate(date, equalTo: visibleMonthDate, toGranularity: .month),
                isAvailable: availableDateKeys.contains(dateKey),
                isSelected: dateKey == selectedDateKey,
                isToday: Calendar.current.isDate(date, inSameDayAs: today),
                isChecked: checkedDateKeys.contains(dateKey)
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Calendar")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)

            calendarHeader
                .padding(.top, 18)

            weekdayHeader
                .padding(.top, 20)

            calendarGrid
                .padding(.top, 12)

            Spacer(minLength: 12)

            dateComparisonBar
        }
        .padding(.horizontal, 32)
        .padding(.top, 36)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .offset(x: blockedSwipeOffset)
        .contentShape(Rectangle())
        .simultaneousGesture(monthGesture)
        .onChange(of: selectedDateKey) {
            syncVisibleMonthWithSelectedDate()
        }
    }

    private var dateComparisonBar: some View {
        HStack(spacing: 0) {
            compactDateInfo(title: "Reviewing", date: selectedDate)

            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: 1, height: 32)
                .padding(.horizontal, 14)

            compactDateInfo(title: "Today", date: today)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: Self.dateComparisonBarHeight)
        .background(Color(.systemGray6).opacity(0.25))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray5), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func compactDateInfo(title: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .textCase(.uppercase)

            Text(Self.compactDateFormatter.string(from: date))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var calendarHeader: some View {
        HStack(spacing: 8) {
            monthMoveButton(systemImage: "chevron.left", value: -1)

            Text(Self.visibleMonthFormatter.string(from: visibleMonthDate))
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(minWidth: 104, alignment: .center)

            monthMoveButton(systemImage: "chevron.right", value: 1)
        }
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .center)
    }

    private func monthMoveButton(systemImage: String, value: Int) -> some View {
        Button {
            moveMonth(by: value)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(availableMonth(by: value) == nil ? .tertiary : .primary)
        .disabled(availableMonth(by: value) == nil)
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(Self.weekdaySymbols.indices, id: \.self) { index in
                Text(Self.weekdaySymbols[index])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: calendarColumns, spacing: Self.calendarGridRowSpacing) {
            ForEach(monthDays) { day in
                Button {
                    guard day.isAvailable else {
                        return
                    }

                    onSelectDate(day.dateKey)
                } label: {
                    calendarDayCell(day)
                }
                .buttonStyle(.plain)
                .disabled(!day.isAvailable)
                .opacity(day.isCurrentMonth ? 1 : 0.25)
            }
        }
        .frame(height: Self.calendarGridHeight, alignment: .top)
    }

    private func calendarDayCell(_ day: MonthDay) -> some View {
        GeometryReader { proxy in
            let cellSize = min(54, proxy.size.width)
            let circleSize = cellSize * 0.78

            ZStack {
                RoundedRectangle(cornerRadius: cellSize * 0.26)
                    .fill(Color("AttendanceBadgeBackground").opacity(day.isSelected ? 0.16 : 0))
                    .frame(width: cellSize, height: cellSize)
                    .offset(y: Self.dayCircleOffsetY)

                Circle()
                    .fill(circleColor(for: day))
                    .frame(width: circleSize, height: circleSize)
                    .overlay {
                        if day.isToday {
                            Circle()
                                .stroke(Color("AttendanceBadgeBackground"), lineWidth: day.isSelected ? 2 : 1.5)
                        } else if !day.isChecked, day.isCurrentMonth, !day.isAvailable {
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        }
                    }
                    .offset(y: Self.dayCircleOffsetY)

                Text("\(Calendar.current.component(.day, from: day.date))")
                    .font(.system(size: max(13, circleSize * 0.42), weight: .bold))
                    .foregroundStyle(textColor(for: day))
                    .offset(y: Self.dayCircleOffsetY)

                if day.isChecked {
                    AttendanceStamp(size: circleSize * 0.57)
                        .offset(y: Self.dayCircleOffsetY)
                }

                if day.isToday {
                    Text("TODAY")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(height: 10)
                        .offset(y: Self.todayLabelOffsetY)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Self.dayCellHeight, maxHeight: Self.dayCellHeight)
        }
        .frame(height: Self.dayCellHeight)
    }

    private var monthGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if abs(value.translation.width) > abs(value.translation.height),
                   abs(value.translation.width) > 70 {
                    moveMonth(by: value.translation.width < 0 ? 1 : -1)
                }
            }
    }

    private func circleColor(for day: MonthDay) -> Color {
        if day.isChecked {
            return Color("PrimaryButtonBackground")
        }

        if day.isAvailable {
            return Color("AttendancePendingColor")
        }

        if day.isSelected {
            return Color(.systemGray)
        }

        if day.isCurrentMonth {
            return Color(.systemGray5)
        }

        return Color.clear
    }

    private func textColor(for day: MonthDay) -> Color {
        if day.isChecked {
            return Color("AttendanceCheckedTextColor")
        }

        if day.isSelected || day.isChecked || day.isAvailable {
            return .white
        }

        return .secondary
    }

    private func moveMonth(by value: Int) {
        guard let nextMonth = availableMonth(by: value) else {
            bounceBlockedSwipe(direction: value)
            return
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            visibleMonthDate = nextMonth
        }
    }

    private func syncVisibleMonthWithSelectedDate() {
        guard !Calendar.current.isDate(selectedDate, equalTo: visibleMonthDate, toGranularity: .month) else {
            return
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            visibleMonthDate = selectedDate
        }
    }

    private func availableMonth(by value: Int) -> Date? {
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: value, to: visibleMonthDate),
              let monthInterval = Calendar.current.dateInterval(of: .month, for: nextMonth) else {
            return nil
        }

        let monthHasAvailableDate = availableDateKeys.contains { dateKey in
            guard let date = Date.nyanglishDate(fromKey: dateKey) else {
                return false
            }

            return monthInterval.contains(date)
        }

        return monthHasAvailableDate ? nextMonth : nil
    }

    private func bounceBlockedSwipe(direction: Int) {
        let offset: CGFloat = direction > 0 ? -18 : 18

        withAnimation(.easeOut(duration: 0.08)) {
            blockedSwipeOffset = offset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) {
                blockedSwipeOffset = 0
            }
        }
    }

    private static let dateComparisonBarHeight: CGFloat = 58
    private static let dayCellHeight: CGFloat = 66
    private static let dayCircleOffsetY: CGFloat = 7
    private static let todayLabelOffsetY: CGFloat = -21
    private static let calendarGridRowSpacing: CGFloat = 10
    private static let maxCalendarRows: CGFloat = 6
    private static let calendarGridHeight = dayCellHeight * maxCalendarRows + calendarGridRowSpacing * (maxCalendarRows - 1)
    private static let weekdaySymbols = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

    private static let compactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMMM d"
        return formatter
    }()

    private static let visibleMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    private static let selectedDateMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "LLLL"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE"
        return formatter
    }()
}

private struct MonthDay: Identifiable {
    let date: Date
    let dateKey: String
    let isCurrentMonth: Bool
    let isAvailable: Bool
    let isSelected: Bool
    let isToday: Bool
    let isChecked: Bool

    var id: String {
        dateKey
    }
}
