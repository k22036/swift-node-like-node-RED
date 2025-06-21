//
//  Tab.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/21.
//

import Testing
@testable import swift_node_like_node_RED
import Foundation

struct TabTests {
    @Test func init_flow() async throws {
        let flowJson = """
            [
                {
                    "id": "357cfb731aa85c01",
                    "type": "tab",
                    "label": "フロー 5",
                    "disabled": false,
                    "info": "",
                    "env": []
                },
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
                            "p": "env",
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
                    "repeat": "",
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
        do {
            let flow = try Flow(flowJson: flowJson)
            print("✅ フローの初期化に成功しました！")
            
            try #require(flow.getTab(by: "357cfb731aa85c01") != nil)
            #expect(flow.getTab(by: "357cfb731aa85c01")?.id == "357cfb731aa85c01")
            #expect(flow.getTab(by: "357cfb731aa85c01")?.type == "tab")
            #expect(flow.getTab(by: "357cfb731aa85c01")?.label == "フロー 5")
            #expect(flow.getTab(by: "357cfb731aa85c01")?.disabled == false)
        } catch {
            // パースに失敗した場合のエラーハンドリング
            print("❌ パースに失敗しました: \(error)")
            throw error
        }
    }
    
    @Test func available_flow() async throws {
        let flowJson = """
            [
                {
                    "id": "357cfb731aa85c01",
                    "type": "tab",
                    "label": "フロー 5",
                    "disabled": false,
                    "info": "",
                    "env": []
                },
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
                            "p": "env",
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
                    "repeat": "",
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
        let flow = try Flow(flowJson: flowJson)
        print("✅ フローの初期化に成功しました！")
        
        flow.start()
        #expect(flow.getNode(by: "f0bd46d65aaae42b")?.isRunning == true)
        #expect(flow.getNode(by: "22927becb75bd1f3")?.isRunning == true)
        #expect(flow.getNode(by: "4df62d3e39f09ef1")?.isRunning == true)
        flow.stop()
    }
    
    @Test func disable_flow() async throws {
        let flowJson = """
            [
                {
                    "id": "357cfb731aa85c01",
                    "type": "tab",
                    "label": "フロー 5",
                    "disabled": true,
                    "info": "",
                    "env": []
                },
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
                            "p": "env",
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
                    "repeat": "",
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
        let flow = try Flow(flowJson: flowJson)
        print("✅ フローの初期化に成功しました！")
        
        flow.start()
        #expect(flow.getNode(by: "f0bd46d65aaae42b")?.isRunning == false)
        #expect(flow.getNode(by: "22927becb75bd1f3")?.isRunning == false)
        #expect(flow.getNode(by: "4df62d3e39f09ef1")?.isRunning == false)
        flow.stop()
    }
}
