//
//  MQTTNode.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/22.
//

import Foundation
import MQTTNIO
import NIO

final class MQTTInNode: Codable, Node {
    let id: String
    let type: String
    let z: String
    let name: String
    let topic: String
    let qos: Int
    let datatype: String
    let broker: String
    let nl: Bool
    let rap: Bool
    let rh: Int
    let inputs: Int
    let x: Int
    let y: Int
    let wires: [[String]]
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        
        let _type = try container.decode(String.self, forKey: .type)
        guard _type == NodeType.mqttin.rawValue else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                                                   debugDescription: "Expected type to be 'mqtt in', but found \(_type)")
        }
        self.type = _type
        
        self.z = try container.decode(String.self, forKey: .z)
        self.name = try container.decode(String.self, forKey: .name)
        self.topic = try container.decode(String.self, forKey: .topic)
        
        let _qos = try container.decode(String.self, forKey: .qos)
        guard let qosValue = Int(_qos) else {
            throw DecodingError.dataCorruptedError(forKey: .qos, in: container,
                                                   debugDescription: "Expected a valid Int for qos, but found \(_qos)")
        }
        self.qos = qosValue
        
        self.datatype = try container.decode(String.self, forKey: .datatype)
        self.broker = try container.decode(String.self, forKey: .broker)
        self.nl = try container.decode(Bool.self, forKey: .nl)
        self.rap = try container.decode(Bool.self, forKey: .rap)
        self.rh = try container.decode(Int.self, forKey: .rh)
        self.inputs = try container.decode(Int.self, forKey: .inputs)
        
        self.x = try container.decode(Int.self, forKey: .x)
        self.y = try container.decode(Int.self, forKey: .y)
        self.wires = try container.decode([[String]].self, forKey: .wires)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, z, name, topic, qos, datatype, broker, nl, rap, rh, inputs, x, y, wires
    }
    
    weak var flow: Flow?
    var isRunning: Bool = false
    var listenerName: String?
    private var config: MQTTBroker?
    
    // MQTTNIO client
    private var client: MQTTClient?
    private var version: MQTTClient.Version = .v3_1_1 // Default to MQTT 3.1.1
    
    deinit {
        terminate()
    }
    
    func initialize(flow: Flow) {
        self.flow = flow
        self.config = flow.getConfig(by: self.broker)
        isRunning = true
    }
    
    func execute() {
        Task {
            if !isRunning { return }
            
            // Parse broker URL
            guard let host = self.config?.broker else {
                print("Invalid broker URL: \(broker)")
                return
            }
            guard let port = self.config?.port else {
                print("Invalid port for broker: \(broker)")
                return
            }
            let identifier = "MQTT_" + self.id
            
            // Configure MQTT client
            if config?.protocolVersion == "5" {
                version = .v5_0
            }
            let keepalive = Int64(config?.keepalive ?? "60") ?? 60
            let clientConfig = MQTTClient.Configuration(version: version,
                                                        keepAliveInterval: .seconds(keepalive))
            
            // create MQTT client
            client = MQTTClient(host: host,
                                port: port,
                                identifier: identifier,
                                eventLoopGroupProvider: .shared(.singletonNIOTSEventLoopGroup),
                                configuration: clientConfig)
            
            // Connect to the MQTT broker
            do {
                let connected = try await connect()
                if !connected {
                    print("Failed to connect to MQTT broker.")
                }
            } catch {
                print("Connection error: \(error)")
                return
            }
            
            // Subscribe to the topic
            do {
                try await subscribe()
            } catch {
                print("Failed to subscribe to topic: \(error)")
                return
            }
        }
    }
    
    func terminate() {
        isRunning = false
        // Disconnect and shutdown
        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await unsubscribe()
                await disconnect()
                try client?.syncShutdownGracefully()
            } catch {
                print("Error during termination: \(error)")
            }
        }
    }
    
    func connect() async throws -> Bool {
        guard let client = client else {
            print("MQTT client is not initialized.")
            return false
        }
        
        if version == .v5_0 {
            _ = try await client.v5.connect()
            return client.isActive()
        } else {
            _ = try await client.connect()
            return client.isActive()
        }
    }
    
    func disconnect() async {
        guard let client = client else {
            print("MQTT client is not initialized.")
            return
        }
        
        if version == .v5_0 {
            _ = try? await client.v5.disconnect()
        } else {
            _ = try? await client.disconnect()
        }
    }
    
    func subscribe() async throws {
        guard let client = client else {
            print("MQTT client is not initialized.")
            return
        }
        
        if version == .v5_0 {
            let info = MQTTSubscribeInfoV5(topicFilter: self.topic, qos: MQTTQoS(rawValue: UInt8(self.qos)) ?? .atMostOnce)
            _ = try await client.v5.subscribe(to: [info])
            print("Subscribed to topic: \(self.topic) with QoS: \(self.qos)")
        } else {
            let info = MQTTSubscribeInfo(topicFilter: self.topic, qos: MQTTQoS(rawValue: UInt8(self.qos)) ?? .atMostOnce)
            _ = try await client.subscribe(to: [info])
            print("Subscribed to topic: \(self.topic) with QoS: \(self.qos)")
        }
        
        let listenerName = "MQTTInNode-\(self.id)"
        self.listenerName = listenerName
        let listener: (Result<MQTTPublishInfo, Error>) -> Void = {massageResult in
            do {
                let mqttMessage = try massageResult.get()
                let msg = String(buffer: mqttMessage.payload)
                let nodeMessage = NodeMessage(payload: msg)
                self.send(msg: nodeMessage)
                print("Received message on topic \(mqttMessage.topicName): \(msg)")
            } catch {
                print("Failed to receive message: \(error)")
            }
        }
        
        client.removePublishListener(named: listenerName)
        client.addPublishListener(named: listenerName, listener)
    }
    
    func unsubscribe() async throws {
        guard let client = client, let listenerName = listenerName else {
            print("MQTT client or listener name is not initialized.")
            return
        }
        
        if version == .v5_0 {
            _ = try await client.v5.unsubscribe(from: [self.topic])
        } else {
            _ = try await client.unsubscribe(from: [self.topic])
        }
        
        client.removePublishListener(named: listenerName)
        print("Unsubscribed from topic: \(self.topic)")
        
        self.listenerName = nil
    }
    
    
    
    func receive(msg: NodeMessage) {}
    
    func send(msg: NodeMessage) {
        if !isRunning { return }
        
        flow?.routeMessage(from: self, message: msg)
    }
}

