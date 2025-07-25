//
//  HTTPRequestNode.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/30.
//

import Foundation

final class HTTPRequestNode: Codable, Node {
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

    weak var flow: Flow?
    var isRunning: Bool = false
    private var currentTask: Task<Void, Never>?

    // AsyncStream continuation for event-driven message delivery
    private var messageContinuation: AsyncStream<NodeMessage>.Continuation?
    // AsyncStream for incoming messages
    private lazy var messageStream: AsyncStream<NodeMessage> = AsyncStream { continuation in
        self.messageContinuation = continuation
    }

    func initialize(flow: Flow) {
        self.flow = flow
        isRunning = true

        messageStream = AsyncStream { continuation in
            messageContinuation = continuation
        }
    }

    func execute() {
        // Prevent multiple executions
        if let task = currentTask, !task.isCancelled {
            print("HTTPRequestNode: already running, skipping execution.")
            return
        }

        currentTask = Task { [weak self] in
            guard let self = self else { return }
            guard isRunning else { return }

            // Build URL with query string if needed
            let requestURLString = self.url
            guard let requestURL = URL(string: requestURLString) else {
                print("Invalid URL: \(requestURLString)")
                return
            }
            let method = self.method.uppercased()

            for await msg in messageStream where isRunning {
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
                    }
                }
                do {
                    let (data, _) = try await URLSession.shared.data(for: request)
                    var responsePayload: Any = data
                    switch ret {
                    case "txt":
                        responsePayload = String(data: data, encoding: .utf8) ?? ""
                    case "obj":
                        responsePayload = (try? JSONSerialization.jsonObject(with: data)) ?? [:]
                    case "bin":
                        responsePayload = data
                    default:
                        break
                    }
                    let outMsg = NodeMessage(payload: responsePayload)
                    send(msg: outMsg)
                } catch is CancellationError {
                    // Task was cancelled, exit the loop
                    return
                } catch {
                    print("HTTPRequestNode error: \(error)")
                    if senderr {
                        let errMsg = NodeMessage(payload: error.localizedDescription)
                        send(msg: errMsg)
                    }
                }
            }
        }
    }

    func terminate() async {
        isRunning = false
        currentTask?.cancel()

        if let task = currentTask {
            _ = await task.value  // Wait for the task to complete
        }
        currentTask = nil
        messageContinuation?.finish()  // Signal the end of the stream
    }

    deinit {
        isRunning = false
        currentTask?.cancel()
        messageContinuation?.finish()
    }

    func receive(msg: NodeMessage) {
        if !isRunning { return }
        // Deliver message to the AsyncStream
        messageContinuation?.yield(msg)
    }

    func send(msg: NodeMessage) {
        if !isRunning { return }

        flow?.routeMessage(from: self, message: msg)
    }
}
