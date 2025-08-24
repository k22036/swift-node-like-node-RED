//
//  FilterNodeTests.swift
//  swift-node-like-node-RED
//
//  Created by GitHub Copilot on 2025/07/21.
//

import Foundation
import Testing

@testable import swift_node_like_node_RED

struct FilterNodeTests {
    @Test func parse() async throws {
        // パース対象のJSON文字列
        let jsonString = """
                {
                    "id": "a8f03721b35a8f5b",
                    "type": "rbe",
                    "z": "7928e240b40ad888",
                    "name": "",
                    "func": "narrowband",
                    "gap": "5%",
                    "start": "a",
                    "inout": "in",
                    "septopics": true,
                    "property": "payload",
                    "topi": "topic",
                    "x": 430,
                    "y": 160,
                    "wires": [
                        [
                            "83400d8839d3fba4"
                        ]
                    ]
                }
            """

        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        let node = try JSONDecoder().decode(FilterNode.self, from: jsonData)
        #expect(node.id == "a8f03721b35a8f5b")
        #expect(node.type == NodeType.filter.rawValue)
        #expect(node.func == "narrowband")
        #expect(node.gap == 5)
        #expect(node.start == "a")
        #expect(node.inout == "in")
        #expect(node.septopics == true)
        #expect(node.property == "payload")
        #expect(node.topi == "topic")
        #expect(node.wires.count == 1)
        #expect(node.wires.first?.first == "83400d8839d3fba4")
    }

    private func createNodeMessage(
        payload: Any, topic: String? = nil, properties: [String: NodeMessageType]? = nil
    ) -> NodeMessage {
        var msg = NodeMessage(payload: payload)
        if let topic = topic {
            msg.properties["topic"] = NodeMessageType.stringValue(topic)
        }
        if let properties = properties {
            for (key, value) in properties {
                msg.properties[key] = value
            }
        }
        return msg
    }

    // should only send output if payload changes - with multiple topics (rbe)
    @Test func rbePayloadChanges() async throws {
        // パース対象のJSON文字列
        let jsonString = """
                {
                    "id": "4847799d7a2f340d",
                    "type": "rbe",
                    "z": "7928e240b40ad888",
                    "name": "",
                    "func": "rbe",
                    "gap": "",
                    "start": "",
                    "inout": "out",
                    "septopics": true,
                    "property": "payload",
                    "topi": "topic",
                    "x": 330,
                    "y": 420,
                    "wires": [
                        ["testNode"]
                    ]
                }
            """

        // ノードの生成
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        let filterNode = try JSONDecoder().decode(FilterNode.self, from: jsonData)
        let testNode = try TestNode(id: "testNode")

        // フローのセットアップ
        let flow = try await Flow(flowJson: "[]")
        await flow.addNode(filterNode)
        await flow.addNode(testNode)

        // 初期化と実行
        await filterNode.initialize(flow: flow)
        await filterNode.execute()

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

        // メッセージ送信
        await filterNode.receive(msg: createNodeMessage(payload: "a"))
        await filterNode.receive(msg: createNodeMessage(payload: "a"))
        await filterNode.receive(msg: createNodeMessage(payload: "a"))
        await filterNode.receive(msg: createNodeMessage(payload: 2))
        await filterNode.receive(msg: createNodeMessage(payload: 2))
        await filterNode.receive(msg: createNodeMessage(payload: true))
        await filterNode.receive(msg: createNodeMessage(payload: false))
        await filterNode.receive(msg: createNodeMessage(payload: false))
        await filterNode.receive(msg: createNodeMessage(payload: true))
        await filterNode.receive(msg: createNodeMessage(payload: 1, topic: "a"))
        await filterNode.receive(msg: createNodeMessage(payload: 1, topic: "b"))
        await filterNode.receive(msg: createNodeMessage(payload: 1, topic: "b"))
        await filterNode.receive(msg: createNodeMessage(payload: 1, topic: "a"))
        await filterNode.receive(msg: createNodeMessage(payload: 1, topic: "c"))

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
        await filterNode.terminate()

        Logger.debugLog("Buffer: \(await testNode.buffer.map({ Util.anyToString($0.payload) }))")
        try #require(await testNode.buffer.count == 8)

        #expect(Util.anyToString(await testNode.buffer[0].payload) == "a")
        #expect(Util.anyToString(await testNode.buffer[1].payload) == "2")
        #expect(Util.anyToString(await testNode.buffer[2].payload) == "true")
        #expect(Util.anyToString(await testNode.buffer[3].payload) == "false")
        #expect(Util.anyToString(await testNode.buffer[4].payload) == "true")

        #expect(Util.getMessageProperty(msg: await testNode.buffer[5], key: "topic") == "a")
        #expect(Util.anyToString(await testNode.buffer[5].payload) == "1")

        #expect(Util.getMessageProperty(msg: await testNode.buffer[6], key: "topic") == "b")
        #expect(Util.anyToString(await testNode.buffer[6].payload) == "1")

        #expect(Util.getMessageProperty(msg: await testNode.buffer[7], key: "topic") == "c")
        #expect(Util.anyToString(await testNode.buffer[7].payload) == "1")
    }

