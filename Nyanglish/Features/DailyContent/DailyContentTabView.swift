//
//  DailyContentTabView.swift
//  Nyanglish
//
//  Created by OpenAI on 5/23/26.
//

import SwiftUI

struct DailyContentTabView: View {
    @Binding var selectedDateKey: String

    let dateKeys: [String]
    let checkedDateKeys: Set<String>
    let weeklyIndicatorHeight: CGFloat

    private var pagerDateKeys: [String] {
        dateKeys.reversed()
    }

    private var availableDateKeys: Set<String> {
        Set(dateKeys)
    }

    private var availableDateKeysInSelectedWeek: Set<String> {
        dateKeysInSelectedWeek(from: dateKeys)
    }

    private var checkedDateKeysInSelectedWeek: Set<String> {
        dateKeysInSelectedWeek(from: Array(checkedDateKeys))
    }

    var body: some View {
        VStack(spacing: 0) {
            WeeklyAttendanceIndicator(
                selectedDateKey: selectedDateKey,
                availableDateKeys: availableDateKeysInSelectedWeek,
                checkedDateKeys: checkedDateKeysInSelectedWeek,
                onSelectDate: selectDate
            )
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .frame(height: weeklyIndicatorHeight)

            dailyPager
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dailyPager: some View {
        TabView(selection: $selectedDateKey) {
            ForEach(pagerDateKeys, id: \.self) { dateKey in
                DailyContentPage(
                    dateKey: dateKey,
                    availableDateKeys: availableDateKeys
                )
                .tag(dateKey)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
    }

    private func dateKeysInSelectedWeek(from keys: [String]) -> Set<String> {
        guard let selectedDate = Date.nyanglishDate(fromKey: selectedDateKey) else {
            return []
        }

        let selectedWeekDateKeys = Set(Date.nyanglishWeekDateKeys(containing: selectedDate))
        return Set(keys.filter { selectedWeekDateKeys.contains($0) })
    }

    private func selectDate(_ dateKey: String) {
        guard availableDateKeys.contains(dateKey), dateKey != selectedDateKey else {
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            selectedDateKey = dateKey
        }
    }
}
