//
//  PhotoLibraryImageSaver.swift
//  Nyanglish
//
//  Created by OpenAI on 7/18/26.
//

import Foundation
import Photos
import UIKit

enum PhotoLibraryImageSaver {
    static func saveContentImage(
        dateKey: String,
        imageURL: String?,
        shouldCache: Bool
    ) async throws {
        let data = try await DailyContentImageCache.imageData(
            for: dateKey,
            imageURL: imageURL,
            shouldCache: shouldCache
        )

        guard let image = UIImage(data: data) else {
            throw PhotoLibraryImageSaveError.invalidImage
        }

        let status = await requestAddOnlyAuthorization()
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryImageSaveError.permissionDenied
        }

        try await save(image)
    }

    private static func requestAddOnlyAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private static func save(_ image: UIImage) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: PhotoLibraryImageSaveError.saveFailed)
                }
            }
        }
    }
}

enum PhotoLibraryImageSaveError: LocalizedError {
    case permissionDenied
    case invalidImage
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Allow photo access in Settings to save images."
        case .invalidImage:
            "Couldn't save this image."
        case .saveFailed:
            "Couldn't save this image."
        }
    }
}
