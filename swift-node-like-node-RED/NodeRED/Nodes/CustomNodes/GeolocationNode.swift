import CoreLocation
import Foundation

/// Custom node that retrieves and sends device geolocation information
final class GeolocationNode: NSObject, Codable, Node, CLLocationManagerDelegate {
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
        guard _type == NodeType.geolocation.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Expected type to be 'geolocation', but found \(_type)")
        }
        self.type = _type

        self.z = try container.decode(String.self, forKey: .z)
        self.name = try container.decode(String.self, forKey: .name)

        // Interval between updates (seconds)
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

        // Delay before first update
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
    weak var flow: Flow?
    var isRunning: Bool = false
    private var currentTask: Task<Void, Never>?
    private var lastSentTime: Date?

    func initialize(flow: Flow) {
        self.flow = flow
        isRunning = true
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }

    func execute() {
        // Prevent multiple concurrent executions
        if let task = currentTask, !task.isCancelled {
            print("GeolocationNode: Already running, skipping execution.")
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
                    requestLocation()
                }
                guard let interval = `repeat`, interval > 0 else {
                    return
                }
                while isRunning {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    if !isRunning { return }
                    requestLocation()
                }
            } catch is CancellationError {
                // Task was cancelled, do nothing
                return
            } catch {
                print("GeolocationNode execution error: \(error)")
                isRunning = false
            }

        }
    }

    func terminate() async {
        isRunning = false
        currentTask?.cancel()

        if let task = currentTask {
            _ = await task.value  // Ensure the task is awaited to avoid memory leaks
        }
        currentTask = nil
    }

    deinit {
        isRunning = false
        currentTask?.cancel()
    }

    func receive(msg: NodeMessage) {
        // This node does not process incoming messages
    }

    func send(msg: NodeMessage) {
        flow?.routeMessage(from: self, message: msg)
    }

    private func requestLocation() {
        locationManager.requestLocation()
    }

    /// For testing: simulate a location update
    func simulateLocation(latitude: Double, longitude: Double) {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        self.locationManager(self.locationManager, didUpdateLocations: [location])
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isRunning, let loc = locations.last else { return }

        // Debounce to prevent rapid-fire messages
        if let lastSent = lastSentTime, Date().timeIntervalSince(lastSent) < 1.0 {
            return
        }

        let payload: [String: Double] = [
            "latitude": loc.coordinate.latitude,  // 緯度
            "longitude": loc.coordinate.longitude,  // 経度
        ]
        let msg = NodeMessage(payload: payload)
        send(msg: msg)
        lastSentTime = Date()

        locationManager.stopUpdatingLocation()  // Stop updates after sending
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("GeolocationNode error: \(error.localizedDescription)")
    }
}
