//
//  HTTPChecker.swift
//  Service Pulse
//

import Foundation

struct HTTPChecker {
    static func check(urlString: String) async -> (status: ServiceStatus, latencyMs: Double?, statusCode: Int?) {
        var resolvedString = urlString.trimmingCharacters(in: .whitespaces)
        if !resolvedString.contains("://") {
            resolvedString = "https://" + resolvedString
        }

        guard let url = URL(string: resolvedString) else {
            return (.unknown, nil, nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        // A health check has to hit the server every poll. Without this, URLSession
        // serves cacheable responses from its local cache, which reports ~0ms
        // latency and doesn't reflect whether the endpoint is actually live.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let start = Date()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let latencyMs = Date().timeIntervalSince(start) * 1000
            guard let httpResponse = response as? HTTPURLResponse else {
                return (.unknown, nil, nil)
            }
            let status: ServiceStatus = (200..<400).contains(httpResponse.statusCode) ? .up : .down
            return (status, latencyMs, httpResponse.statusCode)
        } catch {
            return (.down, nil, nil)
        }
    }
}
