//
//  AttendanceRecord.swift
//  Nyanglish
//
//  Created by Seoyeon Kim on 5/13/26.
//

import Foundation
import SwiftData

@Model
final class AttendanceRecord {
    @Attribute(.unique) var dateKey: String
    var checkedAt: Date

    init(dateKey: String, checkedAt: Date = .now) {
        self.dateKey = dateKey
        self.checkedAt = checkedAt
    }
}
