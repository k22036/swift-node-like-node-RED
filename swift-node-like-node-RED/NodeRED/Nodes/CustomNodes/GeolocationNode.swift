import AsyncAlgorithms
@preconcurrency import CoreLocation
import Foundation

private actor GeolocationState: NodeState, Sendable {
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
    private var keepAliveTask: Task<Void, Never>?
    fileprivate var monitor: CLMonitor?

    fileprivate var isInsideArea: Bool = false
    fileprivate var lastSentTime: Date?
    fileprivate var lastLocation: CLLocation?

    fileprivate func initBackgroundSession() {
        self.backgroundSession = CLBackgroundActivitySession()
    }

    fileprivate func finishBackgroundSession() {
        backgroundSession?.invalidate()
    }

    fileprivate func setKeepAliveTask(_ task: Task<Void, Never>?) {
        self.keepAliveTask = task
    }

    fileprivate func finishKeepAliveTask() async {
        keepAliveTask?.cancel()
        await keepAliveTask?.value  // Wait for the task to complete
        keepAliveTask = nil
    }

    fileprivate func setMonitor(_ monitor: CLMonitor?) {
        self.monitor = monitor
    }

    fileprivate func addMonitorCondition(
        _ condition: CLMonitor.CircularGeographicCondition, identifier: String
    ) async {
        await monitor?.add(condition, identifier: identifier)
    }

    fileprivate func removeMonitor(identifier: String) async {
        await monitor?.remove(identifier)
        monitor = nil
    }

    fileprivate func setIsInsideArea(_ isInsideArea: Bool) {
        self.isInsideArea = isInsideArea
    }

    fileprivate func setLastSendTime(_ lastSendTime: Date) {
        self.lastSentTime = lastSendTime
    }

    fileprivate func setLastLocation(_ lastLocation: CLLocation) {
        self.lastLocation = lastLocation
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

    fileprivate func getLocationManager() -> CLLocationManager {
        return self.locationManager
    }

    fileprivate func startUpdateLocation() {
        locationManager.startUpdatingLocation()
    }

    fileprivate func stopUpdateLocation() {
        locationManager.stopUpdatingLocation()
    }

    fileprivate func requestLocation() {
        locationManager.requestLocation()
    }
}

/// Custom node that retrieves and sends device geolocation information
final class GeolocationNode: NSObject, Codable, Sendable, Node, CLLocationManagerDelegate {
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
                forKey: .keepAlive, in: container,
                debugDescription: "Invalid keep alive type: \(_keepAlive)")
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

    private let state = GeolocationState()
    private let locationState = LocationState()
    nonisolated(unsafe) private var locationManager: LocationManager?

    var isRunning: Bool {
        get async {
            await state.isRunning
        }
    }

    private var identifier: String {
        "GeolocationArea, centerLat: \(centerLat), centerLon: \(centerLon), radius: \(radius)"
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
            print("GeolocationNode: Already running, skipping execution.")
            return
        }

        let currentTask = Task { [weak self] in
            guard let self = self else { return }

            if mode == ModeType.update.rawValue {
                locationManager?.startUpdateLocation()
                return
            } else if mode == ModeType.area.rawValue {
                if await locationState.monitor == nil {
                    // Use a unique name for each monitor instance to avoid conflicts
                    let monitor = await CLMonitor("GeolocationArea\(id)")
                    await locationState.setMonitor(monitor)
                }
                let condition = CLMonitor.CircularGeographicCondition(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    radius: radius)
                await locationState.addMonitorCondition(condition, identifier: identifier)

                // keep alive task
                if let interval = `repeat`, interval > 0, keepAlive != KeepAliveType.none.rawValue {
                    await locationState.finishKeepAliveTask()
                    let keepAliveTask = Task { [weak self] in
                        guard let self = self else { return }
                        for await _ in AsyncTimerSequence(
                            interval: .seconds(interval), clock: .suspending)
                        {
                            if await !isRunning { break }
                            await sendKeepAlive()
                        }
                    }
                    await locationState.setKeepAliveTask(keepAliveTask)
                }

                do {
                    guard let events = await locationState.monitor?.events else {
                        print("Geolocation area monitoring not available.")
                        return
                    }
                    for try await event in events {
                        if Task.isCancelled { break }
                        if event.state == .satisfied {
                            await locationState.setIsInsideArea(true)
                            await sendEnter()
                        } else if event.state == .unsatisfied {
                            await locationState.setIsInsideArea(false)
                            await sendExit()
                        }
                    }
                } catch {
                    if !(error is CancellationError) {
                        print("Geolocation area monitoring error: \(error)")
                    }
                }
                await locationState.finishKeepAliveTask()
                return
            }

            do {
                if once {
                    if onceDelay > 0 {
                        try await Task.sleep(nanoseconds: UInt64(onceDelay * 1_000_000_000))
                    }
                    if await !isRunning { return }
                    locationManager?.requestLocation()
                }
                guard let interval = `repeat`, interval > 0 else {
                    return
                }
                for await _ in AsyncTimerSequence(interval: .seconds(interval), clock: .suspending)
                {
                    if await !isRunning { return }
                    locationManager?.requestLocation()
                }
            } catch is CancellationError {
                // Task was cancelled, do nothing
                return
            } catch {
                print("GeolocationNode execution error: \(error)")
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
        await locationState.removeMonitor(identifier: identifier)
        locationManager?.stopUpdateLocation()
        await locationState.finishKeepAliveTask()
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

    private func sendEnter() async {
        let payload: [String: String] = ["event": "enter"]
        let msg = NodeMessage(payload: payload)
        await send(msg: msg)
    }

    private func sendExit() async {
        let payload: [String: String] = ["event": "exit"]
        let msg = NodeMessage(payload: payload)
        await send(msg: msg)
    }

    // keep alive event sender
    private func sendKeepAlive() async {
        guard await isRunning else { return }

        // 現在位置を取得し、エリア内判定
        locationManager?.requestLocation()
        let location = await locationState.lastLocation
        let isInside: Bool
        if let location = location {
            let center = CLLocation(latitude: centerLat, longitude: centerLon)
            let distance = location.distance(from: center)
            isInside = distance <= radius
            await locationState.setIsInsideArea(isInside)
        } else {
            // 位置情報がなければ従来通りフラグで判定
            isInside = await locationState.isInsideArea
        }

        switch keepAlive {
        case KeepAliveType.inside.rawValue:
            if isInside {
                let payload: [String: String] = ["event": "keepalive_inside"]
                let msg = NodeMessage(payload: payload)
                await send(msg: msg)
            }
        case KeepAliveType.outside.rawValue:
            if !isInside {
                let payload: [String: String] = ["event": "keepalive_outside"]
                let msg = NodeMessage(payload: payload)
                await send(msg: msg)
            }
        default:
            let payload: [String: String] = [
                "event": isInside ? "keepalive_inside" : "keepalive_outside"
            ]
            let msg = NodeMessage(payload: payload)
            await send(msg: msg)
        }
    }

    /// For testing: simulate a CLMonitor event for area mode
    func simulateAreaEvent(state: CLMonitor.Event.State) async {
        if state == .satisfied {
            await sendEnter()
        } else if state == .unsatisfied {
            await sendExit()
        }
    }

    /// For testing: simulate a location update
    func simulateLocation(latitude: Double, longitude: Double) async {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        if let locationManager = locationManager?.getLocationManager() {
            self.locationManager(locationManager, didUpdateLocations: [location])
        }
    }

    // MARK: - CLLocationManagerDelegate

    internal func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        Task.detached { @Sendable [weak self] in
            guard let self = self else { return }

            guard await isRunning, let loc = locations.last else { return }
            // Debounce to prevent rapid-fire messages
            if let lastSent = await locationState.lastSentTime,
                Date().timeIntervalSince(lastSent) < 0.9
            {
                return
            }

            if mode == ModeType.area.rawValue {
                await locationState.setLastLocation(loc)
                await locationState.setLastSendTime(Date())
                return
            }

            let payload: [String: Double] = [
                "latitude": loc.coordinate.latitude,  // 緯度
                "longitude": loc.coordinate.longitude,  // 経度
            ]
            let msg = NodeMessage(payload: payload)
            await send(msg: msg)
            await locationState.setLastLocation(loc)
            await locationState.setLastSendTime(Date())
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("GeolocationNode error: \(error.localizedDescription)")
    }
}
