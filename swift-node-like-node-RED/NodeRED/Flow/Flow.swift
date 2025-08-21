//
//  Flow.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/18.
//

import Foundation

fileprivate actor FlowState: Sendable {
    private var nodes: [String: Node] = [:]
    private var tabs: [String: Tab] = [:]
    private var configs: [String: MQTTBroker] = [:]

    fileprivate func setNode(_ node: Node) {
        nodes[node.id] = node
    }
    fileprivate func getNode(by id: String) -> Node? {
        return nodes[id]
    }
    fileprivate func getNodes() -> [Node] {
        return Array(nodes.values)
    }

    fileprivate func setTab(_ tab: Tab) {
        tabs[tab.id] = tab
    }
    fileprivate func getTab(by id: String) -> Tab? {
        return tabs[id]
    }

    fileprivate func setConfig(_ config: MQTTBroker) {
        configs[config.id] = config
    }
    fileprivate func getConfig(by id: String) -> MQTTBroker? {
        return configs[id]
    }
}

final class Flow: Sendable {
    private let state = FlowState()

    private struct RawNode: Codable, Sendable {
        let type: String
    }

    init(flowJson: String) async throws {
        if flowJson.isEmpty {
            throw NSError(
                domain: "FlowError", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Flow JSON is empty"])
        }
        // Convert JSON array string to list of JSON strings
        guard let data = flowJson.data(using: .utf8) else {
            throw NSError(
                domain: "FlowError", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Flow JSON data"])
        }
        let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [Any] ?? []
        let flowJsonStrings = try jsonArray.map { element -> String in
            let elementData = try JSONSerialization.data(withJSONObject: element, options: [])
            guard let jsonString = String(data: elementData, encoding: .utf8) else {
                throw NSError(
                    domain: "FlowError", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to decode JSON element"])
            }
            return jsonString
        }

        // Parse each JSON string into Node instances
        for jsonString in flowJsonStrings {
            let jsonData = jsonString.data(using: .utf8)!
            let rawNode = try JSONDecoder().decode(RawNode.self, from: jsonData)

            if rawNode.type == FlowType.tab.rawValue {
                await addTab(from: jsonData)
            } else if rawNode.type == ConfigType.mqttBroker.rawValue {
                await addConfig(from: jsonData)
            } else if let node = createNode(jsonData: jsonData, type: rawNode.type) {
                await addNode(node)
            } else {
                print("Unsupported node type: \(rawNode.type)")
                continue
            }
        }
    }

    private func addTab(from jsonData: Data) async {
        do {
            let tab = try JSONDecoder().decode(Tab.self, from: jsonData)
            await state.setTab(tab)
        } catch {
            print("Error decoding Tab: \(error)")
        }
    }

    func getTab(by id: String) async -> Tab? {
        return await state.getTab(by: id)
    }

    private func addConfig(from jsonData: Data) async {
        do {
            let config = try JSONDecoder().decode(MQTTBroker.self, from: jsonData)
            await state.setConfig(config)
        } catch {
            print("Error decoding config: \(error)")
        }
    }

    func getConfig(by id: String) async -> MQTTBroker? {
        return await state.getConfig(by: id)
    }

    private func createNode(jsonData: Data, type: String) -> Node? {
        do {
            switch type {
            // common
            case NodeType.inject.rawValue:
                return try JSONDecoder().decode(InjectNode.self, from: jsonData)
            case NodeType.debug.rawValue:
                return try JSONDecoder().decode(DebugNode.self, from: jsonData)
            // function
            case NodeType.filter.rawValue:
                return try JSONDecoder().decode(FilterNode.self, from: jsonData)
            // network
            case NodeType.mqttin.rawValue:
                return try JSONDecoder().decode(MQTTInNode.self, from: jsonData)
            case NodeType.mqttout.rawValue:
                return try JSONDecoder().decode(MQTTOutNode.self, from: jsonData)
            case NodeType.httpRequest.rawValue:
                return try JSONDecoder().decode(HTTPRequestNode.self, from: jsonData)
            // mobile
            case NodeType.geolocation.rawValue:
                return try JSONDecoder().decode(GeolocationNode.self, from: jsonData)
            case NodeType.camera.rawValue:
                return try JSONDecoder().decode(CameraNode.self, from: jsonData)
            case NodeType.accelerometer.rawValue:
                return try JSONDecoder().decode(AccelerometerNode.self, from: jsonData)
            case NodeType.attitude.rawValue:
                return try JSONDecoder().decode(AttitudeNode.self, from: jsonData)
            case NodeType.magnetometer.rawValue:
                return try JSONDecoder().decode(MagnetometerNode.self, from: jsonData)
            case NodeType.gravity.rawValue:
                return try JSONDecoder().decode(GravityNode.self, from: jsonData)
            case NodeType.altitude.rawValue:
                return try JSONDecoder().decode(AltitudeNode.self, from: jsonData)
            case NodeType.velocity.rawValue:
                return try JSONDecoder().decode(VelocityNode.self, from: jsonData)
            case NodeType.pressure.rawValue:
                return try JSONDecoder().decode(PressureNode.self, from: jsonData)
            case NodeType.brightness.rawValue:
                return try JSONDecoder().decode(BrightnessNode.self, from: jsonData)
            case NodeType.direction.rawValue:
                return try JSONDecoder().decode(DirectionNode.self, from: jsonData)

            default:
                // Handle other node types or throw an error
                print("Unsupported node type: \(type)")
            }
        } catch {
            print("Error decoding node of type \(type): \(error)")
        }
        return nil
    }

    func addNode(_ node: Node) async {
        await state.setNode(node)
    }

    func getNode(by id: String) async -> Node? {
        return await state.getNode(by: id)
    }

    /// Returns the first CameraNode in this flow, if any
    func getCameraNode() async -> CameraNode? {
        return await state.getNodes().first(where: { $0 is CameraNode }) as? CameraNode
    }

    func start() async {
        await initialize()
        await execute()
    }

    func stop() async {
        await terminate()
    }

    // Extracted helpers for node lifecycle operations
    /// Applies the given action to all nodes that are available (not on a disabled tab).
    private func forEachAvailableNode(_ action: (Node) async -> Void) async {
        for node in await state.getNodes() where await isAvailableNode(node: node) {
            await action(node)
        }
    }

    /// Determines whether a node should participate based on its tab's disabled state.
    private func isAvailableNode(node: Node) async -> Bool {
        if let tab = await getTab(by: node.z), tab.disabled {  // z: ex. tab ID
            return false
        }
        return true
    }

    /// Applies the given action to all nodes regardless of availability.
    private func forEachNode(_ action: (Node) -> Void) async {
        for node in await state.getNodes() {
            action(node)
        }
    }

    func initialize() async {
        await forEachAvailableNode { await $0.initialize(flow: self) }
    }

    func execute() async {
        await forEachAvailableNode { await $0.execute() }
    }

    func terminate() async {
        let semaphore = AsyncSemaphore(value: 10)
        await withTaskGroup(of: Void.self) { group in
            for node in await state.getNodes() {
                group.addTask {
                    await semaphore.wait()
                    await node.terminate()
                    await semaphore.signal()
                }
            }
        }
    }

    func routeMessage(from sourceNode: Node, message: NodeMessage) async {
        let outputIndex = 0
        let targetNodeIds = sourceNode.wires[outputIndex]

        for nodeId in targetNodeIds {
            if let targetNode = await getNode(by: nodeId) {
                // メッセージクローンを作成
                let clonedMessage = cloneMessage(message)
                await targetNode.receive(msg: clonedMessage)
            }
        }
    }

    /// Deep copy implementation for NodeMessage.
    /// Note: This performs a shallow copy for payload and a shallow copy for each property value.
    /// If payload or property values are reference types, changes to their contents may affect the original.
    /// For true deep copy, ensure all properties and payload are value types or implement deep copy themselves.
    private func cloneMessage(_ msg: NodeMessage) -> NodeMessage {
        // Deep copyの実装
        var clonedMsg = NodeMessage(payload: msg.payload)
        clonedMsg.properties = msg.properties.mapValues { $0 }
        return clonedMsg
    }
}
