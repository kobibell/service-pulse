//
//  Models.swift
//  Service Pulse
//

import Foundation

enum ServiceType: String, Codable, CaseIterable {
    case ping
    case docker
    case appleContainer
    case http
    case tcp

    var displayName: String {
        switch self {
        case .ping: return "Ping"
        case .docker: return "Docker"
        case .appleContainer: return "Mac Containers"
        case .http: return "HTTP"
        case .tcp: return "TCP Port"
        }
    }

    var symbolName: String {
        switch self {
        case .ping: return "dot.radiowaves.left.and.right"
        case .docker: return "shippingbox"
        case .appleContainer: return "cube.transparent"
        case .http: return "globe"
        case .tcp: return "point.3.connected.trianglepath.dotted"
        }
    }

    /// Mac Containers are the headline feature, so their icon gets an accent tint
    /// to stand out from the otherwise-monochrome service list.
    var isHighlighted: Bool {
        self == .appleContainer
    }
}

enum ServiceStatus: String, Codable {
    case up
    case down
    case unknown
}

enum OverallStatus {
    case allGood
    case degraded
    case down
    case unknown
}

struct Service: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var type: ServiceType
    var host: String
    var isPaused: Bool = false

    init(id: UUID = UUID(), name: String, type: ServiceType, host: String, isPaused: Bool = false) {
        self.id = id
        self.name = name
        self.type = type
        self.host = host
        self.isPaused = isPaused
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(ServiceType.self, forKey: .type)
        host = try container.decode(String.self, forKey: .host)
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
    }
}
