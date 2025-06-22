//
//  MQTTNodeTests.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/22.
//

import Testing
@testable import swift_node_like_node_RED
import Foundation

struct MQTTNodeTests {
    
    @Test func MQTT_config_parse() async throws {
        // パース対象のJSON文字列
        let jsonString = """
            {
                "id": "f46f9b1e20e42771",
                "type": "mqtt-broker",
                "name": "",
                "broker": "10.0.1.10",
                "port": "1883",
                "clientid": "",
                "autoConnect": true,
                "usetls": false,
                "protocolVersion": "4",
                "keepalive": "60",
                "cleansession": true,
                "autoUnsubscribe": true,
                "birthTopic": "",
                "birthQos": "0",
                "birthRetain": "false",
                "birthPayload": "",
                "birthMsg": {},
                "closeTopic": "",
                "closeQos": "0",
                "closeRetain": "false",
                "closePayload": "",
                "closeMsg": {},
                "willTopic": "",
                "willQos": "0",
                "willRetain": "false",
                "willPayload": "",
                "willMsg": {},
                "userProps": "",
                "sessionExpiry": ""
            }
        """
        
        // JSON文字列をData型に変換
        guard let jsonData = jsonString.data(using: .utf8) else {
            fatalError("JSON文字列をDataに変換できませんでした。")
        }
        
        do {
            let node = try JSONDecoder().decode(MQTTBroker.self, from: jsonData)
            
            // パース結果の確認
            print("✅ パースに成功しました！")
            print("--------------------")
            
            #expect(node.id == "f46f9b1e20e42771")
            #expect(node.type == "mqtt-broker")
            #expect(node.broker == "10.0.1.10")
            #expect(node.port == 1883)
            #expect(node.clientid.isEmpty == true)
            #expect(node.autoConnect == true)
            #expect(node.usetls == false)
            #expect(node.protocolVersion == "4")
            #expect(node.keepalive == "60")
            #expect(node.autoUnsubscribe == true)

        } catch {
            // パースに失敗した場合のエラーハンドリング
            print("❌ パースに失敗しました: \(error)")
            throw error
        }
    }
}