class MQTTOutNode: Codable, Node {
    let id: String
    let type: String
    let z: String
    let name: String
    let topic: String
    let qos: Int
    let retain: String
    let respTopic: String
    let contentType: String
    let userProps: String
    let correl: String
    let expiry: String
    let broker: String
    let x: Int
    let y: Int
    let wires: [[String]]
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        
        let _type = try container.decode(String.self, forKey: .type)
        guard _type == NodeType.mqttout.rawValue else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                                                   debugDescription: "Expected type to be 'mqtt out', but found \(_type)")
        }
        self.type = _type
        
        self.z = try container.decode(String.self, forKey: .z)
        self.name = try container.decode(String.self, forKey: .name)
        self.topic = try container.decode(String.self, forKey: .topic)
        
        let _qos = try container.decode(String.self, forKey: .qos)
        guard let qosValue = Int(_qos) else {
            throw DecodingError.dataCorruptedError(forKey: .qos, in: container,
                                                   debugDescription: "Expected a valid Int for qos, but found \(_qos)")
        }
        self.qos = qosValue
        
        self.retain = try container.decode(String.self, forKey: .retain)
        self.respTopic = try container.decode(String.self, forKey: .respTopic)
        self.contentType = try container.decode(String.self, forKey: .contentType)
        self.userProps = try container.decode(String.self, forKey: .userProps)
        self.correl = try container.decode(String.self, forKey: .correl)
        self.expiry = try container.decode(String.self, forKey: .expiry)
        self.broker = try container.decode(String.self, forKey: .broker)
        self.x = try container.decode(Int.self, forKey: .x)
        self.y = try container.decode(Int.self, forKey: .y)
        self.wires = try container.decode([[String]].self, forKey: .wires)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, z, name, topic, qos, retain, respTopic, contentType, userProps, correl, expiry, broker, x, y, wires
    }
    
    weak var flow: Flow?
    var isRunning: Bool = false
    private var config: MQTTBroker?
    
    // AsyncStream continuation for event-driven message delivery
    private var messageContinuation: AsyncStream<NodeMessage>.Continuation?
    // AsyncStream for incoming messages
    private lazy var messageStream: AsyncStream<NodeMessage> = AsyncStream { continuation in
        self.messageContinuation = continuation
    }
    
    // MQTTNIO client
    private var client: MQTTClient?
    private var version: MQTTClient.Version = .v3_1_1 // Default to MQTT 3.1.1
    
    deinit {
        terminate()
    }
    
    func initialize(flow: Flow) {
        self.flow = flow
        self.config = flow.getConfig(by: self.broker)
        isRunning = true
    }
    
    func execute() {
        Task {
            if !isRunning { return }
            
            // Parse broker URL
            guard let host = self.config?.broker else {
                print("Invalid broker URL: \(broker)")
                return
            }
            guard let port = self.config?.port else {
                print("Invalid port for broker: \(broker)")
                return
            }
            let identifier = "MQTT_" + self.id
            
            // Configure MQTT client
            if config?.protocolVersion == "5" {
                version = .v5_0
            }
            let keepalive = Int64(config?.keepalive ?? "60") ?? 60
            let clientConfig = MQTTClient.Configuration(version: version,
                                                        keepAliveInterval: .seconds(keepalive))
            
            // create MQTT client
            client = MQTTClient(host: host,
                                port: port,
                                identifier: identifier,
                                eventLoopGroupProvider: .shared(.singletonNIOTSEventLoopGroup),
                                configuration: clientConfig)
            
            // Connect to the MQTT broker
            do {
                let connected = try await connect()
                if !connected {
                    print("Failed to connect to MQTT broker.")
                }
            } catch {
                print("Connection error: \(error)")
                return
            }
            
            // Process messages as they arrive
            for await msg in messageStream where isRunning {
                await publish(msg: msg)
            }
        }
    }
    
    func terminate() {
        isRunning = false
        // Disconnect and shutdown
        Task { [weak self] in
            guard let self = self else { return }
            await disconnect()
            try client?.syncShutdownGracefully()
        }
    }
    
    func connect() async throws -> Bool {
        guard let client = client else {
            print("MQTT client is not initialized.")
            return false
        }
        
        if version == .v5_0 {
            _ = try await client.v5.connect()
            return client.isActive()
        } else {
            _ = try await client.connect()
            return client.isActive()
        }
    }
    
    func disconnect() async {
        guard let client = client else {
            print("MQTT client is not initialized.")
            return
        }
        
        if version == .v5_0 {
            _ = try? await client.v5.disconnect()
        } else {
            _ = try? await client.disconnect()
        }
    }
    
    func publish(msg: NodeMessage) async {
        guard let client = client else {
            print("MQTT client is not initialized.")
            return
        }
        
        let payload = ByteBufferAllocator().buffer(string: "\(msg.payload)")
        
        do {
            if version == .v5_0 {
                _ = try await client.v5.publish(to: self.topic,
                                                payload: payload,
                                                qos: MQTTQoS(rawValue: UInt8(self.qos)) ?? .atMostOnce)
                print("Published message to topic: \(self.topic) with QoS: \(self.qos)")
            } else {
                let _: () = try await client.publish(to: self.topic,
                                                     payload: payload,
                                                     qos: MQTTQoS(rawValue: UInt8(self.qos)) ?? .atMostOnce)
                print("Published message to topic: \(self.topic) with QoS: \(self.qos)")
            }
        } catch {
            print("Failed to publish message: \(error)")
        }
    }
    
    
    func receive(msg: NodeMessage) {
        guard isRunning else { return }
        // Deliver message to the AsyncStream
        messageContinuation?.yield(msg)
    }
    
    func send(msg: NodeMessage) {
    }
}

