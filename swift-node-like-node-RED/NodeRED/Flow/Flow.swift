//
//  Flow.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/18.
//

import Foundation

final class Flow {
    private var nodes: [String: Node] = [:]
    private var tab: [String: Tab] = [:]
    private var config: [String: MQTTBroker] = [:]

    private struct RawNode: Codable {
        let type: String
    }

    init(flowJson: String) throws {
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
                addTab(from: jsonData)
            } else if rawNode.type == ConfigType.mqttBroker.rawValue {
                addConfig(from: jsonData)
            } else if let node = createNode(jsonData: jsonData, type: rawNode.type) {
                addNode(node)
            } else {
                print("Unsupported node type: \(rawNode.type)")
                continue
            }
        }
    }

    private func addTab(from jsonData: Data) {
        do {
            let tab = try JSONDecoder().decode(Tab.self, from: jsonData)
            self.tab[tab.id] = tab
        } catch {
            print("Error decoding Tab: \(error)")
        }
    }

    func getTab(by id: String) -> Tab? {
        return tab[id]
    }

    private func addConfig(from jsonData: Data) {
        do {
            let config = try JSONDecoder().decode(MQTTBroker.self, from: jsonData)
            self.config[config.id] = config
        } catch {
            print("Error decoding config: \(error)")
        }
    }

    func getConfig(by id: String) -> MQTTBroker? {
        return config[id]
    }

    private func createNode(jsonData: Data, type: String) -> Node? {
        do {
            switch type {
            // common
            case NodeType.inject.rawValue:
                return try JSONDecoder().decode(InjectNode.self, from: jsonData)
            case NodeType.debug.rawValue:
                return try JSONDecoder().decode(DebugNode.self, from: jsonData)
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

    func addNode(_ node: Node) {
        nodes[node.id] = node
    }

    func getNode(by id: String) -> Node? {
        return nodes[id]
    }

    /// Returns the first CameraNode in this flow, if any
    func getCameraNode() -> CameraNode? {
        return nodes.values.compactMap { $0 as? CameraNode }.first
    }

    func start() {
        initialize()
        execute()
    }

    func stop() {
        terminate()
    }

    // Extracted helpers for node lifecycle operations
    /// Applies the given action to all nodes that are available (not on a disabled tab).
    private func forEachAvailableNode(_ action: (Node) -> Void) {
        for node in nodes.values where isAvailableNode(node: node) {
            action(node)
        }
    }

    /// Determines whether a node should participate based on its tab's disabled state.
    private func isAvailableNode(node: Node) -> Bool {
        if let tab = tab[node.z], tab.disabled {
            return false
        }
        return true
    }

    /// Applies the given action to all nodes regardless of availability.
    private func forEachNode(_ action: (Node) -> Void) {
        for node in nodes.values {
            action(node)
        }
    }

    func initialize() {
        forEachAvailableNode { $0.initialize(flow: self) }
    }

    func execute() {
        forEachAvailableNode { $0.execute() }
    }

    func terminate() {
        forEachNode { $0.terminate() }
    }

    func routeMessage(from sourceNode: Node, message: NodeMessage) {
        let outputIndex = 0
        let targetNodeIds = sourceNode.wires[outputIndex]

        for nodeId in targetNodeIds {
            if let targetNode = nodes[nodeId] {
                // メッセージクローンを作成
                let clonedMessage = cloneMessage(message)
                targetNode.receive(msg: clonedMessage)
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
