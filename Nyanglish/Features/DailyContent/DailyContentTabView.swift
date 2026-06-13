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

    @State private var isLogoCollapsed = false
    @State private var hasScrolledWhileLogoCollapsed = false
    @State private var isIgnoringPageSwitchTopReset = false
    @State private var lastScrollDistance: CGFloat = 0

    private let logoHeaderHeight: CGFloat = 52
    private let logoCollapseTriggerOffset: CGFloat = 4
    private let logoRecollapseConfirmationOffset: CGFloat = 12
    private let logoExpandApproachOffset: CGFloat = 8
    private let logoExpandTriggerOffset: CGFloat = 0.5

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

    private var logoCollapseProgress: CGFloat {
        isLogoCollapsed ? 1 : 0
    }

    private var logoOpacity: Double {
        Double(1 - logoCollapseProgress)
    }

    private var logoVerticalOffset: CGFloat {
        -logoHeaderHeight * logoCollapseProgress
    }

    private var contentVerticalOffset: CGFloat {
        logoHeaderHeight * (1 - logoCollapseProgress)
    }

    var body: some View {
        ZStack(alignment: .top) {
            contentStack
                .offset(y: contentVerticalOffset)

            logoHeader
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .onChange(of: selectedDateKey) { _, _ in
            isIgnoringPageSwitchTopReset = isLogoCollapsed
            hasScrolledWhileLogoCollapsed = false
            lastScrollDistance = 0
        }
    }

    private var contentStack: some View {
        VStack(spacing: 0) {
            WeeklyAttendanceIndicator(
                selectedDateKey: selectedDateKey,
                availableDateKeys: availableDateKeysInSelectedWeek,
                checkedDateKeys: checkedDateKeysInSelectedWeek,
                onSelectDate: selectDate
            )
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 4)
            .frame(height: weeklyIndicatorHeight)

            dailyPager
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var logoHeader: some View {
        Image("OnboardingLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 116, height: 42)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity)
            .offset(y: logoVerticalOffset)
            .frame(height: logoHeaderHeight, alignment: .top)
            .clipped()
            .opacity(logoOpacity)
            .allowsHitTesting(false)
    }

    private var dailyPager: some View {
        TabView(selection: $selectedDateKey) {
            ForEach(pagerDateKeys, id: \.self) { dateKey in
                DailyContentPage(
                    dateKey: dateKey,
                    availableDateKeys: availableDateKeys,
                    onScrollOffsetChange: { distance in
                        updateLogoScrollDistance(distance, for: dateKey)
                    }
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

        isIgnoringPageSwitchTopReset = isLogoCollapsed
        hasScrolledWhileLogoCollapsed = false
        lastScrollDistance = 0

        withAnimation(.easeInOut(duration: 0.18)) {
            selectedDateKey = dateKey
        }
    }

    private func updateLogoScrollDistance(_ distance: CGFloat, for dateKey: String) {
        guard dateKey == selectedDateKey else {
            return
        }

        if isIgnoringPageSwitchTopReset, distance <= logoExpandTriggerOffset {
            return
        }

        isIgnoringPageSwitchTopReset = false

        if isLogoCollapsed {
            if distance > logoRecollapseConfirmationOffset {
                hasScrolledWhileLogoCollapsed = true
            }

            if distance <= logoExpandTriggerOffset, lastScrollDistance > logoExpandApproachOffset {
                return
            }

            defer {
                lastScrollDistance = distance
            }

            guard hasScrolledWhileLogoCollapsed, distance <= logoExpandTriggerOffset else {
                return
            }

            withAnimation(.easeOut(duration: 0.16)) {
                isLogoCollapsed = false
            }
            hasScrolledWhileLogoCollapsed = false
            return
        }

        lastScrollDistance = distance

        guard distance > logoCollapseTriggerOffset else {
            return
        }

        withAnimation(.easeOut(duration: 0.16)) {
            isLogoCollapsed = true
        }
        hasScrolledWhileLogoCollapsed = false
    }
}
