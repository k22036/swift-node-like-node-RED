//
//  DebugNode.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/17.
//

import Foundation

final class DebugNode: Codable, Node {
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
  private let x: Int
  private let y: Int
  let wires: [[String]]

  required init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)

    let _type = try container.decode(String.self, forKey: .type)
    guard _type == NodeType.debug.rawValue else {
      throw DecodingError.dataCorruptedError(
        forKey: .type, in: container,
        debugDescription: "Expected type to be 'debug', but found \(_type)")
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

  private enum CodingKeys: String, CodingKey {  // Coding keys for decoding
    case id, type, z, name, active, tosidebar, console, tostatus, complete, targetType, statusVal,
      statusType, x, y, wires
  }

  weak var flow: Flow?
  var isRunning: Bool = false
  // AsyncStream continuation for event-driven message delivery
  private var messageContinuation: AsyncStream<NodeMessage>.Continuation?
  // AsyncStream for incoming messages
  private lazy var messageStream: AsyncStream<NodeMessage> = AsyncStream { continuation in
    self.messageContinuation = continuation
  }

  deinit {
    isRunning = false
  }

  func initialize(flow: Flow) {
    self.flow = flow
    isRunning = true
  }

  func execute() {
    Task {
      // Process messages as they arrive
      for await msg in messageStream where isRunning {
        logNodeMessage(msg: msg)
      }
    }
  }

  func terminate() {
    isRunning = false
  }

  func receive(msg: NodeMessage) {
    guard isRunning else { return }
    // Deliver message to the AsyncStream
    messageContinuation?.yield(msg)
  }

  func send(msg: NodeMessage) {}

  /// 指定されたフォーマットでノードのデバッグメッセージをコンソールに出力
  /// - Parameters:
  ///   - nodeName: ログを出力するノードの名前 (例: "debug 2")
  ///   - payload: ログに出力する値 (Any型で様々なデータを受け取れます)
  private func logNodeMessage(msg: NodeMessage) {
    // 1. 現在の日付と時刻をフォーマット
    let timestamp = DebugNode.dateFormatter.string(from: Date())

    // 2. ペイロードの型を判定して、表示用の文字列を生成
    let payloadType: String
    let payloadValue: String

    switch msg.payload {
    case is Int, is Double, is Float:
      // 数値型の場合
      payloadType = "number"
      payloadValue = "\(msg.payload)"
    case let string as String:
      // 文字列型の場合
      payloadType = "string"
      payloadValue = "\"\(string)\""
    default:
      // その他の型の場合
      payloadType = "\(Swift.type(of: msg.payload))"  // 型名をそのまま表示
      payloadValue = "\(msg.payload)"
    }

    // 3. ログメッセージを組み立てて出力
    print("\(timestamp) ノード: \(self.name)")
    print("msg.payload : \(payloadType)")
    print(payloadValue)
    print("----------------------------------------")  // ログの区切り線
  }

  /// Shared DateFormatter for log timestamps
  private static let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.dateFormat = "yyyy/MM/dd HH:mm:ss"
    return df
  }()
}
