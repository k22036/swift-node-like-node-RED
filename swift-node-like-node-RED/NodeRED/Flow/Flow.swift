//
//  Flow.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/18.
//

class Flow {
    private var nodes: [String: Node] = [:]
    
    func addNode(_ node: Node) {
        nodes[node.id] = node
    }
      
    func routeMessage(from sourceNode: Node, message: NodeMessage) {
        let outputIndex = 0
        let targetNodeIds = sourceNode.wires[outputIndex]
          
        for nodeId in targetNodeIds {
            if let targetNode = nodes[nodeId] {
                // メッセージクローンを作成
                let clonedMessage = cloneMessage(message)
                targetNode.receive(msg: clonedMessage)
            }
        }
    }
      
    /// Deep copy implementation for NodeMessage.
    /// Note: This performs a shallow copy for payload and a shallow copy for each property value.
    /// If payload or property values are reference types, changes to their contents may affect the original.
    /// For true deep copy, ensure all properties and payload are value types or implement deep copy themselves.
    private func cloneMessage(_ msg: NodeMessage) -> NodeMessage {
        // Deep copyの実装
        var clonedMsg = NodeMessage(payload: msg.payload)
        clonedMsg.properties = msg.properties.mapValues { $0 }
        return clonedMsg
    }
}
