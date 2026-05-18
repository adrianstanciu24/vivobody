//
//  Item.swift
//  workapp
//
//  Created by Adrian Stanciu on 18.05.2026.
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
