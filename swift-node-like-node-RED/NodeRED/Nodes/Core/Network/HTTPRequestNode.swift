//
//  HTTPRequestNode.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/30.
//

import Foundation

private actor HTTPRequestState: NodeState, Sendable {
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

final class HTTPRequestNode: Codable, Node, Sendable {
    let id: String
    let type: String
    let z: String
    let name: String
    let method: String
    let ret: String
    let paytoqs: String
    let url: String  // TODO: check url format
    let tls: String
    let persist: Bool
    let proxy: String
    let insecureHTTPParser: Bool
    let authType: String
    let senderr: Bool
    //    let headers: []
    private let x: Int
    private let y: Int
    let wires: [[String]]

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)

        let _type = try container.decode(String.self, forKey: .type)
        guard _type == NodeType.httpRequest.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Expected type to be 'http request', but found \(_type)")
        }
        self.type = _type

        self.z = try container.decode(String.self, forKey: .z)
        self.name = try container.decode(String.self, forKey: .name)
        self.method = try container.decode(String.self, forKey: .method)
        self.ret = try container.decode(String.self, forKey: .ret)
        self.paytoqs = try container.decode(String.self, forKey: .paytoqs)
        self.url = try container.decode(String.self, forKey: .url)
        self.tls = try container.decode(String.self, forKey: .tls)
        self.persist = try container.decode(Bool.self, forKey: .persist)
        self.proxy = try container.decode(String.self, forKey: .proxy)
        self.insecureHTTPParser = try container.decode(Bool.self, forKey: .insecureHTTPParser)
        self.authType = try container.decode(String.self, forKey: .authType)
        self.senderr = try container.decode(Bool.self, forKey: .senderr)
        self.x = try container.decode(Int.self, forKey: .x)
        self.y = try container.decode(Int.self, forKey: .y)
        self.wires = try container.decode([[String]].self, forKey: .wires)
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, z, name, method, ret, paytoqs, url, tls, persist, proxy, insecureHTTPParser,
            authType, senderr, x, y, wires
    }

    private let state = HTTPRequestState()

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
            print("HTTPRequestNode: already running, skipping execution.")
            return
        }

        let currentTask = Task { [weak self] in
            guard let self = self else { return }
            guard await isRunning else { return }

            // Build URL with query string if needed
            let requestURLString = self.url
            guard let requestURL = URL(string: requestURLString) else {
                print("Invalid URL: \(requestURLString)")
                return
            }
            let method = self.method.uppercased()

            let messageStream = await state.messageStream
            for await msg in messageStream where await isRunning {
                var request = URLRequest(url: requestURL)
                request.httpMethod = method
                if paytoqs == "body" {
                    if let dataPayload = msg.payload as? Data {
                        request.setValue(
                            "application/octet-stream", forHTTPHeaderField: "Content-Type")
                        request.httpBody = dataPayload
                    } else if let dictPayload = msg.payload as? [String: Any] {
                        if let bodyData = try? JSONSerialization.data(withJSONObject: dictPayload) {
                            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                            request.httpBody = bodyData
                        }
                    } else if let payloadStr = msg.payload as? String {
                        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                        request.httpBody = payloadStr.data(using: .utf8)
                    } else {
                        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
                        let payloadStr = "\(msg.payload)"
                        request.httpBody = payloadStr.data(using: .utf8)
                    }
                }
                do {
                    let (data, _) = try await URLSession.shared.data(for: request)
                    var responsePayload: any Sendable = data
                    switch ret {
                    case "txt":
                        responsePayload = String(data: data, encoding: .utf8) ?? ""
                    case "obj":
                        // JSONオブジェクトの場合
                        if let jsonObject = try? JSONSerialization.jsonObject(with: data)
                            as? [String: any Sendable]
                        {
                            responsePayload = jsonObject
                            // JSON配列の場合
                        } else if let jsonArray = try? JSONSerialization.jsonObject(with: data)
                            as? [any Sendable]
                        {
                            responsePayload = jsonArray
                            // どちらでもない場合
                        } else {
                            let ret: [String: any Sendable] = [:]
                            responsePayload = ret
                        }
                    case "bin":
                        responsePayload = data
                    default:
                        break
                    }
                    let outMsg = NodeMessage(payload: responsePayload)
                    await send(msg: outMsg)
                } catch is CancellationError {
                    // Task was cancelled, exit the loop
                    return
                } catch let urlError as URLError where urlError.code == .cancelled {
                    // URLSession task was cancelled (NSURLErrorDomain code=-999), treat like task cancellation
                    return
                } catch {
                    print("HTTPRequestNode error: \(error)")
                    let errMsg = NodeMessage(payload: error.localizedDescription)
                    await send(msg: errMsg)
                }
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
        if await !isRunning { return }
        // Deliver message to the AsyncStream
        await state.messageContinuation?.yield(msg)
    }

    func send(msg: NodeMessage) async {
        if await !isRunning { return }

        await state.flow?.routeMessage(from: self, message: msg)
    }
}