    // should ignore multiple topics if told to (rbe)
    @Test func rbeIgnoreMultipleTopics() async throws {
        // パース対象のJSON文字列
        let jsonString = """
                {
                    "id": "4847799d7a2f340d",
                    "type": "rbe",
                    "z": "7928e240b40ad888",
                    "name": "",
                    "func": "rbe",
                    "gap": "",
                    "start": "",
                    "inout": "out",
                    "septopics": false,
                    "property": "payload",
                    "topi": "topic",
                    "x": 370,
                    "y": 340,
                    "wires": [
                        [
                            "testNode"
                        ]
                    ]
                }
            """

        // ノードの生成
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        let filterNode = try JSONDecoder().decode(FilterNode.self, from: jsonData)
        let testNode = try TestNode(id: "testNode")

        // フローのセットアップ
        let flow = try await Flow(flowJson: "[]")
        await flow.addNode(filterNode)
        await flow.addNode(testNode)

        // 初期化と実行
        await filterNode.initialize(flow: flow)
        await filterNode.execute()

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

        // メッセージ送信
        await filterNode.receive(msg: createNodeMessage(payload: "a", topic: "a"))
        await filterNode.receive(msg: createNodeMessage(payload: "a", topic: "b"))
        await filterNode.receive(msg: createNodeMessage(payload: "a", topic: "c"))
        await filterNode.receive(msg: createNodeMessage(payload: 2, topic: "a"))
        await filterNode.receive(msg: createNodeMessage(payload: 2, topic: "b"))
        await filterNode.receive(msg: createNodeMessage(payload: true, topic: "a"))
        await filterNode.receive(msg: createNodeMessage(payload: false, topic: "b"))
        await filterNode.receive(msg: createNodeMessage(payload: false, topic: "c"))
        await filterNode.receive(msg: createNodeMessage(payload: true, topic: "d"))
        await filterNode.receive(msg: createNodeMessage(payload: 1, topic: "a"))
        await filterNode.receive(msg: createNodeMessage(payload: 1, topic: "b"))
        await filterNode.receive(msg: createNodeMessage(payload: 1, topic: "c"))
        await filterNode.receive(msg: createNodeMessage(payload: 1, topic: "d"))
        await filterNode.receive(msg: createNodeMessage(payload: 2, topic: "a"))

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
        await filterNode.terminate()

        Logger.debugLog("Buffer: \(await testNode.buffer.map({ Util.anyToString($0.payload) }))")
        try #require(await testNode.buffer.count == 7)

        #expect(Util.anyToString(await testNode.buffer[0].payload) == "a")
        #expect(Util.anyToString(await testNode.buffer[1].payload) == "2")
        #expect(Util.anyToString(await testNode.buffer[2].payload) == "true")
        #expect(Util.anyToString(await testNode.buffer[3].payload) == "false")
        #expect(Util.anyToString(await testNode.buffer[4].payload) == "true")

        #expect(Util.getMessageProperty(msg: await testNode.buffer[5], key: "topic") == "a")
        #expect(Util.anyToString(await testNode.buffer[5].payload) == "1")

        #expect(Util.getMessageProperty(msg: await testNode.buffer[6], key: "topic") == "a")
        #expect(Util.anyToString(await testNode.buffer[6].payload) == "2")
    }

