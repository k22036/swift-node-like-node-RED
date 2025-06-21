//
//  InjectNode.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/16.
//

import Foundation


class InjectNode: Codable, Node {
    let id: String
    let type: String
    let z: String
    let name: String
    let props: [Props]
    let `repeat`: Double?
    let crontab: String
    let once: Bool
    let onceDelay: Double
    let topic: String
    let payload: String
    let payloadType: String
    let x: Int
    let y: Int
    let wires: [[String]]
    
    struct Props: Codable {
        let p: String
        let v: String?
        let vt: String?
    }
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        
        let _type = try container.decode(String.self, forKey: .type)
        guard _type == "inject" else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Expected type to be 'inject', but found \(_type)")
        }
        self.type = _type
        
        self.z = try container.decode(String.self, forKey: .z)
        self.name = try container.decode(String.self, forKey: .name)
        self.props = try container.decode([Props].self, forKey: .props)
        
        let _repeat = try container.decode(String.self, forKey: .repeat)
        if _repeat.isEmpty {
            self.repeat = nil
        } else if let repeatValue = Double(_repeat) {
            self.repeat = repeatValue
        } else {
            throw DecodingError.dataCorruptedError(forKey: .repeat, in: container, debugDescription: "Expected a Double value for repeat")
        }
        
        self.crontab = try container.decode(String.self, forKey: .crontab)
        self.once = try container.decode(Bool.self, forKey: .once)
        
        // onceDelay can be either a String or a Number in the JSON
        if let onceDelayDouble = try? container.decode(Double.self, forKey: .onceDelay) {
            self.onceDelay = onceDelayDouble
        } else if let onceDelayString = try? container.decode(String.self, forKey: .onceDelay),
                  let onceDelayValue = Double(onceDelayString) {
            self.onceDelay = onceDelayValue
        } else {
            throw DecodingError.dataCorruptedError(forKey: .onceDelay, in: container, debugDescription: "Expected a Double or String convertible to Double for onceDelay")
        }
        
        self.topic = try container.decode(String.self, forKey: .topic)
        self.payload = try container.decode(String.self, forKey: .payload)
        self.payloadType = try container.decode(String.self, forKey: .payloadType)
        self.x = try container.decode(Int.self, forKey: .x)
        self.y = try container.decode(Int.self, forKey: .y)
        self.wires = try container.decode([[String]].self, forKey: .wires)
    }
    
    enum CodingKeys: String, CodingKey { // Coding keys for decoding
        case id, type, z, name, props, `repeat`, crontab, once, onceDelay, topic, payload, payloadType, x, y, wires
    }
    
    weak var flow: Flow?
    var isRunning: Bool = false
    
    deinit {
        isRunning = false
    }
    
    func initalize(flow: Flow) {
        self.flow = flow
        isRunning = true
    }
    
    func execute() {
        Task {
            if !isRunning { return }
            
            if once {
                // If the node is set to trigger once, wait for the specified delay before sending the message
                if onceDelay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(onceDelay * 1_000_000_000))
                }
                if !isRunning { return }
                let msg = createMessage()
                send(msg: msg)
            }
            
            guard let repeatValue = `repeat`, repeatValue > 0 else {
                print("No repeat set or repeat value is zero. Exiting execution.")
                return // If no repeat is set, exit
            }
                
            while isRunning {
                try await Task.sleep(nanoseconds: UInt64(repeatValue * 1_000_000_000))
                if !isRunning { return }
                let msg = createMessage()
                send(msg: msg)
            }
        }
    }
    
    func terminate() {
        isRunning = false
    }
    
    func receive(msg: NodeMessage) {}
    
    func send(msg: NodeMessage) {
        flow?.routeMessage(from: self, message: msg)
    }
    
    private func createMessage() -> NodeMessage {
        var msg: NodeMessage
        
        switch payloadType {
        case NodeRedType.date.rawValue:
            msg = NodeMessage(payload: Date().timeIntervalSince1970)
        case NodeRedType.number.rawValue:
            if let value = convertToNumber(payload) {
                msg = NodeMessage(payload: value)
            } else {
                msg = NodeMessage(payload: 0) // Default value if conversion fails
            }
        case NodeRedType.boolean.rawValue:
            let value = convertToBoolean(payload) ?? false // Default value if conversion fails
            msg = NodeMessage(payload: value)
        default:
            msg = NodeMessage(payload: payload)
        }
        
        for prop in props {
            if prop.p == "payload" {
                continue // payload is already set
            }
            
            guard let vt = prop.vt else {
                continue // Skip if type is not specified
            }
            let propValue = prop.v ?? ""
            
            guard let property = convertToNodeMessageType(propValue, vt: vt) else {
                continue // Skip if conversion fails
            }
            msg.properties[prop.p] = property
        }
        
        return msg
    }
    
    private func convertToNodeMessageType(_ value: String, vt: String) -> NodeMessageType? {
        switch vt {
        case NodeRedType.date.rawValue:
            return NodeMessageType.intValue(Int(Date().timeIntervalSince1970))
        case NodeRedType.number.rawValue:
            if let intValue = Int(value) {
                return NodeMessageType.intValue(intValue)
            } else if let doubleValue = Double(value) {
                return NodeMessageType.doubleValue(doubleValue)
            } else {
                return nil // Conversion failed
            }
        case NodeRedType.string.rawValue:
            return NodeMessageType.stringValue(value)
        case NodeRedType.boolean.rawValue:
            return NodeMessageType.boolValue(convertToBoolean(value) ?? false) // Default to false if conversion fails
        default:
            return nil // Unsupported type
        }
    }
    
    /// Convert string to number (Int or Double)
    private func convertToNumber(_ value: String) -> Any? {
        if let intValue = Int(value) {
            return intValue
        } else if let doubleValue = Double(value) {
            return doubleValue
        }
        return nil
    }
    
    /// Convert string to boolean with extended support
    private func convertToBoolean(_ value: String) -> Bool? {
        let lowercased = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch lowercased {
        case "true":
            return true
        case "false":
            return false
        default:
            return nil
        }
    }
}
