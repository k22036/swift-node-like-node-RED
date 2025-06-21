//
//  ContentView.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/16.
//

import SwiftUI

struct ContentView: View {
    @State private var flowJson: String = ""
    @State private var flow: Flow?
    @State private var isRunning: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Flow Configuration:")
                .font(.headline)
            TextEditor(text: $flowJson)
                .font(.system(.body, design: .monospaced))
                .border(Color.gray)
                .frame(height: 200)
            HStack {
                Button("Deploy") { deployFlow() }
                    .disabled(flowJson.isEmpty || isRunning)
                Button("Start") {
                    flow?.start()
                    isRunning = true
                }
                .disabled(flow == nil || isRunning)
                Button("Stop") {
                    flow?.stop()
                    isRunning = false
                }
                .disabled(!isRunning)
                Button("Clear Config") {
                    clearFlow()
                }
                .disabled(isRunning || (flow == nil && flowJson.isEmpty))
            }
            Text("Status: \(isRunning ? "Running" : "Stopped")")
                .font(.subheadline)
            Spacer()
        }
        .padding()
    }

    private func deployFlow() {
        do {
            let f = try Flow(flowJson: flowJson)
            flow = f
        } catch {
            print("Failed to deploy flow: \(error)")
        }
        isRunning = false
    }
    
    /// Configとフローをクリアする
    private func clearFlow() {
        flowJson = ""
        flow = nil
        isRunning = false
    }
}

#Preview {
    ContentView()
}
