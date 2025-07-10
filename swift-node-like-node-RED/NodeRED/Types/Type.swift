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
    // common
    case inject = "inject"
    case debug = "debug"
    // network
    case mqttin = "mqtt in"
    case mqttout = "mqtt out"
    case http_request = "http request"
    // mobile
    case geolocation = "geolocation"
    case camera = "camera"
    case accelerometer = "accelerometer"
    case attitude = "attitude"
    case magnetometer = "magnetometer"
    case gravity = "gravity"
    case altitude = "altitude"
    case velocity = "velocity"
}

enum FlowType: String {
    case tab = "tab"
}

enum ConfigType: String {
    case MQTTBroker = "mqtt-broker"
}
