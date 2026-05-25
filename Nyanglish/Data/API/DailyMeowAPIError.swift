//
//  DailyMeowAPIError.swift
//  Nyanglish
//
//  Created by OpenAI on 5/23/26.
//

import Foundation

enum DailyMeowAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(code: Int, detail: String?)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL, .invalidResponse, .httpStatus, .decodingFailed:
            return message
        }
    }

    private var message: String {
        switch self {
        case .httpStatus(404, let detail) where detail == "No approved meme available":
            return "오늘 휴강이에요!"
        case .httpStatus(404, let detail) where detail == "No approved content available":
            return "오늘 휴강이에요!"
        default:
            return "서버에 문제가 생겼어요! 잠시 후 다시 시도해 주세요."
        }
    }
}
