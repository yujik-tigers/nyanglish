//
//  APIConfiguration.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/19/26.
//

import Foundation

enum APIConfiguration {
    // 개발 테스트용 HTTP 서버입니다. 배포 전 https://api.daily-meow.site 로 교체하면 됩니다.
    static let baseURL = URL(string: "http://www.daily-meow.site:8000")!
}
