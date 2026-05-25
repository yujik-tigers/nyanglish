//
//  DailyMeowAPIClient.swift
//  Nyanglish
//
//  Created by OpenAI on 5/23/26.
//

import Foundation

final class DailyMeowAPIClient {
    static let shared = DailyMeowAPIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    func get<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem]
    ) async throws -> Response {
        var components = URLComponents(url: APIConfiguration.baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw DailyMeowAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DailyMeowAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorResponse = try? decoder.decode(DailyMeowErrorResponse.self, from: data)
            throw DailyMeowAPIError.httpStatus(
                code: httpResponse.statusCode,
                detail: errorResponse?.detail
            )
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw DailyMeowAPIError.decodingFailed
        }
    }
}
