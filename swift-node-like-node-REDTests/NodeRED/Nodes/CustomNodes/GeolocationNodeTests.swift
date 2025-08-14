//
//  GeolocationNodeTests.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/21.
//

import Foundation
import Testing

@testable import swift_node_like_node_RED

struct GeolocationNodeTests {
    @Test func parse() async throws {
        let jsonString = """
            [
                {
                    "id": "geo1",
                    "type": "geolocation",
                    "z": "test-z",
                    "name": "geo test",
                    "repeat": "5",
                    "once": true,
                    "onceDelay": "0.3",
                    "mode": "periodic",
                    "centerLat": 0,
                    "centerLon": 0,
                    "radius": 100,
                    "keepAlive": "both",
                    "x": 10,
                    "y": 20,
                    "wires": [["node1"]]
                }
            ]
            """
        guard let data = jsonString.data(using: .utf8) else {
            fatalError("Failed to convert JSON string to Data")
        }
        let nodes = try JSONDecoder().decode([GeolocationNode].self, from: data)
        guard let node = nodes.first else {
            fatalError("No GeolocationNode found in JSON data")
        }
        #expect(node.id == "geo1")
        #expect(node.type == NodeType.geolocation.rawValue)
        #expect(node.z == "test-z")
        #expect(node.name == "geo test")
        #expect(node.repeat == 5.0)
        #expect(node.once == true)
        #expect(node.onceDelay == 0.3)
        #expect(node.mode == "periodic")
        #expect(node.centerLat == 0)
        #expect(node.centerLon == 0)
        #expect(node.radius == 100)
        #expect(node.wires.first?.first == "node1")
    }

    @Test func periodicModeSimulateLocation() async throws {
        // Create node and test target
        let jsonString = """
            [
                {
                    "id": "geo2",
                    "type": "geolocation",
                    "z": "test-z",
                    "name": "",
                    "repeat": "",
                    "once": false,
                    "onceDelay": 0,
                    "mode": "periodic",
                    "centerLat": 0,
                    "centerLon": 0,
                    "radius": 100,
                    "keepAlive": "both",
                    "x": 0,
                    "y": 0,
                    "wires": [["test-node"]]
                }
            ]
            """
        guard let data = jsonString.data(using: .utf8) else {
            fatalError("Failed to convert JSON string to Data")
        }
        let node = try JSONDecoder().decode([GeolocationNode].self, from: data).first!
        let testNode = try TestNode(id: "test-node")
        let flow = try Flow(flowJson: "[]")
        flow.addNode(node)
        flow.addNode(testNode)

        // Initialize node
        node.initialize(flow: flow)

        // Simulate a location update
        node.simulateLocation(latitude: 12.34, longitude: 56.78)
        try await Task.sleep(nanoseconds: UInt64(1.1 * 1_000_000_000))
        node.simulateLocation(latitude: 12.34, longitude: 56.78)

        // Allow asynchronous send
        try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))

        await node.terminate()

        #expect(testNode.buffer.count == 2)
        for msg in testNode.buffer {
            guard let payload = msg.payload as? [String: Double] else {
                #expect(Bool(false), "Payload is not a dictionary")
                continue
            }
            #expect(payload["latitude"] == 12.34)
            #expect(payload["longitude"] == 56.78)
        }
    }

    @Test func updateModeTest() async throws {
        // Create node and test target
        let jsonString = """
            [
                {
                    "id": "geo_update",
                    "type": "geolocation",
                    "z": "test-z",
                    "name": "geo update test",
                    "repeat": "",
                    "once": false,
                    "onceDelay": 0,
                    "mode": "update",
                    "centerLat": 0,
                    "centerLon": 0,
                    "radius": 0,
                    "keepAlive": "both",
                    "x": 0,
                    "y": 0,
                    "wires": [["test-node-update"]]
                }
            ]
            """
        guard let data = jsonString.data(using: .utf8) else {
            fatalError("Failed to convert JSON string to Data")
        }
        let node = try JSONDecoder().decode([GeolocationNode].self, from: data).first!
        let testNode = try TestNode(id: "test-node-update")
        let flow = try Flow(flowJson: "[]")
        flow.addNode(node)
        flow.addNode(testNode)

        // Initialize and execute node
        node.initialize(flow: flow)
        node.execute()

        // Simulate a location update
        node.simulateLocation(latitude: 35.681236, longitude: 139.767125)  // Tokyo Station

        // Allow asynchronous send
        try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))

        await node.terminate()

        #expect(testNode.buffer.count == 1)
        if let msg = testNode.buffer.first {
            guard let payload = msg.payload as? [String: Double] else {
                #expect(Bool(false), "Payload is not a dictionary")
                return
            }
            #expect(payload["latitude"] == 35.681236)
            #expect(payload["longitude"] == 139.767125)
        }
    }

    @Test func areaModeTest() async throws {
        // Create node and test target
        let jsonString = """
            [
                {
                    "id": "geo-area",
                    "type": "geolocation",
                    "z": "test-z",
                    "name": "geo area test",
                    "repeat": "",
                    "once": false,
                    "onceDelay": 0,
                    "mode": "area",
                    "centerLat": 35.681236,
                    "centerLon": 139.767125,
                    "radius": 100,
                    "keepAlive": "both",
                    "x": 0,
                    "y": 0,
                    "wires": [["test-node-area"]]
                }
            ]
            """
        guard let data = jsonString.data(using: .utf8) else {
            fatalError("Failed to convert JSON string to Data")
        }
        let node = try JSONDecoder().decode([GeolocationNode].self, from: data).first!
        let testNode = try TestNode(id: "test-node-area")
        let flow = try Flow(flowJson: "[]")
        flow.addNode(node)
        flow.addNode(testNode)

        // Initialize and execute node
        node.initialize(flow: flow)
        // In a real scenario, execute() would be called and CLMonitor would handle events.
        // For testing, we will call the simulation method directly.

        // Simulate entering the area
        node.simulateAreaEvent(state: .satisfied)
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // Simulate exiting the area
        node.simulateAreaEvent(state: .unsatisfied)
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        await node.terminate()

        #expect(testNode.buffer.count == 2)
        if testNode.buffer.count == 2 {
            let enterMsg = testNode.buffer[0]
            let exitMsg = testNode.buffer[1]

            guard let enterPayload = enterMsg.payload as? [String: String],
                let exitPayload = exitMsg.payload as? [String: String]
            else {
                #expect(Bool(false), "Payload is not a dictionary of strings")
                return
            }

            #expect(enterPayload["event"] == "enter")
            #expect(exitPayload["event"] == "exit")
        }
    }
}
