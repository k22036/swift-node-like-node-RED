//
//  InjectNodeTests.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/16.
//

import Testing
@testable import swift_node_like_node_RED
import Foundation

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
                print("✅ パースに成功しました！")
                print("--------------------")
                print("ノードID: \(firstNode.id)")
                #expect(firstNode.id == "444f85d65fc0f212")
                print("ノードタイプ: \(firstNode.type)")
                #expect(firstNode.type == "inject")
                print("ペイロードタイプ: \(firstNode.payloadType)")
                #expect(firstNode.payloadType == "date")
                print("接続先ノードID: \(firstNode.wires.first?.first ?? "なし")")
                #expect(firstNode.wires.first?.first == "2c2786ded68a1173")
                
                // propsの確認
                for prop in firstNode.props {
                    print("プロパティ名: \(prop.p), 型: \(prop.vt ?? "未定義")")
                    #expect(prop.p == "payload" || prop.p == "topic")
                }
                
                #expect(firstNode.repeat == 1.0)
                #expect(firstNode.once == true)
                #expect(firstNode.onceDelay == 0.5)
            }
        } catch {
            // パースに失敗した場合のエラーハンドリング
            print("❌ パースに失敗しました: \(error)")
        }
    }

}
