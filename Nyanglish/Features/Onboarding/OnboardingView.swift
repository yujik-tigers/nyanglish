//
//  OnboardingView.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/12/26.
//

import SwiftUI

struct OnboardingView: View {
    let onStart: () -> Void

    @State private var logoRevealProgress: CGFloat = 0
    @State private var isStartVisible = false

    private let logoAnimationDuration: Double = 1.6
    private let logoSize = CGSize(width: 190, height: 96)

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            revealedLogo

            Button {
                onStart()
            } label: {
                Text("Start")
                    .font(.headline.weight(.bold))
            }
            .buttonStyle(.primary(width: 176, verticalPadding: 20))
            .opacity(isStartVisible ? 1 : 0)
            .offset(y: isStartVisible ? 0 : 10)
            .disabled(!isStartVisible)

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Canvas"))
        .onAppear {
            startIntroAnimation()
        }
    }

    private var revealedLogo: some View {
        Image("OnboardingLogo")
            .resizable()
            .scaledToFit()
            .frame(width: logoSize.width, height: logoSize.height)
            .mask {
                logoRevealMask
            }
    }

    private var logoRevealMask: some View {
        GeometryReader { proxy in
            if logoRevealProgress >= 0.999 {
                Rectangle()
                    .fill(.white)
            } else {
                let width = proxy.size.width
                let revealWidth = width * logoRevealProgress
                let gradientWidth = min(44, revealWidth)

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.white)
                        .frame(width: max(0, revealWidth - gradientWidth))

                    LinearGradient(
                        colors: [.white, .white.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: gradientWidth)
                    .offset(x: max(0, revealWidth - gradientWidth))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    private func startIntroAnimation() {
        logoRevealProgress = 0
        isStartVisible = false

        withAnimation(.easeInOut(duration: logoAnimationDuration)) {
            logoRevealProgress = 1
        }

        withAnimation(.easeOut(duration: 0.35).delay(logoAnimationDuration + 0.12)) {
            isStartVisible = true
        }
    }
}

#Preview {
    OnboardingView {}
}
