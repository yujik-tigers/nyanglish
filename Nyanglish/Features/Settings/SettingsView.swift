//
//  SettingsView.swift
//  Nyanglish
//
//  Created by OpenAI on 5/23/26.
//

import SwiftData
import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

struct SettingsView: View {
    let onResetTodayData: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @AppStorage("attendanceNotificationEnabled") private var attendanceNotificationEnabled = false
    @AppStorage("attendanceNotificationMinutesAfterMidnight") private var attendanceNotificationMinutesAfterMidnight = 20 * 60
    @Query private var attendanceRecords: [AttendanceRecord]
    @Query private var dailyContents: [DailyContentItem]
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var dataResetAlert: DataResetAlert?
    @State private var errorMessage: String?

    private var todayKey: String {
        Date.now.nyanglishDateKey
    }

    private var hasCheckedToday: Bool {
        attendanceRecords.contains { $0.dateKey == todayKey }
    }

    private var totalAttendanceCount: Int {
        Set(attendanceRecords.map(\.dateKey)).count
    }

    private var currentStreakCount: Int {
        let checkedDateKeys = Set(attendanceRecords.map(\.dateKey))
        var currentDate = Calendar.current.startOfDay(for: .now)
        var streak = 0

        while checkedDateKeys.contains(currentDate.nyanglishDateKey) {
            streak += 1

            guard let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) else {
                break
            }

            currentDate = previousDate
        }

