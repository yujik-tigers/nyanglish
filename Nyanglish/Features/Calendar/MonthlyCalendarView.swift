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
                isChecked: checkedDateKeys.contains(dateKey)
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            monthHeader

            weekdayHeader

            LazyVGrid(columns: calendarColumns, spacing: 16) {
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .padding(.top, 54)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .offset(x: blockedSwipeOffset)
        .contentShape(Rectangle())
        .simultaneousGesture(monthGesture)
    }

    private var monthHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text("TODAY")
                    .font(.caption.weight(.bold))

                Text("\(Calendar.current.component(.day, from: today))")
                    .font(.system(size: 86, weight: .black))

                VStack(alignment: .leading, spacing: 0) {
                    Text(Self.monthFormatter.string(from: visibleMonthDate).uppercased())
                        .font(.title3.weight(.semibold))

                    Text(Self.yearFormatter.string(from: visibleMonthDate))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if Calendar.current.isDate(today, equalTo: visibleMonthDate, toGranularity: .month) {
                Text(Self.weekdayFormatter.string(from: today))
                    .font(.title.weight(.medium))
                    .padding(.bottom, 14)
            }
        }
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

    private func calendarDayCell(_ day: MonthDay) -> some View {
        GeometryReader { proxy in
            let cellSize = min(54, proxy.size.width)
            let circleSize = cellSize * 0.78

            ZStack {
                RoundedRectangle(cornerRadius: cellSize * 0.26)
                    .fill(Color("AttendanceBadgeBackground").opacity(day.isSelected ? 0.16 : 0))
                    .frame(width: cellSize, height: cellSize)

                Circle()
                    .fill(circleColor(for: day))
                    .frame(width: circleSize, height: circleSize)
                    .overlay {
                        if !day.isChecked, day.isCurrentMonth, !day.isAvailable {
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        }
                    }

                Text("\(Calendar.current.component(.day, from: day.date))")
                    .font(.system(size: max(13, circleSize * 0.42), weight: .bold))
                    .foregroundStyle(textColor(for: day))

                if day.isChecked {
                    AttendanceStamp(size: circleSize * 0.57)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54)
        }
        .frame(height: 54)
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
            return Color("AttendanceBadgeBackground")
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

    private static let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "LLLL"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter
    }()
}

private struct MonthDay: Identifiable {
    let date: Date
    let dateKey: String
    let isCurrentMonth: Bool
    let isAvailable: Bool
    let isSelected: Bool
    let isChecked: Bool

    var id: String {
        dateKey
    }
}