// MQTT Broker configuration class
class MQTTBroker: Codable {
    let id: String
    let type: String
    let name: String
    let broker: String
    let port: Int
    let clientid: String
    let autoConnect: Bool
    let usetls: Bool
    let protocolVersion: String
    let keepalive: String
    let cleansession: Bool
    let autoUnsubscribe: Bool
    let birthTopic: String
    let birthQos: Int
    let birthRetain: Bool
    let birthPayload: String
    let birthMsg: [String: String]
    let closeTopic: String
    let closeQos: Int
    let closeRetain: Bool
    let closePayload: String
    let closeMsg: [String: String]
    let willTopic: String
    let willQos: Int
    let willRetain: Bool
    let willPayload: String
    let willMsg: [String: String]
    let userProps: String
    let sessionExpiry: String
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        
        let _type = try container.decode(String.self, forKey: .type)
        guard _type == ConfigType.MQTTBroker.rawValue else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                                                   debugDescription: "Expected type to be 'mqtt-broker', but found \(_type)")
        }
        self.type = _type
        
        self.name = try container.decode(String.self, forKey: .name)
        self.broker = try container.decode(String.self, forKey: .broker)
        
        let _port = try container.decode(String.self, forKey: .port)
        guard let portValue = Int(_port) else {
            throw DecodingError.dataCorruptedError(forKey: .port, in: container,
                                                   debugDescription: "Expected a valid Int for port, but found \(_port)")
        }
        self.port = portValue
        
        self.clientid = try container.decode(String.self, forKey: .clientid)
        self.autoConnect = try container.decode(Bool.self, forKey: .autoConnect)
        self.usetls = try container.decode(Bool.self, forKey: .usetls)
        self.protocolVersion = try container.decode(String.self, forKey: .protocolVersion)
        self.keepalive = try container.decode(String.self, forKey: .keepalive)
        self.cleansession = try container.decode(Bool.self, forKey: .cleansession)
        self.autoUnsubscribe = try container.decode(Bool.self, forKey: .autoUnsubscribe)
        self.birthTopic = try container.decode(String.self, forKey: .birthTopic)
        
        let _birthQos = try container.decode(String.self, forKey: .birthQos)
        guard let birthQosValue = Int(_birthQos) else {
            throw DecodingError.dataCorruptedError(forKey: .birthQos, in: container,
                                                   debugDescription: "Expected a valid Int for birthQos, but found \(_birthQos)")
        }
        self.birthQos = birthQosValue
        
        let _birthRetain = try container.decode(String.self, forKey: .birthRetain)
        guard let birthRetainValue = Bool(_birthRetain) else {
            throw DecodingError.dataCorruptedError(forKey: .birthRetain, in: container,
                                                   debugDescription: "Expected a valid Bool for birthRetain, but found \(_birthRetain)")
        }
        self.birthRetain = birthRetainValue
        
        self.birthPayload = try container.decode(String.self, forKey: .birthPayload)
        self.birthMsg = try container.decode([String: String].self, forKey: .birthMsg)
        self.closeTopic = try container.decode(String.self, forKey: .closeTopic)
        
        let _closeQos = try container.decode(String.self, forKey: .closeQos)
        guard let closeQosValue = Int(_closeQos) else {
            throw DecodingError.dataCorruptedError(forKey: .closeQos, in: container,
                                                   debugDescription: "Expected a valid Int for closeQos, but found \(_closeQos)")
        }
        self.closeQos = closeQosValue
        
        let _closeRetain = try container.decode(String.self, forKey: .closeRetain)
        guard let closeRetainValue = Bool(_closeRetain) else {
            throw DecodingError.dataCorruptedError(forKey: .closeRetain, in: container,
                                                   debugDescription: "Expected a valid Bool for closeRetain, but found \(_closeRetain)")
        }
        self.closeRetain = closeRetainValue
        
        self.closePayload = try container.decode(String.self, forKey: .closePayload)
        self.closeMsg = try container.decode([String: String].self, forKey: .closeMsg)
        self.willTopic = try container.decode(String.self, forKey: .willTopic)
        
        let _willQos = try container.decode(String.self, forKey: .willQos)
        guard let willQosValue = Int(_willQos) else {
            throw DecodingError.dataCorruptedError(forKey: .willQos, in: container,
                                                   debugDescription: "Expected a valid Int for willQos, but found \(_willQos)")
        }
        self.willQos = willQosValue
        
        let _willRetain = try container.decode(String.self, forKey: .willRetain)
        guard let willRetainValue = Bool(_willRetain) else {
            throw DecodingError.dataCorruptedError(forKey: .willRetain, in: container,
                                                   debugDescription: "Expected a valid Bool for willRetain, but found \(_willRetain)")
        }
        self.willRetain = willRetainValue
        
        self.willPayload = try container.decode(String.self, forKey: .willPayload)
        self.willMsg = try container.decode([String: String].self, forKey: .willMsg)
        self.userProps = try container.decode(String.self, forKey: .userProps)
        self.sessionExpiry = try container.decode(String.self, forKey: .sessionExpiry)
    }
}
