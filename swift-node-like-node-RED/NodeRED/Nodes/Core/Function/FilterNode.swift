//
//  FilterNode.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/07/20.
//

import Foundation

final class FilterNode: Codable, Node {
    let id: String
    let type: String
    let z: String
    let name: String
    let `func`: String
    let gap: Double
    let start: String
    let `inout`: String
    let septopics: Bool
    let property: String
    let topi: String
    private let x: Int
    private let y: Int
    let wires: [[String]]

    private let pc: Bool

    private enum FuncType: String {
        case rbe = "rbe"
        case rbei = "rbei"
        case deadbandEq = "deadbandEq"
        case deadband = "deadband"
        case narrowbandEq = "narrowbandEq"
        case narrowband = "narrowband"
    }

    private enum InOutType: String {
        case `in` = "in"
        case out = "out"
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)

        let _type = try container.decode(String.self, forKey: .type)
        guard _type == NodeType.filter.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Expected type to be 'rbe(filter)', but found \(_type)")
        }
        self.type = _type

        self.z = try container.decode(String.self, forKey: .z)
        self.name = try container.decode(String.self, forKey: .name)

        let _func = try container.decode(String.self, forKey: .func)
        guard let funcType = FuncType(rawValue: _func) else {
            throw DecodingError.dataCorruptedError(
                forKey: .func, in: container,
                debugDescription: "Invalid func type: \(_func)")
        }
        self.func = funcType.rawValue

        let gapString = try container.decode(String.self, forKey: .gap)
        if gapString == "" {
            // default case when gap is not specified
            self.gap = 0.0
            self.pc = false
        } else if gapString.hasSuffix("%") {
            guard let value = Double(gapString.dropLast()) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .gap, in: container,
                    debugDescription: "Invalid percentage gap value: \(gapString)")
            }
            self.gap = value
            self.pc = true
        } else {
            guard let value = Double(gapString) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .gap, in: container, debugDescription: "Invalid gap value: \(gapString)"
                )
            }
            self.gap = value
            self.pc = false
        }

        self.start = try container.decode(String.self, forKey: .start)

        let _inout = try container.decode(String.self, forKey: .`inout`)
        guard let inOutType = InOutType(rawValue: _inout) else {
            throw DecodingError.dataCorruptedError(
                forKey: .`inout`, in: container,
                debugDescription: "Invalid inout type: \(_inout)")
        }
        self.inout = inOutType.rawValue

        self.septopics = try container.decode(Bool.self, forKey: .septopics)
        self.property = try container.decode(String.self, forKey: .property)
        self.topi = try container.decode(String.self, forKey: .topi)
        self.x = try container.decode(Int.self, forKey: .x)
        self.y = try container.decode(Int.self, forKey: .y)
        self.wires = try container.decode([[String]].self, forKey: .wires)
    }

    private enum CodingKeys: String, CodingKey {  // Coding keys for decoding
        case id, type, z, name, `func`, gap, start, `inout`, septopics, property, topi, x, y, wires
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
            print("FilterNode: Already running, skipping execution.")
            return
        }

        currentTask = Task { [weak self] in
            guard let self = self else { return }
            // Process messages as they arrive
            for await msg in messageStream where isRunning {
                filterNodeMessage(msg: msg)
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
        guard isRunning else { return }
        // Deliver message to the AsyncStream
        messageContinuation?.yield(msg)
    }

    func send(msg: NodeMessage) {
        flow?.routeMessage(from: self, message: msg)
    }

    private var previous: [String: String] = [:]

    private func filterNodeMessage(msg: NodeMessage) {
        let topic = Util.getMessageProperty(msg: msg, key: topi)

        let reset = Util.getMessageProperty(msg: msg, key: "reset") ?? "false"
        if reset != "false" {
            if septopics, let topic = topic, !topic.isEmpty {
                // delete the previous message for this topic
                previous.removeValue(forKey: topic)
            } else {
                previous.removeAll()
            }

            return
        }

        guard let value = Util.getMessageProperty(msg: msg, key: property) else {
            print("FilterNode: No property '\(property)' found in message.")
            return
        }

        if value.isEmpty {
            return
        }

        let noTopic = "_no_topic"
        let t: String = septopics ? (topic ?? noTopic) : noTopic

        if `func` == FuncType.rbe.rawValue || `func` == FuncType.rbei.rawValue {
            let doSend = `func` != FuncType.rbei.rawValue || previous[t] != nil
            let previousValue = previous[t]
            if value != previousValue {
                previous[t] = value
                if doSend {
                    send(msg: msg)
                }
            }
        } else {
            let valueNumericPrefix = value.prefix { "0123456789.-+".contains($0) }
            guard !valueNumericPrefix.isEmpty, let n = Double(valueNumericPrefix) else {
                print("FilterNode: Invalid number for property '\(property)': \(value)")
                return
            }
            if n.isNaN {
                print("FilterNode: NaN value for property '\(property)': \(value)")
                return
            }

            if previous[t] == nil
                && (`func` == FuncType.narrowband.rawValue
                    || `func` == FuncType.narrowbandEq.rawValue)
            {
                if start == "" {
                    previous[t] = String(n)
                } else {
                    previous[t] = start
                }
            }

            var gap: Double = self.gap
            if pc {
                let numericPrefix =
                    previous[t]?.prefix { "0123456789.-+".contains($0) } ?? "_no_numeric_prefix"
                if numericPrefix.isEmpty {
                    return
                }

                if let previousValue = Double(numericPrefix) {
                    gap = abs(previousValue * (self.gap / 100.0))
                }
            }

            if previous[t] == nil && `func` == FuncType.narrowbandEq.rawValue {
                previous[t] = String(n)
            }
            if previous[t] == nil {
                previous[t] = String(n - gap - 1)
            }

            let previousNumericPrefix =
                previous[t]?.prefix { "0123456789.-+".contains($0) } ?? "_no_numeric_prefix"
            guard !previousNumericPrefix.isEmpty,
                let previousValue = Double(previousNumericPrefix)
            else {
                print("FilterNode: Previous value for topic '\(t)' is not a valid number.")
                return
            }

            if abs(n - previousValue) == gap {
                if `func` == FuncType.deadbandEq.rawValue || `func` == FuncType.narrowband.rawValue
                {
                    if `inout` == InOutType.out.rawValue {
                        previous[t] = String(n)
                    }
                    send(msg: msg)
                }
            } else if abs(n - previousValue) > gap {
                if `func` == FuncType.deadband.rawValue || `func` == FuncType.deadbandEq.rawValue {
                    if `inout` == InOutType.out.rawValue {
                        previous[t] = String(n)
                    }
                    send(msg: msg)
                }
            } else if abs(n - previousValue) < gap {
                if `func` == FuncType.narrowband.rawValue
                    || `func` == FuncType.narrowbandEq.rawValue
                {
                    if `inout` == InOutType.out.rawValue {
                        previous[t] = String(n)
                    }
                    send(msg: msg)
                }
            }

            if `inout` == InOutType.in.rawValue {
                previous[t] = String(n)
            }
        }
    }
}
