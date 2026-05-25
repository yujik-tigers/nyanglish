//
//  DailyContentRepository.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/13/26.
//

import Foundation

enum DailyContentRepository {
    static func fetchContent(for dateKey: String) async throws -> DailyContentItem {
        let response: DailyMeowAPIResponse<DailyMeowContentResponse> = try await DailyMeowAPIClient.shared.get(
            path: "/api/v1/contents/",
            queryItems: [
                URLQueryItem(name: "date", value: dateKey),
                URLQueryItem(name: "content_type", value: ContentType.redditMeme.rawValue)
            ]
        )

        let date = Date.nyanglishDate(fromKey: dateKey) ?? .now
        DailyContentSupplementStore.saveFullTranslation(response.content.fullTranslationText, for: dateKey)
        return response.content.dailyContentItem(dateKey: dateKey, date: date)
    }
}
