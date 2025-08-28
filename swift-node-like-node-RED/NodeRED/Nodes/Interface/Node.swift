//
//  Node.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/16.
//

protocol NodeState: Sendable {
    var flow: Flow? { get async }  // must weak to avoid retain cycles
    var isRunning: Bool { get async }
}

protocol Node: Sendable {
    var id: String { get }
    var type: String { get }
    var z: String { get }
    var wires: [[String]] { get }

    init(from decoder: any Decoder) throws

    var isRunning: Bool { get async }

    func initialize(flow: Flow) async
    func execute() async
    func terminate() async

    func receive(msg: NodeMessage) async
    func send(msg: NodeMessage) async
}
