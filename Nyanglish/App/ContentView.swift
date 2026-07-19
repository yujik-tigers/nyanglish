//
//  ContentView.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/10/26.
//

import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("installedDateKey") private var installedDateKey = ""
    @AppStorage("attendanceNotificationEnabled") private var attendanceNotificationEnabled = false
    @AppStorage("attendanceNotificationMinutesAfterMidnight") private var attendanceNotificationMinutesAfterMidnight = 20 * 60
    @Query private var attendanceRecords: [AttendanceRecord]
    @State private var selectedDateKey = Date.now.nyanglishDateKey
    @State private var selectedTab: MainTab = .content

    private var dateKeys: [String] {
        InstalledDateRange.dateKeys(installedDateKey: installedDateKey)
    }

    private var checkedDateKeys: Set<String> {
        Set(attendanceRecords.map(\.dateKey))
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
            showTodayHome()
        }
        .task {
            await synchronizeTodayAttendanceFromSharedStore()
            mirrorTodayAttendanceIfNeeded()
            pruneDailyContentCache()
            await refreshAttendanceReminderIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                showTodayHome()
                await synchronizeTodayAttendanceFromSharedStore()
                mirrorTodayAttendanceIfNeeded()
                pruneDailyContentCache()
                await refreshAttendanceReminderIfNeeded()
            }
        }
        .onChange(of: dateKeys) {
            clampSelectedDateToAvailableRange()
        }
        .onChange(of: checkedDateKeys) {
            mirrorTodayAttendanceIfNeeded()
            Task {
                await refreshAttendanceReminderIfNeeded()
            }
        }
        .onChange(of: selectedDateKey) {
            clampSelectedDateToAvailableRange()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            showTodayHome()
            Task {
                await synchronizeTodayAttendanceFromSharedStore()
                mirrorTodayAttendanceIfNeeded()
                pruneDailyContentCache()
                await refreshAttendanceReminderIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .calendar:
            MonthlyCalendarView(
                selectedDateKey: selectedDateKey,
                availableDateKeys: Set(dateKeys),
                checkedDateKeys: checkedDateKeys,
                onSelectDate: selectDateFromCalendar
            )
        case .content:
            DailyContentTabView(
                selectedDateKey: $selectedDateKey,
                dateKeys: dateKeys,
                checkedDateKeys: checkedDateKeys,
                weeklyIndicatorHeight: Self.weeklyIndicatorHeight
            )
        case .settings:
            SettingsView(onResetTodayData: showTodayContent)
        }
    }

    private func showTodayHome() {
        let todayKey = Date.now.nyanglishDateKey

        if installedDateKey.isEmpty {
            installedDateKey = todayKey
        }

        selectedDateKey = todayKey
        selectedTab = .content
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
        if installedDateKey.isEmpty {
            installedDateKey = Date.now.nyanglishDateKey
        }

        selectedDateKey = Date.now.nyanglishDateKey
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

    @MainActor
    private func synchronizeTodayAttendanceFromSharedStore() async {
        let todayKey = Date.now.nyanglishDateKey
        guard AttendanceSyncStore.hasCheckedAttendance(for: todayKey),
              !checkedDateKeys.contains(todayKey) else {
            return
        }

        do {
            var descriptor = FetchDescriptor<AttendanceRecord>(
                predicate: #Predicate { record in
                    record.dateKey == todayKey
                }
            )
            descriptor.fetchLimit = 1

            if try modelContext.fetch(descriptor).isEmpty {
                modelContext.insert(AttendanceRecord(dateKey: todayKey))
                try modelContext.save()
            }
        } catch {
            modelContext.rollback()
        }
    }

    private func mirrorTodayAttendanceIfNeeded() {
        let todayKey = Date.now.nyanglishDateKey
        guard checkedDateKeys.contains(todayKey) else {
            return
        }

        AttendanceSyncStore.markAttendanceChecked(for: todayKey)
    }

    private func pruneDailyContentCache() {
        DailyContentCachePolicy.pruneExpiredContent(in: modelContext)
    }

    private func refreshAttendanceReminderIfNeeded() async {
        guard attendanceNotificationEnabled else {
            return
        }

        let hour = attendanceNotificationMinutesAfterMidnight / 60
        let minute = attendanceNotificationMinutesAfterMidnight % 60

        try? await AttendanceNotificationScheduler.scheduleDailyReminder(
            hour: hour,
            minute: minute,
            checkedDateKeys: checkedDateKeys
        )
    }

    private static let bottomMenuBarHeight: CGFloat = 76
    private static let weeklyIndicatorHeight: CGFloat = 112
}

#Preview {
    ContentView()
        .modelContainer(for: [DailyContentItem.self, AttendanceRecord.self], inMemory: true)
}
