import AsyncAlgorithms
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
    let mode: String
    let centerLat: Double
    let centerLon: Double
    let radius: Double
    let keepAlive: String
    private let x: Int
    private let y: Int
    let wires: [[String]]

    private enum ModeType: String {
        case periodic = "periodic"
        case update = "update"
        case area = "area"
    }

    private enum KeepAliveType: String {
        case none = "none"
        case both = "both"
        case inside = "inside"
        case outside = "outside"
    }

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

        let _mode = try container.decode(String.self, forKey: .mode)
        guard let modeType = ModeType(rawValue: _mode) else {
            throw DecodingError.dataCorruptedError(
                forKey: .mode, in: container,
                debugDescription: "Invalid mode type: \(_mode)")
        }
        self.mode = modeType.rawValue

        if let lat = try? container.decode(Double.self, forKey: .centerLat) {
            self.centerLat = lat
        } else if let latStr = try? container.decode(String.self, forKey: .centerLat),
            let lat = Double(latStr)
        {
            self.centerLat = lat
        } else {
            let latInt = try container.decode(Int.self, forKey: .centerLat)
            self.centerLat = Double(latInt)
        }

        if let lon = try? container.decode(Double.self, forKey: .centerLon) {
            self.centerLon = lon
        } else if let lonStr = try? container.decode(String.self, forKey: .centerLon),
            let lon = Double(lonStr)
        {
            self.centerLon = lon
        } else {
            let lonInt = try container.decode(Int.self, forKey: .centerLon)
            self.centerLon = Double(lonInt)
        }

        if let radiusVal = try? container.decode(Double.self, forKey: .radius) {
            self.radius = radiusVal
        } else if let radiusStr = try? container.decode(String.self, forKey: .radius),
            let radiusVal = Double(radiusStr)
        {
            self.radius = radiusVal
        } else {
            let radiusInt = try container.decode(Int.self, forKey: .radius)
            self.radius = Double(radiusInt)
        }

        let _keepAlive = try container.decode(String.self, forKey: .keepAlive)
        guard let keepAliveType = KeepAliveType(rawValue: _keepAlive) else {
            throw DecodingError.dataCorruptedError(
                forKey: .mode, in: container,
                debugDescription: "Invalid mode type: \(_keepAlive)")
        }
        self.keepAlive = keepAliveType.rawValue

        self.x = try container.decode(Int.self, forKey: .x)
        self.y = try container.decode(Int.self, forKey: .y)
        self.wires = try container.decode([[String]].self, forKey: .wires)
    }

    private enum CodingKeys: String, CodingKey {
        case id, type, z, name, `repeat`, once, onceDelay, mode, centerLat, centerLon, radius, x, y,
            wires, keepAlive
    }

    var locationManager: CLLocationManager = CLLocationManager()
    weak var flow: Flow?
    var isRunning: Bool = false
    private var currentTask: Task<Void, Never>?
    private var keepAliveTask: Task<Void, Never>?
    private var isInsideArea: Bool = false
    private var lastSentTime: Date?
    private var lastLocation: CLLocation?

    var monitor: CLMonitor?
    lazy var identifier: String = {
        "GeolocationArea, centerLat: \(centerLat), centerLon: \(centerLon), radius: \(radius)"
    }()

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

            if mode == ModeType.update.rawValue {
                startUpdateLocation()
                return
            } else if mode == ModeType.area.rawValue {
                if monitor == nil {
                    // Use a unique name for each monitor instance to avoid conflicts
                    monitor = await CLMonitor("GeolocationArea\(id)")
                }
                let condition = CLMonitor.CircularGeographicCondition(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    radius: radius)
                await monitor?.add(condition, identifier: identifier)

                guard let monitor = monitor else {
                    print("Failed to initialize geolocation area monitoring.")
                    return
                }

                // keep alive task
                if let interval = `repeat`, interval > 0, keepAlive != KeepAliveType.none.rawValue {
                    keepAliveTask?.cancel()
                    keepAliveTask = Task { [weak self] in
                        guard let self = self else { return }
                        for await _ in AsyncTimerSequence(
                            interval: .seconds(interval), clock: .suspending)
                        {
                            if !self.isRunning { break }
                            self.sendKeepAlive()
                        }
                    }
                }

                do {
                    for try await event in await monitor.events {
                        if Task.isCancelled { break }
                        if event.state == .satisfied {
                            isInsideArea = true
                            sendEnter()
                        } else if event.state == .unsatisfied {
                            isInsideArea = false
                            sendExit()
                        }
                    }
                } catch {
                    if !(error is CancellationError) {
                        print("Geolocation area monitoring error: \(error)")
                    }
                }
                keepAliveTask?.cancel()
                if let task = keepAliveTask {
                    _ = await task.value
                }
                keepAliveTask = nil
                return
            }

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
                for await _ in AsyncTimerSequence(interval: .seconds(interval), clock: .suspending)
                {
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
        keepAliveTask?.cancel()
        locationManager.stopUpdatingLocation()
        await monitor?.remove(identifier)
        monitor = nil
        if let task = currentTask {
            _ = await task.value
        }
        if let task = keepAliveTask {
            _ = await task.value
        }
        currentTask = nil
    }

    deinit {
        isRunning = false
        currentTask?.cancel()
        keepAliveTask?.cancel()
        keepAliveTask = nil
        locationManager.stopUpdatingLocation()
        monitor = nil
    }

    func receive(msg: NodeMessage) {
        // This node does not process incoming messages
    }

    func send(msg: NodeMessage) {
        flow?.routeMessage(from: self, message: msg)
    }

    func sendEnter() {
        let payload: [String: String] = ["event": "enter"]
        let msg = NodeMessage(payload: payload)
        send(msg: msg)
    }

    func sendExit() {
        let payload: [String: String] = ["event": "exit"]
        let msg = NodeMessage(payload: payload)
        send(msg: msg)
    }

    // keep alive event sender
    func sendKeepAlive() {
        guard isRunning else { return }

        // 現在位置を取得し、エリア内判定
        requestLocation()
        let location = lastLocation
        let isInside: Bool
        if let location = location {
            let center = CLLocation(latitude: centerLat, longitude: centerLon)
            let distance = location.distance(from: center)
            isInside = distance <= radius
            isInsideArea = isInside  // 更新エリア内フラグ
        } else {
            // 位置情報がなければ従来通りフラグで判定
            isInside = isInsideArea
        }

        switch keepAlive {
        case KeepAliveType.inside.rawValue:
            if isInside {
                let payload: [String: String] = ["event": "keepalive_inside"]
                let msg = NodeMessage(payload: payload)
                send(msg: msg)
            }
        case KeepAliveType.outside.rawValue:
            if !isInside {
                let payload: [String: String] = ["event": "keepalive_outside"]
                let msg = NodeMessage(payload: payload)
                send(msg: msg)
            }
        default:
            let payload: [String: String] = [
                "event": isInside ? "keepalive_inside" : "keepalive_outside"
            ]
            let msg = NodeMessage(payload: payload)
            send(msg: msg)
        }
    }

    private func startUpdateLocation() {
        locationManager.startUpdatingLocation()
    }

    private func requestLocation() {
        locationManager.requestLocation()
    }

    /// For testing: simulate a CLMonitor event for area mode
    func simulateAreaEvent(state: CLMonitor.Event.State) {
        if state == .satisfied {
            sendEnter()
        } else if state == .unsatisfied {
            sendExit()
        }
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
        if let lastSent = lastSentTime, Date().timeIntervalSince(lastSent) < 0.9 {
            return
        }

        if mode == ModeType.area.rawValue {
            lastLocation = loc
            lastSentTime = Date()
            return
        }

        let payload: [String: Double] = [
            "latitude": loc.coordinate.latitude,  // 緯度
            "longitude": loc.coordinate.longitude,  // 経度
        ]
        let msg = NodeMessage(payload: payload)
        send(msg: msg)
        lastSentTime = Date()
        lastLocation = loc
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("GeolocationNode error: \(error.localizedDescription)")
    }
}
