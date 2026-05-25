//
//  NyanglishModelStore.swift
//  Nyanglish
//
//  Created by OpenAI on 5/25/26.
//

import Foundation
import SwiftData

enum NyanglishModelStore {
    static let appGroupIdentifier = "group.yujik-tigers.Nyanglish"

    static let schema = Schema([
        DailyContentItem.self,
        AttendanceRecord.self,
    ])

    static func makeContainer() throws -> ModelContainer {
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(appGroupIdentifier)
        )

        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }
}
