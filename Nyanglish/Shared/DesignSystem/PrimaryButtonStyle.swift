//
//  PrimaryButtonStyle.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/13/26.
//

import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var width: CGFloat?
    var horizontalPadding: CGFloat = 28
    var verticalPadding: CGFloat = 14

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color("PrimaryButtonText"))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(width: width)
            .background(Color("PrimaryButtonBackground"))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle {
        PrimaryButtonStyle()
    }

    static func primary(
        width: CGFloat? = nil,
        horizontalPadding: CGFloat = 28,
        verticalPadding: CGFloat = 14
    ) -> PrimaryButtonStyle {
        PrimaryButtonStyle(
            width: width,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        )
    }
}
