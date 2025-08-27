//
//  FilterNode.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/07/20.
//

import Foundation

private actor FilterState: NodeState, Sendable {
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

    fileprivate actor Previous {
        private var _previous: [String: String] = [:]

        fileprivate func setValue(_ value: String, forKey key: String) {
            _previous[key] = value
        }

        fileprivate func getValue(forKey key: String) -> String? {
            return _previous[key]
        }

        fileprivate func removeValue(forKey key: String) {
            _previous.removeValue(forKey: key)
        }

        fileprivate func removeAll() {
            _previous.removeAll()
        }
    }

    fileprivate let previous = Previous()
}

final class FilterNode: Codable, Sendable, Node {
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

    private let state = FilterState()

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
            print("FilterNode: Already running, skipping execution.")
            return
        }

        let currentTask = Task { [weak self] in
            guard let self = self else { return }
            // Process messages as they arrive
            let messageStream = await state.messageStream
            for await msg in messageStream where await isRunning {
                await filterNodeMessage(msg: msg)
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

    func send(msg: NodeMessage) async {
        await state.flow?.routeMessage(from: self, message: msg)
    }

    private func filterNodeMessage(msg: NodeMessage) async {
        let topic = Util.getMessageProperty(msg: msg, key: topi)

        let reset = Util.getMessageProperty(msg: msg, key: "reset") ?? "false"
        if reset != "false" {
            if septopics, let topic = topic, !topic.isEmpty {
                // delete the previous message for this topic
                await state.previous.removeValue(forKey: topic)
            } else {
                await state.previous.removeAll()
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
            let previousValue = await state.previous.getValue(forKey: t)
            let doSend = `func` != FuncType.rbei.rawValue || previousValue != nil
            if value != previousValue {
                await state.previous.setValue(value, forKey: t)
                if doSend {
                    await send(msg: msg)
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

            if await state.previous.getValue(forKey: t) == nil
                && (`func` == FuncType.narrowband.rawValue
                    || `func` == FuncType.narrowbandEq.rawValue)
            {
                if start == "" {
                    await state.previous.setValue(String(n), forKey: t)
                } else {
                    await state.previous.setValue(start, forKey: t)
                }
            }

            var gap: Double = self.gap
            if pc {
                let previousValue = await state.previous.getValue(forKey: t)
                let numericPrefix =
                    previousValue?.prefix { "0123456789.-+".contains($0) } ?? "_no_numeric_prefix"
                if numericPrefix.isEmpty {
                    return
                }

                if let previousValue = Double(numericPrefix) {
                    gap = abs(previousValue * (self.gap / 100.0))
                }
            }

            var previousValue = await state.previous.getValue(forKey: t)
            if previousValue == nil && `func` == FuncType.narrowbandEq.rawValue {
                previousValue = String(n)
                await state.previous.setValue(String(n), forKey: t)
            }
            if previousValue == nil {
                previousValue = String(n - gap - 1)
                await state.previous.setValue(String(n - gap - 1), forKey: t)
            }

            let previousNumericPrefix =
                previousValue?.prefix { "0123456789.-+".contains($0) } ?? "_no_numeric_prefix"
            guard !previousNumericPrefix.isEmpty,
                let previousValue = Double(previousNumericPrefix)
            else {
                print(
                    "FilterNode: Previous value (\(previousValue ?? "")) for topic '\(t)' is not a valid number."
                )
                return
            }

            if abs(n - previousValue) == gap {
                if `func` == FuncType.deadbandEq.rawValue || `func` == FuncType.narrowband.rawValue
                {
                    if `inout` == InOutType.out.rawValue {
                        await state.previous.setValue(String(n), forKey: t)
                    }
                    await send(msg: msg)
                }
            } else if abs(n - previousValue) > gap {
                if `func` == FuncType.deadband.rawValue || `func` == FuncType.deadbandEq.rawValue {
                    if `inout` == InOutType.out.rawValue {
                        await state.previous.setValue(String(n), forKey: t)
                    }
                    await send(msg: msg)
                }
            } else if abs(n - previousValue) < gap {
                if `func` == FuncType.narrowband.rawValue
                    || `func` == FuncType.narrowbandEq.rawValue
                {
                    if `inout` == InOutType.out.rawValue {
                        await state.previous.setValue(String(n), forKey: t)
                    }
                    await send(msg: msg)
                }
            }

            if `inout` == InOutType.in.rawValue {
                await state.previous.setValue(String(n), forKey: t)
            }
        }
    }
}
