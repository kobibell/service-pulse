//
//  TCPChecker.swift
//  Service Pulse
//

import Foundation
import Network

struct TCPChecker {
    /// Parses "host:port", including bracketed IPv6 literals like "[::1]:8080".
    /// Returns nil when the format is invalid or the port is out of range.
    static func parseTarget(_ target: String) -> (host: String, port: UInt16)? {
        let trimmed = target.trimmingCharacters(in: .whitespaces)

        // Bracketed IPv6: [host]:port
        if trimmed.hasPrefix("[") {
            guard let close = trimmed.firstIndex(of: "]") else { return nil }
            let host = String(trimmed[trimmed.index(after: trimmed.startIndex)..<close])
            let rest = trimmed[trimmed.index(after: close)...]
            guard rest.hasPrefix(":"), let port = UInt16(rest.dropFirst()), !host.isEmpty else {
                return nil
            }
            return (host, port)
        }

        // host:port, split on the last colon. A bare (unbracketed) IPv6 literal
        // has multiple colons and is rejected here; it must use brackets.
        guard let lastColon = trimmed.lastIndex(of: ":") else { return nil }
        let host = String(trimmed[..<lastColon])
        let portString = trimmed[trimmed.index(after: lastColon)...]
        guard !host.isEmpty, !host.contains(":"), let port = UInt16(portString) else {
            return nil
        }
        return (host, port)
    }

    static func check(target: String) async -> (status: ServiceStatus, latencyMs: Double?) {
        guard let parsed = parseTarget(target), let portValue = NWEndpoint.Port(rawValue: parsed.port) else {
            return (.unknown, nil)
        }
        let host = parsed.host

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