        return streak
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding {
            dateForReminderMinutes(attendanceNotificationMinutesAfterMidnight)
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            attendanceNotificationMinutesAfterMidnight = (components.hour ?? 20) * 60 + (components.minute ?? 0)

            if attendanceNotificationEnabled {
                Task {
                    await scheduleReminderIfAllowed()
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                notificationSection
                attendanceSummarySection
                dataSection
                widgetSection
                appInfoSection
#if DEBUG
                developerSection
#endif
            }
            .padding(.horizontal, 32)
            .padding(.top, 36)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Canvas"))
        .task {
            notificationStatus = await AttendanceNotificationScheduler.authorizationStatus()
            if attendanceNotificationEnabled {
                await scheduleReminderIfAllowed()
            }
        }
        .alert(item: $dataResetAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: .destructive(Text(alert.buttonTitle)) {
                    resetData(alert.kind)
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("Settings")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var notificationSection: some View {
        settingsGroup("Notifications") {
            settingsRow {
                Toggle(isOn: notificationToggleBinding) {
                    settingsRowLabel(icon: "bell", title: "Attendance Reminder")
                }
                .font(Self.settingsFont)
                .tint(Color("PrimaryButtonBackground"))
            }

            settingsDivider

            if notificationStatus == .denied {
                settingsRow {
                    notificationTimeRow
                }

                settingsDivider

                settingsRow {
                    Button {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    } label: {
                        settingsRowLabel(icon: "gear", title: "Open Notification Settings")
                    }
                    .font(Self.settingsFont)
                    .foregroundStyle(Self.primaryTextColor)
                }
            } else {
                settingsRow {
                    notificationTimeRow
                }
            }

            if let errorMessage {
                settingsDivider

                settingsRow {
                    Text(errorMessage)
                        .font(Self.settingsFont)
                        .foregroundStyle(Self.accentColor)
                }
            }
        }
    }

    private var notificationTimeRow: some View {
        HStack(spacing: 10) {
            settingsIcon("clock")

            Text("Reminder Time")
                .font(Self.settingsFont)
                .foregroundStyle(Self.primaryTextColor)

            Spacer()

            datePickerPill
        }
        .disabled(!attendanceNotificationEnabled)
        .opacity(attendanceNotificationEnabled ? 1 : 0.38)
        .animation(.easeInOut(duration: 0.18), value: attendanceNotificationEnabled)
    }

    private var datePickerPill: some View {
        DatePicker(
            "",
            selection: reminderTimeBinding,
            displayedComponents: .hourAndMinute
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        .font(Self.valueFont)
        .tint(Color(.darkGray))
    }

    private var attendanceSummarySection: some View {
        settingsGroup("Attendance") {
            settingsRow {
                settingValueRow(
                    icon: "checkmark.seal.fill",
                    title: "Today",
                    value: hasCheckedToday ? "Done" : "Not yet"
                )
            }

            settingsDivider

            settingsRow {
                settingValueRow(
                    icon: "flame.fill",
                    title: "Streak",
                    value: "\(currentStreakCount)d"
                )
            }

            settingsDivider

            settingsRow {
                settingValueRow(
                    icon: "calendar",
                    title: "Total Days",
                    value: "\(totalAttendanceCount)d"
                )
            }
        }
    }

    private var dataSection: some View {
        settingsGroup("Data") {
            settingsRow {
                Button(role: .destructive) {
                    dataResetAlert = .all
                } label: {
                    settingsRowLabel(icon: "trash", title: "Reset All Records")
                }
                .font(Self.settingsFont)
                .foregroundStyle(Self.accentColor)
            }

        }
    }

    private var widgetSection: some View {
        settingsGroup("Widgets") {
            settingsRow {
                settingsRowLabel(
                    icon: "square.grid.2x2",
                    title: "Add the widget to your Home Screen for quick check-ins."
                )
            }
        }
    }

    private var appInfoSection: some View {
        settingsGroup("About") {
            settingsRow {
                settingValueRow(
                    icon: "info.circle",
                    title: "Version",
                    value: appVersionText
                )
            }
        }
    }

#if DEBUG
    private var developerSection: some View {
        settingsGroup("Developer") {
            settingsRow {
                Button {
                    Task {
                        await scheduleTestReminder()
                    }
                } label: {
                    settingsRowLabel(icon: "bell.and.waves.left.and.right", title: "Send Test Notification")
                }
                .font(Self.settingsFont)
                .foregroundStyle(Self.primaryTextColor)
            }

            settingsDivider

            settingsRow {
                Button {
                    deleteTodayTestData()
                } label: {
                    settingsRowLabel(icon: "wrench.and.screwdriver", title: "Delete Today's Test Data")
                }
                .font(Self.settingsFont)
                .foregroundStyle(Self.primaryTextColor)
            }
        }
    }
#endif

    private var notificationToggleBinding: Binding<Bool> {
        Binding {
            attendanceNotificationEnabled
        } set: { isEnabled in
            attendanceNotificationEnabled = isEnabled

            Task {
                if isEnabled {
                    await scheduleReminderIfAllowed()
                } else {
                    AttendanceNotificationScheduler.cancelDailyReminder()
                    notificationStatus = await AttendanceNotificationScheduler.authorizationStatus()
                }
            }
        }
    }

    private func settingsGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(Self.sectionTitleFont)
                    .foregroundStyle(Self.sectionTitleColor)
                    .padding(.horizontal, Self.groupHorizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 2)

                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, 12)
            .padding(.horizontal, Self.groupHorizontalPadding)
    }

    private var settingsDivider: some View {
        Divider()
            .padding(.horizontal, Self.groupHorizontalPadding)
    }

    private func settingValueRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            settingsIcon(icon)

            Text(title)
                .foregroundStyle(Self.primaryTextColor)

            Spacer()

            Text(value)
                .font(Self.valueFont)
                .foregroundStyle(Self.primaryTextColor)
        }
        .font(Self.settingsFont)
        .frame(maxWidth: .infinity)
    }

    private func settingsRowLabel(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            settingsIcon(icon)

            Text(title)
                .font(Self.settingsFont)
                .foregroundStyle(Self.primaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(Self.iconFont)
            .foregroundStyle(Self.iconColor)
            .frame(width: Self.iconFrameSize, height: Self.iconFrameSize)
    }

    private func scheduleReminderIfAllowed() async {
        errorMessage = nil

        do {
            var status = await AttendanceNotificationScheduler.authorizationStatus()

            if status == .notDetermined {
                _ = try await AttendanceNotificationScheduler.requestAuthorization()
                status = await AttendanceNotificationScheduler.authorizationStatus()
            }

            notificationStatus = status

            guard status == .authorized || status == .provisional || status == .ephemeral else {
                attendanceNotificationEnabled = false
                AttendanceNotificationScheduler.cancelDailyReminder()
                return
            }

            let hour = attendanceNotificationMinutesAfterMidnight / 60
            let minute = attendanceNotificationMinutesAfterMidnight % 60
            try await AttendanceNotificationScheduler.scheduleDailyReminder(
                hour: hour,
                minute: minute,
                checkedDateKeys: Set(attendanceRecords.map(\.dateKey))
            )
        } catch {
            attendanceNotificationEnabled = false
            errorMessage = "Couldn't set up notifications."
        }
    }

#if DEBUG
    private func scheduleTestReminder() async {
        errorMessage = nil

        do {
            var status = await AttendanceNotificationScheduler.authorizationStatus()

            if status == .notDetermined {
                _ = try await AttendanceNotificationScheduler.requestAuthorization()
                status = await AttendanceNotificationScheduler.authorizationStatus()
            }

            notificationStatus = status

            guard status == .authorized || status == .provisional || status == .ephemeral else {
                errorMessage = "Notifications are turned off."
                return
            }

            try await AttendanceNotificationScheduler.scheduleTestReminder()
        } catch {
            errorMessage = "Couldn't schedule the test notification."
        }
    }
#endif

    private func dateForReminderMinutes(_ minutesAfterMidnight: Int) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .minute, value: minutesAfterMidnight, to: startOfDay) ?? .now
    }

