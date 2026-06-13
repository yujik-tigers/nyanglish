//
//  MainTab.swift
//  Nyanglish
//
//  Created by OpenAI on 5/23/26.
//

import Foundation

enum MainTab: String, CaseIterable, Identifiable {
    case calendar
    case content
    case settings

    var id: String {
        rawValue
    }

    func systemImageName(isSelected: Bool) -> String {
        switch self {
        case .calendar:
            return isSelected ? "clock.fill" : "clock"
        case .content:
            return isSelected ? "house.fill" : "house"
        case .settings:
            return isSelected ? "gearshape.fill" : "gearshape"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .calendar:
            return "Calendar"
        case .content:
            return "Content"
        case .settings:
            return "Settings"
        }
    }
}
