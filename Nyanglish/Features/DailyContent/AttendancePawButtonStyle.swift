//
//  AttendancePawButtonStyle.swift
//  Nyanglish
//
//  Created by OpenAI on 5/23/26.
//

import SwiftUI

struct AttendancePawButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(
                configuration.isPressed
                ? Color("AttendanceBadgeBackground")
                : Color("PrimaryButtonBackground")
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
