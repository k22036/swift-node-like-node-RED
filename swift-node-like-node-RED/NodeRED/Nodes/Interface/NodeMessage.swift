//
//  NodeMessage.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/17.
//

import Foundation

struct NodeMessage {
    var payload: Any
    private var _msgid: String
    var properties: [String: NodeMessageType] = [:]
      
    init(payload: Any) {
        self.payload = payload
        self._msgid = UUID().uuidString
    }
}

enum NodeMessageType: Equatable {
    case intValue(Int)
    case doubleValue(Double)
    case stringValue(String)
    case boolValue(Bool)
    
    var isIntValue: Bool {
        if case .intValue = self { return true }
        return false
    }
    
    var isDoubleValue: Bool {
        if case .doubleValue = self { return true }
        return false
    }
    
    var isStringValue: Bool {
        if case .stringValue = self { return true }
        return false
    }
    
    var isBoolValue: Bool {
        if case .boolValue = self { return true }
        return false
    }
}
