//
//  ImagePreview.swift
//  Nyanglish
//
//  Created by OpenAI on 5/23/26.
//

import SwiftUI

struct ImagePreviewItem: Identifiable {
    let dateKey: String
    let imageURL: String

    var id: String {
        "\(dateKey)-\(imageURL)"
    }
}

struct ImagePreview: View {
    let dateKey: String
    let imageURL: String
    let shouldCache: Bool
    let isSavingImage: Bool
    @Binding var saveAlert: ImageSaveAlert?
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            CachedContentImage(
                dateKey: dateKey,
                imageURL: imageURL,
                shouldCache: shouldCache
            ) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 16)
            } loading: {
                ProgressView()
                    .tint(.white)
            } failure: {
                statusText("Couldn't load the image.")
            }

            HStack(spacing: 12) {
                Button(action: onSave) {
                    if isSavingImage {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSavingImage)

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
        .alert(item: $saveAlert) { alert in
            Alert(title: Text(alert.message))
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
