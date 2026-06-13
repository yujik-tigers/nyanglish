//
//  DailyMeowDTO.swift
//  Nyanglish
//
//  Created by OpenAI on 5/23/26.
//

import Foundation

struct DailyMeowAPIResponse<Content: Decodable>: Decodable {
    let statusCode: Int
    let statusMessage: String
    let content: Content

    private enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case statusMessage = "status_message"
        case content
    }
}

struct DailyMeowErrorResponse: Decodable {
    let detail: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let stringDetail = try? container.decode(String.self, forKey: .detail) {
            detail = stringDetail
        } else if let validationErrors = try? container.decode([DailyMeowValidationError].self, forKey: .detail) {
            detail = validationErrors.map(\.message).joined(separator: "\n")
        } else {
            detail = nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case detail
    }
}

private struct DailyMeowValidationError: Decodable {
    let message: String

    private enum CodingKeys: String, CodingKey {
        case message = "msg"
    }
}

struct DailyMeowContentResponse: Decodable {
    let id: Int
    let type: ContentType
    let status: ContentStatus
    let content: String?
    let contentTranslation: String?
    let expression: String?
    let expressionTranslation: String?
    let background: String?
    let createdAt: String
    let usedAt: String?
    let imageURL: String?
    let author: String?
    let title: String?
    let literalType: LiteralType?

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case status
        case content
        case contentTranslation = "content_translation"
        case expression
        case expressionTranslation = "expression_translation"
        case background
        case createdAt = "created_at"
        case usedAt = "used_at"
        case imageURL = "image_url"
        case author
        case title
        case literalType = "literal_type"
    }

    func dailyContentItem(dateKey: String, date: Date) -> DailyContentItem {
        DailyContentItem(
            dateKey: dateKey,
            date: date,
            category: type.displayName,
            topic: primaryText,
            translation: secondaryText,
            sourceText: sourceText,
            imageURL: resolvedImageURL
        )
    }

    private var primaryText: String {
        firstNonEmpty(expression, content, title, background) ?? "Today's content"
    }

    private var secondaryText: String {
        firstNonEmpty(expressionTranslation, contentTranslation, background) ?? ""
    }

    var fullTranslationText: String? {
        firstNonEmpty(contentTranslation)
    }

    private var sourceText: String {
        let parts = [author, title, literalType?.displayName]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }

        return parts.isEmpty ? "Daily Meow" : parts.joined(separator: " | ")
    }

    private var resolvedImageURL: String? {
        guard let imageURL, !imageURL.isEmpty else {
            return nil
        }

        return URL(string: imageURL, relativeTo: APIConfiguration.baseURL)?.absoluteString ?? imageURL
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        values.first { value in
            guard let value else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? nil
    }
}

enum ContentType: String, Decodable {
    case redditMeme = "reddit_meme"
    case quote
    case literalQuote = "literal_quote"
    case fact

    var displayName: String {
        switch self {
        case .redditMeme:
            return "Vocabulary / Expression"
        case .quote:
            return "Quote"
        case .literalQuote:
            return "Literal Quote"
        case .fact:
            return "Fact"
        }
    }
}

enum ContentStatus: String, Decodable {
    case raw
    case analyzed
    case pending
    case approved
    case rejected
    case used
}

enum LiteralType: String, Decodable {
    case movie
    case book

    var displayName: String {
        switch self {
        case .movie:
            return "Movie"
        case .book:
            return "Book"
        }
    }
}
