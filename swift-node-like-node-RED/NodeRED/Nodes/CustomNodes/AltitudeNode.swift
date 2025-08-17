import AsyncAlgorithms
import CoreLocation
import Foundation

/// Custom node that retrieves and sends device altitude (elevation) information
final class AltitudeNode: NSObject, Codable, Node, CLLocationManagerDelegate {
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
        guard _type == NodeType.altitude.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Expected type to be 'altitude', but found \(_type)")
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

    var locationManager: CLLocationManager = CLLocationManager()
    private var backgroundSession: CLBackgroundActivitySession?
    weak var flow: Flow?
    var isRunning: Bool = false
    private var currentTask: Task<Void, Never>?
    private var lastSentTime: Date?

    func initialize(flow: Flow) {
        self.flow = flow
        isRunning = true
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        self.backgroundSession = CLBackgroundActivitySession()
    }

    func execute() {
        // Prevent multiple executions
        if let task = currentTask, !task.isCancelled {
            print("AltitudeNode: Already running, skipping execution.")
            return
        }

        currentTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                if once {
                    if onceDelay > 0 {
                        try await Task.sleep(nanoseconds: UInt64(onceDelay * 1_000_000_000))
                    }
                    if !isRunning { return }
                    requestAltitude()
                }
                guard let interval = `repeat`, interval > 0 else {
                    return
                }
                for await _ in AsyncTimerSequence(interval: .seconds(interval), clock: .suspending)
                {
                    if !isRunning { return }
                    requestAltitude()
                }
            } catch is CancellationError {
                // Task was cancelled, do nothing
                return
            } catch {
                print("AltitudeNode: Error during execution - \(error)")
                isRunning = false
                locationManager.stopUpdatingLocation()
                backgroundSession?.invalidate()
                return
            }

        }
    }

    func terminate() async {
        isRunning = false
        currentTask?.cancel()
        locationManager.stopUpdatingLocation()
        backgroundSession?.invalidate()

        if let task = currentTask {
            _ = await task.value  // Wait for the task to complete
        }
        currentTask = nil
    }

    deinit {
        isRunning = false
        currentTask?.cancel()
        locationManager.stopUpdatingLocation()
        backgroundSession?.invalidate()
        locationManager.delegate = nil
    }

    func receive(msg: NodeMessage) {
        // This node does not process incoming messages
    }

    func send(msg: NodeMessage) {
        flow?.routeMessage(from: self, message: msg)
    }

    private func requestAltitude() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        locationManager.startUpdatingLocation()
    }

    // CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isRunning, let location = locations.last else { return }
        // Debounce to prevent rapid-fire messages
        if let lastSent = self.lastSentTime, Date().timeIntervalSince(lastSent) < 0.1 {
            return
        }
        let payload: [String: Double] = [
            "altitude": location.altitude
        ]
        let msg = NodeMessage(payload: payload)
        send(msg: msg)
        self.lastSentTime = Date()
        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Optionally handle error
        print("Failed to get altitude: \(error.localizedDescription)")
    }

    /// For testing: simulate an altitude update
    func simulateAltitude(_ altitude: Double) {
        let payload: [String: Double] = ["altitude": altitude]
        let msg = NodeMessage(payload: payload)
        send(msg: msg)
    }
}
