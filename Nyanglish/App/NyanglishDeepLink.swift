//
//  NyanglishDeepLink.swift
//  Nyanglish
//
//  Created by OpenAI on 7/19/26.
//

import Foundation

enum NyanglishDeepLink: Equatable {
    case todayContent

    init?(url: URL) {
        guard url.scheme == "nyanglish" else {
            return nil
        }

        if url.host == "content", url.path == "/today" {
            self = .todayContent
        } else {
            return nil
        }
    }
}
