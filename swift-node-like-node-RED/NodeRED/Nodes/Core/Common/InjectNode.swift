//
//  InjectNode.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/16.
//

import Foundation


struct InjectNode: Codable, Node {
    let id: String
    let type: String
    let z: String
    let name: String
    let props: [Props]
    let `repeat`: Double
    let crontab: String
    let once: Bool
    let onceDelay: Double
    let topic: String
    let payload: String
    let payloadType: String
    let x: Int
    let y: Int
    let wires: [[String]]
    
    init(from decoder: Decoder) throws {
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
        guard let repeatValue = Double(_repeat) else {
            throw DecodingError.dataCorruptedError(forKey: .repeat, in: container, debugDescription: "Expected a Double value for repeat")
        }
        self.repeat = repeatValue
        
        self.crontab = try container.decode(String.self, forKey: .crontab)
        self.once = try container.decode(Bool.self, forKey: .once)
        let _onceDelay = try container.decode(String.self, forKey: .onceDelay)
        guard let onceDelayValue = Double(_onceDelay) else {
            throw DecodingError.dataCorruptedError(forKey: .onceDelay, in: container, debugDescription: "Expected a Double value for onceDelay")
        }
        self.onceDelay = onceDelayValue
        
        self.topic = try container.decode(String.self, forKey: .topic)
        self.payload = try container.decode(String.self, forKey: .payload)
        self.payloadType = try container.decode(String.self, forKey: .payloadType)
        self.x = try container.decode(Int.self, forKey: .x)
        self.y = try container.decode(Int.self, forKey: .y)
        self.wires = try container.decode([[String]].self, forKey: .wires)
    }
    
    struct Props: Codable {
        let p: String
        let vt: String?
    }
}
