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
    // function
    case filter = "rbe"
    // network
    case mqttin = "mqtt in"
    case mqttout = "mqtt out"
    case httpRequest = "http request"
    // mobile
    case geolocation = "geolocation"
    case camera = "camera"
    case accelerometer = "accelerometer"
    case attitude = "attitude"
    case magnetometer = "magnetometer"
    case gravity = "gravity"
    case altitude = "altitude"
    case velocity = "velocity"
    case pressure = "pressure"
    case brightness = "brightness"
    case direction = "direction"
}

enum FlowType: String {
    case tab = "tab"
}

enum ConfigType: String {
    case mqttBroker = "mqtt-broker"
}
