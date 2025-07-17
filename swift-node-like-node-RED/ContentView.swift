//
//  ContentView.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/16.
//

import AVFoundation
import SwiftUI
import UIKit

struct ContentView: View {
  @State private var flowJson: String = ""
  @State private var flow: Flow?
  @State private var isRunning: Bool = false

  var body: some View {
    TabView {
      // Flow Configuration Tab
      VStack(alignment: .leading, spacing: 10) {
        Text("Flow Configuration:")
          .font(.headline)
        TextEditor(text: $flowJson)
          .font(.system(.body, design: .monospaced))
          .border(Color.gray)
          .frame(height: 200)
          .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
              Spacer()
              Button("Done") {
                UIApplication.shared.sendAction(
                  #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
              }
            }
          }
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
      .tabItem { Label("Config", systemImage: "gearshape") }

      // Camera Preview Tab
      Group {
        if let session = flow?.getCameraNode()?.session {
          CameraPreview(session: session)
            .ignoresSafeArea()
        } else {
          Text("No CameraNode available")
        }
      }
      .tabItem { Label("Camera", systemImage: "camera") }
    }
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

/// UIViewRepresentable for displaying AVCaptureSession
struct CameraPreview: UIViewRepresentable {
  let session: AVCaptureSession

  func makeUIView(context: Context) -> PreviewView {
    let view = PreviewView()
    view.backgroundColor = .black
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill
    view.layer.addSublayer(previewLayer)
    view.previewLayer = previewLayer
    return view
  }

  func updateUIView(_ uiView: PreviewView, context: Context) {
    // No need to update the frame here anymore, layoutSubviews will handle it.
  }
}

/// A custom UIView that holds the AVCaptureVideoPreviewLayer
class PreviewView: UIView {
  var previewLayer: AVCaptureVideoPreviewLayer?

  override func layoutSubviews() {
    super.layoutSubviews()
    previewLayer?.frame = self.bounds
  }
}

#Preview {
  ContentView()
}
