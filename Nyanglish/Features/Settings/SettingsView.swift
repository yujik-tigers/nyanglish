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
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
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
                secondaryButton: .cancel(Text("취소"))
            )
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("설정")
                .font(Self.headerFont)
                .foregroundStyle(Self.primaryTextColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var notificationSection: some View {
        settingsGroup("알림") {
            settingsRow {
                Toggle(isOn: notificationToggleBinding) {
                    settingsRowLabel(icon: "bell.badge", title: "출석 알림")
                }
                .font(Self.settingsFont)
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
                        settingsRowLabel(icon: "gear", title: "알림 권한 열기")
                    }
                    .font(Self.settingsFont)
                    .foregroundStyle(Self.primaryTextColor)
                }
            } else {
                settingsRow {
                    notificationTimeRow
                }
            }

            settingsDivider

            settingsRow {
                Button {
                    Task {
                        await scheduleTestReminder()
                    }
                } label: {
                    settingsRowLabel(icon: "bell.and.waves.left.and.right", title: "테스트 알림 보내기")
                }
                .font(Self.settingsFont)
                .foregroundStyle(Self.primaryTextColor)
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

            DatePicker(
                "알림 시간",
                selection: reminderTimeBinding,
                displayedComponents: .hourAndMinute
            )
            .font(Self.settingsFont)
            .foregroundStyle(Self.primaryTextColor)
        }
        .disabled(!attendanceNotificationEnabled)
        .opacity(attendanceNotificationEnabled ? 1 : 0.38)
        .animation(.easeInOut(duration: 0.18), value: attendanceNotificationEnabled)
    }

    private var attendanceSummarySection: some View {
        settingsGroup("기록") {
            settingsRow {
                settingValueRow(
                    icon: "checkmark.seal.fill",
                    title: "오늘 출석",
                    value: hasCheckedToday ? "완료" : "아직 전"
                )
            }

            settingsDivider

            settingsRow {
                settingValueRow(
                    icon: "flame.fill",
                    title: "연속 출석",
                    value: "\(currentStreakCount)일"
                )
            }

            settingsDivider

            settingsRow {
                settingValueRow(
                    icon: "calendar",
                    title: "총 출석일",
                    value: "\(totalAttendanceCount)일"
                )
            }
        }
    }

    private var dataSection: some View {
        settingsGroup("데이터") {
            settingsRow {
                Button(role: .destructive) {
                    dataResetAlert = .all
                } label: {
                    settingsRowLabel(icon: "trash", title: "모든 기록 초기화")
                }
                .font(Self.settingsFont)
                .foregroundStyle(Self.accentColor)
            }

#if DEBUG
            settingsDivider

            settingsRow {
                Button {
                    deleteTodayTestData()
                } label: {
                    settingsRowLabel(icon: "wrench.and.screwdriver", title: "오늘 테스트 데이터 삭제")
                }
                .font(Self.settingsFont)
                .foregroundStyle(Self.primaryTextColor)
            }
#endif
        }
    }

    private var widgetSection: some View {
        settingsGroup("위젯") {
            settingsRow {
                VStack(alignment: .leading, spacing: 8) {
                    settingsRowLabel(
                        icon: "square.grid.2x2",
                        title: "홈 화면에서 앱 아이콘을 길게 누른 뒤 위젯을 추가할 수 있습니다."
                    )

                    Text("위젯을 통해 바로 출석할 수 있습니다.")
                        .font(Self.helperFont)
                        .foregroundStyle(Self.secondaryTextColor)
                        .padding(.leading, Self.iconFrameSize + 10)
                }
            }
        }
    }

    private var appInfoSection: some View {
        settingsGroup("앱") {
            settingsRow {
                settingValueRow(
                    icon: "info.circle",
                    title: "버전",
                    value: appVersionText
                )
            }
        }
    }

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
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Self.settingsFont.weight(.bold))
                .foregroundStyle(Self.secondaryTextColor)
                .padding(.horizontal, 14)

            VStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
    }

    private var settingsDivider: some View {
        Divider()
            .padding(.leading, 14 + Self.iconFrameSize + 10)
    }

    private func settingValueRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            settingsIcon(icon)

            Text(title)
                .foregroundStyle(Self.primaryTextColor)

            Spacer()

            Text(value)
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
            try await AttendanceNotificationScheduler.scheduleDailyReminder(hour: hour, minute: minute)
        } catch {
            attendanceNotificationEnabled = false
            errorMessage = "알림을 설정하지 못했습니다."
        }
    }

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
                errorMessage = "알림 권한이 꺼져 있습니다."
                return
            }

            try await AttendanceNotificationScheduler.scheduleTestReminder()
        } catch {
            errorMessage = "테스트 알림을 설정하지 못했습니다."
        }
    }

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
            WidgetCenter.shared.reloadAllTimelines()
            onResetTodayData()
        } catch {
            modelContext.rollback()
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private static let settingsFont = Font.system(size: 15, weight: .regular)
    private static let helperFont = Font.system(size: 13, weight: .regular)
    private static let headerFont = Font.system(size: 22, weight: .bold)
    private static let iconFont = Font.system(size: 18, weight: .semibold)
    private static let iconFrameSize: CGFloat = 24
    private static let primaryTextColor = Color.black
    private static let secondaryTextColor = Color(.systemGray)
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
        title: "모든 기록을 초기화할까요?",
        message: "출석 기록과 저장된 콘텐츠가 모두 삭제됩니다. 삭제된 데이터는 복구할 수 없습니다.",
        buttonTitle: "초기화"
    )
}
