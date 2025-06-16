//
//  Item.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/16.
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
