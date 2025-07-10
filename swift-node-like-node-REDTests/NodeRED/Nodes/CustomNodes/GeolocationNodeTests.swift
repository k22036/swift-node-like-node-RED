//
//  GeolocationNodeTests.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/21.
//

import Testing
@testable import swift_node_like_node_RED
import Foundation

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
        #expect(node.wires.first?.first == "node1")
    }

    @Test func simulateLocation() async throws {
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

        // Allow asynchronous send
        try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
        
        node.terminate()

        #expect(testNode.buffer.count == 1)
        if let msg = testNode.buffer.first {
            guard let payload = msg.payload as? [String: Double] else {
                fatalError("Payload is not a dictionary")
            }
            #expect(payload["latitude"] == 12.34)
            #expect(payload["longitude"] == 56.78)
        }
    }
}
