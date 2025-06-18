//
//  DebugNodeTests.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/17.
//

import Testing
@testable import swift_node_like_node_RED
import Foundation

struct DebugNodeTests {
    
    // パース対象のJSON文字列
    let jsonString = """
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

    @Test func parse() async throws {
        // JSON文字列をData型に変換
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        
        do {
            let nodes = try JSONDecoder().decode([DebugNode].self, from: jsonData)
            
            // パース結果の確認
            if let firstNode = nodes.first {
                print("✅ パースに成功しました！")
                print("--------------------")
                print("ノードID: \(firstNode.id)")
                #expect(firstNode.id == "f0bd46d65aaae42b")
                print("ノードタイプ: \(firstNode.type)")
                #expect(firstNode.type == "debug")
                print("ノード名: \(firstNode.name)")
                #expect(firstNode.name == "debug 2")
                print("接続先ノードID: \(firstNode.wires.first?.first ?? "なし")")
                #expect(firstNode.wires.isEmpty == true)
                
                #expect(firstNode.active == true)
                #expect(firstNode.tosidebar == true)
                #expect(firstNode.complete == "payload")
                #expect(firstNode.targetType == "msg")
            }
        } catch {
            // パースに失敗した場合のエラーハンドリング
            print("❌ パースに失敗しました: \(error)")
        }
    }

    @Test func printLog() {
        let msg = NodeMessage(payload: "Debug message")
        
        // JSON文字列をData型に変換
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        
        do {
            let nodes = try JSONDecoder().decode([DebugNode].self, from: jsonData)
            
            // パース結果の確認
            if let firstNode = nodes.first {
                print("✅ パースに成功しました！")
                print("--------------------")
                print("ノードID: \(firstNode.id)")
                print("ノードタイプ: \(firstNode.type)")
                print("ノード名: \(firstNode.name)")
                
                #expect(firstNode.isRunning == false)
                firstNode.initalize()
                #expect(firstNode.isRunning == true)
                firstNode.execute()
                firstNode.receive(msg: msg)
                
                // 0.5秒待機
                Thread.sleep(forTimeInterval: 0.5)
                firstNode.terminate()
                #expect(firstNode.isRunning == false)
            }
        } catch {
            // パースに失敗した場合のエラーハンドリング
            print("❌ パースに失敗しました: \(error)")
        }
    }
}
