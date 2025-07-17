import Foundation
import Testing

@testable import swift_node_like_node_RED

struct DirectionNodeTests {
    @Test func parse() async throws {
        let jsonString = """
            [
                {
                    "id": "direction1",
                    "type": "direction",
                    "z": "test-z",
                    "name": "direction test",
                    "repeat": "2.0",
                    "once": true,
                    "onceDelay": "0.2",
                    "x": 15,
                    "y": 25,
                    "wires": [["node2"]]
                }
            ]
            """
        guard let data = jsonString.data(using: .utf8) else {
            fatalError("Failed to convert JSON string to Data")
        }
        let nodes = try JSONDecoder().decode([DirectionNode].self, from: data)
        guard let node = nodes.first else {
            fatalError("No DirectionNode found in JSON data")
        }
        #expect(node.id == "direction1")
        #expect(node.type == NodeType.direction.rawValue)
        #expect(node.z == "test-z")
        #expect(node.name == "direction test")
        #expect(node.repeat == 2.0)
        #expect(node.once == true)
        #expect(node.onceDelay == 0.2)
        #expect(node.wires.first?.first == "node2")
    }

    @Test func simulateDirection() async throws {
        let jsonString = """
            [
                {
                    "id": "direction2",
                    "type": "direction",
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
        let node = try JSONDecoder().decode([DirectionNode].self, from: data).first!
        let testNode = try TestNode(id: "test-node")
        let flow = try Flow(flowJson: "[]")
        flow.addNode(node)
        flow.addNode(testNode)

        node.initialize(flow: flow)
        node.simulateHeading(123.45)
        try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
        node.terminate()

        #expect(testNode.buffer.count == 1)
        if let msg = testNode.buffer.first {
            guard let payload = msg.payload as? [String: Double] else {
                fatalError("Payload is not a dictionary")
            }
            #expect(payload["heading"] == 123.45)
        }
    }
}
