//
//  DailyContentImageCache.swift
//  Nyanglish
//
//  Created by OpenAI on 7/18/26.
//

import Foundation

enum DailyContentImageCache {
    private static let imagesDirectoryName = "DailyContentImages"
    private static let imageFileName = "content.image"
    private static let sourceURLFileName = "source.url"

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

    static func cacheImageIfNeeded(for item: DailyContentItem, shouldCache: Bool) async {
        guard shouldCache, item.imageURL != nil else {
            return
        }

        _ = try? await imageData(
            for: item.dateKey,
            imageURL: item.imageURL,
            shouldCache: shouldCache
        )
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

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Couldn't download the image."
        case .downloadFailed:
            "Couldn't download the image."
        }
    }
}
