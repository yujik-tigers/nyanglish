//
//  DailyContentItem.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/13/26.
//

import Foundation
import SwiftData

@Model
final class DailyContentItem {
    @Attribute(.unique) var dateKey: String
    var date: Date
    var category: String
    var topic: String
    var translation: String
    var sourceText: String
    var imageURL: String?

    init(
        dateKey: String,
        date: Date,
        category: String,
        topic: String,
        translation: String,
        sourceText: String,
        imageURL: String? = nil
    ) {
        self.dateKey = dateKey
        self.date = date
        self.category = category
        self.topic = topic
        self.translation = translation
        self.sourceText = sourceText
        self.imageURL = imageURL
    }
}
