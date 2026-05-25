//
//  RootView.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/12/26.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}

#Preview("First Launch") {
    RootView()
        .modelContainer(for: [DailyContentItem.self, AttendanceRecord.self], inMemory: true)
}
