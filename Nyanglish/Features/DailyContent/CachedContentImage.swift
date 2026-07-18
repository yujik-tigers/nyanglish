//
//  CachedContentImage.swift
//  Nyanglish
//
//  Created by OpenAI on 7/18/26.
//

import SwiftUI
import UIKit

struct CachedContentImage<Success: View, Loading: View, Failure: View>: View {
    let dateKey: String
    let imageURL: String
    let shouldCache: Bool
    let success: (Image) -> Success
    let loading: () -> Loading
    let failure: () -> Failure

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                success(Image(uiImage: image))
            } else if didFail {
                failure()
            } else {
                loading()
            }
        }
        .task(id: cacheKey) {
            await loadImage()
        }
    }

    private var cacheKey: String {
        "\(dateKey)-\(imageURL)"
    }

    @MainActor
    private func loadImage() async {
        image = nil
        didFail = false

        if shouldCache,
           let data = DailyContentImageCache.cachedImageData(for: dateKey, imageURL: imageURL),
           let cachedImage = UIImage(data: data) {
            image = cachedImage
            return
        }

        do {
            let data = try await DailyContentImageCache.imageData(
                for: dateKey,
                imageURL: imageURL,
                shouldCache: shouldCache
            )

            guard let downloadedImage = UIImage(data: data) else {
                didFail = true
                return
            }

            image = downloadedImage
        } catch {
            didFail = true
        }
    }
}
