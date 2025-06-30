//
//  Type.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/19.
//

enum NodeRedType: String {
    case date = "date"
    case number = "num"
    case string = "str"
    case boolean = "bool"
}

enum NodeType: String {
    case inject = "inject"
    case debug = "debug"
    case geolocation = "geolocation"
    case camera = "camera"
    case mqttin = "mqtt in"
    case mqttout = "mqtt out"
}

enum FlowType: String {
    case tab = "tab"
}

enum ConfigType: String {
    case MQTTBroker = "mqtt-broker"
}
