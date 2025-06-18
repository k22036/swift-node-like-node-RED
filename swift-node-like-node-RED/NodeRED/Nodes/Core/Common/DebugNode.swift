//
//  DebugNode.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/17.
//

import Foundation
import DequeModule

class DebugNode: Codable, Node {
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
    
    var isRunning: Bool = false
    private var buffer: Deque<NodeMessage> = Deque<NodeMessage>()
    
    enum CodingKeys: String, CodingKey { // Coding keys for decoding
        case id, type, z, name, active, tosidebar, console, tostatus, complete, targetType, statusVal, statusType, x, y, wires
    }
    
    deinit {
        isRunning = false
    }
    
    func initalize() {
        isRunning = true
    }
    
    func execute() {
        Task {
            if !isRunning { return }
            
            while isRunning {
                if let msg = buffer.popFirst() {
                    // ノードのデバッグメッセージをログに出力
                    logNodeMessage(msg: msg)
                }
            }
        }
    }
    
    func terminate() {
        isRunning = false
    }
    
    func receive(msg: NodeMessage) {
        buffer.append(msg)
    }
    
    func send(msg: NodeMessage) {}
    
    
    /// 指定されたフォーマットでノードのデバッグメッセージをコンソールに出力
    /// - Parameters:
    ///   - nodeName: ログを出力するノードの名前 (例: "debug 2")
    ///   - payload: ログに出力する値 (Any型で様々なデータを受け取れます)
    private func logNodeMessage(msg: NodeMessage) {
        // 1. 現在の日付と時刻を "yyyy/MM/dd HH:mm:ss" 形式の文字列に変換
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // 形式を固定するためにロケールを指定
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())

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
            payloadType = "\(Swift.type(of: msg.payload))" // 型名をそのまま表示
            payloadValue = "\(msg.payload)"
        }
        
        // 3. ログメッセージを組み立てて出力
        print("\(timestamp) ノード: \(self.name)")
        print("msg.payload : \(payloadType)")
        print(payloadValue)
        print("----------------------------------------") // ログの区切り線
    }
}
