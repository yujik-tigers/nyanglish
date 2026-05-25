//
//  ContentView.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/10/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @AppStorage("installedDateKey") private var installedDateKey = ""
    @Query private var attendanceRecords: [AttendanceRecord]
    @State private var selectedDateKey = Date.now.nyanglishDateKey
    @State private var selectedTab: MainTab = .content

    private var dateKeys: [String] {
        InstalledDateRange.dateKeys(installedDateKey: installedDateKey)
    }

    var body: some View {
        GeometryReader { proxy in
            let contentHeight = max(proxy.size.height - Self.bottomMenuBarHeight, 0)

            VStack(spacing: 0) {
                selectedTabView
                    .frame(width: proxy.size.width, height: contentHeight)
                    .clipped()

                BottomMenuBar(selectedTab: $selectedTab)
                    .frame(width: proxy.size.width, height: Self.bottomMenuBarHeight)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Color("Canvas"))
        .onAppear {
            prepareInitialDateState()
        }
        .onChange(of: dateKeys) {
            clampSelectedDateToAvailableRange()
        }
        .onChange(of: selectedDateKey) {
            clampSelectedDateToAvailableRange()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .calendar:
            MonthlyCalendarView(
                selectedDateKey: selectedDateKey,
                availableDateKeys: Set(dateKeys),
                checkedDateKeys: Set(attendanceRecords.map(\.dateKey)),
                onSelectDate: selectDateFromCalendar
            )
        case .content:
            DailyContentTabView(
                selectedDateKey: $selectedDateKey,
                dateKeys: dateKeys,
                checkedDateKeys: Set(attendanceRecords.map(\.dateKey)),
                weeklyIndicatorHeight: Self.weeklyIndicatorHeight
            )
        case .settings:
            SettingsView(onResetTodayData: showTodayContent)
        }
    }

    private func prepareInitialDateState() {
        let todayKey = Date.now.nyanglishDateKey

        if installedDateKey.isEmpty {
            installedDateKey = todayKey
        }

        selectedDateKey = todayKey
        clampSelectedDateToAvailableRange()
    }

    private func selectDateFromCalendar(_ dateKey: String) {
        guard dateKeys.contains(dateKey) else {
            return
        }

        selectedDateKey = dateKey
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedTab = .content
        }
    }

    private func clampSelectedDateToAvailableRange() {
        guard !dateKeys.contains(selectedDateKey) else {
            return
        }

        selectedDateKey = dateKeys.first ?? Date.now.nyanglishDateKey
    }

    private func showTodayContent() {
        let todayKey = Date.now.nyanglishDateKey
        selectedDateKey = todayKey
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedTab = .content
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "nyanglish" else {
            return
        }

        if url.host == "content", url.path == "/today" {
            showTodayContent()
        }
    }

    private static let bottomMenuBarHeight: CGFloat = 76
    private static let weeklyIndicatorHeight: CGFloat = 112
}

#Preview {
    ContentView()
        .modelContainer(for: [DailyContentItem.self, AttendanceRecord.self], inMemory: true)
}
