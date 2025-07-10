import Foundation
import CoreMotion

/// Custom node that retrieves and sends device attitude (pitch, roll, yaw) information
final class AttitudeNode: NSObject, Codable, Node {
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
        guard _type == NodeType.attitude.rawValue else {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container,
                                                   debugDescription: "Expected type to be 'attitude', but found \(_type)")
        }
        self.type = _type
        
        self.z = try container.decode(String.self, forKey: .z)
        self.name = try container.decode(String.self, forKey: .name)
        
        if let repeatValStr = try? container.decode(String.self, forKey: .repeat), let val = Double(repeatValStr) {
            self.`repeat` = val
        } else if let val = try? container.decode(Double.self, forKey: .repeat) {
            self.`repeat` = val
        } else {
            self.`repeat` = nil
        }
        
        self.once = try container.decode(Bool.self, forKey: .once)
        
        if let delayStr = try? container.decode(String.self, forKey: .onceDelay), let val = Double(delayStr) {
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
    private var lastSentTime: Date?
    
    deinit {
        isRunning = false
        motionManager.stopDeviceMotionUpdates()
    }
    
    func initialize(flow: Flow) {
        self.flow = flow
        isRunning = true
        execute()
    }
    
    func execute() {
        Task {
            if once {
                if onceDelay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(onceDelay * 1_000_000_000))
                }
                if !isRunning { return }
                requestAttitude()
            }
            guard let interval = `repeat`, interval > 0 else {
                return
            }
            while isRunning {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if !isRunning { return }
                requestAttitude()
            }
        }
    }
    
    func terminate() {
        isRunning = false
        motionManager.stopDeviceMotionUpdates()
    }
    
    func receive(msg: NodeMessage) {
        // This node does not process incoming messages
    }
    
    func send(msg: NodeMessage) {
        flow?.routeMessage(from: self, message: msg)
    }
    
    private func requestAttitude() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.startDeviceMotionUpdates(to: OperationQueue.current ?? OperationQueue.main) { [weak self] data, error in
            guard let self = self, self.isRunning, let attitude = data?.attitude else { return }
            // Debounce to prevent rapid-fire messages
            if let lastSent = self.lastSentTime, Date().timeIntervalSince(lastSent) < 0.1 {
                return
            }
            let payload: [String: Double] = [
                "pitch": attitude.pitch,
                "roll": attitude.roll,
                "yaw": attitude.yaw
            ]
            let msg = NodeMessage(payload: payload)
            self.send(msg: msg)
            self.lastSentTime = Date()
            self.motionManager.stopDeviceMotionUpdates()
        }
    }
    
    /// For testing: simulate an attitude update
    func simulateAttitude(pitch: Double, roll: Double, yaw: Double) {
        let payload: [String: Double] = ["pitch": pitch, "roll": roll, "yaw": yaw]
        let msg = NodeMessage(payload: payload)
        send(msg: msg)
    }
}