    // should only send output if another chosen property changes - foo (rbe)
    @Test func rbePropertyChanges() async throws {
        // パース対象のJSON文字列
        let jsonString = """
                {
                    "id": "4847799d7a2f340d",
                    "type": "rbe",
                    "z": "7928e240b40ad888",
                    "name": "",
                    "func": "rbe",
                    "gap": "",
                    "start": "",
                    "inout": "out",
                    "septopics": true,
                    "property": "foo",
                    "topi": "topic",
                    "x": 370,
                    "y": 340,
                    "wires": [
                        [
                            "testNode"
                        ]
                    ]
                }
            """

        // ノードの生成
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        let filterNode = try JSONDecoder().decode(FilterNode.self, from: jsonData)
        let testNode = try TestNode(id: "testNode")

        // フローのセットアップ
        let flow = try await Flow(flowJson: "[]")
        await flow.addNode(filterNode)
        await flow.addNode(testNode)

        // 初期化と実行
        await filterNode.initialize(flow: flow)
        await filterNode.execute()

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

        // メッセージ送信
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "", properties: ["foo": NodeMessageType.stringValue("a")]))
        await filterNode.receive(msg: createNodeMessage(payload: "a"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "", properties: ["foo": NodeMessageType.stringValue("a")]))
        await filterNode.receive(msg: createNodeMessage(payload: "a"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "", properties: ["foo": NodeMessageType.stringValue("a")]))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "", properties: ["foo": NodeMessageType.stringValue("b")]))

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
        await filterNode.terminate()

        Logger.debugLog("Buffer: \(await testNode.buffer.map({ Util.anyToString($0.payload) }))")
        try #require(await testNode.buffer.count == 2)

        #expect(Util.getMessageProperty(msg: await testNode.buffer[0], key: "foo") == "a")
        #expect(Util.getMessageProperty(msg: await testNode.buffer[1], key: "foo") == "b")
    }

    // should only send output if payload changes - ignoring first value (rbei)
    @Test func rbeiPayloadChanges() async throws {
        // パース対象のJSON文字列
        let jsonString = """
                {
                    "id": "4847799d7a2f340d",
                    "type": "rbe",
                    "z": "7928e240b40ad888",
                    "name": "",
                    "func": "rbei",
                    "gap": "",
                    "start": "",
                    "inout": "out",
                    "septopics": true,
                    "property": "payload",
                    "topi": "topic",
                    "x": 370,
                    "y": 340,
                    "wires": [
                        [
                            "testNode"
                        ]
                    ]
                }
            """

        // ノードの生成
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        let filterNode = try JSONDecoder().decode(FilterNode.self, from: jsonData)
        let testNode = try TestNode(id: "testNode")

        // フローのセットアップ
        let flow = try await Flow(flowJson: "[]")
        await flow.addNode(filterNode)
        await flow.addNode(testNode)

        // 初期化と実行
        await filterNode.initialize(flow: flow)
        await filterNode.execute()

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

        // メッセージ送信
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "a", topic: "a"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "a", topic: "b"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "a", topic: "a"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "b", topic: "a"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "b", topic: "b"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "c", topic: "a"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "c", topic: "b"))

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
        await filterNode.terminate()

        Logger.debugLog("Buffer: \(await testNode.buffer.map({ Util.anyToString($0.payload) }))")
        try #require(await testNode.buffer.count == 4)

        #expect(Util.getMessageProperty(msg: await testNode.buffer[0], key: "topic") == "a")
        #expect(Util.anyToString(await testNode.buffer[0].payload) == "b")

        #expect(Util.getMessageProperty(msg: await testNode.buffer[1], key: "topic") == "b")
        #expect(Util.anyToString(await testNode.buffer[1].payload) == "b")

        #expect(Util.getMessageProperty(msg: await testNode.buffer[2], key: "topic") == "a")
        #expect(Util.anyToString(await testNode.buffer[2].payload) == "c")

        #expect(Util.getMessageProperty(msg: await testNode.buffer[3], key: "topic") == "b")
        #expect(Util.anyToString(await testNode.buffer[3].payload) == "c")
    }

    // should send output if queue is reset (rbe)
    @Test func rbeResetPrevious() async throws {
        // パース対象のJSON文字列
        let jsonString = """
                {
                    "id": "4847799d7a2f340d",
                    "type": "rbe",
                    "z": "7928e240b40ad888",
                    "name": "",
                    "func": "rbe",
                    "gap": "",
                    "start": "",
                    "inout": "out",
                    "septopics": true,
                    "property": "payload",
                    "topi": "topic",
                    "x": 370,
                    "y": 340,
                    "wires": [
                        [
                            "testNode"
                        ]
                    ]
                }
            """

        // ノードの生成
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        let filterNode = try JSONDecoder().decode(FilterNode.self, from: jsonData)
        let testNode = try TestNode(id: "testNode")

        // フローのセットアップ
        let flow = try await Flow(flowJson: "[]")
        await flow.addNode(filterNode)
        await flow.addNode(testNode)

        // 初期化と実行
        await filterNode.initialize(flow: flow)
        await filterNode.execute()

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

        // メッセージ送信
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "a", topic: "a"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "a", topic: "a"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "b", topic: "b"))

        // reset all
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "", properties: ["reset": NodeMessageType.boolValue(true)]))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "a", topic: "a"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "b", topic: "b"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "b", topic: "b"))

        // reset b
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "", topic: "b", properties: ["reset": NodeMessageType.stringValue("")]))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "b", topic: "b"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "a", topic: "a"))

        // reset all
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "", properties: ["reset": NodeMessageType.stringValue("")]))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "b", topic: "b"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "a", topic: "a"))

        // don't reset a non topic
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "", topic: "c"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "b", topic: "b"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "a", topic: "a"))
        await filterNode.receive(
            msg: createNodeMessage(
                payload: "c", topic: "c"))

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
        await filterNode.terminate()

        Logger.debugLog("Buffer: \(await testNode.buffer.map({ Util.anyToString($0.payload) }))")
        try #require(await testNode.buffer.count == 8)

        #expect(Util.anyToString(await testNode.buffer[0].payload) == "a")
        #expect(Util.anyToString(await testNode.buffer[1].payload) == "b")
        #expect(Util.anyToString(await testNode.buffer[2].payload) == "a")
        #expect(Util.anyToString(await testNode.buffer[3].payload) == "b")
        #expect(Util.anyToString(await testNode.buffer[4].payload) == "b")
        #expect(Util.anyToString(await testNode.buffer[5].payload) == "b")
        #expect(Util.anyToString(await testNode.buffer[6].payload) == "a")
        #expect(Util.anyToString(await testNode.buffer[7].payload) == "c")
    }

    // should only send output if x away from original value (deadbandEq)
    @Test func deadbandEqOnlySend() async throws {
        // パース対象のJSON文字列
        let jsonString = """
                {
                    "id": "4847799d7a2f340d",
                    "type": "rbe",
                    "z": "7928e240b40ad888",
                    "name": "",
                    "func": "deadbandEq",
                    "gap": "10",
                    "start": "",
                    "inout": "out",
                    "septopics": true,
                    "property": "payload",
                    "topi": "topic",
                    "x": 390,
                    "y": 340,
                    "wires": [
                        [
                            "testNode"
                        ]
                    ]
                }
            """

        // ノードの生成
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        let filterNode = try JSONDecoder().decode(FilterNode.self, from: jsonData)
        let testNode = try TestNode(id: "testNode")

        // フローのセットアップ
        let flow = try await Flow(flowJson: "[]")
        await flow.addNode(filterNode)
        await flow.addNode(testNode)

        // 初期化と実行
        await filterNode.initialize(flow: flow)
        await filterNode.execute()

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

        // メッセージ送信
        await filterNode.receive(msg: createNodeMessage(payload: 0))
        await filterNode.receive(msg: createNodeMessage(payload: 2))
        await filterNode.receive(msg: createNodeMessage(payload: 4))
        await filterNode.receive(msg: createNodeMessage(payload: 6))
        await filterNode.receive(msg: createNodeMessage(payload: 8))
        await filterNode.receive(msg: createNodeMessage(payload: 10))
        await filterNode.receive(msg: createNodeMessage(payload: 15))
        await filterNode.receive(msg: createNodeMessage(payload: 20))

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
        await filterNode.terminate()

        Logger.debugLog("Buffer: \(await testNode.buffer.map({ Util.anyToString($0.payload) }))")
        try #require(await testNode.buffer.count == 3)

        #expect(Util.anyToString(await testNode.buffer[0].payload) == "0")
        #expect(Util.anyToString(await testNode.buffer[1].payload) == "10")
        #expect(Util.anyToString(await testNode.buffer[2].payload) == "20")
    }

    // should only send output if more than x away from original value (deadband)
    @Test func deadbandOnlySend() async throws {
        // パース対象のJSON文字列
        let jsonString = """
                {
                    "id": "4847799d7a2f340d",
                    "type": "rbe",
                    "z": "7928e240b40ad888",
                    "name": "",
                    "func": "deadband",
                    "gap": "10",
                    "start": "",
                    "inout": "out",
                    "septopics": true,
                    "property": "payload",
                    "topi": "topic",
                    "x": 390,
                    "y": 340,
                    "wires": [
                        [
                            "testNode"
                        ]
                    ]
                }
            """

        // ノードの生成
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        let filterNode = try JSONDecoder().decode(FilterNode.self, from: jsonData)
        let testNode = try TestNode(id: "testNode")

        // フローのセットアップ
        let flow = try await Flow(flowJson: "[]")
        await flow.addNode(filterNode)
        await flow.addNode(testNode)

        // 初期化と実行
        await filterNode.initialize(flow: flow)
        await filterNode.execute()

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

        // メッセージ送信
        await filterNode.receive(msg: createNodeMessage(payload: 0))
        await filterNode.receive(msg: createNodeMessage(payload: 2))
        await filterNode.receive(msg: createNodeMessage(payload: 4))
        await filterNode.receive(msg: createNodeMessage(payload: "6 deg"))
        await filterNode.receive(msg: createNodeMessage(payload: 8))
        await filterNode.receive(msg: createNodeMessage(payload: 20))
        await filterNode.receive(msg: createNodeMessage(payload: 15))
        await filterNode.receive(msg: createNodeMessage(payload: "5 deg"))

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
        await filterNode.terminate()

        Logger.debugLog("Buffer: \(await testNode.buffer.map({ Util.anyToString($0.payload) }))")
        try #require(await testNode.buffer.count == 3)

        #expect(Util.anyToString(await testNode.buffer[0].payload) == "0")
        #expect(Util.anyToString(await testNode.buffer[1].payload) == "20")
        #expect(Util.anyToString(await testNode.buffer[2].payload) == "5 deg")
    }

    // should only send output if more than x% away from original value (deadband)
    @Test func deadbandOnlySendPercent() async throws {
        // パース対象のJSON文字列
        let jsonString = """
                {
                    "id": "4847799d7a2f340d",
                    "type": "rbe",
                    "z": "7928e240b40ad888",
                    "name": "",
                    "func": "deadband",
                    "gap": "10%",
                    "start": "",
                    "inout": "out",
                    "septopics": true,
                    "property": "payload",
                    "topi": "topic",
                    "x": 390,
                    "y": 340,
                    "wires": [
                        [
                            "testNode"
                        ]
                    ]
                }
            """

        // ノードの生成
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        let filterNode = try JSONDecoder().decode(FilterNode.self, from: jsonData)
        let testNode = try TestNode(id: "testNode")

        // フローのセットアップ
        let flow = try await Flow(flowJson: "[]")
        await flow.addNode(filterNode)
        await flow.addNode(testNode)

        // 初期化と実行
        await filterNode.initialize(flow: flow)
        await filterNode.execute()

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

        // メッセージ送信
        await filterNode.receive(msg: createNodeMessage(payload: 100))
        await filterNode.receive(msg: createNodeMessage(payload: 95))
        await filterNode.receive(msg: createNodeMessage(payload: 105))
        await filterNode.receive(msg: createNodeMessage(payload: 111))
        await filterNode.receive(msg: createNodeMessage(payload: 120))
        await filterNode.receive(msg: createNodeMessage(payload: 135))

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
        await filterNode.terminate()

        Logger.debugLog("Buffer: \(await testNode.buffer.map({ Util.anyToString($0.payload) }))")
        try #require(await testNode.buffer.count == 3)

        #expect(Util.anyToString(await testNode.buffer[0].payload) == "100")
        #expect(Util.anyToString(await testNode.buffer[1].payload) == "111")
        #expect(Util.anyToString(await testNode.buffer[2].payload) == "135")
    }

    // should warn if no number found in deadband mode
    @Test func deadbandWarn() async throws {
        // パース対象のJSON文字列
        let jsonString = """
                {
                    "id": "4847799d7a2f340d",
                    "type": "rbe",
                    "z": "7928e240b40ad888",
                    "name": "",
                    "func": "deadband",
                    "gap": "10",
                    "start": "",
                    "inout": "out",
                    "septopics": true,
                    "property": "payload",
                    "topi": "topic",
                    "x": 390,
                    "y": 340,
                    "wires": [
                        [
                            "testNode"
                        ]
                    ]
                }
            """

        // ノードの生成
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        let filterNode = try JSONDecoder().decode(FilterNode.self, from: jsonData)
        let testNode = try TestNode(id: "testNode")

        // フローのセットアップ
        let flow = try await Flow(flowJson: "[]")
        await flow.addNode(filterNode)
        await flow.addNode(testNode)

        // 初期化と実行
        await filterNode.initialize(flow: flow)
        await filterNode.execute()

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

        // メッセージ送信
        await filterNode.receive(msg: createNodeMessage(payload: "banana"))

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
        await filterNode.terminate()

        Logger.debugLog("Buffer: \(await testNode.buffer.map({ Util.anyToString($0.payload) }))")
        try #require(await testNode.buffer.count == 0)
    }

    // should not send output if x away or greater from original value (narrowbandEq)
    @Test func narrowbandEqOnlySend() async throws {
        // パース対象のJSON文字列
        let jsonString = """
                {
                    "id": "4847799d7a2f340d",
                    "type": "rbe",
                    "z": "7928e240b40ad888",
                    "name": "",
                    "func": "narrowbandEq",
                    "gap": "10",
                    "start": "1",
                    "inout": "out",
                    "septopics": true,
                    "property": "payload",
                    "topi": "topic",
                    "x": 390,
                    "y": 340,
                    "wires": [
                        [
                            "testNode"
                        ]
                    ]
                }
            """

        // ノードの生成
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        let filterNode = try JSONDecoder().decode(FilterNode.self, from: jsonData)
        let testNode = try TestNode(id: "testNode")

        // フローのセットアップ
        let flow = try await Flow(flowJson: "[]")
        await flow.addNode(filterNode)
        await flow.addNode(testNode)

        // 初期化と実行
        await filterNode.initialize(flow: flow)
        await filterNode.execute()

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

        // メッセージ送信
        await filterNode.receive(msg: createNodeMessage(payload: 100))
        await filterNode.receive(msg: createNodeMessage(payload: 0))
        await filterNode.receive(msg: createNodeMessage(payload: 10))
        await filterNode.receive(msg: createNodeMessage(payload: 5))
        await filterNode.receive(msg: createNodeMessage(payload: 15))
        await filterNode.receive(msg: createNodeMessage(payload: 10))
        await filterNode.receive(msg: createNodeMessage(payload: 20))
        await filterNode.receive(msg: createNodeMessage(payload: 25))

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
        await filterNode.terminate()

        Logger.debugLog("Buffer: \(await testNode.buffer.map({ Util.anyToString($0.payload) }))")
        try #require(await testNode.buffer.count == 3)

        #expect(Util.anyToString(await testNode.buffer[0].payload) == "0")
        #expect(Util.anyToString(await testNode.buffer[1].payload) == "5")
        #expect(Util.anyToString(await testNode.buffer[2].payload) == "10")
    }

    // should not send output if more than x away from original value (narrowband)
    @Test func narrowbandOnlySend() async throws {
        // パース対象のJSON文字列
        let jsonString = """
                {
                    "id": "4847799d7a2f340d",
                    "type": "rbe",
                    "z": "7928e240b40ad888",
                    "name": "",
                    "func": "narrowband",
                    "gap": "10",
                    "start": "",
                    "inout": "out",
                    "septopics": true,
                    "property": "payload",
                    "topi": "topic",
                    "x": 390,
                    "y": 340,
                    "wires": [
                        [
                            "testNode"
                        ]
                    ]
                }
            """

        // ノードの生成
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        let filterNode = try JSONDecoder().decode(FilterNode.self, from: jsonData)
        let testNode = try TestNode(id: "testNode")

        // フローのセットアップ
        let flow = try await Flow(flowJson: "[]")
        await flow.addNode(filterNode)
        await flow.addNode(testNode)

        // 初期化と実行
        await filterNode.initialize(flow: flow)
        await filterNode.execute()

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

        // メッセージ送信
        await filterNode.receive(msg: createNodeMessage(payload: 0))
        await filterNode.receive(msg: createNodeMessage(payload: 20))
        await filterNode.receive(msg: createNodeMessage(payload: 40))
        await filterNode.receive(msg: createNodeMessage(payload: "6 deg"))
        await filterNode.receive(msg: createNodeMessage(payload: 18))
        await filterNode.receive(msg: createNodeMessage(payload: 20))
        await filterNode.receive(msg: createNodeMessage(payload: 50))
        await filterNode.receive(msg: createNodeMessage(payload: "5 deg"))

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
        await filterNode.terminate()

        Logger.debugLog("Buffer: \(await testNode.buffer.map({ Util.anyToString($0.payload) }))")
        try #require(await testNode.buffer.count == 3)

        #expect(Util.anyToString(await testNode.buffer[0].payload) == "0")
        #expect(Util.anyToString(await testNode.buffer[1].payload) == "6 deg")
        #expect(Util.anyToString(await testNode.buffer[2].payload) == "5 deg")
    }

    // should send output if gap is 0 and input doesnt change (narrowband)
    @Test func narrowbandNotChange() async throws {
        // パース対象のJSON文字列
        let jsonString = """
                {
                    "id": "4847799d7a2f340d",
                    "type": "rbe",
                    "z": "7928e240b40ad888",
                    "name": "",
                    "func": "narrowband",
                    "gap": "0",
                    "start": "",
                    "inout": "out",
                    "septopics": true,
                    "property": "payload",
                    "topi": "topic",
                    "x": 390,
                    "y": 340,
                    "wires": [
                        [
                            "testNode"
                        ]
                    ]
                }
            """

        // ノードの生成
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        let filterNode = try JSONDecoder().decode(FilterNode.self, from: jsonData)
        let testNode = try TestNode(id: "testNode")

        // フローのセットアップ
        let flow = try await Flow(flowJson: "[]")
        await flow.addNode(filterNode)
        await flow.addNode(testNode)

        // 初期化と実行
        await filterNode.initialize(flow: flow)
        await filterNode.execute()

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

        // メッセージ送信
        await filterNode.receive(msg: createNodeMessage(payload: 1))
        await filterNode.receive(msg: createNodeMessage(payload: 1))
        await filterNode.receive(msg: createNodeMessage(payload: 1))
        await filterNode.receive(msg: createNodeMessage(payload: 1))
        await filterNode.receive(msg: createNodeMessage(payload: 0))
        await filterNode.receive(msg: createNodeMessage(payload: 1))

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
        await filterNode.terminate()

        Logger.debugLog("Buffer: \(await testNode.buffer.map({ Util.anyToString($0.payload) }))")
        try #require(await testNode.buffer.count == 5)

        #expect(Util.anyToString(await testNode.buffer[0].payload) == "1")
        #expect(Util.anyToString(await testNode.buffer[4].payload) == "1")
    }

    // should not send output if more than x away from original value (narrowband in step mode)
    @Test func narrowbandInMode() async throws {
        // パース対象のJSON文字列
        let jsonString = """
                {
                    "id": "4847799d7a2f340d",
                    "type": "rbe",
                    "z": "7928e240b40ad888",
                    "name": "",
                    "func": "narrowband",
                    "gap": "10",
                    "start": "500",
                    "inout": "in",
                    "septopics": true,
                    "property": "payload",
                    "topi": "topic",
                    "x": 390,
                    "y": 340,
                    "wires": [
                        [
                            "testNode"
                        ]
                    ]
                }
            """

        // ノードの生成
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        let filterNode = try JSONDecoder().decode(FilterNode.self, from: jsonData)
        let testNode = try TestNode(id: "testNode")

        // フローのセットアップ
        let flow = try await Flow(flowJson: "[]")
        await flow.addNode(filterNode)
        await flow.addNode(testNode)

        // 初期化と実行
        await filterNode.initialize(flow: flow)
        await filterNode.execute()

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))

        // メッセージ送信
        await filterNode.receive(msg: createNodeMessage(payload: 50))
        await filterNode.receive(msg: createNodeMessage(payload: 55))
        await filterNode.receive(msg: createNodeMessage(payload: 200))
        await filterNode.receive(msg: createNodeMessage(payload: 205))

        // 処理待機
        try await Task.sleep(nanoseconds: UInt64(1 * 1_000_000_000))
        await filterNode.terminate()

        Logger.debugLog("Buffer: \(await testNode.buffer.map({ Util.anyToString($0.payload) }))")
        try #require(await testNode.buffer.count == 2)

        #expect(Util.anyToString(await testNode.buffer[0].payload) == "55")
        #expect(Util.anyToString(await testNode.buffer[1].payload) == "205")
    }
}
