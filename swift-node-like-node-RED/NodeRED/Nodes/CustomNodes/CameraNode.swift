import AVFoundation
import CoreImage
import Foundation
import UIKit

/// Custom node that captures images from the device camera and sends them as base64 strings
final class CameraNode: NSObject, Codable, Node {
    let id: String
    let type: String
    let z: String
    let name: String
    let `repeat`: Double?
    let once: Bool
    let onceDelay: Double
    private let x: Int
    private let y: Int
    let wires: [[String]]

    // Camera capture properties
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var shouldCaptureFrame = false  // flag to capture next frame
    /// Expose capture session for preview
    var session: AVCaptureSession { captureSession }
    weak var flow: Flow?
    var isRunning: Bool = false

    // Add a shared CIContext to reuse for image conversion
    private lazy var ciContext = CIContext()

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)

        let _type = try container.decode(String.self, forKey: .type)
        guard _type == NodeType.camera.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Expected type to be 'camera', but found \(_type)")
        }
        self.type = _type

        self.z = try container.decode(String.self, forKey: .z)
        self.name = try container.decode(String.self, forKey: .name)

        if let repeatValStr = try? container.decode(String.self, forKey: .repeat),
            let val = Double(repeatValStr)
        {
            self.`repeat` = val
        } else if let val = try? container.decode(Double.self, forKey: .repeat) {
            self.`repeat` = val
        } else {
            self.`repeat` = nil
        }

        self.once = try container.decode(Bool.self, forKey: .once)
        if let delayStr = try? container.decode(String.self, forKey: .onceDelay),
            let val = Double(delayStr)
        {
            self.onceDelay = val
        } else if let val = try? container.decode(Double.self, forKey: .onceDelay) {
            self.onceDelay = val
        } else {
            self.onceDelay = 0
        }

        self.x = try container.decode(Int.self, forKey: .x)
        self.y = try container.decode(Int.self, forKey: .y)
        self.wires = try container.decode([[String]].self, forKey: .wires)
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, z, name, `repeat`, once, onceDelay, x, y, wires
    }

    func initialize(flow: Flow) {
        self.flow = flow
        isRunning = true
        setupSession()
    }

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        captureSession.beginConfiguration()
        if let deviceInput = try? AVCaptureDeviceInput(device: device),
            captureSession.canAddInput(deviceInput)
        {
            captureSession.addInput(deviceInput)
        }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) {
            videoOutput.setSampleBufferDelegate(
                self, queue: DispatchQueue(label: "CameraNodeVideoQueue"))
            captureSession.addOutput(videoOutput)
        }
        captureSession.commitConfiguration()
        Task {
            captureSession.startRunning()
        }
    }

    func execute() {
        Task {
            if once {
                if onceDelay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(onceDelay * 1_000_000_000))
                }
                if !isRunning { return }
                capturePhoto()
            }
            guard let interval = `repeat`, interval > 0 else {
                return
            }
            while isRunning {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if !isRunning { return }
                capturePhoto()
            }
        }
    }

    private func capturePhoto() {
        shouldCaptureFrame = true
    }

    func terminate() {
        isRunning = false
        captureSession.stopRunning()
    }

    func receive(msg: NodeMessage) {
        // No input handling
    }

    func send(msg: NodeMessage) {
        flow?.routeMessage(from: self, message: msg)
    }
}

extension CameraNode: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isRunning && shouldCaptureFrame else { return }
        shouldCaptureFrame = false
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Get current device orientation and rotate the image
        let orientation = UIDevice.current.orientation
        let rotation: CGAffineTransform

        switch orientation {
        case .portrait:
            rotation = CGAffineTransform(rotationAngle: -(.pi / 2))
        case .portraitUpsideDown:
            rotation = CGAffineTransform(rotationAngle: .pi / 2)
        case .landscapeLeft:
            rotation = CGAffineTransform(rotationAngle: .pi)
        case .landscapeRight:
            rotation = CGAffineTransform(rotationAngle: 0)
        default:
            // Assume portrait if orientation is unknown
            rotation = CGAffineTransform(rotationAngle: -(.pi / 2))
        }
        ciImage = ciImage.transformed(by: rotation)

        // Use the shared context instead of creating a new one each time
        let context = ciContext
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        guard let data = uiImage.jpegData(compressionQuality: 0.8) else { return }
        let msg = NodeMessage(payload: data)
        send(msg: msg)
    }
}
