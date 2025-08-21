//
//  DebugNodeTests.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/17.
//

import Foundation
import Testing

@testable import swift_node_like_node_RED

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
                Logger.debugLog("✅ パースに成功しました！")
                Logger.debugLog("--------------------")
                Logger.debugLog("ノードID: \(firstNode.id)")
                #expect(firstNode.id == "f0bd46d65aaae42b")
                Logger.debugLog("ノードタイプ: \(firstNode.type)")
                #expect(firstNode.type == "debug")
                Logger.debugLog("ノード名: \(firstNode.name)")
                #expect(firstNode.name == "debug 2")
                Logger.debugLog("接続先ノードID: \(firstNode.wires.first?.first ?? "なし")")
                #expect(firstNode.wires.isEmpty == true)

                #expect(firstNode.active == true)
                #expect(firstNode.tosidebar == true)
                #expect(firstNode.complete == "payload")
                #expect(firstNode.targetType == "msg")
            }
        } catch {
            // パースに失敗した場合のエラーハンドリング
            Logger.debugLog("❌ パースに失敗しました: \(error)")
            throw error
        }
    }

    @Test func printLog() async throws {
        let msg = NodeMessage(payload: "Debug message")

        // JSON文字列をData型に変換
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }

        do {
            let debugNode = (try JSONDecoder().decode([DebugNode].self, from: jsonData).first)!

            let flow = try await Flow(flowJson: "[]")
            await flow.addNode(debugNode)

            // パース結果の確認
            Logger.debugLog("✅ パースに成功しました！")
            Logger.debugLog("--------------------")
            Logger.debugLog("ノードID: \(debugNode.id)")
            Logger.debugLog("ノードタイプ: \(debugNode.type)")
            Logger.debugLog("ノード名: \(debugNode.name)")

            #expect(await debugNode.isRunning == false)
            await debugNode.initialize(flow: flow)
            #expect(await debugNode.isRunning == true)
            await debugNode.execute()
            await debugNode.receive(msg: msg)

            // 0.5秒待機
            try await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
            await debugNode.terminate()
            #expect(await debugNode.isRunning == false)
        } catch {
            // パースに失敗した場合のエラーハンドリング
            Logger.debugLog("❌ パースに失敗しました: \(error)")
            throw error
        }
    }
}
