//
//  AsyncSemaphoreTests.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/07/20.
//

import Foundation
import Testing

@testable import swift_node_like_node_RED

struct AsyncSemaphoreTests {
    @Test func waitAndSignal() async throws {
        // セマフォの初期値を1に設定
        let sem = AsyncSemaphore(value: 1)
        // 最初のwaitはすぐ通過する
        await sem.wait()

        // 2つ目のwaitはsignalが来るまでブロックされる
        var resumed = false
        Task {
            await sem.wait()
            resumed = true
        }

        // 少し待っても resumed は false のまま
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(resumed == false)

        // signal を送り、待機中のタスクを再開
        await sem.signal()

        // 再開後、resumed が true になっている
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(resumed == true)
    }

    @Test func multiplePermits() async throws {
        // セマフォの初期値を2に設定
        let sem = AsyncSemaphore(value: 2)
        // 2つまでのwaitはすぐ通過する
        await sem.wait()
        await sem.wait()

        // 3つ目のwaitはsignalが来るまでブロックされる
        var resumed3 = false
        Task {
            await sem.wait()
            resumed3 = true
        }

        // 少し待っても resumed3 は false のまま
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(resumed3 == false)

        // signal を送り、待機中のタスクを再開
        await sem.signal()

        // 再開後、resumed3 が true になっている
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(resumed3 == true)
    }
}
