//
//  Logger.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/08/07.
//

final class Logger {
    static func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        #if DEBUG
            print(items.map { "\($0)" }.joined(separator: separator), terminator: terminator)
        #endif
    }
}
