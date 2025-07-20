//
//  AsyncSemaphore.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/07/20.
//

actor AsyncSemaphore {
    private let value: Int
    private var count = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func wait() async {
        count += 1
        if count > value {
            await withCheckedContinuation { waiters.append($0) }
        }
    }

    func signal() {
        count -= 1
        if !waiters.isEmpty {
            waiters.removeFirst().resume()
        }
    }
}
