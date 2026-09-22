//
//  JournalEntry.swift
//  AI_Journel
//
//  Created by Arpit Parekh on 17/09/26.
//

import Foundation
import SwiftData

@Model
final class JournalEntry {
    var timestamp: Date
    var body: String
    var tags: [String]

    init(timestamp: Date = .now, body: String = "", tags: [String] = []) {
        self.timestamp = timestamp
        self.body = body
        self.tags = tags
    }
}
