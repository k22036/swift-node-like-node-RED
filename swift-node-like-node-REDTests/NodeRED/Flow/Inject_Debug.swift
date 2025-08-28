//
//  Inject_Debug.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/19.
//

import Foundation
import Testing

@testable import swift_node_like_node_RED

struct Inject_Debug_Tests {
    @Test func execute_inject_debug() async throws {
        // パース対象のJSON文字列
        let injectJsonString = """
            [
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
                            "vt": "str"
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
                    "repeat": "1",
                    "crontab": "",
                    "once": true,
                    "onceDelay": 0.1,
                    "topic": "",
                    "payload": "1",
                    "payloadType": "num",
                    "x": 210,
                    "y": 180,
                    "wires": [
                        [
                            "f0bd46d65aaae42b",
                        ]
                    ]
                }
            ]
            """
        let debugJsonString = """
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
                }
            ]
            """

        // JSON文字列をData型に変換
        guard let injectJsonData = injectJsonString.data(using: .utf8) else {
            fatalError("inject: JSON文字列をDataに変換できませんでした。")
        }
        guard let debugJsonData = debugJsonString.data(using: .utf8) else {
            fatalError("debug: JSON文字列をDataに変換できませんでした。")
        }

        do {
            let injectNode =
                (try JSONDecoder().decode([InjectNode].self, from: injectJsonData).first)!
            let debugNode = (try JSONDecoder().decode([DebugNode].self, from: debugJsonData).first)!

            #expect(injectNode.wires.first == ["f0bd46d65aaae42b"])
            Logger.debugLog("✅ パースに成功しました！")

            let flow = try await Flow(flowJson: "[]")
            await flow.addNode(injectNode)
            await flow.addNode(debugNode)

            await debugNode.initialize(flow: flow)
            await injectNode.initialize(flow: flow)

            #expect(await debugNode.isRunning == true)
            #expect(await injectNode.isRunning == true)

            await debugNode.execute()
            await injectNode.execute()

            try await Task.sleep(nanoseconds: UInt64(2 * 1_000_000_000))

            await debugNode.terminate()
            await injectNode.terminate()
        } catch {
            // パースに失敗した場合のエラーハンドリング
            Logger.debugLog("❌ パースに失敗しました: \(error)")
            throw error
        }
    }
}
