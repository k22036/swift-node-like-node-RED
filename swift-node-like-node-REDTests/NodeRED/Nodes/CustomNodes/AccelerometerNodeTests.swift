import Testing
@testable import swift_node_like_node_RED
import Foundation

struct AccelerometerNodeTests {
    @Test func parse() async throws {
        let jsonString = """
        [
            {
                "id": "accel1",
                "type": "accelerometer",
                "z": "test-z",
                "name": "accel test",
                "repeat": "2.5",
                "once": true,
                "onceDelay": "0.2",
                "x": 11,
                "y": 22,
                "wires": [["node2"]]
            }
        ]
        """
        guard let data = jsonString.data(using: .utf8) else {
            fatalError("Failed to convert JSON string to Data")
        }
        let nodes = try JSONDecoder().decode([AccelerometerNode].self, from: data)
        guard let node = nodes.first else {
            fatalError("No AccelerometerNode found in JSON data")
        }
        #expect(node.id == "accel1")
        #expect(node.type == NodeType.accelerometer.rawValue)
        #expect(node.z == "test-z")
        #expect(node.name == "accel test")
        #expect(node.repeat == 2.5)
        #expect(node.once == true)
        #expect(node.onceDelay == 0.2)
        #expect(node.wires.first?.first == "node2")
    }

    @Test func simulateAccelerometer() async throws {
        let jsonString = """
        [
            {
                "id": "accel2",
                "type": "accelerometer",
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
        let node = try JSONDecoder().decode([AccelerometerNode].self, from: data).first!
        let testNode = try TestNode(id: "test-node")
        let flow = try Flow(flowJson: "[]")
        flow.addNode(node)
        flow.addNode(testNode)

        node.initialize(flow: flow)
        node.simulateAccelerometer(x: 0.11, y: 0.22, z: 0.33)
        try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
        node.terminate()

        #expect(testNode.buffer.count == 1)
        if let msg = testNode.buffer.first {
            guard let payload = msg.payload as? [String: Double] else {
                fatalError("Payload is not a dictionary")
            }
            #expect(payload["x"] == 0.11)
            #expect(payload["y"] == 0.22)
            #expect(payload["z"] == 0.33)
        }
    }
}

