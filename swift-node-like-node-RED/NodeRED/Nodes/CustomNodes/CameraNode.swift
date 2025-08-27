@preconcurrency import AVFoundation
import AsyncAlgorithms
@preconcurrency import CoreImage
import Foundation
import UIKit

private actor CameraState: NodeState, Sendable {
    fileprivate weak var flow: Flow?
    fileprivate var isRunning: Bool = false

    fileprivate var currentTask: Task<Void, Never>?

    fileprivate func setFlow(_ flow: Flow) {
        self.flow = flow
    }

    fileprivate func setIsRunning(_ running: Bool) {
        self.isRunning = running
    }

    fileprivate func setCurrentTask(_ task: Task<Void, Never>?) {
        self.currentTask = task
    }

    fileprivate func finishCurrentTask() async {
        currentTask?.cancel()
        await currentTask?.value  // Wait for the task to complete
        currentTask = nil
    }
}

private actor CaptureState: Sendable {
    fileprivate var shouldCaptureFrame = false  // flag to capture next frame

    fileprivate func setShouldCaptureFrame(_ capture: Bool) {
        shouldCaptureFrame = capture
    }
}

/// Custom node that captures images from the device camera and sends them as base64 strings
final class CameraNode: NSObject, Codable, Sendable, Node {
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

    private let state = CameraState()
    private let captureState = CaptureState()

    var isRunning: Bool {
        get async {
            await state.isRunning
        }
    }

    // Camera capture properties
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    /// Expose capture session for preview
    var session: AVCaptureSession { captureSession }
    private let ciContext = CIContext()

    func initialize(flow: Flow) async {
        await state.setFlow(flow)
        await state.setIsRunning(true)
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

    func execute() async {
        // Prevent multiple executions
        if let task = await state.currentTask, !task.isCancelled {
            print("CameraNode: Already running, skipping execution.")
            return
        }

        let currentTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                if once {
                    if onceDelay > 0 {
                        try await Task.sleep(nanoseconds: UInt64(onceDelay * 1_000_000_000))
                    }
                    if await !isRunning { return }
                    await capturePhoto()
                }
                guard let interval = `repeat`, interval > 0 else {
                    return
                }
                for await _ in AsyncTimerSequence(interval: .seconds(interval), clock: .suspending)
                {
                    if await !isRunning { return }
                    await capturePhoto()
                }
            } catch is CancellationError {
                return
            } catch {
                print("CameraNode execution error: \(error)")
            }
        }
        await state.setCurrentTask(currentTask)
    }

    private func capturePhoto() async {
        await captureState.setShouldCaptureFrame(true)
    }

    func terminate() async {
        await state.setIsRunning(false)
        captureSession.stopRunning()
        await state.finishCurrentTask()
    }

    deinit {
        captureSession.stopRunning()
    }

    func receive(msg: NodeMessage) {
        // No input handling
    }

    func send(msg: NodeMessage) async {
        await state.flow?.routeMessage(from: self, message: msg)
    }
}

extension CameraNode: AVCaptureVideoDataOutputSampleBufferDelegate {
    @objc
    internal func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Get current device orientation and rotate the image
        let angle = CGFloat(connection.videoRotationAngle) * .pi / 180
        let rotation = CGAffineTransform(rotationAngle: angle)

        ciImage = ciImage.transformed(by: rotation)

        // Use the shared context instead of creating a new one each time
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        guard let data = uiImage.jpegData(compressionQuality: 0.8) else { return }

        Task.detached { @Sendable [weak self] in
            guard let self = self else { return }

            let isRunning = await isRunning
            let shouldCaptureFrame = await captureState.shouldCaptureFrame
            guard isRunning && shouldCaptureFrame else { return }
            await captureState.setShouldCaptureFrame(false)

            let msg = NodeMessage(payload: data)
            await send(msg: msg)
        }
    }
}
