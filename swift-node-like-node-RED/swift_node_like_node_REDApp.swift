//
//  swift_node_like_node_REDApp.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/16.
//

import SwiftUI
import SwiftData

@main
struct swift_node_like_node_REDApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
