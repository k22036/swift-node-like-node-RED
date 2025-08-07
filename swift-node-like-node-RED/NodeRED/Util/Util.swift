//
//  Util.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/07/21.
//

import Foundation

class Util {
    static func getMessageProperty(msg: NodeMessage, key: String) -> String? {
        if key == "payload" {
            return Util.anyToString(msg.payload)
        } else if let value = msg.properties[key] {
            return Util.nodeMessageTypeToString(value)
        }
        return nil
    }

    static func isSameNodeMessage(_ msg1: NodeMessage, _ msg2: NodeMessage) -> Bool {
        if Util.anyToString(msg1.payload) != Util.anyToString(msg2.payload) {
            return false
        }

        let props1 = msg1.properties
        let props2 = msg2.properties

        if props1.count != props2.count {
            return false
        }

        for (key, value1) in props1 {
            if let value2 = props2[key] {
                if Util.nodeMessageTypeToString(value1) != Util.nodeMessageTypeToString(value2) {
                    return false
                }
            } else {
                return false
            }
        }

        return true
    }

    static func convertDictToJSON(_ dict: [String: Any]) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict) else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }

    static func anyToString(_ value: Any) -> String {
        if let stringValue = value as? String {
            return stringValue
        } else if let intValue = value as? Int {
            return String(intValue)
        } else if let doubleValue = value as? Double {
            return String(doubleValue)
        } else if let boolValue = value as? Bool {
            return String(boolValue)
        } else {
            return "\(value)"
        }
    }

    static func nodeMessageTypeToString(_ value: NodeMessageType) -> String {
        switch value {
        case .stringValue(let str):
            return str
        case .intValue(let int):
            return String(int)
        case .doubleValue(let double):
            return String(double)
        case .boolValue(let bool):
            return String(bool)
        }
    }
}
