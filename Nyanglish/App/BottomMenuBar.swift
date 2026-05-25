//
//  BottomMenuBar.swift
//  Nyanglish
//
//  Created by OpenAI on 5/23/26.
//

import SwiftUI

struct BottomMenuBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedTab = tab
                    }
                } label: {
                    Image(systemName: tab.systemImageName(isSelected: selectedTab == tab))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color(.darkGray))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .offset(y: -10)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.accessibilityLabel)
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(.separator).opacity(0.35))
                .frame(height: 1)
        }
    }
}
