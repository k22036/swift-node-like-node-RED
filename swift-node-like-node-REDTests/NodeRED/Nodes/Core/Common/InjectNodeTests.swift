//
//  InjectNodeTests.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/16.
//

import Foundation
import Testing

@testable import swift_node_like_node_RED

struct InjectNodeTests {

    @Test func parse() async throws {
        // パース対象のJSON文字列
        let jsonString = """
            [
                {
                    "id": "444f85d65fc0f212",
                    "type": "inject",
                    "z": "63886f77ebc65347",
                    "name": "",
                    "props": [
                        {
                            "p": "payload"
                        },
                        {
                            "p": "topic",
                            "vt": "str"
                        }
                    ],
                    "repeat": "1",
                    "crontab": "",
                    "once": true,
                    "onceDelay": "0.5",
                    "topic": "",
                    "payload": "",
                    "payloadType": "date",
                    "x": 340,
                    "y": 160,
                    "wires": [
                        [
                            "2c2786ded68a1173"
                        ]
                    ]
                }
            ]
            """

        // JSON文字列をData型に変換
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }

        do {
            let nodes = try JSONDecoder().decode([InjectNode].self, from: jsonData)

            // パース結果の確認
            if let firstNode = nodes.first {
                Logger.debugLog("✅ パースに成功しました！")
                Logger.debugLog("--------------------")
                Logger.debugLog("ノードID: \(firstNode.id)")
                #expect(firstNode.id == "444f85d65fc0f212")
                Logger.debugLog("ノードタイプ: \(firstNode.type)")
                #expect(firstNode.type == "inject")
                Logger.debugLog("ペイロードタイプ: \(firstNode.payloadType)")
                #expect(firstNode.payloadType == "date")
                Logger.debugLog("接続先ノードID: \(firstNode.wires.first?.first ?? "なし")")
                #expect(firstNode.wires.first?.first == "2c2786ded68a1173")

                Logger.debugLog("props.count: \(firstNode.props.count)")
                #expect(firstNode.props.count == 2)

                // propsの確認
                for prop in firstNode.props {
                    Logger.debugLog("プロパティ名: \(prop.p), 型: \(prop.vt ?? "未定義")")
                    #expect(prop.p == "payload" || prop.p == "topic")
                }

                #expect(firstNode.repeat == 1.0)
                #expect(firstNode.once == true)
                #expect(firstNode.onceDelay == 0.5)
            }
        } catch {
            // パースに失敗した場合のエラーハンドリング
            Logger.debugLog("❌ パースに失敗しました: \(error)")
            throw error
        }
    }

    @Test func execute_inject() async throws {
        // パース対象のJSON文字列
        let jsonString = """
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
                            "test-node",
                        ]
                    ]
                }
            ]
            """

        // JSON文字列をData型に変換
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }

        do {
            let injectNode = (try JSONDecoder().decode([InjectNode].self, from: jsonData).first)!
            let testNode = try TestNode(id: "test-node")

            #expect(injectNode.wires.first == ["test-node"])
            Logger.debugLog("✅ パースに成功しました！")

            let flow = try Flow(flowJson: "[]")
            flow.addNode(injectNode)
            flow.addNode(testNode)

            testNode.initialize(flow: flow)
            injectNode.initialize(flow: flow)

            #expect(injectNode.isRunning == true)

            testNode.execute()
            injectNode.execute()

            try await Task.sleep(nanoseconds: UInt64(2 * 1_000_000_000))

            testNode.terminate()
            await injectNode.terminate()

            Logger.debugLog("buffer length: \(testNode.buffer.count)")
            #expect(testNode.buffer.count > 0)

            for msg in testNode.buffer {
                Logger.debugLog("ペイロード: \(msg.payload)")
                #expect(msg.payload is Int)
                #expect(msg.payload as? Int == 1)

                Logger.debugLog("props: \(msg.properties)")
                Logger.debugLog("props.count: \(msg.properties.count)")
                #expect(msg.properties.count == 5)

                for prop in msg.properties {
                    switch prop.key {
                    case "topic":
                        Logger.debugLog("トピック: \(prop.value)")
                        #expect(prop.value.isStringValue == true)
                        #expect(prop.value == NodeMessageType.stringValue(""))
                    case "test1":
                        Logger.debugLog("test1: \(prop.value)")
                        #expect(prop.value.isBoolValue == true)
                        #expect(prop.value == NodeMessageType.boolValue(true))
                    case "test2":
                        Logger.debugLog("test2: \(prop.value)")
                        #expect(prop.value.isIntValue == true)
                        #expect(prop.value == NodeMessageType.intValue(0))
                    case "test3":
                        Logger.debugLog("test3: \(prop.value)")
                        #expect(prop.value.isStringValue == true)
                        #expect(prop.value == NodeMessageType.stringValue("aa"))
                    case "test4":
                        Logger.debugLog("test4: \(prop.value)")
                        #expect(prop.value.isIntValue == true)
                    case "test5":
                        Logger.debugLog("test5: \(prop.value)")
                        #expect(prop.value.isIntValue == true)
                        #expect(prop.value == NodeMessageType.intValue(2))
                    default:
                        continue
                    }
                }
            }
        } catch {
            // パースに失敗した場合のエラーハンドリング
            Logger.debugLog("❌ パースに失敗しました: \(error)")
            throw error
        }
    }
}
