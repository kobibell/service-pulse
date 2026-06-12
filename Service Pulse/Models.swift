//
//  Models.swift
//  Service Pulse
//

import Foundation

enum ServiceType: String, Codable, CaseIterable {
    case ping
    case docker

    var displayName: String {
        switch self {
        case .ping: return "Ping"
        case .docker: return "Docker"
        }
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
}
