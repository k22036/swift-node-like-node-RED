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

final class TestNode: Codable, Node {
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

  weak var flow: Flow?
  var isRunning: Bool = false
  var buffer: Deque<NodeMessage> = Deque<NodeMessage>()

  deinit {
    isRunning = false
  }

  func initialize(flow: Flow) {
    self.flow = flow
    isRunning = true
  }

  func execute() {}

  func terminate() {
    isRunning = false
  }

  func receive(msg: NodeMessage) {
    buffer.append(msg)
  }

  func send(msg: NodeMessage) {}
}
