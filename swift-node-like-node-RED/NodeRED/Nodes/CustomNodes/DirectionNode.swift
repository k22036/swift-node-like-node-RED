import AsyncAlgorithms
@preconcurrency import CoreLocation
import Foundation
import UIKit

private actor DirectionState: NodeState, Sendable {
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

private actor LocationState: Sendable {
    private var backgroundSession: CLBackgroundActivitySession?

    fileprivate func initBackgroundSession() {
        self.backgroundSession = CLBackgroundActivitySession()
    }

    fileprivate func finishBackgroundSession() {
        backgroundSession?.invalidate()
    }
}

private final class LocationManager: Sendable {
    private let locationManager: CLLocationManager = CLLocationManager()

    @MainActor
    fileprivate init() {
        // locationManagerをmainスレッドで初期化するために必要
    }

    fileprivate func initLocationManager(delegate: CLLocationManagerDelegate) {
        locationManager.delegate = delegate
        locationManager.requestWhenInUseAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
    }

    fileprivate func startUpdateHeading() {
        locationManager.startUpdatingHeading()
    }

    fileprivate func stopUpdateHeading() {
        locationManager.stopUpdatingHeading()
    }
}

/// Custom node that retrieves and sends device heading (direction) information
final class DirectionNode: NSObject, Codable, Node, Sendable, CLLocationManagerDelegate {
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
        guard _type == NodeType.direction.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Expected type to be 'direction', but found \(_type)")
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

    private let state = DirectionState()
    private let locationState = LocationState()
    nonisolated(unsafe) private var locationManager: LocationManager?

    var isRunning: Bool {
        get async {
            await state.isRunning
        }
    }

    func initialize(flow: Flow) async {
        await state.setFlow(flow)
        await state.setIsRunning(true)
        self.locationManager = await LocationManager()
        locationManager?.initLocationManager(delegate: self)
        await locationState.initBackgroundSession()
    }

    func execute() async {
        // Prevent multiple concurrent executions
        if let task = await state.currentTask, !task.isCancelled {
            print("DirectionNode: already running, skipping execution.")
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
                    requestDirection()
                }
                guard let interval = `repeat`, interval > 0 else {
                    return
                }
                for await _ in AsyncTimerSequence(interval: .seconds(interval), clock: .suspending)
                {
                    if await !isRunning { return }
                    requestDirection()
                }
            } catch is CancellationError {
                // Task was cancelled, do nothing
                return
            } catch {
                print("DirectionNode execution error: \(error)")
                await state.setIsRunning(false)
                locationManager?.stopUpdateHeading()
                await locationState.finishBackgroundSession()
                return
            }
        }
        await state.setCurrentTask(currentTask)
    }

    /// Requests the current device heading
    private func requestDirection() {
        locationManager?.startUpdateHeading()
    }

    func terminate() async {
        await state.setIsRunning(false)
        await locationState.finishBackgroundSession()
        locationManager?.stopUpdateHeading()
        await state.finishCurrentTask()
    }

    deinit {
        locationManager?.stopUpdateHeading()
    }

    func receive(msg: NodeMessage) {
        // This node does not process incoming messages
    }

    func send(msg: NodeMessage) async {
        await state.flow?.routeMessage(from: self, message: msg)
    }

    /// Helper function to send heading message
    private func sendHeadingMessage(_ heading: Double) async {
        let payload: [String: Double] = ["heading": heading]
        let msg = NodeMessage(payload: payload)
        await send(msg: msg)
    }

    // CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task.detached { @Sendable [weak self] in
            guard let self = self else { return }

            guard await isRunning else { return }
            await sendHeadingMessage(newHeading.trueHeading)
            // Stop after retrieving the heading once
            locationManager?.stopUpdateHeading()
        }
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        return true
    }

    /// For testing: simulate a heading update
    func simulateHeading(_ heading: Double) async {
        await sendHeadingMessage(heading)
    }
}
