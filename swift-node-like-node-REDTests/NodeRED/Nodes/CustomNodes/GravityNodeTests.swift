import Testing
@testable import swift_node_like_node_RED
import Foundation

struct GravityNodeTests {
    @Test func parse() async throws {
        let jsonString = """
        [
            {
                "id": "grav1",
                "type": "gravity",
                "z": "test-z",
                "name": "grav test",
                "repeat": "1.0",
                "once": true,
                "onceDelay": "0.1",
                "x": 10,
                "y": 20,
                "wires": [["node2"]]
            }
        ]
        """
        guard let data = jsonString.data(using: .utf8) else {
            fatalError("Failed to convert JSON string to Data")
        }
        let nodes = try JSONDecoder().decode([GravityNode].self, from: data)
        guard let node = nodes.first else {
            fatalError("No GravityNode found in JSON data")
        }
        #expect(node.id == "grav1")
        #expect(node.type == "gravity")
        #expect(node.z == "test-z")
        #expect(node.name == "grav test")
        #expect(node.repeat == 1.0)
        #expect(node.once == true)
        #expect(node.onceDelay == 0.1)
        #expect(node.wires.first?.first == "node2")
    }

    @Test func simulateGravity() async throws {
        let jsonString = """
        [
            {
                "id": "grav2",
                "type": "gravity",
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
        let node = try JSONDecoder().decode([GravityNode].self, from: data).first!
        let testNode = try TestNode(id: "test-node")
        let flow = try Flow(flowJson: "[]")
        flow.addNode(node)
        flow.addNode(testNode)

        node.initialize(flow: flow)
        node.simulateGravity(x: 9.8, y: 0.0, z: -9.8)
        try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))

        #expect(testNode.buffer.count == 1)
        if let msg = testNode.buffer.first {
            guard let payload = msg.payload as? [String: Double] else {
                fatalError("Payload is not a dictionary")
            }
            #expect(payload["x"] == 9.8)
            #expect(payload["y"] == 0.0)
            #expect(payload["z"] == -9.8)
        }
    }
}
