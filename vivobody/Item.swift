//
//  Item.swift
//  vivobody
//
//  Created by Adrian Stanciu on 11.03.2026.
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
