//
//  NodeMessage.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/17.
//

import Foundation

struct NodeMessage {
    var payload: Any
    var _msgid: String
    var properties: [String: Any] = [:]
      
    init(payload: Any) {
        self.payload = payload
        self._msgid = UUID().uuidString
    }
}
