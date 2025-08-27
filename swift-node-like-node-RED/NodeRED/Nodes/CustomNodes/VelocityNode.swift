import AsyncAlgorithms
@preconcurrency import CoreLocation
import Foundation

private actor VelocityState: NodeState, Sendable {
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

    fileprivate var lastSentTime: Date?
    private var lastVelocity = 0.0
    fileprivate var isRequested = false

    fileprivate func initBackgroundSession() {
        self.backgroundSession = CLBackgroundActivitySession()
    }

    fileprivate func finishBackgroundSession() {
        backgroundSession?.invalidate()
    }

    fileprivate func setLastSendTime(_ lastSendTime: Date) {
        self.lastSentTime = lastSendTime
    }

    fileprivate func setLastVelocity(_ lastVelocity: Double) {
        self.lastVelocity = lastVelocity
    }

    fileprivate func setIsRequested(_ isRequested: Bool) {
        self.isRequested = isRequested
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
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
    }

    fileprivate func startUpdateLocation() {
        locationManager.startUpdatingLocation()
    }

    fileprivate func stopUpdateLocation() {
        locationManager.stopUpdatingLocation()
    }
}

/// Custom node that retrieves and sends device velocity information
final class VelocityNode: NSObject, Codable, Node, Sendable, CLLocationManagerDelegate {
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
        guard _type == NodeType.velocity.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Expected type to be 'velocity', but found \(_type)")
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

    private let state = VelocityState()
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
            print("VelocityNode: Already running, skipping execution.")
            return
        }

        let currentTask = Task { [weak self] in
            guard let self = self else { return }

            locationManager?.startUpdateLocation()

            do {
                if once {
                    if onceDelay > 0 {
                        try await Task.sleep(nanoseconds: UInt64(onceDelay * 1_000_000_000))
                    }
                    if await !isRunning { return }
                    await requestVelocity()
                }
                guard let interval = `repeat`, interval > 0 else {
                    return
                }
                for await _ in AsyncTimerSequence(interval: .seconds(interval), clock: .suspending)
                {
                    if await !isRunning { return }
                    await requestVelocity()
                }
            } catch is CancellationError {
                // Task was cancelled, do nothing
                return
            } catch {
                print("VelocityNode execution error: \(error)")
                await state.setIsRunning(false)
                locationManager?.stopUpdateLocation()
                await locationState.finishBackgroundSession()
            }
        }
        await state.setCurrentTask(currentTask)
    }

    func terminate() async {
        await state.setIsRunning(false)
        await locationState.finishBackgroundSession()
        locationManager?.stopUpdateLocation()
        await state.finishCurrentTask()
    }

    deinit {
        locationManager?.stopUpdateLocation()
    }

    func receive(msg: NodeMessage) {
        // This node does not process incoming messages
    }

    func send(msg: NodeMessage) async {
        await state.flow?.routeMessage(from: self, message: msg)
    }

    private func requestVelocity() async {
        guard CLLocationManager.locationServicesEnabled() else { return }
        await locationState.setIsRequested(true)
    }

    // CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task.detached { @Sendable [weak self] in
            guard let self = self else { return }

            guard await isRunning, let location = locations.last, location.speed >= 0 else {
                return
            }
            await locationState.setLastVelocity(location.speed)

            // Debounce to prevent rapid-fire messages
            if let lastSent = await self.locationState.lastSentTime,
                Date().timeIntervalSince(lastSent) < 0.02
            {
                return
            }
            if await !self.locationState.isRequested {
                return
            }

            let payload: [String: Double] = [
                "velocity": location.speed  // m/s
            ]
            let msg = NodeMessage(payload: payload)
            await send(msg: msg)
            await self.locationState.setLastSendTime(Date())
            await self.locationState.setIsRequested(false)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Optionally handle error
        print("Failed to get velocity: \(error.localizedDescription)")
    }

    /// For testing: simulate a velocity update
    func simulateVelocity(_ velocity: Double) async {
        let payload: [String: Double] = ["velocity": velocity]
        let msg = NodeMessage(payload: payload)
        await send(msg: msg)
    }
}
