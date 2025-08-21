//
//  TestNode.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/19.
//

//
//  DebugNode.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/17.
//

import DequeModule
import Foundation

fileprivate actor TestState: NodeState, Sendable {
    fileprivate weak var flow: Flow?
    fileprivate var isRunning: Bool = false
    fileprivate var buffer: Deque<NodeMessage> = Deque<NodeMessage>()

    fileprivate func setFlow(_ flow: Flow) {
        self.flow = flow
    }

    fileprivate func setIsRunning(_ running: Bool) {
        self.isRunning = running
    }

    fileprivate func bufferAppend(_ msg: NodeMessage) {
        buffer.append(msg)
    }
}

final class TestNode: Codable, Sendable, Node {
    let id: String
    let type: String
    let z: String
    let wires: [[String]]

    required init(id: String) throws {
        self.id = id
        self.type = "test"
        self.wires = []
        self.z = "test-z"
    }

    enum CodingKeys: String, CodingKey {  // Coding keys for decoding
        case id, type, z, wires
    }

    private let state = TestState()

    var isRunning: Bool {
        get async {
            await state.isRunning
        }
    }

    var buffer: Deque<NodeMessage> {
        get async {
            await state.buffer
        }
    }

    deinit {
    }

    func initialize(flow: Flow) async {
        await state.setFlow(flow)
        await state.setIsRunning(true)
    }

    func execute() {}

    func terminate() async {
        await state.setIsRunning(false)
    }

    func receive(msg: NodeMessage) async {
        await state.bufferAppend(msg)
    }

    func send(msg: NodeMessage) {}
}
