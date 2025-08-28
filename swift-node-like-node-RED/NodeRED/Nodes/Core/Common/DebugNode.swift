//
//  DebugNode.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/17.
//

import Foundation

private actor DebugState: NodeState, Sendable {
    fileprivate weak var flow: Flow?
    fileprivate var isRunning: Bool = false

    fileprivate var currentTask: Task<Void, Never>?

    // AsyncStream continuation for event-driven message delivery
    fileprivate var messageContinuation: AsyncStream<NodeMessage>.Continuation?
    // AsyncStream for incoming messages as a computed property
    fileprivate var messageStream: AsyncStream<NodeMessage> {
        AsyncStream { continuation in
            self.messageContinuation = continuation
        }
    }

    fileprivate func setFlow(_ flow: Flow) {
        self.flow = flow
    }

    fileprivate func setIsRunning(_ running: Bool) {
        self.isRunning = running
    }

    fileprivate func setCurrentTask(_ task: Task<Void, Never>?) {
        self.currentTask = task
    }

    fileprivate func finishCurrentTask() async {
        currentTask?.cancel()
        await currentTask?.value  // Wait for the task to complete
        currentTask = nil
    }

    fileprivate func finishMessageStream() {
        messageContinuation?.finish()
        messageContinuation = nil
    }
}

final class DebugNode: Codable, Sendable, Node {
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
        case id, type, z, name, active, tosidebar, console, tostatus, complete, targetType,
            statusVal,
            statusType, x, y, wires
    }

    private let state = DebugState()

    var isRunning: Bool {
        get async {
            await state.isRunning
        }
    }

    func initialize(flow: Flow) async {
        await state.setFlow(flow)
        await state.setIsRunning(true)
    }

    func execute() async {
        // Prevent multiple executions
        if let task = await state.currentTask, !task.isCancelled {
            print("DebugNode: Already running, skipping execution.")
            return
        }

        let currentTask = Task { [weak self] in
            guard let self = self else { return }
            // Process messages as they arrive
            let messageStream = await state.messageStream
            for await msg in messageStream where await isRunning {
                logNodeMessage(msg: msg)
            }
        }
        await state.setCurrentTask(currentTask)
    }

    func terminate() async {
        await state.setIsRunning(false)
        await state.finishMessageStream()
        await state.finishCurrentTask()
    }

    deinit {
    }

    func receive(msg: NodeMessage) async {
        guard await isRunning else { return }
        // Deliver message to the AsyncStream
        await state.messageContinuation?.yield(msg)
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
