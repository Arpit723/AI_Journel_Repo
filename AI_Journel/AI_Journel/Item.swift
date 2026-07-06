//
//  Item.swift
//  AI_Journel
//
//  Created by Arpit Parekh on 06/07/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
