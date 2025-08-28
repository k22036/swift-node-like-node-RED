//
//  Tab.swift
//  swift-node-like-node-RED
//
//  Created by k22036kk on 2025/06/21.
//

final class Tab: Codable, Sendable {
    let id: String
    let type: String
    let label: String
    let disabled: Bool
    let info: String
    //    let env: [String: String]

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)

        let _type = try container.decode(String.self, forKey: .type)
        guard _type == FlowType.tab.rawValue else {
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Expected type to be 'tab', but found \(_type)")
        }
        self.type = _type

        self.label = try container.decode(String.self, forKey: .label)
        self.disabled = try container.decode(Bool.self, forKey: .disabled)
        self.info = try container.decode(String.self, forKey: .info)
        //        self.env = try container.decode([String: String].self, forKey: .env)
    }
}
