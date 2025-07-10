import Testing
@testable import swift_node_like_node_RED
import Foundation

struct AttitudeNodeTests {
    @Test func parse() async throws {
        let jsonString = """
        [
            {
                "id": "att1",
                "type": "attitude",
                "z": "test-z",
                "name": "att test",
                "repeat": "1.5",
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
        let nodes = try JSONDecoder().decode([AttitudeNode].self, from: data)
        guard let node = nodes.first else {
            fatalError("No AttitudeNode found in JSON data")
        }
        #expect(node.id == "att1")
        #expect(node.type == "attitude")
        #expect(node.z == "test-z")
        #expect(node.name == "att test")
        #expect(node.repeat == 1.5)
        #expect(node.once == true)
        #expect(node.onceDelay == 0.1)
        #expect(node.wires.first?.first == "node2")
    }

    @Test func simulateAttitude() async throws {
        let jsonString = """
        [
            {
                "id": "att2",
                "type": "attitude",
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
        let node = try JSONDecoder().decode([AttitudeNode].self, from: data).first!
        let testNode = try TestNode(id: "test-node")
        let flow = try Flow(flowJson: "[]")
        flow.addNode(node)
        flow.addNode(testNode)

        node.initialize(flow: flow)
        node.simulateAttitude(pitch: 0.1, roll: 0.2, yaw: 0.3)
        try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
        node.terminate()

        #expect(testNode.buffer.count == 1)
        if let msg = testNode.buffer.first {
            guard let payload = msg.payload as? [String: Double] else {
                fatalError("Payload is not a dictionary")
            }
            #expect(payload["pitch"] == 0.1)
            #expect(payload["roll"] == 0.2)
            #expect(payload["yaw"] == 0.3)
        }
    }
}