    private func resetData(_ kind: DataResetKind) {
        switch kind {
        case .all:
            dailyContents.forEach(modelContext.delete)
            attendanceRecords.forEach(modelContext.delete)
        }

        do {
            try modelContext.save()
            AttendanceSyncStore.clearAll()
            DailyContentSupplementStore.clearAllFullTranslations()
            WidgetCenter.shared.reloadAllTimelines()
            onResetTodayData()
        } catch {
            modelContext.rollback()
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let suffix = Bundle.main.object(forInfoDictionaryKey: "NyanglishVersionSuffix") as? String
        return [version, suffix]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static let settingsFont = Font.system(size: 15, weight: .regular)
    private static let valueFont = Font.system(size: 15, weight: .regular)
    private static let sectionTitleFont = Font.system(size: 14, weight: .semibold)
    private static let iconFont = Font.system(size: 16, weight: .semibold)
    private static let iconFrameSize: CGFloat = 20
    private static let groupHorizontalPadding: CGFloat = 24
    private static let primaryTextColor = Color.black
    private static let secondaryTextColor = Color(.systemGray)
    private static let sectionTitleColor = Color(.systemGray2)
    private static let iconColor = Color(.darkGray)
    private static let accentColor = Color.red

#if DEBUG
    private func deleteTodayTestData() {
        let todayKey = Date.now.nyanglishDateKey

        attendanceRecords
            .filter { $0.dateKey == todayKey }
            .forEach(modelContext.delete)

        dailyContents
            .filter { $0.dateKey == todayKey }
            .forEach(modelContext.delete)

        do {
            try modelContext.save()
            AttendanceSyncStore.clearAttendance(for: todayKey)
            DailyContentSupplementStore.removeFullTranslation(for: todayKey)
            WidgetCenter.shared.reloadAllTimelines()
            onResetTodayData()
        } catch {
            modelContext.rollback()
        }
    }
#endif
}

private enum DataResetKind {
    case all
}

private struct DataResetAlert: Identifiable {
    let kind: DataResetKind
    let title: String
    let message: String
    let buttonTitle: String

    var id: String {
        switch kind {
        case .all:
            "all"
        }
    }

    static let all = DataResetAlert(
        kind: .all,
        title: "Reset all records?",
        message: "This will delete your attendance history and saved content. This action can't be undone.",
        buttonTitle: "Reset"
    )
}
