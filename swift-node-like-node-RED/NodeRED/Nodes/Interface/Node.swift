//
//  Node.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/16.
//

protocol Node {
    var id: String { get }
    var type: String { get }
    var z: String { get }
    var wires: [[String]] { get }

    init(from decoder: any Decoder) throws

    var flow: Flow? { get }  // must weak to avoid retain cycles
    var isRunning: Bool { get }

    func initialize(flow: Flow)
    func execute()
    func terminate() async

    func receive(msg: NodeMessage)
    func send(msg: NodeMessage)
}
