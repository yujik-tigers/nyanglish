//
//  DailyContentRepository.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/13/26.
//

import Foundation

enum DailyContentRepository {
    static func fetchContent(for dateKey: String) async throws -> DailyContentItem {
        try await fetchContentResult(for: dateKey, cacheSupplement: true).item
    }

    static func fetchContentResult(
        for dateKey: String,
        cacheSupplement: Bool
    ) async throws -> DailyContentFetchResult {
        let response: DailyMeowAPIResponse<DailyMeowContentResponse> = try await DailyMeowAPIClient.shared.get(
            path: "/api/v1/contents/",
            queryItems: [
                URLQueryItem(name: "date", value: dateKey),
                URLQueryItem(name: "content_type", value: ContentType.redditMeme.rawValue)
            ]
        )

        let date = Date.nyanglishDate(fromKey: dateKey) ?? .now
        let fullTranslation = response.content.fullTranslationText
        if cacheSupplement {
            DailyContentSupplementStore.saveFullTranslation(fullTranslation, for: dateKey)
        }
        let item = response.content.dailyContentItem(dateKey: dateKey, date: date)

        return DailyContentFetchResult(
            item: item,
            fullTranslation: fullTranslation
        )
    }
}

struct DailyContentFetchResult {
    let item: DailyContentItem
    let fullTranslation: String?
}
