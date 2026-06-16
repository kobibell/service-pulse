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

/// The outcome of checking a single service, passed back from a concurrent
/// poll task to the main actor for application to published state.
struct CheckResult: Sendable {
    let id: UUID
    let status: ServiceStatus
    let latency: Double?
    let statusCode: Int?
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
    /// For HTTP checks only: accept self-signed / untrusted certificates.
    var allowInsecureTLS: Bool = false

    init(id: UUID = UUID(), name: String, type: ServiceType, host: String, isPaused: Bool = false, allowInsecureTLS: Bool = false) {
        self.id = id
        self.name = name
        self.type = type
        self.host = host
        self.isPaused = isPaused
        self.allowInsecureTLS = allowInsecureTLS
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(ServiceType.self, forKey: .type)
        host = try container.decode(String.self, forKey: .host)
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        // Added after the first releases, so older saved configs won't have it.
        allowInsecureTLS = try container.decodeIfPresent(Bool.self, forKey: .allowInsecureTLS) ?? false
    }
}

/// Decodes to a `Service?`, yielding nil instead of throwing when an individual
/// entry can't be decoded. Lets `load()` skip a single unreadable service (for
/// example one whose type was written by a newer build) rather than dropping the
/// entire saved list.
struct FailableService: Decodable {
    let service: Service?

    init(from decoder: Decoder) throws {
        service = try? Service(from: decoder)
    }
}
