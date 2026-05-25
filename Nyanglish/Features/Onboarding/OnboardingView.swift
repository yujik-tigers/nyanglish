//
//  OnboardingView.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/12/26.
//

import SwiftUI

struct OnboardingView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image("OnboardingLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 80)

            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
                .overlay {
                    // 1080 x 1350 px
                    Image(systemName: "photo")
                        .font(.system(size: 44, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 620)
                .padding(.horizontal, 32)

            Spacer(minLength: 20)

            Button {
                onStart()
            } label: {
                Text("시작하기")
                    .font(.headline.weight(.bold))
            }
            .buttonStyle(.primary(width: 176, verticalPadding: 20))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color("Canvas"))
    }
}

#Preview {
    OnboardingView {}
}
