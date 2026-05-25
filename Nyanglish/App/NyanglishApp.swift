//
//  NyanglishApp.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/10/26.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct NyanglishApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresentationDelegate.shared
    }

    var sharedModelContainer: ModelContainer = {
        do {
            return try NyanglishModelStore.makeContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(sharedModelContainer)
    }
}
