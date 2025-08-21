//
//  Flow.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/21.
//

import Foundation
import Testing

@testable import swift_node_like_node_RED

struct FlowTests {
    let flowJson = """
        [
            {
                "id": "f0bd46d65aaae42b",
                "type": "debug",
                "z": "357cfb731aa85c01",
                "name": "debug 2",
                "active": true,
                "tosidebar": true,
                "console": false,
                "tostatus": false,
                "complete": "payload",
                "targetType": "msg",
                "statusVal": "",
                "statusType": "auto",
                "x": 480,
                "y": 180,
                "wires": []
            },
            {
                "id": "22927becb75bd1f3",
                "type": "inject",
                "z": "357cfb731aa85c01",
                "name": "",
                "props": [
                    {
                        "p": "payload"
                    },
                    {
                        "p": "topic",
                        "v": "",
                        "vt": "num"
                    },
                    {
                        "p": "test1",
                        "v": "true",
                        "vt": "bool"
                    },
                    {
                        "p": "test2",
                        "v": "",
                        "vt": "num"
                    },
                    {
                        "p": "test3",
                        "v": "aa",
                        "vt": "str"
                    },
                    {
                        "p": "test4",
                        "v": "",
                        "vt": "date"
                    },
                    {
                        "p": "test5",
                        "v": "2",
                        "vt": "num"
                    }
                ],
                "repeat": "0.4",
                "crontab": "",
                "once": false,
                "onceDelay": "1",
                "topic": "",
                "payload": "true",
                "payloadType": "bool",
                "x": 210,
                "y": 180,
                "wires": [
                    [
                        "f0bd46d65aaae42b",
                        "4df62d3e39f09ef1"
                    ]
                ]
            },
            {
                "id": "4df62d3e39f09ef1",
                "type": "debug",
                "z": "357cfb731aa85c01",
                "name": "debug 3",
                "active": true,
                "tosidebar": true,
                "console": false,
                "tostatus": false,
                "complete": "test4",
                "targetType": "msg",
                "statusVal": "",
                "statusType": "auto",
                "x": 480,
                "y": 240,
                "wires": []
            }
        ]
        """
    @Test func init_flow() async throws {
        do {
            let flow = try await Flow(flowJson: flowJson)
            Logger.debugLog("✅ フローの初期化に成功しました！")

            #expect(await flow.getNode(by: "f0bd46d65aaae42b") != nil)
            #expect(await flow.getNode(by: "22927becb75bd1f3") != nil)
            #expect(await flow.getNode(by: "4df62d3e39f09ef1") != nil)

            #expect(await flow.getNode(by: "f0bd46d65aaae42b") is DebugNode)
            #expect(await flow.getNode(by: "22927becb75bd1f3") is InjectNode)
            #expect(await flow.getNode(by: "4df62d3e39f09ef1") is DebugNode)
        } catch {
            // パースに失敗した場合のエラーハンドリング
            Logger.debugLog("❌ パースに失敗しました: \(error)")
            throw error
        }
    }

    @Test func start_flow() async throws {
        let flow = try await Flow(flowJson: flowJson)
        Logger.debugLog("✅ フローの初期化に成功しました！")

        await flow.start()
        #expect(await flow.getNode(by: "f0bd46d65aaae42b")?.isRunning == true)
        #expect(await flow.getNode(by: "22927becb75bd1f3")?.isRunning == true)
        #expect(await flow.getNode(by: "4df62d3e39f09ef1")?.isRunning == true)
    }

    @Test func stop_flow() async throws {
        let flow = try await Flow(flowJson: flowJson)
        Logger.debugLog("✅ フローの初期化に成功しました！")

        await flow.start()
        #expect(await flow.getNode(by: "f0bd46d65aaae42b")?.isRunning == true)
        #expect(await flow.getNode(by: "22927becb75bd1f3")?.isRunning == true)
        #expect(await flow.getNode(by: "4df62d3e39f09ef1")?.isRunning == true)

        try await Task.sleep(nanoseconds: 2 * 1_000_000_000)  // 1秒待機

        await flow.stop()
        #expect(await flow.getNode(by: "f0bd46d65aaae42b")?.isRunning == false)
        #expect(await flow.getNode(by: "22927becb75bd1f3")?.isRunning == false)
        #expect(await flow.getNode(by: "4df62d3e39f09ef1")?.isRunning == false)
    }
}
