//
//  TCPChecker.swift
//  Service Pulse
//

import Foundation
import Network

struct TCPChecker {
    /// Expects "host:port". Returns nil status code components if the format is invalid.
    static func check(target: String) async -> (status: ServiceStatus, latencyMs: Double?) {
        let parts = target.split(separator: ":")
        guard parts.count == 2, let port = UInt16(parts[1]), let portValue = NWEndpoint.Port(rawValue: port) else {
            return (.unknown, nil)
        }
        let host = String(parts[0])

        let connection = NWConnection(host: NWEndpoint.Host(host), port: portValue, using: .tcp)
        let start = Date()

        return await withCheckedContinuation { continuation in
            var resumed = false
            let resume: (ServiceStatus, Double?) -> Void = { status, latency in
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: (status, latency))
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let latency = Date().timeIntervalSince(start) * 1000
                    resume(.up, latency)
                case .failed, .cancelled:
                    resume(.down, nil)
                default:
                    break
                }
            }

            connection.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                resume(.down, nil)
            }
        }
    }
}
