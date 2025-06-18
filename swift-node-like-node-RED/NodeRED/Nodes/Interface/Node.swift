//
//  Node.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/16.
//

protocol Node {
    var id: String { get }
    var type: String { get }
    
    init(from decoder: any Decoder) throws
}

protocol StartNode: Node {
    func send(msg: NodeMessage)
}

protocol MiddleNode: Node {
    func receive(msg: NodeMessage)
    func send(msg: NodeMessage)
}

protocol EndNode: Node {
    func receive(msg: NodeMessage)
}
