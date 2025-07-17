import CoreLocation
import Foundation
import UIKit

/// Custom node that retrieves and sends device heading (direction) information
final class DirectionNode: NSObject, Codable, Node, CLLocationManagerDelegate {
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

  private var locationManager: CLLocationManager?
  weak var flow: Flow?
  var isRunning: Bool = false

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

  deinit {
    terminate()
  }

  func initialize(flow: Flow) {
    self.flow = flow
    isRunning = true
    locationManager = CLLocationManager()
    locationManager?.delegate = self
    locationManager?.requestWhenInUseAuthorization()
    locationManager?.startUpdatingHeading()
  }

  func execute() {
    Task {
      if once {
        if onceDelay > 0 {
          try await Task.sleep(nanoseconds: UInt64(onceDelay * 1_000_000_000))
        }
        if !isRunning { return }
        requestDirection()
      }
      guard let interval = `repeat`, interval > 0 else {
        return
      }
      while isRunning {
        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        if !isRunning { return }
        requestDirection()
      }
    }
  }

  /// Requests the current device heading
  private func requestDirection() {
    locationManager?.startUpdatingHeading()
  }

  func terminate() {
    isRunning = false
    locationManager?.stopUpdatingHeading()
    locationManager = nil
  }

  func receive(msg: NodeMessage) {
    // This node does not process incoming messages
  }

  func send(msg: NodeMessage) {
    flow?.routeMessage(from: self, message: msg)
  }

  /// Helper function to send heading message
  private func sendHeadingMessage(_ heading: Double) {
    let payload: [String: Double] = ["heading": heading]
    let msg = NodeMessage(payload: payload)
    send(msg: msg)
  }

  // CLLocationManagerDelegate
  func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
    guard isRunning else { return }
    sendHeadingMessage(newHeading.trueHeading)
    // Stop after retrieving the heading once
    locationManager?.stopUpdatingHeading()
  }

  func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
    return true
  }

  /// For testing: simulate a heading update
  func simulateHeading(_ heading: Double) {
    sendHeadingMessage(heading)
  }
}
