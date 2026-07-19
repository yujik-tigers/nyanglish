//
//  DailyContentImageCache.swift
//  Nyanglish
//
//  Created by OpenAI on 7/18/26.
//

import Foundation
import UIKit

enum DailyContentImageCache {
    private static let imagesDirectoryName = "DailyContentImages"
    private static let imageFileName = "content.image"
    private static let widgetThumbnailFileName = "widget-thumbnail.image"
    private static let sourceURLFileName = "source.url"
    private static let widgetThumbnailMaxPixelLength: CGFloat = 360
    private static let widgetThumbnailCompressionQuality: CGFloat = 0.78

    static func cachedImageData(for dateKey: String, imageURL: String?) -> Data? {
        guard let imageURL, !imageURL.isEmpty else {
            return nil
        }

        let directory = imageDirectory(for: dateKey)
        guard sourceURL(in: directory) == imageURL else {
            return nil
        }

        return try? Data(contentsOf: directory.appendingPathComponent(imageFileName))
    }

    static func cachedWidgetThumbnailData(for dateKey: String, imageURL: String?) -> Data? {
        guard let imageURL, !imageURL.isEmpty else {
            return nil
        }

        let directory = imageDirectory(for: dateKey)
        guard sourceURL(in: directory) == imageURL else {
            return nil
        }

        return try? Data(contentsOf: directory.appendingPathComponent(widgetThumbnailFileName))
    }

    static func imageData(
        for dateKey: String,
        imageURL: String?,
        shouldCache: Bool
    ) async throws -> Data {
        guard let imageURL, let url = URL(string: imageURL) else {
            throw DailyContentImageCacheError.invalidURL
        }

        if shouldCache, let cachedData = cachedImageData(for: dateKey, imageURL: imageURL) {
            return cachedData
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw DailyContentImageCacheError.downloadFailed
        }

        if shouldCache {
            try save(data, for: dateKey, imageURL: imageURL)
        }

        return data
    }

    static func prepareWidgetThumbnail(
        for dateKey: String,
        imageURL: String?,
        sourceData: Data? = nil
    ) async throws -> Data {
        if let cachedThumbnail = cachedWidgetThumbnailData(for: dateKey, imageURL: imageURL) {
            return cachedThumbnail
        }

        let originalData: Data
        if let sourceData {
            originalData = sourceData
        } else if let cachedData = cachedImageData(for: dateKey, imageURL: imageURL) {
            originalData = cachedData
        } else {
            originalData = try await imageData(for: dateKey, imageURL: imageURL, shouldCache: true)
        }

        let thumbnailData = try makeWidgetThumbnailData(from: originalData)
        try saveWidgetThumbnail(thumbnailData, for: dateKey, imageURL: imageURL)
        return thumbnailData
    }

    static func remoteImageData(imageURL: String?, timeout: TimeInterval = 8) async throws -> Data {
        guard let imageURL, let url = URL(string: imageURL) else {
            throw DailyContentImageCacheError.invalidURL
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw DailyContentImageCacheError.downloadFailed
        }

        return data
    }

    static func pruneExpiredImages(today: Date = .now) {
        let root = imageCacheRootDirectory()
        guard let dateDirectories = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ) else {
            return
        }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        let cutoffDate = calendar.date(
            byAdding: .day,
            value: -DailyContentCachePolicy.retentionDays,
            to: todayStart
        ) ?? todayStart

        for directory in dateDirectories {
            let dateKey = directory.lastPathComponent
            guard let date = Date.nyanglishDate(fromKey: dateKey),
                  calendar.startOfDay(for: date) >= cutoffDate else {
                try? FileManager.default.removeItem(at: directory)
                continue
            }
        }
    }

    private static func save(_ data: Data, for dateKey: String, imageURL: String) throws {
        let directory = imageDirectory(for: dateKey)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(imageFileName), options: .atomic)
        try imageURL.write(
            to: directory.appendingPathComponent(sourceURLFileName),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func saveWidgetThumbnail(_ data: Data, for dateKey: String, imageURL: String?) throws {
        guard let imageURL, !imageURL.isEmpty else {
            throw DailyContentImageCacheError.invalidURL
        }

        let directory = imageDirectory(for: dateKey)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(widgetThumbnailFileName), options: .atomic)

        if sourceURL(in: directory) != imageURL {
            try imageURL.write(
                to: directory.appendingPathComponent(sourceURLFileName),
                atomically: true,
                encoding: .utf8
            )
        }
    }

    private static func makeWidgetThumbnailData(from data: Data) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw DailyContentImageCacheError.invalidImage
        }

        let scale = min(
            widgetThumbnailMaxPixelLength / max(image.size.width, 1),
            widgetThumbnailMaxPixelLength / max(image.size.height, 1),
            1
        )
        let targetSize = CGSize(
            width: max(image.size.width * scale, 1),
            height: max(image.size.height * scale, 1)
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let thumbnailData = thumbnail.jpegData(compressionQuality: widgetThumbnailCompressionQuality) else {
            throw DailyContentImageCacheError.invalidImage
        }

        return thumbnailData
    }

    private static func sourceURL(in directory: URL) -> String? {
        try? String(
            contentsOf: directory.appendingPathComponent(sourceURLFileName),
            encoding: .utf8
        )
    }

    private static func imageDirectory(for dateKey: String) -> URL {
        imageCacheRootDirectory().appendingPathComponent(dateKey, isDirectory: true)
    }

    private static func imageCacheRootDirectory() -> URL {
        let baseDirectory = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: NyanglishModelStore.appGroupIdentifier)?
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]

        return baseDirectory.appendingPathComponent(imagesDirectoryName, isDirectory: true)
    }
}

enum DailyContentImageCacheError: LocalizedError {
    case invalidURL
    case downloadFailed
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Couldn't download the image."
        case .downloadFailed:
            "Couldn't download the image."
        case .invalidImage:
            "Couldn't load the image."
        }
    }
}
