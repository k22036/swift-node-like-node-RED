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
}

enum FlowType: String {
    case tab = "tab"
}
