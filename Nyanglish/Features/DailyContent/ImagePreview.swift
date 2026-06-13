//
//  ImagePreview.swift
//  Nyanglish
//
//  Created by OpenAI on 5/23/26.
//

import SwiftUI

struct ImagePreviewItem: Identifiable {
    let url: URL

    var id: String {
        url.absoluteString
    }
}

struct ImagePreview: View {
    let url: URL
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 16)
                case .failure:
                    statusText("Couldn't load the image.")
                case .empty:
                    ProgressView()
                        .tint(.white)
                @unknown default:
                    statusText("Couldn't load the image.")
                }
            }

            HStack(spacing: 12) {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)
            .padding(.trailing, 20)
        }
    }

    private func statusText(_ text: String) -> some View {
        Text(text)
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(24)
    }
}
