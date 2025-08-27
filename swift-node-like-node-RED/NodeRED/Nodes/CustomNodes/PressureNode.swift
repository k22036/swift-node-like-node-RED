import AsyncAlgorithms
@preconcurrency import CoreMotion
import Foundation

private actor PressureState: NodeState, Sendable {
    fileprivate weak var flow: Flow?
    fileprivate var isRunning: Bool = false
    fileprivate var lastSentTime: Date?

    fileprivate var currentTask: Task<Void, Never>?

    fileprivate func setFlow(_ flow: Flow) {
        self.flow = flow
    }

    fileprivate func setIsRunning(_ running: Bool) {
        self.isRunning = running
    }

    fileprivate func setLastSentTime(_ time: Date) {
        self.lastSentTime = time
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

/// Custom node that retrieves and sends device pressure (barometric) information
final class PressureNode: NSObject, Codable, Node, Sendable {
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
        guard _type == NodeType.pressure.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Expected type to be 'pressure', but found \(_type)")
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

    private let state = PressureState()
    private let altimeter: CMAltimeter = CMAltimeter()

    var isRunning: Bool {
        get async {
            await state.isRunning
        }
    }

    func initialize(flow: Flow) async {
        await state.setFlow(flow)
        await state.setIsRunning(true)
    }

    func execute() async {
        // Prevent multiple concurrent executions
        if let task = await state.currentTask, !task.isCancelled {
            print("PressureNode: Already running, skipping execution.")
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
                    requestPressure()
                }
                guard let interval = `repeat`, interval > 0 else {
                    return
                }
                for await _ in AsyncTimerSequence(interval: .seconds(interval), clock: .suspending)
                {
                    if await !isRunning { return }
                    requestPressure()
                }
            } catch is CancellationError {
                // Task was cancelled, do nothing
                return
            } catch {
                print("PressureNode execution error: \(error)")
                await state.setIsRunning(false)
                altimeter.stopRelativeAltitudeUpdates()
            }
        }
        await state.setCurrentTask(currentTask)
    }

    func terminate() async {
        await state.setIsRunning(false)
        altimeter.stopRelativeAltitudeUpdates()
        await state.finishCurrentTask()
    }

    deinit {
        altimeter.stopRelativeAltitudeUpdates()
    }

    func receive(msg: NodeMessage) {
        // This node does not process incoming messages
    }

    func send(msg: NodeMessage) async {
        await state.flow?.routeMessage(from: self, message: msg)
    }

    private func requestPressure() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeter.startRelativeAltitudeUpdates(to: OperationQueue.main) { [weak self] data, error in
            Task { @Sendable [weak self] in
                guard let self = self, await self.isRunning, let data = data else { return }
                // Debounce to prevent rapid-fire messages
                if let lastSent = await self.state.lastSentTime,
                    Date().timeIntervalSince(lastSent) < 0.1
                {
                    return
                }
                // pressure: kPa -> hPa
                // swift-format-ignore: AlwaysUseLowerCamelCase
                let pressure_hPa = data.pressure.doubleValue * 10.0
                let payload: [String: Double] = ["pressure": pressure_hPa]
                let msg = NodeMessage(payload: payload)
                await self.send(msg: msg)
                await self.state.setLastSentTime(Date())
                self.altimeter.stopRelativeAltitudeUpdates()
            }
        }
    }

    /// For testing: simulate a pressure update
    // swift-format-ignore: AlwaysUseLowerCamelCase
    func simulatePressure(_ pressure_hPa: Double) async {
        let payload: [String: Double] = ["pressure": pressure_hPa]
        let msg = NodeMessage(payload: payload)
        await send(msg: msg)
    }
}
