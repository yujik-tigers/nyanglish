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
            return "No lesson is available today."
        case .httpStatus(404, let detail) where detail == "No approved content available":
            return "No lesson is available today."
        default:
            return "Something went wrong. Please try again later."
        }
    }
}
