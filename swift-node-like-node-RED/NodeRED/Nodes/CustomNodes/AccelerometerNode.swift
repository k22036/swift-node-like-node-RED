import CoreMotion
import Foundation

/// Custom node that retrieves and sends device accelerometer information
final class AccelerometerNode: NSObject, Codable, Node {
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
        guard _type == NodeType.accelerometer.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Expected type to be 'accelerometer', but found \(_type)")
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

    var motionManager: CMMotionManager = CMMotionManager()
    weak var flow: Flow?
    var isRunning: Bool = false
    private var currentTask: Task<Void, Never>?
    private var lastSentTime: Date?

    func initialize(flow: Flow) {
        self.flow = flow
        isRunning = true
    }

    func execute() {
        // Prevent multiple executions
        if let task = currentTask, !task.isCancelled {
            print("AccelerometerNode: Already running, skipping execution.")
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
                    requestAccelerometer()
                }
                guard let interval = `repeat`, interval > 0 else {
                    return
                }
                while isRunning {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    if !isRunning { return }
                    requestAccelerometer()
                }
            } catch is CancellationError {
                // Task was cancelled, do nothing
                return
            } catch {
                print("AccelerometerNode: Error in task execution - \(error)")
                isRunning = false
                motionManager.stopAccelerometerUpdates()
                return
            }
        }
    }

    func terminate() async {
        isRunning = false
        currentTask?.cancel()
        motionManager.stopAccelerometerUpdates()

        if let task = currentTask {
            _ = await task.value  // Wait for the task to complete
        }
        currentTask = nil
    }

    deinit {
        isRunning = false
        currentTask?.cancel()
        motionManager.stopAccelerometerUpdates()
    }

    func receive(msg: NodeMessage) {
        // This node does not process incoming messages
    }

    func send(msg: NodeMessage) {
        flow?.routeMessage(from: self, message: msg)
    }

    private func requestAccelerometer() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.startAccelerometerUpdates(to: OperationQueue.current ?? OperationQueue.main) {
            [weak self] data, error in
            guard let self = self, self.isRunning, let accel = data?.acceleration else { return }
            // Debounce to prevent rapid-fire messages
            if let lastSent = self.lastSentTime, Date().timeIntervalSince(lastSent) < 0.1 {
                return
            }
            let payload: [String: Double] = [
                "x": accel.x,
                "y": accel.y,
                "z": accel.z,
            ]
            let msg = NodeMessage(payload: payload)
            self.send(msg: msg)
            self.lastSentTime = Date()
            self.motionManager.stopAccelerometerUpdates()
        }
    }

    /// For testing: simulate an accelerometer update
    func simulateAccelerometer(x: Double, y: Double, z: Double) {
        let payload: [String: Double] = ["x": x, "y": y, "z": z]
        let msg = NodeMessage(payload: payload)
        send(msg: msg)
    }
}
