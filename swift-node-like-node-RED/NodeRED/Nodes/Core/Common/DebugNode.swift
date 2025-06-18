//
//  DebugNode.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/17.
//

class DebugNode: Codable, EndNode {
    let id: String
    let type: String
    let z: String
    let name: String
    let active: Bool
    let tosidebar: Bool
    let console: Bool
    let tostatus: Bool
    let complete: String
    let targetType: String
    let statusVal: String
    let statusType: String
    let x: Int
    let y: Int
    let wires: [[String]]
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        
        let _type = try container.decode(String.self, forKey: .type)
        guard _type == "debug" else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Expected type to be 'debug', but found \(_type)")
        }
        self.type = _type
        
        self.z = try container.decode(String.self, forKey: .z)
        self.name = try container.decode(String.self, forKey: .name)
        self.active = try container.decode(Bool.self, forKey: .active)
        self.tosidebar = try container.decode(Bool.self, forKey: .tosidebar)
        self.console = try container.decode(Bool.self, forKey: .console)
        self.tostatus = try container.decode(Bool.self, forKey: .tostatus)
        self.complete = try container.decode(String.self, forKey: .complete)
        self.targetType = try container.decode(String.self, forKey: .targetType)
        self.statusVal = try container.decode(String.self, forKey: .statusVal)
        self.statusType = try container.decode(String.self, forKey: .statusType)
        self.x = try container.decode(Int.self, forKey: .x)
        self.y = try container.decode(Int.self, forKey: .y)
        self.wires = try container.decode([[String]].self, forKey: .wires)
    }
    
    func receive(msg: NodeMessage) {
        // TODO: Implement message receiving logic
    }
}
